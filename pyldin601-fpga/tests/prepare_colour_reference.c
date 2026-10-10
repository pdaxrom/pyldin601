// Execute the original 601 BIOS/XBIOS vectors, then save their mode/CRTC
// values and graphics memory for the RTL renderer. No FPGA ROM table is used.
#define main firmware_boot_main
#include "test_firmware.c"
#undef main

static void bios(unsigned vector,unsigned a,unsigned b,unsigned x){
 unsigned char*ram=MC6800GetCpuRam();
 ram[0x1000]=0x3f;ram[0x1001]=vector;ram[0x1002]=1;
 PC=0x1000;A=a;B=b;X=x;fWai=0;MC6800SetInterrupt(0);
 for(unsigned n=0;n<2000000;n++){
  MC6800Step();if(PC==0x1002)return;
 }
 fprintf(stderr,"native BIOS vector %02x failed PC=%04x\n",vector,PC);exit(1);
}
static unsigned screen_base;
static unsigned colour(unsigned mode,unsigned x,unsigned y){
 return ((x*3+y*5+(x/7))^(y/11))&((mode==1)?15:3);
}
static unsigned packed_address(unsigned width,unsigned x,unsigned y){
 unsigned pixels_per_byte=width/40;
 return screen_base+(y/8)*320+(x/pixels_per_byte)*8+y%8;
}
static void word_at(unsigned address,unsigned value){
 unsigned char*r=MC6800GetCpuRam();r[address]=value>>8;r[address+1]=value;
}
int main(void){
 size_t size;unsigned char*rom=load("build/rom.reference",&size);
 if(size!=(ROM_BYTES+512))return 1;
 memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load("build/test-sd.img",&image_size);memcpy(config+64,image+462,32);
 committed=1;MC6800Init();MC6800Reset();
 for(unsigned n=0;n<2000000;n++){
  if(n%5000==4999){tick=128;KBDUpdate();MC6800SetInterrupt(1);}MC6800Step();
 }
 unsigned char*r=MC6800GetCpuRam();
 if(!(r[0xe629]&1))return 1;
 // Allocate through the installed XBIOS. The interrupted DOS stack is
 // above himem; use a separate harness stack before filling the screen.
 bios(0x60,0,0,0);screen_base=X;SP=0x17ff;
 if(!screen_base||(screen_base&7)){fprintf(stderr,"unaligned screen %04x\n",screen_base);return 1;}
 for(unsigned test=0;test<5;test++){
  unsigned mode=test?2:1,palette=test?test-1:0,width=mode==1?80:160,bits=mode==1?4:2;
  bios(0x12,mode,palette,screen_base);
  unsigned expected=mode==1?0x3f:(0x25|(palette<<3));
  if(r[0xe629]!=expected||crtc[1]!=40||crtc[6]!=25||((crtc[12]<<8)|crtc[13])!=(screen_base>>3)){
   fprintf(stderr,"mode/CRTC mismatch test=%u E629=%02x width=%u height=%u start=%02x%02x\n",test,r[0xe629],crtc[1],crtc[6],crtc[12],crtc[13]);return 1;
  }
  // Check actual XBIOS PLOT packing at byte/cell/row boundaries, including
  // first and last pixels. API coordinates are the common 640x400 space.
  memset(r+screen_base,0,8000);
  for(unsigned n=0;n<64;n++){
   unsigned x=n==63?width-1:(n*23)%width,y=n==63?199:(n*37)%200,c=(n&((1<<bits)-1));
   word_at(0x1010,c);word_at(0x1012,0);bios(0x66,0,0,0x1010);
   word_at(0x1010,x*(640/width));word_at(0x1012,y*2);bios(0x66,3,0,0x1010);
   unsigned address=packed_address(width,x,y),shift=8-bits*(x%(width/40)+1);
   if(((r[address]>>shift)&((1<<bits)-1))!=c){
    fprintf(stderr,"XBIOS PLOT packing mismatch mode=%u x=%u y=%u colour=%u byte[%04x]=%02x shift=%u\n",mode,x,y,c,address,r[address],shift);return 1;
   }
  }
  memset(r+screen_base,0,8000);
  for(unsigned y=0;y<200;y++)for(unsigned x=0;x<width;x++){
   unsigned shift=8-bits*(x%(width/40)+1);
   r[packed_address(width,x,y)]|=colour(mode,x,y)<<shift;
  }
  // Disable the cursor using a real MC6845 write, preserving BIOS geometry.
  SuperIoWriteByte(0xe600,10);SuperIoWriteByte(0xe601,0x20);
  char path[80];FILE*f;
  snprintf(path,sizeof(path),"build/colour-%u-ram.mem",test);f=fopen(path,"w");if(!f)return 1;
  for(unsigned n=0;n<65536;n++)fprintf(f,"%02x\n",r[n]);fclose(f);
  snprintf(path,sizeof(path),"build/colour-%u-config.mem",test);f=fopen(path,"w");if(!f)return 1;
  fprintf(f,"%02x\n",r[0xe629]);for(unsigned n=0;n<16;n++)fprintf(f,"%02x\n",crtc[n]);fclose(f);
  snprintf(path,sizeof(path),"build/colour-%u-pixels.mem",test);f=fopen(path,"w");if(!f)return 1;
  for(unsigned y=0;y<200;y++)for(unsigned x=0;x<320;x++){
   unsigned c=colour(mode,x/(320/width),y);
   if(mode==2)c=(palette/2)*8+c*2+!(palette&1);
   fprintf(f,"%02x\n",c);
  }fclose(f);
  if(mode==2){
   for(unsigned p=0;p<4;p++){
    bios(0x22,6,0,0);bios(0x22,p,0,0);
    if(r[0xe629]!=(0x25|(p<<3))){fprintf(stderr,"XBIOS palette failed p=%u mode=%02x\n",p,r[0xe629]);return 1;}
   }
  }
 }
 bios(0x12,3,0,screen_base);if(r[0xe629]!=0x39)return 1;
 bios(0x12,0,0,0);if(r[0xe629]!=1)return 1;
 puts("PASS original 601 BIOS: 16/4/2-colour/text mode registers, 16 palette changes, 320 XBIOS PLOT pixels and graphics packing; prepared five colour frames");
 return 0;
}
