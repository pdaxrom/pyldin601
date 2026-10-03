// Original 601A BIOS and installed XBIOS determine registers, layout and PLOT
// packing. The expected renderer follows the documented byte/attribute format.
#define main firmware_boot_main
#include "test_firmware.c"
#undef main

static void bios(unsigned vector,unsigned a,unsigned b,unsigned x){
 unsigned char*r=MC6800GetCpuRam();r[0x1000]=0x3f;r[0x1001]=vector;r[0x1002]=1;
 PC=0x1000;A=a;B=b;X=x;fWai=0;MC6800SetInterrupt(0);
 for(unsigned n=0;n<2000000;n++){MC6800Step();if(PC==0x1002)return;}
 fprintf(stderr,"601A BIOS vector %02x failed PC=%04x\n",vector,PC);exit(1);
}
static unsigned pattern(unsigned x,unsigned y,unsigned mask){
 return ((x*3+y*5+x/7)^(y/11))&mask;
}
static void word_at(unsigned address,unsigned value){
 unsigned char*r=MC6800GetCpuRam();r[address]=value>>8;r[address+1]=value;
}
int main(void){
 size_t size;unsigned char*rom=load("build/rom-a.reference",&size);
 if(size!=0x51a00||rom[25]!=1||rom[512+0x50ff7]!=0x80)return 1;
 memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,0x51800);free(rom);
 image=load("build/models-sd.img",&image_size);memcpy(config+64,image+462,32);
 committed=1;model_a=1;MC6800Init();MC6800Reset();
 for(unsigned n=0;n<2000000;n++){
  if(n%5000==4999){tick=128;KBDUpdate();MC6800SetInterrupt(1);}MC6800Step();
 }
 unsigned char*r=MC6800GetCpuRam();
 bios(0x60,0,0,0);unsigned screen=X;SP=0x17ff;
 if(!screen||(screen&7)||screen+16000>0xe000){fprintf(stderr,"601A graphics allocation %04x\n",screen);return 1;}
 for(unsigned test=0;test<12;test++){
  unsigned graphics=test<6,mode=test<5?(test?2:1):test==5?3:(test==6||test==10)?4:0;
  unsigned palette=test>0&&test<5?test-1:0;
  unsigned bits=mode==1?4:mode==2?2:1,width=640/bits,height=graphics?200:216;
  bios(0x12,mode,test>=8?0x70:palette,graphics?screen:0);
  unsigned expected_mode=mode==1?0x3f:mode==2?0x25|(palette<<3):mode==3?0x39:mode==4?1:test>=8?7:3;
  unsigned start=(crtc[12]<<8)|crtc[13];
  if(r[0xe629]!=expected_mode||crtc[1]!=80||crtc[6]!=(graphics?25:27)||start!=(graphics?screen>>3:0xf000)){
   fprintf(stderr,"601A mode %u registers E629=%02x R1=%u R6=%u start=%04x\n",mode,r[0xe629],crtc[1],crtc[6],start);return 1;
  }
  if(graphics){
   memset(r+screen,0,16000);
   for(unsigned n=0;n<64;n++){
    unsigned x=n==63?width-1:n*23%width,y=n==63?199:n*37%200,c=n&((1<<bits)-1);
    word_at(0x1010,c);word_at(0x1012,0);bios(0x66,0,0,0x1010);
    word_at(0x1010,x*(640/width));word_at(0x1012,y*2);bios(0x66,3,0,0x1010);
    unsigned address=screen+(y/8)*640+(x/(8/bits))*8+y%8,shift=8-bits*(x%(8/bits)+1);
    if(((r[address]>>shift)&((1<<bits)-1))!=c){fprintf(stderr,"601A PLOT packing failed x=%u y=%u\n",x,y);return 1;}
   }
   memset(r+screen,0,16000);
   for(unsigned y=0;y<200;y++)for(unsigned x=0;x<width;x++)
    r[screen+(y/8)*640+(x/(8/bits))*8+y%8]|=pattern(x,y,(1<<bits)-1)<<(8-bits*(x%(8/bits)+1));
  }else{
   // Write complete rows through real BIOS, including underscores, all glyphs
   // and all 128 attribute combinations (blink bit is checked in RTL too).
   unsigned columns=mode==4?80:40;
   for(unsigned y=0;y<25;y++)for(unsigned x=0;x<columns;x++){
    unsigned c=x%9==0?'_':(x+y*columns)&255,attribute=(x+y*columns)&127;
    if(test==9)attribute|=128;
    bios(0x15,x,y,0);bios(0x16,0,attribute,0);
    bios(0x22,0x1b,0,0);bios(0x22,c,0,0); // escaped glyph, including controls
    unsigned address=0xf000+y*80+x*(mode==4?1:2);
    if(r[address+(mode==4?0:1)]!=c||(mode==0&&r[address]!=attribute)){
     fprintf(stderr,"601A text packing mode=%u x=%u y=%u\n",mode,x,y);return 1;
    }
   }
  }
  if(test>=10){
   bios(0x15,7,3,0);
   unsigned expected_cursor=0xf000+3*80+(mode==4?7:15);
   if(((crtc[14]<<8)|crtc[15])!=expected_cursor){fprintf(stderr,"601A BIOS cursor mismatch\n");return 1;}
  }
  SuperIoWriteByte(0xe600,10);SuperIoWriteByte(0xe601,test>=10?0:0x20);
  SuperIoWriteByte(0xe600,11);SuperIoWriteByte(0xe601,7);
  char path[100];FILE*f;
  snprintf(path,sizeof(path),"build/601a-%u-ram.mem",test);f=fopen(path,"w");if(!f)return 1;
  for(unsigned n=0;n<65536;n++)fprintf(f,"%02x\n",r[n]);fclose(f);
  snprintf(path,sizeof(path),"build/601a-%u-config.mem",test);f=fopen(path,"w");if(!f)return 1;
  fprintf(f,"%02x\n",r[0xe629]);for(unsigned n=0;n<16;n++)fprintf(f,"%02x\n",crtc[n]);fclose(f);
  snprintf(path,sizeof(path),"build/601a-%u-pixels.mem",test);f=fopen(path,"w");if(!f)return 1;
  for(unsigned y=0;y<height;y++)for(unsigned x=0;x<640;x++){
   unsigned c;
   if(graphics){c=pattern(x/(640/width),y,(1<<bits)-1);if(mode==2)c=(palette/2)*8+c*2+!(palette&1);else if(mode==3)c=c?15:0;}
   else{
    unsigned a=0xf000+(y/8)*80+x/(mode==4?8:16)*(mode==4?1:2);
    unsigned ch=r[a+(mode==4?0:1)],attribute=r[a];
    unsigned font_byte=physical[0x61000+(ch&127)*16+(ch>>7)*8+y%8];
    unsigned on=(font_byte>>(7-(mode==4?x%8:(x%16)/2)))&1;
    if(test>=10&&y/8==3&&x/(mode==4?8:16)==7)on=!on;
    c=test>=8&&mode==0?(on?(attribute>>4)&7:attribute&15):on?15:0;
   }
   fprintf(f,"%02x\n",c);
  }fclose(f);
 }
 puts("PASS original 601A BIOS: all five modes, four palettes, 384 XBIOS PLOT pixels, 8000 BIOS text/attribute writes and both native cursor addresses; prepared twelve independent frames");
 return 0;
}
