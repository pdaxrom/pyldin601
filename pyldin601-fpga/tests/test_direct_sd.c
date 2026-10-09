// Execute UniAS ROM code through original BIOS banked SWI dispatch.
// Real SPI byte protocol, CRC16 and SDHC/SDSC sectors; no INT17 host hook.
#define DIRECT_SD_FIXTURE 1
#define NATIVE_STABILITY_MAIN unused_stability_main
#include "test_native_stability.c"
#undef NATIVE_STABILITY_MAIN
static unsigned calls;
static unsigned invoke(unsigned op,unsigned drive,unsigned track,unsigned head,unsigned sector,unsigned buf){
 unsigned char*r=MC6800GetCpuRam();unsigned saved_page=page;
 r[0x200]=drive;r[0x201]=track;r[0x202]=head;r[0x203]=sector;r[0x204]=buf>>8;r[0x205]=buf;
 r[0x210]=0x3f;r[0x211]=0x5f;r[0x212]=0x01;
 PC=0x210;SP=0xbdff;A=op;B=0x53;X=0x200;i=0;
 uint64_t limit=virtual_cycles+20000000;
 do{until(virtual_cycles+1);if(virtual_cycles>limit){dump();fprintf(stderr,"INT17 timeout op=%02x\n",op);exit(1);}}while(PC!=0x212);
 if(page!=saved_page||SP!=0xbdff||X!=0x200||(spi_control&2)==0||fdc_port_accesses){fprintf(stderr,"SWI/page/stack/CS lost op=%02x page=%02x SP=%04x X=%04x\n",op,page,SP,X);exit(1);}
 calls++;return A;
}
static void require(int yes,const char*what){if(!yes){fprintf(stderr,"FAIL %s\n",what);exit(1);}}
static void put_le32(unsigned char*p,uint32_t v){for(unsigned n=0;n<4;n++)p[n]=v>>(n*8);}
int main(int argc,char**argv){
 if(argc!=5)return 2;
 model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");sdsc=!strcmp(argv[4],"sdsc");
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);
 require(n==0x51a00,"ROM size");memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,0x51800);free(rom);
 image=load(argv[1],&image_size);memcpy(config+64,image+462,32);
 unsigned char*original=malloc(image_size);memcpy(original,image,image_size);
 committed=1;MC6800Init();MC6800Reset();until(60000000);
 unsigned char*r=MC6800GetCpuRam();
 // UniDOS wraps INT17 and installs its saved BIOS vector at INT5F.
 // Register the same entry through the original INT2F service.
 unsigned entry=physical[0x16011]*256+physical[0x16012];
 r[0x210]=0x3f;r[0x211]=0x2f;r[0x212]=1;
 PC=0x210;SP=0xbdff;A=0x5f;B=11;X=entry;i=0;
 do{until(virtual_cycles+1);}while(PC!=0x212);
 require((r[0xedaf]&15)==11&&r[0xeebe]*256+r[0xeebf]==entry,"native INT2F registers banked INT17 entry");
 require(r[0xbf99]&&r[0xbf8b]&&r[0xbf97],"both MBR/BPB partitions mounted");
 require(invoke(0x80,0,0,0,1,0x3000)==0,"reset/mount");
 for(unsigned drive=0;drive<2;drive++){
  unsigned entry=462+16*drive,start=le32(image+entry+8),len=le16(image+start*512+19);
  unsigned spt=le16(image+start*512+24),heads=le16(image+start*512+26);
  unsigned rels[]={0,1,len/2,len-1};
  for(unsigned t=0;t<4;t++){
   unsigned rel=rels[t],sec=rel%spt+1,h=(rel/spt)%heads,tr=rel/(spt*heads);
   runtime_read_delay=7;
   require(invoke(1,drive,tr,h,sec,0x3000)==0,"read");
   require(!memcmp(r+0x3000,image+(start+rel)*512,512),"read payload/CHS");
   require(invoke(3,drive,tr,h,sec,0x3000)==0&&B==tr,"seek ID");
   for(unsigned b=0;b<512;b++)r[0x3000+b]=(b*31+drive+t)&255;
   sd_busy_reads=9;sd_busy_transition=3;
   require(invoke(2,drive,tr,h,sec,0x3000)==0,"write/data token/busy");
   require(!memcmp(r+0x3000,image+(start+rel)*512,512),"written payload");
   memcpy(image+(start+rel)*512,original+(start+rel)*512,512);
  }
  unsigned before=sd_reads,writes=sd_writes;
  require(invoke(1,drive,0,0,0,0x3000)!=0,"sector zero rejected");
  require(invoke(2,drive,0,heads,1,0x3000)!=0,"head outside partition rejected");
  unsigned tr=len/(spt*heads),h=(len/spt)%heads,sec=len%spt+1;
  require(invoke(1,drive,tr,h,sec,0x3000)!=0,"one past end rejected");
  require(sd_reads==before&&sd_writes==writes,"invalid addresses issue no disk I/O");
  // Read faults must return, leave CS high and permit the next good command.
  runtime_bad_crc=1;require(invoke(1,drive,0,0,1,0x3000)==0x10,"CRC rejection");runtime_bad_crc=0;
  runtime_no_token=1;require(invoke(1,drive,0,0,1,0x3000)!=0,"token timeout");runtime_no_token=0;
  runtime_r1=4;require(invoke(1,drive,0,0,1,0x3000)!=0,"R1 error");runtime_r1=0;
  sd_deny_write=1;require(invoke(2,drive,0,0,1,0x3000)==0x40,"write rejection");sd_deny_write=0;
  require(invoke(1,drive,0,0,1,0x3000)==0,"recovery read");
  // Format only the specified C/H/R/N sector, using the BIOS fill parameter.
  r[0x3200]=1;r[0x3201]=0;r[0x3202]=2;r[0x3203]=2;
  require(invoke(4,drive,1,0,1,0x3200)==0,"format ID");
  unsigned format_lba=start+spt*heads+1;
  unsigned fill=r[(r[0xed26]*256+r[0xed27])+7];
  for(unsigned b=0;b<512;b++)require(image[format_lba*512+b]==fill,"format fill");
  memcpy(image+format_lba*512,original+format_lba*512,512);
  r[0x3203]=1;before=sd_writes;require(invoke(4,drive,1,0,1,0x3200)!=0&&sd_writes==before,"bad format size writes nothing");
 }
 // All successful writes restored: MBR, boot partition, gaps and other sectors
 // must be byte-identical, proving no write escaped either data partition.
 require(!memcmp(image,original,image_size),"complete disk unchanged outside requested sectors");
 // The original boot-B flag swaps the two logical drives without copying.
 config[24]=1;require(invoke(0x80,0,0,0,1,0x3000)==0,"boot-B remount");
 for(unsigned drive=0;drive<2;drive++){
  unsigned start=le32(original+462+16*(drive^1)+8);
  require(invoke(1,drive,0,0,1,0x3000)==0&&!memcmp(r+0x3000,image+start*512,512),"boot-B logical swap");
 }
 config[24]=0;
 // Corrupt MBR/BPB fields independently. Reset reparses the on-card layout;
 // rejected drives must never issue a sector write, even after a good mount.
 unsigned a_start=le32(original+470),b_start=le32(original+486);
 for(unsigned fault=0;fault<21;fault++){
  memcpy(image,original,image_size);unsigned char*bpb=image+a_start*512;
  switch(fault){
   case 0:image[510]=0;break;
   case 1:put_le32(image+470,le32(image+454));break;
   case 2:put_le32(image+486,a_start+le32(image+474)/2);break;
   case 3:put_le32(image+470,0xfffffff0);put_le32(image+474,100);break;
   case 4:put_le32(image+474,0);break;
   case 5:image[466]=6;break;
   case 6:bpb[510]=0;break;
   case 7:bpb[11]=0;bpb[12]=4;break;
   case 8:bpb[13]=3;break;
   case 9:bpb[26]=3;break;
   case 10:bpb[24]=bpb[25]=0;break;
   case 11:bpb[24]=0;bpb[25]=1;break;
   case 12:bpb[19]=bpb[20]=255;break;
   case 13:bpb[16]=0;break;
   case 14:bpb[14]=bpb[15]=0;break;
   case 15:bpb[17]=bpb[18]=0;break;
   case 16:bpb[22]=bpb[23]=0;break;
   case 17:bpb[19]=bpb[20]=0;break;
   case 18:image[450]=1;break;
   case 19:put_le32(image+454,0);break;
   case 20:put_le32(image+458,0);break;
  }
  invoke(0x80,0,0,0,1,0x3000);unsigned before=sd_writes;
  require(!r[0xbf8b],"corrupt partition not mounted");
  require(invoke(2,0,0,0,1,0x3000)!=0&&sd_writes==before,"corrupt layout cannot write");
  if(fault==2)require(!r[0xbf97],"overlapping partitions both rejected");
 }
 memcpy(image,original,image_size);
 require(invoke(0x80,0,0,0,1,0x3000)==0,"valid layout recovery");
 require(invoke(1,1,0,0,1,0x3000)==0&&!memcmp(r+0x3000,image+b_start*512,512),"valid B after recovery");
 missing_sd=1;require(invoke(1,0,0,0,1,0x3000)!=0,"missing card");missing_sd=0;
 require(invoke(1,0,0,0,1,0x3000)==0,"card returns");
 unsigned saved_page=r[0xedf0]&0xf0;MC6800Reset();until(virtual_cycles+6000000);
 require((r[0xedf0]&0xf0)==saved_page,"warm reset reinstalls extension");
 printf("PASS UniAS banked INT17 %s/%s/%s: %u calls, CRC, writes, format, CHS bounds, boot-B swap, 21 corrupt MBR/BPB layouts, recovery, IRQ/CS/ROM pages, warm reset; zero FDC accesses\n",argv[2],argv[3],argv[4],calls);
 return 0;
}
