// Real MC6800/HD6303 code, banked BIOS SWI and byte-level SDHC/SDSC model.
#define DIRECT_SD_FIXTURE 1
#define COMPACT_FIXTURE 1
#define PARTITION_FIXTURE 1
#define NATIVE_STABILITY_MAIN unused_stability_main
#include "test_native_stability.c"
#undef NATIVE_STABILITY_MAIN
static void check(int ok,const char*why){if(!ok){dump();fprintf(stderr,"FAIL %s\n",why);exit(1);}}
static unsigned raw(unsigned op,unsigned x){
 unsigned savedpc=PC,savedsp=SP,savedpage=page;unsigned char*r=MC6800GetCpuRam();
 r[0x210]=0x3f;r[0x211]=0xe2;r[0x212]=1;PC=0x210;A=op;X=x;
 uint64_t deadline=virtual_cycles+20000000;
 while(PC!=0x212&&virtual_cycles<deadline)until(virtual_cycles+1);
 check(PC==0x212&&SP==savedsp&&page==savedpage&&X==x,"raw SWI preserves SP/page/X");
 unsigned result=A;PC=savedpc;return result;
}
static void descriptor(unsigned buffer,uint32_t lba){
 unsigned char*r=MC6800GetCpuRam();r[0x3000]=buffer>>8;r[0x3001]=buffer;
 for(unsigned n=0;n<4;n++)r[0x3002+n]=lba>>(n*8);
}
int main(int argc,char**argv){
 if(argc!=4)return 2;model_a=!strcmp(argv[1],"601a");cpu_hd=!strcmp(argv[2],"hd6303");sdsc=!strcmp(argv[3],"sdsc");
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);
 memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 rom=load("build/partitions/SD.ROM",&n);check(n==8192,"raw ROM size");memcpy(physical+0x16000,rom,n);free(rom);
 image=load("images/sd.img",&image_size);memcpy(config+64,image+462,32);committed=1;
 MC6800Init();MC6800Reset();until(60000000);
 unsigned char*r=MC6800GetCpuRam();check(raw(0,0x3000)==0,"CMD9 capacity");
 check(le32(r+0x3000)==image_size/512,"CSD capacity equals image sectors");
 unsigned char*copy=malloc(image_size);memcpy(copy,image,image_size);
 for(unsigned i=0;i<5;i++){
  unsigned lbas[]={0,1,2048,34816,image_size/512-1};unsigned lba=lbas[i];descriptor(0x4000,lba);
  check(raw(1,0x3000)==0&&!memcmp(r+0x4000,image+lba*512,512),"raw read whole-card range");
  for(unsigned b=0;b<512;b++)r[0x4000+b]=b*17+i;
  sd_busy_reads=9;sd_busy_transition=3;
  check(raw(2,0x3000)==0&&!memcmp(r+0x4000,image+lba*512,512),"raw write CRC/token/complete busy");
  memcpy(image+lba*512,copy+lba*512,512);
 }
 unsigned before=sd_writes;
 descriptor(0x4000,image_size/512);check(raw(2,0x3000)==4&&sd_writes==before,"end-exclusive capacity");
 descriptor(0x4000,0xffffffff);check(raw(2,0x3000)==4&&sd_writes==before,"32-bit out of range");
 for(unsigned buffer=0xbe01;buffer<0xe700;buffer+=0x100){
  if(buffer>=0xe000&&buffer<=0xe400)continue;
  descriptor(buffer,1);check(raw(2,0x3000)==4&&sd_writes==before,"ROM/I/O and wrapped buffers rejected");
 }
 descriptor(0x4000,1);runtime_bad_crc=1;check(raw(1,0x3000)==5,"CRC rejection");runtime_bad_crc=0;
 runtime_no_token=1;check(raw(1,0x3000)==6,"token timeout");runtime_no_token=0;
 sd_deny_write=1;check(raw(2,0x3000)==3,"write denied");sd_deny_write=0;
 check(raw(1,0x3000)==0,"fault recovery");
 check(!memcmp(image,copy,image_size),"no unintended card writes");
 printf("PASS raw SD %s/%s/%s: CMD9 capacity, full-card I/O, bounds/CRC/busy/fault recovery, page/SP/X\n",argv[1],argv[2],argv[3]);return 0;
}
