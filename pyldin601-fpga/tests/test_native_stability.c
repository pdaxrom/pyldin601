// Long idle and completed DIR commands on the original classic emulator.
// This is a firmware baseline, not a test of the FPGA CPU or electrical SRAM.
#define main firmware_boot_main
#include "test_firmware.c"
#undef main
static uint64_t virtual_cycles,next_irq=20000;
static unsigned irq_count,resets,watch_resets;
static void until(uint64_t target){
 while(virtual_cycles<target){
  if(virtual_cycles>=next_irq){tick=128;KBDUpdate();MC6800SetInterrupt(1);irq_count++;next_irq+=20000;}
  if(watch_resets&&PC==0xf006)resets++;
  int cycles=MC6800Step();virtual_cycles+=cycles>0?cycles:1;
 }
}
static void dump(void){
 unsigned start=crtc[12]*256+crtc[13],stride=crtc[1];
 fprintf(stderr,"cycles=%llu PC=%04x SP=%04x start=%04x stride=%u page=%02x IRQs=%u reads=%u\n",(unsigned long long)virtual_cycles,PC,SP,start,stride,page,irq_count,sd_reads);
 for(unsigned y=0;y<25;y++){for(unsigned x=0;x<40;x++){unsigned c=MC6800GetCpuRam()[(start+y*stride+x)&65535];fputc(c>=32&&c<127?c:'.',stderr);}fputc('\n',stderr);}
}
static void key(unsigned scan){KBDKeyDown(scan);until(virtual_cycles+100000);KBDKeyUpCode(scan);until(virtual_cycles+100000);}
static unsigned at_prompt(void){
 unsigned cursor=crtc[14]*256+crtc[15];const unsigned char*ram=MC6800GetCpuRam();
 for(unsigned gap=4;gap<=8;gap++){
  unsigned a=(cursor-gap)&65535;
  if(ram[a]=='A'&&ram[(a+1)&65535]==':'&&ram[(a+2)&65535]=='\\'&&ram[(a+3)&65535]=='>')
   return PC>=0xf380&&PC<=0xf3a8;
 }
 return 0;
}
static void wait_prompt(void){
 uint64_t deadline=virtual_cycles+15000000;
 do{until(virtual_cycles+10000);if(at_prompt())return;}while(virtual_cycles<deadline);
 dump();fprintf(stderr,"DOS did not return to its input prompt\n");exit(1);
}
#ifndef NATIVE_STABILITY_MAIN
#define NATIVE_STABILITY_MAIN main
#endif
int NATIVE_STABILITY_MAIN(int argc,char**argv){
 if(argc<2)return 2;size_t size;unsigned char*rom=load("build/rom.reference",&size);if(size!=0x51a00)return 1;
 memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,0x51800);free(rom);
 image=load(argv[1],&image_size);memcpy(config+64,image+462,32);
 for(unsigned n=0;n<2;n++){
  unsigned off=446+16*(n+1),base=32+16*n;memcpy(config+base,image+off+8,8);
  const unsigned char*bpb=image+le32(config+base)*512;
  unsigned sectors=le16(bpb+19),spt=le16(bpb+24),heads=le16(bpb+26);
  config[base+8]=spt;config[base+9]=0;config[base+10]=heads;config[base+11]=0;
  config[base+12]=sectors/(spt*heads);config[base+13]=0;
 }
 committed=1;MC6800Init();MC6800Reset();until(60000000);key(0x1c);until(62000000);
 watch_resets=1;
 unsigned start=crtc[12]*256+crtc[13],stride=crtc[1];unsigned char header[120];
 for(unsigned y=0;y<3;y++)memcpy(header+y*40,MC6800GetCpuRam()+start+y*stride,40);
 unsigned idle_seconds=argc>2?strtoul(argv[2],0,0):120;
 for(unsigned sec=60;sec<=idle_seconds;sec+=60){
  until((uint64_t)(62+sec)*1000000);
  for(unsigned y=0;y<3;y++)if(memcmp(header+y*40,MC6800GetCpuRam()+start+y*stride,40)){
   dump();fprintf(stderr,"idle header changed after %u virtual seconds\n",sec);return 1;}
 }
 printf("PASS native firmware idle header unchanged for %u virtual seconds (%u IRQs)\n",idle_seconds,irq_count);fflush(stdout);
 key(0x1c);wait_prompt();
 for(unsigned cmd=0;cmd<32;cmd++){
  unsigned reads=sd_reads;
  key(0x20);key(0x17);key(0x13);key(0x1c);wait_prompt();
  if(sd_reads==reads){dump();fprintf(stderr,"DIR %u did not read its directory\n",cmd+1);return 1;}
 }
 if(resets){fprintf(stderr,"native firmware reset %u times\n",resets);return 1;}
 printf("PASS native firmware completed 32 DIR commands and returned to prompt each time; %u direct SPI reads, zero resets\n",sd_reads);
 return 0;
}
