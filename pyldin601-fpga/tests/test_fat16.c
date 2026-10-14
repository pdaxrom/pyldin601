// Real native file API on a fragmented FAT16 volume. The oracle is on-disk
// little-endian FAT/directory data, independent of the assembly implementation.
#define DOS_API_CYCLES 500000000
#define PARTITION_FIXTURE 1
#define COMPACT_FIXTURE 1
#define DIRECT_SD_FIXTURE 1
#define ROMDISK_MAIN unused_romdisk_main
#include "test_romdisk_unidos.c"
#undef ROMDISK_MAIN
#include "../build/partitions/kernel_labels.h"

static unsigned open_file(const char*name,unsigned mode,unsigned buffer){
 unsigned char*r=MC6800GetCpuRam();strcpy((char*)r+0x8000,name);
 word_at(0x8100,0x8000);word_at(0x8102,buffer);
 unsigned status=invoke(0x4a,mode,0,0x8100);
 if(status)fprintf(stderr,"OPEN %s: %u\n",name,status);
 require(status==0,"open FAT16 file");return result_b;
}
static void seek_file(unsigned h,unsigned pos,unsigned method){
 unsigned char*r=MC6800GetCpuRam();r[0x8104]=pos>>24;r[0x8105]=pos>>16;
 r[0x8106]=pos>>8;r[0x8107]=pos;
 require(invoke(0x50,h,method,0x8104)==0,"seek FAT16 file");
}
static unsigned create_file(const char*name){
 unsigned char*r=MC6800GetCpuRam();strcpy((char*)r+0x8000,name);
 word_at(0x8100,0x8000);word_at(0x8102,0);
 unsigned status=invoke(0x4b,0,0,0x8100);if(status)fprintf(stderr,"CREATE %s: %u\n",name,status);
 require(status==0,"create FAT16 file");return result_b;
}
static void write_bytes(unsigned h,const unsigned char*data,unsigned size){
 unsigned char*r=MC6800GetCpuRam();
 for(unsigned off=0;off<size;){
  unsigned n=size-off>731?731:size-off;memcpy(r+0x4000,data+off,n);
  word_at(0x8100,0x4000);word_at(0x8102,n);
  unsigned status=invoke(0x4d,h,0,0x8100);
  if(status)fprintf(stderr,"WRITE off=%u: %u\n",off,status);
  require(status==0&&result_x==n,"write FAT16 data");off+=n;
 }
}
static void named_call(unsigned op,const char*name){
 unsigned char*r=MC6800GetCpuRam();strcpy((char*)r+0x8000,name);
 require(invoke(op,0,0,0x8000)==0,"native pathname operation");
}
static void read_check(const char*name,const unsigned char*expected,unsigned size,unsigned buffer){
 unsigned char*r=MC6800GetCpuRam();unsigned h=open_file(name,1,buffer);
 require(invoke(0x51,h,0,0x8110)==0,"native size call");
 require(((unsigned)r[0x8110]<<24|r[0x8111]<<16|r[0x8112]<<8|r[0x8113])==size,"FAT16 file size");
 for(unsigned off=0;off<size;){
  unsigned n=size-off>731?731:size-off;word_at(0x8100,0x4000);word_at(0x8102,n);
  require(invoke(0x4c,h,0,0x8100)==0&&result_x==n,"FAT16 partial read");
  if(memcmp(r+0x4000,expected+off,n)){
   unsigned k=0;while(k<n&&r[0x4000+k]==expected[off+k])k++;
   fprintf(stderr,"%s mismatch at %u+%u: got=%02x expected=%02x sector_hi=%04x\n",name,off,k,r[0x4000+k],expected[off+k],r[UK_SEC_HI]*256+r[UK_SEC_HI+1]);
   unsigned fs=r[UK_FS_STATE]*256+r[UK_FS_STATE+1];
   unsigned hp=r[UK_RWF_HNDL]*256+r[UK_RWF_HNDL+1];
   fprintf(stderr,"handle=%u side:",h);for(unsigned j=0;j<6;j++)fprintf(stderr," %02x",r[hp+48+j]);fputc('\n',stderr);
   fprintf(stderr,"handle=%04x cluster=%02x%02x index=%u low=%02x%02x full:",hp,r[hp+43],r[hp+44],r[hp+45],r[hp+46],r[hp+47]);
   for(unsigned j=0;j<7;j++)fprintf(stderr," %02x",r[UK_FULLTABLE+j]);fputc('\n',stderr);
   fprintf(stderr,"ctx:");for(unsigned j=0;j<50;j++)fprintf(stderr," %02x",r[fs+100+j]);fputc('\n',stderr);
  }
  require(!memcmp(r+0x4000,expected+off,n),"FAT16 partial data matches oracle");off+=n;
 }
 unsigned positions[]={0,511,512,2047,2048,4096,65535,65536};
 for(unsigned k=0;k<sizeof positions/sizeof*positions;k++)if(positions[k]+512<=size){
  seek_file(h,positions[k],0);word_at(0x8100,0x4000);word_at(0x8102,512);
  require(invoke(0x4c,h,0,0x8100)==0&&result_x==512,"FAT16 seek/read");
  require(!memcmp(r+0x4000,expected+positions[k],512),"FAT16 seek data matches oracle");
 }
 require(invoke(0x4e,h,0,0)==0,"close FAT16 input");
}
static unsigned bank_init_pc,bank_fault;
static void bank_fault_hook(void){
 if(page==(bank_fault>=5?10:11)&&PC==bank_init_pc){
  unsigned char*r=MC6800GetCpuRam();
  if(bank_fault==1){unsigned state=r[0xefca]*256+r[0xefcb];r[state+6]=0;}
  if(bank_fault==2)r[0xefd0]=r[0xefd1]=0;
  if(bank_fault==3||bank_fault==4){
   const unsigned char unavailable[]={0x86,bank_fault==3?1:0,0x97,6,0x39};memcpy(r+0x306,unavailable,sizeof unavailable);
   word_at(0xefd0,0x306);r[0xedf4]&=0x0f;
  }
  if(bank_fault>=5){
   size_t count;unsigned char*handler=load("build/fat16/file-cache-fault.bin",&count);
   memcpy(r+0x306,handler,count);free(handler);r[0x305]=bank_fault==5?1:0;
   word_at(0xefd0,0x306);r[0xedf4]&=0x0f;
  }
  native_step_hook=NULL;
 }
}
static void wide_fat12(void){
 unsigned char*r=MC6800GetCpuRam();size_t size;
 unsigned char*expected=load("build/fat16/wide12.expected",&size);
 read_check("C:WIDE.BIN",expected,size,0);free(expected);
 unsigned char data[97777];for(unsigned k=0;k<sizeof data;k++)data[k]=(k*23^(k>>9)^0x56)&255;
 unsigned h=create_file("C:WRITE.BIN");write_bytes(h,data,sizeof data);
 seek_file(h,4567,0);require(invoke(0x6c,h,0,0)==0&&invoke(0x4e,h,0,0)==0,"wide FAT12 truncate/close");
 strcpy((char*)r+0x8000,"C:WRITE.BIN");strcpy((char*)r+0x8040,"C:RENAMED.BIN");word_at(0x8100,0x8000);word_at(0x8102,0x8040);
 require(invoke(0x56,0,0,0x8100)==0,"rename on a high-address FAT12 root");
 read_check("C:RENAMED.BIN",data,4567,0);named_call(0x4f,"C:RENAMED.BIN");
 named_call(0x48,"C:NEWDIR");named_call(0x49,"C:NEWDIR");
 require(invoke(0x52,2,0,0x8110)==0,"wide FAT12 free space");
 unsigned free_bytes=((unsigned)r[0x8110]<<24)|(r[0x8111]<<16)|(r[0x8112]<<8)|r[0x8113];
 require(free_bytes==(1527-342)*65536u,"SPC128 free-space arithmetic");
 require(invoke(0xeb,3,2,0)==0,"wide FAT12 descriptor");unsigned descriptor=result_x;
 word_at(descriptor+26,341);word_at(descriptor+28,342);
 require(invoke(0xe9,2,0,descriptor)==0,"odd FAT12 entry straddling sector");
 word_at(descriptor+26,682);word_at(descriptor+28,0xfff);
 require(invoke(0xe9,2,0,descriptor)==0&&invoke(0xeb,2,2,0)==0,"even FAT12 entry straddling sector");
 unsigned char*v=image+40960*512,*fat=v+65535*512;
 require(fat_next(fat,340)==0xfff&&fat_next(fat,341)==342&&fat_next(fat,342)==682&&fat_next(fat,682)==0xfff&&fat_next(fat,683)==0,"FAT12 adjacent nibbles preserved");
 require(!memcmp(fat,fat+512*512,512*512),"wide FAT12 mirrors agree");
 FILE*f=fopen("build/fat16/wide12-after.img","wb");require(f&&fwrite(v,1,262144*512,f)==262144*512&&!fclose(f),"save wide FAT12 oracle volume");
 require(!resets&&!fdc_port_accesses,"wide FAT12 makes no reset/FDC access");
 printf("PASS wide FAT12: BPB32, reserved=65535, SPF=512, SPC128, high sectors, split entries, write/truncate/rename/delete/mkdir/free-space\n");
}
int main(int argc,char**argv){
 if(argc!=5&&argc!=6)return 2;model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");sdsc=!strcmp(argv[4],"sdsc");
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 const char*rom_directory=getenv("FAT_TEST_ROMS");char rom_path[256];
 snprintf(rom_path,sizeof rom_path,"%s/%s",rom_directory?rom_directory:"build",model_a?"rom-a.reference":"rom.reference");
 size_t n;unsigned char*rom=load(rom_path,&n);
 memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 if(argc==6){
  if(!strcmp(argv[5],"no-ram"))ram_hardware_missing=1;
  if(!strcmp(argv[5],"no-e5"))memset(physical+0x1c000,255,8192);
  if(!strcmp(argv[5],"exhausted")||!strcmp(argv[5],"no-e8")||!strcmp(argv[5],"no-copy")||!strcmp(argv[5],"bad-copy")||!strcmp(argv[5],"no-file-copy")||!strcmp(argv[5],"bad-file-copy")){
   bank_fault=!strcmp(argv[5],"exhausted")?1:!strcmp(argv[5],"no-e8")?2:!strcmp(argv[5],"no-copy")?3:!strcmp(argv[5],"bad-copy")?4:!strcmp(argv[5],"no-file-copy")?5:6;
   FILE*f=fopen(bank_fault>=5?"build/partitions/PARTS.ROM.LST":"build/partitions/SD.ROM.LST","r");char line[256];require(f!=NULL,"banked listing");
   while(fgets(line,sizeof line,f))if(sscanf(line,bank_fault>=5?"FILE_CACHE_INITIALIZE =$%x":"FC_BANK_INITIALIZE =$%x",&bank_init_pc)==1)break;
   fclose(f);require(bank_init_pc>=0xc000,"bank constructor address");native_step_hook=bank_fault_hook;
  }
 }
 image=load(argv[1],&image_size);committed=1;MC6800Init();MC6800Reset();until(60000000);
 key(0x1c);key(0x1c);prompt_wait();watch_resets=1;
 if(bank_fault>=3)word_at(0xefd0,0xf640);
 unsigned char*r=MC6800GetCpuRam();unsigned work=r[0xbf80]*256+r[0xbf81];
 unsigned banked=r[UK_FS_AREA+UK_FS_BANK]==1;
#ifdef EXPECT_FAT_RAMMAN
 require(banked==((argc==5||!strcmp(argv[5],"wide12")||bank_fault>=5)&&EXPECT_FAT_RAMMAN),"optional banked cache selection/fallback");
#endif
 unsigned file_banked=r[UK_FS_AREA+UK_FS_FILE_FLAG]==1;
 require(file_banked==(banked&&bank_fault<5),"file caches independently select banked mode or RAM fallback");
 unsigned header=r[work+512+72+12]*256+r[work+512+72+13];
 require((r[header+9]*256+r[header+10]-header)==(banked?27:539),"banked private header saves 512 bytes of CPU RAM");
 if(file_banked)require(header==UK_FS_HEADER_POOL,"C header/current-directory occupy reclaimed buffer instead of heap");
 if(banked){
  require(invoke(0xe5,0,0,0)==1&&result_b==110,"one system-owned RAMMAN bank");
  require(invoke(0xe5,3,0,0)==0&&invoke(0xe5,0,0,0)==1&&result_b==110,"application cleanup preserves system FAT lease");
 }
 if(bank_fault==3||bank_fault==4)require(invoke(0xe5,0,0,0)==1&&result_b==111,"failed bank-copy probe releases lease");
 require(r[work+512+11]==255&&r[work+512+24+11]==0&&r[work+512+48+11]==1&&r[work+512+72+11]==2,
         "bootstrap stays hidden and A/B/C letters are preserved");
 unsigned pool_heap=r[0xee1e]*256+r[0xee1f];
 command("b:mount sd0:part1");require(contains("Mounted as D"),"native utility mounts bootstrap as D");
 command("b:umount d:");require(contains("Unmounted."),"native utility unmounts bootstrap");
 if(file_banked)require(r[0xee1e]*256+r[0xee1f]==pool_heap,"pooled mount does not retain utility or allocate heap metadata");

 // Handle expansion allocates resident memory and relocates the native stack.
 // Exercise it in the real shell before switching to an independent API stack.
 command("handles 32");require(r[UK_N_HANDLES]==32,"expand native handle list");
 PC=0x212;SP=0x7000;r[0]=0;
 require(invoke(0xea,0,0,0)==1&&invoke(0xea,3,0,0)==1,"reject invalid full-sector operations before dereferencing descriptor");
 require(invoke(0xeb,7,0,0)==1,"reject unknown filesystem control operation");
 if(argc==6&&!strcmp(argv[5],"wide12")){wide_fat12();return 0;}
 unsigned char*high=load("build/fat16/high.expected",&n);read_check("C:HICHAIN.BIN",high,n,0);free(high);
 // READ of 97 bytes forces cached partial I/O, rather than aligned SD bypass.
 unsigned cache0=open_file("C:HICHAIN.BIN",1,0),cache1=open_file("C:ALIAS.BIN",1,0);
 unsigned h0=r[UK_FILE_HANDLES]*256+r[UK_FILE_HANDLES+1];
 for(unsigned k=0;k<cache0;k++)h0=r[h0]*256+r[h0+1];
 unsigned h1=r[UK_FILE_HANDLES]*256+r[UK_FILE_HANDLES+1];
 for(unsigned k=0;k<cache1;k++)h1=r[h1]*256+r[h1+1];
 require(r[h0+39]*256+r[h0+40]!=r[h1+39]*256+r[h1+40],"default caches retain separate logical identities");
 high=load("build/fat16/high.expected",&n);unsigned char*alias_cache=load("build/fat16/alias.expected",&n);
 unsigned char pooled_headers[5*93];if(file_banked)memcpy(pooled_headers,r+UK_FS_HEADER_POOL,sizeof pooled_headers);
 for(unsigned k=0;k<12;k++)for(unsigned j=0;j<2;j++){
  unsigned handle=j?cache1:cache0;seek_file(handle,k*97,0);
  word_at(0x8100,0x4000);word_at(0x8102,97);
  require(invoke(0x4c,handle,0,0x8100)==0&&result_x==97&&!memcmp(r+0x4000,(j?alias_cache:high)+k*97,97),"interleaved default caches preserve partial sectors");
 }
 if(file_banked)require(!memcmp(pooled_headers,r+UK_FS_HEADER_POOL,sizeof pooled_headers),"cache switches never overwrite reclaimed metadata");
 require(invoke(0x4e,cache1,0,0)==0&&invoke(0x4e,cache0,0,0)==0,"close both logical default caches");free(high);free(alias_cache);
 // Both default caches may contain dirty data while directory operations
 // repeatedly select the first window. Commit must retain both generations.
 unsigned dirty0=create_file("C:CACHEA.BIN"),dirty1=create_file("C:CACHEB.BIN");
 unsigned char bytes0[388],bytes1[388];for(unsigned k=0;k<388;k++){bytes0[k]=k*3+7;bytes1[k]=k*11+9;}
 for(unsigned k=0;k<4;k++){write_bytes(dirty0,bytes0+k*97,97);write_bytes(dirty1,bytes1+k*97,97);}
 named_call(0x48,"C:CACHEDIR");named_call(0x49,"C:CACHEDIR");
 require(invoke(0x5a,dirty0,0,0)==0&&invoke(0x5a,dirty1,0,0)==0,"commit both dirty default caches after directory window changes");
 require(invoke(0x4e,dirty1,0,0)==0&&invoke(0x4e,dirty0,0,0)==0,"close both default writers");
 read_check("C:CACHEA.BIN",bytes0,388,0);read_check("C:CACHEB.BIN",bytes1,388,0);
 named_call(0x4f,"C:CACHEA.BIN");named_call(0x4f,"C:CACHEB.BIN");
 // A custom cache shared by handles must keep one high-word key through
 // close/reopen and slot reuse, even when both files have equal low sectors.
 memset(r+0x9000,0,517);r[0x9200]=255;
 unsigned shared0=open_file("C:HICHAIN.BIN",1,0x9000),shared1=open_file("C:ALIAS.BIN",1,0x9000);
 word_at(0x8100,0x4000);word_at(0x8102,512);
 require(invoke(0x4c,shared0,0,0x8100)==0,"fill shared high cache");
 require(invoke(0x4e,shared0,0,0)==0,"close first shared-buffer owner");
 require(invoke(0x4c,shared1,0,0x8100)==0,"replace shared cache from an aliased low sector");
 unsigned char*alias=load("build/fat16/alias.expected",&n);require(!memcmp(r+0x4000,alias,512),"alias fixture data");free(alias);
 shared0=open_file("C:HICHAIN.BIN",1,0x9000);
 word_at(0x8100,0x4000);word_at(0x8102,512);
 require(invoke(0x4c,shared0,0,0x8100)==0,"reopened shared cache");
 high=load("build/fat16/high.expected",&n);require(!memcmp(r+0x4000,high,512),"shared high-word key survives handle slot reuse");free(high);
 require(invoke(0x4e,shared0,0,0)==0&&invoke(0x4e,shared1,0,0)==0,"close shared-cache handles");
 unsigned char*inner=load("build/fat16/inner.expected",&n);read_check("C:HIDIR\\INNER.BIN",inner,n,0);
 // Force handle expansion and exercise a caller-supplied cache as well.
 memset(r+0x9000,0,517);r[0x9200]=255;
 read_check("C:HIDIR\\INNER.BIN",inner,n,0x9000);free(inner);
 // Reclaim cache records after more than 32 distinct caller buffers. The
 // old 9000 buffer has been freed/reused as unrelated caller data: eviction
 // must never write to it. Keep another C: file open throughout the test.
 memset(r+0x9000,0x5a,517);unsigned keep=open_file("C:ALIAS.BIN",1,0);
 high=load("build/fat16/high.expected",&n);
 for(unsigned k=0;k<40;k++){
  unsigned buffer=0x1800+k*517;memset(r+buffer,0,517);r[buffer+512]=255;
  unsigned temporary=open_file("C:HICHAIN.BIN",1,buffer);
  word_at(0x8100,0x7d00);word_at(0x8102,512);
  require(invoke(0x4c,temporary,0,0x8100)==0&&!memcmp(r+0x7d00,high,512),"caller buffer map lookup/reclamation");
  require(invoke(0x4e,temporary,0,0)==0,"close temporary cache owner");
 }
 free(high);for(unsigned k=0;k<517;k++)require(r[0x9000+k]==0x5a,"eviction preserves freed caller-buffer memory");
 require(invoke(0x4e,keep,0,0)==0,"close retained cache-test handle");
 // Sector 65535 -> 65536 falls inside LOWFILL's existing contiguous chain.
 // Exercise both aligned transfers and partial cached writes over the carry.
 unsigned wrap_handle=open_file("C:LOWFILL.BIN",3,0),wrap_position=(65535u-545u)*512u;
 unsigned char wrap_data[1024],zeros[1024]={0};for(unsigned k=0;k<sizeof wrap_data;k++)wrap_data[k]=k*7+0x39;
 seek_file(wrap_handle,wrap_position,0);word_at(0x8100,0x4000);word_at(0x8102,1024);
 require(invoke(0x4c,wrap_handle,0,0x8100)==0&&result_x==1024&&!memcmp(r+0x4000,zeros,1024),"read across sector low-word carry");
 seek_file(wrap_handle,wrap_position,0);write_bytes(wrap_handle,wrap_data,1024);
 require(invoke(0x5a,wrap_handle,0,0)==0,"commit across sector low-word carry");
 seek_file(wrap_handle,wrap_position,0);word_at(0x8100,0x4000);word_at(0x8102,1024);
 require(invoke(0x4c,wrap_handle,0,0x8100)==0&&!memcmp(r+0x4000,wrap_data,1024),"data matches over sector 65535/65536");
 seek_file(wrap_handle,wrap_position,0);write_bytes(wrap_handle,zeros,1024);
 require(invoke(0x4e,wrap_handle,0,0)==0,"restore low-word carry fixture");
 unsigned char data[97777];for(unsigned k=0;k<sizeof data;k++)data[k]=(k*23^(k>>9)^0x56)&255;
 unsigned h=create_file("C:HIDIR\\WRITE.BIN");seek_file(h,0,0);
 write_bytes(h,data,sizeof data);
 // Failed commits keep data/FAT dirty and retain the handle for retry.
 invoke(0x2e,7,0,0);unsigned old_error=result_x,old_error_page=result_b;
 const unsigned char fail_handler[]={0x86,3,0x97,6,0x39};memcpy(r+0x8300,fail_handler,sizeof fail_handler);
 invoke(0x2f,7,0,0x8300); // Select Fail through the native critical-error API.
 unsigned before=sd_writes;sd_deny_write=1;
 require(invoke(0x5a,h,0,0)==3&&sd_writes==before,"failed commit reports write protection");
 sd_deny_write=0;require(invoke(0x5a,h,0,0)==0,"commit retries dirty state");
 // Write succeeds in the first FAT but fails in its second copy. Flush must
 // retain the dirty cache and rewrite both copies on retry.
 require(invoke(0xeb,3,2,0)==0,"get native FAT16 descriptor");unsigned descriptor=result_x;
 word_at(descriptor+26,32767);word_at(descriptor+28,32768);
 require(invoke(0xe9,2,0,descriptor)==0,"mark actual FAT sector dirty");
 sd_deny_write_lba=40960+1+256+32767/256;before=sd_writes;
 require(invoke(0xeb,2,2,0)==3&&sd_writes==before+1&&r[descriptor+25],"failed second FAT mirror keeps dirty state");
 sd_deny_write_lba=UINT32_MAX;
 require(invoke(0xeb,2,2,0)==0&&!r[descriptor+25]&&sd_writes==before+3,"FAT mirror flush retry writes both copies");
 sd_deny_write=1;require(invoke(0x4e,h,0,0)==3,"failed close retains output handle");sd_deny_write=0;
 require(invoke(0x4e,h,0,0)==0,"close FAT16 output");
 read_check("C:HIDIR\\WRITE.BIN",data,sizeof data,0);
 // Move an actual high-address disk handle to another slot.
 h=open_file("C:HIDIR\\WRITE.BIN",3,0);
 require(invoke(0x59,h,0,0)==0,"move native disk handle");h=result_b;
 seek_file(h,65535,0);word_at(0x8100,0x4000);word_at(0x8102,512);
 require(invoke(0x4c,h,0,0x8100)==0&&!memcmp(r+0x4000,data+65535,512),"moved handle keeps full sector metadata");
 seek_file(h,4567,0);require(invoke(0x6c,h,0,0)==0,"truncate FAT16 chain");
 require(invoke(0x4e,h,0,0)==0,"close truncated file");
 read_check("C:HIDIR\\WRITE.BIN",data,4567,0);
 strcpy((char*)r+0x8000,"C:HIDIR\\WRITE.BIN");strcpy((char*)r+0x8040,"C:HIDIR\\RENAMED.BIN");word_at(0x8100,0x8000);word_at(0x8102,0x8040);
 require(invoke(0x56,0,0,0x8100)==0,"rename FAT16 file in high directory");
 read_check("C:HIDIR\\RENAMED.BIN",data,4567,0);
 // Append beyond the last FAT sector's EOF marker, then delete the chain.
 h=open_file("C:HICHAIN.BIN",3,0);seek_file(h,0,2);write_bytes(h,data,2301);
 require(invoke(0x4e,h,0,0)==0,"append FAT16 high chain");
 named_call(0x4f,"C:HIDIR\\RENAMED.BIN");
 named_call(0x48,"C:HIDIR\\NEWDIR");named_call(0x49,"C:HIDIR\\NEWDIR");
 // A failed synchronous CREATE has no open handle but leaves its directory
 // cache dirty. Media-check must retry that cache before invalidating keys.
 strcpy((char*)r+0x8000,"C:FAIL.BIN");word_at(0x8100,0x8000);word_at(0x8102,0);
 sd_deny_write=1;require(invoke(0x4b,0,0,0x8100)==3,"denied create retains directory cache");
 require(invoke(0x5c,2,0,0)==3,"denied media flush reports failure before invalidation");
 require(!(r[0xe200]==255&&r[0xe203])&&!(r[0xe405]==255&&r[0xe408]),"failed media flush preserves dirty cache drive");
 sd_deny_write=0;require(invoke(0x5c,2,0,0)==0,"media check retries pending directory write");
 read_check("C:FAIL.BIN",data,0,0);named_call(0x4f,"C:FAIL.BIN");
 invoke(0x2f,7,old_error_page,old_error);
 // Mount/unmount bootstrap after A/B/C. This must not renumber existing drives.
 require(invoke(0xe1,2,1,0)==0&&result_b==3,"explicit bootstrap FAT16 mount gets D");
 require(invoke(0xe1,3,1,0)==0,"unmount bootstrap FAT16");
 unsigned char*v=image+40960*512;
 require(invoke(0xe1,5,0,0)==0,"rescan preserves mounted FAT16");
 v[33]-=2;require(invoke(0xe1,5,0,0)==15,"rescan rejects changed TotSec32");v[33]+=2;
 v[15]=1;require(invoke(0xe1,5,0,0)==15,"rescan rejects changed reserved high byte");v[15]=0;
 require(invoke(0xe1,5,0,0)==0,"rescan recovers after rejected geometry");
 word_at(0x8100,0x4000);r[0x8102]=2;r[0x8103]=0;r[0x8104]=4;r[0x8105]=r[0x8106]=0;
 before=sd_reads;require(invoke(0xea,1,0,0x8100)==4&&sd_reads==before,"32-bit sector end bound is checked before I/O");
 require(!memcmp(v+512,v+257*512,256*512),"all FAT16 mirrors agree after mutations");
 require(invoke(0x52,2,0,0x8110)==0,"FAT16 free space");
 unsigned allocated=0;for(unsigned j=2;j<65401;j++)allocated+=le16(v+512+j*2)!=0;
 unsigned free_bytes=((unsigned)r[0x8110]<<24)|(r[0x8111]<<16)|(r[0x8112]<<8)|r[0x8113];
 require(free_bytes==(65399-allocated)*2048u,"FAT16 free space matches independent allocation count");
 FILE*f=fopen("build/fat16/after.img","wb");require(f&&fwrite(v,1,262144*512,f)==262144*512&&!fclose(f),"save regular volume for independent checking");
 require(invoke(0xe1,3,4,0)==0,"unmount data FAT16 before format");
 unsigned himem_before=r[0xee1e]*256+r[0xee1f];before=sd_writes;sd_deny_write=1;
 require(invoke(0xe1,10,4,0)==3&&sd_writes==before,"denied FAT16 format performs no writes");sd_deny_write=0;
 require(r[0xee1e]*256+r[0xee1f]==himem_before,"failed format frees temporary state");
 require(invoke(0xe1,10,4,0)==0,"native FAT16 format");
 require(r[0xee1e]*256+r[0xee1f]==himem_before,"successful format frees temporary state");
 require(le16(v+14)==2048&&le16(v+22)==256&&v[13]==4&&le32(v+32)==262144&&!le16(v+19),"FAT16 formatter publishes complete BPB");
 require(invoke(0xe1,2,4,0)==0&&result_b==2,"formatted FAT16 remounts as C");
 h=create_file("C:FRESH.BIN");write_bytes(h,data,4567);require(invoke(0x4e,h,0,0)==0,"formatted FAT16 file close");
 read_check("C:FRESH.BIN",data,4567,0);
 // Cyclic file/directory chains must return an error rather than hanging.
 require(invoke(0xeb,3,2,0)==0,"formatted descriptor");descriptor=result_x;
 word_at(descriptor+26,2);word_at(descriptor+28,2);
 require(invoke(0xe9,2,0,descriptor)==0&&invoke(0xeb,2,2,0)==0,"inject a cyclic FAT16 chain");
 strcpy((char*)r+0x8000,"C:FRESH.BIN");word_at(0x8100,0x8000);word_at(0x8102,0);
 require(invoke(0x4a,1,0,0x8100)==10,"cyclic file rejected at open");
 word_at(descriptor+26,2);word_at(descriptor+28,3);
 require(invoke(0xe9,2,0,descriptor)==0&&invoke(0xeb,2,2,0)==0,"restore chain after cycle test");
 f=fopen("build/fat16/formatted.img","wb");require(f&&fwrite(v,1,262144*512,f)==262144*512&&!fclose(f),"save formatted volume for independent checking");
 // Exercise the formatter's TotSec16 branch as well as the large TotSec32
 // profile, with the same physical card and the same drive letter.
 require(invoke(0xe1,3,4,0)==0,"unmount before small FAT16 profile");
 image[506]=0xe0;image[507]=0x7f;image[508]=image[509]=0;
 require(invoke(0xe1,5,0,0)==0&&invoke(0xe1,10,4,0)==0,"format small FAT16 partition after rescan");
 require(le16(v+19)==32736&&!le32(v+32)&&v[13]==1,"small FAT16 publishes TotSec16/SPC1");
 require(invoke(0xe1,2,4,0)==0&&result_b==2,"small FAT16 keeps C");
 h=create_file("C:SMALL.BIN");write_bytes(h,data,4567);require(invoke(0x4e,h,0,0)==0,"small FAT16 write");read_check("C:SMALL.BIN",data,4567,0);
 f=fopen("build/fat16/small16.img","wb");require(f&&fwrite(v,1,32736*512,f)==32736*512&&!fclose(f),"save small FAT16 volume");
 require(!resets&&!fdc_port_accesses,"no reset or CHS/FDC access");
 printf("PASS FAT16 native %s/%s/%s cache=%s: A/B/C, high clusters/sectors, seek/cache/handles, writes/commit retry, append/truncate/delete/mkdir and mirrors\n",argv[2],argv[3],argv[4],banked?"RAMMAN":"CPU");
 return 0;
}
