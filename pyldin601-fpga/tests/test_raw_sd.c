// Real MC6800/HD6303 code, banked BIOS SWI and byte-level SDHC/SDSC model.
#define DIRECT_SD_FIXTURE 1
#define COMPACT_FIXTURE 1
#define PARTITION_FIXTURE 1
#define NATIVE_STABILITY_MAIN unused_stability_main
#include "test_native_stability.c"
#undef NATIVE_STABILITY_MAIN
static void check(int ok,const char*why){if(!ok){dump();fprintf(stderr,"FAIL %s\n",why);exit(1);}}
static unsigned raw(unsigned op,unsigned x){
 unsigned savedpc=PC,savedsp=SP,savedpage=page,savedb=B;unsigned char*r=MC6800GetCpuRam();
 r[0x210]=0x3f;r[0x211]=0xe2;r[0x212]=1;PC=0x210;A=op;X=x;
 uint64_t deadline=virtual_cycles+20000000;
 while(PC!=0x212&&virtual_cycles<deadline)until(virtual_cycles+1);
 check(PC==0x212&&SP==savedsp&&page==savedpage&&X==x&&B==savedb,"raw SWI preserves SP/page/X/B");
 unsigned result=A;PC=savedpc;return result;
}
static void descriptor(unsigned buffer,uint32_t lba){
 unsigned char*r=MC6800GetCpuRam();r[0x3000]=buffer>>8;r[0x3001]=buffer;
 for(unsigned n=0;n<4;n++)r[0x3002+n]=lba>>(n*8);
}
static void text_mode(unsigned mode,unsigned base){
 unsigned pc0=PC,sp0=SP,page0=page,a0=A,b0=B,x0=X;
 unsigned h0=h,i0=i,n0=n,z0=z,v0=v,c0=c;
 unsigned char*r=MC6800GetCpuRam();r[0x210]=0x3f;r[0x211]=0x12;r[0x212]=1;
 PC=0x210;A=0x80|mode;B=0;X=base;
 uint64_t deadline=virtual_cycles+15000000;
 while(PC!=0x212&&virtual_cycles<deadline)until(virtual_cycles+1);
 check(PC==0x212&&SP==sp0&&page==page0,"native text-mode SWI returns");
 check(r[0xed12]==mode&&((r[0xed19]<<8)|r[0xed1a])==base,"native text mode and screen address applied");
 // Bit 7 of INT 12 retains the screen address and skips CLS. Use the
 // real console CLS to update the BIOS status-line pointer at that base.
 r[0x211]=0x22;PC=0x210;A=12;deadline=virtual_cycles+15000000;
 while(PC!=0x212&&virtual_cycles<deadline)until(virtual_cycles+1);
 check(PC==0x212&&SP==sp0&&page==page0,"native console CLS returns");
 PC=pc0;A=a0;B=b0;X=x0;h=h0;i=i0;n=n0;z=z0;v=v0;c=c0;
}
static unsigned indicator_base,indicator_commands,indicator_seen,indicator_code;
static void watch_indicator(void){
 if(sd_commands==indicator_commands)return;
 indicator_commands=sd_commands;
 if((cmd[0]&63)!=17&&(cmd[0]&63)!=24)return;
 unsigned char*r=MC6800GetCpuRam();unsigned end=indicator_base+(model_a?159:81);
 if(r[end]!=indicator_code)fprintf(stderr,"indicator at %04x: expected %c, got %02x (model=%s mode=%u)\n",end,indicator_code,r[end],model_a?"601A":"601",r[0xed12]);
 check(r[end]==indicator_code,"R/W is visible in the final status-line character during SD I/O");
 if(model_a)check(r[indicator_base+81]==0x5a&&r[end-1]==0x5a,"601A left character and final colour attribute preserved");
 indicator_seen++;
}
static void indicators(void){
 unsigned char*r=MC6800GetCpuRam();unsigned modes[]={0,4},bases[]={0xf000,0x7000};
 // Native clock IRQ refreshes the whole status row. Pause the timer only
 // for these sentinel checks; all normal I/O cases below run with IRQs.
 uint64_t saved_next=next_irq,started=virtual_cycles;
 unsigned saved_tick=tick,saved_irq=IRQrequest,saved_mask=i;
 next_irq=UINT64_MAX;tick=0;MC6800SetInterrupt(0);
 for(unsigned m=0;m<(model_a?2:1);m++)for(unsigned b=0;b<2;b++){
  text_mode(modes[m],bases[b]);indicator_base=(r[0xed20]<<8)|r[0xed21];
  if(indicator_base!=bases[b]+(model_a?80:42)*25)fprintf(stderr,"status base %04x, screen %04x, size %04x\n",indicator_base,bases[b],(r[0xed15]<<8)|r[0xed16]);
  check(indicator_base==bases[b]+(model_a?80:42)*25,"status line follows native screen base");
  unsigned end=indicator_base+(model_a?159:81);
  for(unsigned op=1;op<=2;op++){
   r[end]=0;if(model_a){r[indicator_base+81]=0x5a;r[end-1]=0x5a;}
   indicator_code=op==1?'R':'W';indicator_commands=sd_commands;indicator_seen=0;
   descriptor(0x4000,1);B=0xa6;native_step_hook=watch_indicator;
   check(raw(op,0x3000)==0,"indicator read/write completes");native_step_hook=0;
   check(indicator_seen==1&&r[end]==0,"indicator cleared after SD I/O");
   if(model_a)check(r[indicator_base+81]==0x5a&&r[end-1]==0x5a,"indicator clear preserves neighbouring cells");
  }
  runtime_bad_crc=1;descriptor(0x4000,1);
  check(raw(1,0x3000)==5&&r[end]==0,"indicator cleared on read failure");runtime_bad_crc=0;
 }
 text_mode(0,0xf000);i=saved_mask;tick=saved_tick;
 next_irq=saved_next+virtual_cycles-started;MC6800SetInterrupt(saved_irq);
 printf("PASS disk indicator %s: native text modes, R/W during I/O, clear on success/error, relocated screen, B preserved\n",model_a?"601A 40/80 columns":"601 40 columns");
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
 indicators();
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
 printf("PASS raw SD %s/%s/%s: CMD9 capacity, full-card I/O, bounds/CRC/busy/fault recovery, page/SP/X/B\n",argv[1],argv[2],argv[3]);return 0;
}
