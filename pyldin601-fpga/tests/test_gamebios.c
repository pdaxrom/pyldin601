// Real native BIOS/UniDOS + assembled ROM E. MMIO model with independent
// framebuffer, font, RGB/PAL, audio and process-lifetime expectations.
#include <stdint.h>
static int hg_read_byte(uint16_t a,unsigned char *out);
static int hg_write_byte(uint16_t a,unsigned char d);
#define HG_FIXTURE 1
#define DIRECT_SD_FIXTURE 1
#define ROMDISK_MAIN unused_romdisk_main
#include "test_romdisk_unidos.c"
#undef ROMDISK_MAIN

static unsigned char gfx[16],pal[8192],saved_pal[8192],ay[16],saved_ay[16];
static unsigned paladdr,readback,front,enabled,pending,overrun,envelopes,jobs;
static uint32_t period=960000,period_shadow=960000,divider=0x03000000,divider_shadow=0x03000000;
static uint64_t audio_last,audio_count,gfx_ready;
static unsigned fault_busy,fault_audio,fault_divider;
static unsigned char raw_bytes[64];
static unsigned raw_head,raw_count,raw_overflow,keyboard_raw_missing;
static void raw_byte(unsigned char b){if(raw_count<64)raw_bytes[(raw_head+raw_count++)&63]=b;else raw_overflow=1;}
static void raw_key(unsigned ext,unsigned up,unsigned char scan){if(ext)raw_byte(0xe0);if(up)raw_byte(0xf0);raw_byte(scan);}
static unsigned state,pcb,sp_before,old_irq,old_page;
static unsigned char*r;
static void (*flip_hook)(unsigned);
static void audio_update(void){
 uint64_t elapsed=virtual_cycles-audio_last;audio_last=virtual_cycles;
 if(!enabled)return;
 audio_count+=elapsed*24;
 if(audio_count>=period){if(pending||audio_count>=2ULL*period)overrun=1;pending=1;audio_count%=period;}
}
static void observe(void){if(r){unsigned vector=r[0xefcc]*256+r[0xefcd];if(vector>=0x100&&vector+384<=0xbe00)state=vector;}audio_update();if(!i&&pending)MC6800SetInterrupt(1);}
static int hg_read_byte(uint16_t a,unsigned char*out){
 if(a>=0xe6b0&&a<=0xe6b3){*out=0xff;if(!keyboard_raw_missing)switch(a&3){case 0:*out='R';break;case 1:*out=(raw_count!=0)|((raw_count==64)<<5)|(raw_overflow<<7);break;case 2:if(raw_count){*out=raw_bytes[raw_head++&63];raw_count--;}break;case 3:*out=raw_count;}return 1;}
 if(a>=0xe650&&a<=0xe65f){unsigned p=a&15;
  *out=p==0?gfx[0]|((fault_busy||virtual_cycles<gfx_ready)?128:0):p==2?front:p==14?(readback?pal[paladdr]:'G'):p==15?5:gfx[p];return 1;}
 if(a>=0xe610&&a<=0xe61f){*out=ay[a&15];return 1;}
 if(a>=0xe690&&a<=0xe69f){unsigned p=a&15;audio_update();*out=0;
  if(p==0)*out=enabled|(pending<<7)|(overrun<<6)|(fault_divider<<5);
  else if(p==1)*out=fault_audio?0xff:0x59;
  else if(p>=2&&p<=5)*out=period>>(8*(5-p));
  else if(p>=11&&p<=14)*out=divider>>(8*(14-p));return 1;}
 return 0;
}
static int hg_write_byte(uint16_t a,unsigned char d){
 if(a>=0xe6b0&&a<=0xe6b3){if(a==0xe6b3&&!keyboard_raw_missing){if(d&1)raw_head=raw_count=0;if(d&2)raw_overflow=0;}return 1;}
 if(a>=0xe690&&a<=0xe69f){unsigned p=a&15;audio_update();
  if(!p){enabled=d&1;if(d&2)pending=overrun=0;if(!(d&1)||(d&4))audio_count=pending=overrun=0;}
  else if(p>=2&&p<=5){unsigned shift=8*(5-p);period_shadow=(period_shadow&~(255U<<shift))|((uint32_t)d<<shift);}
  else if(p==6&&d&1){require(period_shadow,"nonzero timer");period=period_shadow;audio_count=pending=overrun=0;}
  else if(p>=11&&p<=14){unsigned shift=8*(14-p);divider_shadow=(divider_shadow&~(255U<<shift))|((uint32_t)d<<shift);}
  else if(p==15&&d&1)divider=divider_shadow;
  return 1;
 }
 if(a>=0xe610&&a<=0xe61f){ay[a&15]=d;if(a==0xe61d)envelopes++;return 1;}
 if(a<0xe650||a>0xe65f)return 0;
 unsigned p=a&15;
 if(!p){gfx[0]=d&7;return 1;}
 if(p==2){paladdr=(paladdr&0x1f00)|d;return 1;}
 if(p==13){paladdr=((d&31)<<8)|(paladdr&255);return 1;}
 if(p==14){pal[paladdr]=d&63;paladdr=(paladdr+1)&8191;return 1;}
 if(p==15){readback=d&1;if(d&2)paladdr=(paladdr+1)&8191;return 1;}
 require(!fault_busy&&virtual_cycles>=gfx_ready,"graphics parameters written only while idle");gfx[p]=d;
 if(p!=1)return 1;jobs++;
 unsigned sp=gfx[4],dp=gfx[5],src=gfx[6]+256*gfx[7],dst=gfx[8]+256*gfx[9],w=gfx[10]+256*gfx[11],height=gfx[12];
 require(sp<16&&dp<16,"framebuffer page bounds");
 unsigned char*s=physical+0x100000+sp*65536,*t=physical+0x100000+dp*65536;
 if(d==3){front=dp;if(flip_hook)flip_hook(dp);gfx_ready=(virtual_cycles/20000+1)*20000;return 1;}
 if(d==4){require(dst<64000,"pixel destination bounds");t[dst]=gfx[3];gfx_ready=virtual_cycles+7;return 1;}
 if(d==5){require(src<64000,"pixel source bounds");gfx[13]=s[src];gfx_ready=virtual_cycles+7;return 1;}
 require(w&&w<=320&&height&&height<=200&&dst+320*(height-1)+w<=64000,"rectangle destination bounds");
 if(d==1){for(unsigned y=0;y<height;y++)memset(t+dst+y*320,gfx[3],w);}
 else if(d==2||d==6){
  require(src+320*(height-1)+w<=64000,"rectangle source bounds");unsigned char copy[64000];
  for(unsigned y=0;y<height;y++)memcpy(copy+y*w,s+src+y*320,w);
  for(unsigned y=0;y<height;y++)for(unsigned x=0;x<w;x++)if(d==2||copy[y*w+x]!=gfx[3])t[dst+y*320+x]=copy[y*w+x];
 }else require(0,"supported command");
 gfx_ready=virtual_cycles+w*height/8+10;return 1;
}
static unsigned game_invoke(unsigned a,unsigned b,unsigned x){
 unsigned pc0=PC,sp0=SP,a0=A,b0=B,x0=X,h0=h,i0=i,n0=n,z0=z,v0=v,c0=c,page0=page;
 r[0x210]=0x3f;r[0x211]=0xe6;r[0x212]=1;PC=0x210;A=a;B=b;X=x;
 uint64_t deadline=virtual_cycles+15000000;
 do{until(virtual_cycles+1);require(virtual_cycles<deadline,"GAMEBIOS returns");}while(PC!=0x212);
 unsigned result=A;result_b=B;result_x=X;
 require(SP==sp0&&page==page0,"GAMEBIOS preserves stack and ROM page");
 require(h==h0&&i==i0&&n==n0&&z==z0&&v==v0&&c==c0,"GAMEBIOS preserves actual returned CCR");
 PC=pc0;A=a0;B=b0;X=x0;return result;
}
static unsigned call(unsigned op,unsigned b,unsigned x,unsigned expected){
 unsigned g=ram_group,old_i=i;unsigned a=game_invoke(op,b,x);
 if(a!=expected){fprintf(stderr,"E6 op%u B%u X%04x: got %u expected %u, state=%04x owner=%04x lock=%u\n",op,b,x,a,expected,state,r[state+4]*256+r[state+5],r[state+3]);require(0,"GAMEBIOS status");}
 require(ram_group==g&&i==old_i,"RAM group and interrupt mask retained");
 if(op!=0&&op!=8&&op!=27)require(result_b==b&&result_x==x,"B and X preserved");return a;
}
static void open_context(unsigned flags){word_at(0x5000,8608);r[0x5002]=1;r[0x5003]=flags;call(1,0,0x5000,0);}
static void rect(int x,int y,unsigned w,unsigned height,unsigned colour){word_at(0x7400,x);word_at(0x7402,y);word_at(0x7404,w);r[0x7406]=height;r[0x7407]=colour;call(9,0,0x7400,0);}
static void pixel(int x,int y,unsigned colour){word_at(0x7400,x);word_at(0x7402,y);r[0x7404]=colour;call(7,0,0x7400,0);}
static void line(int x0,int y0,int x1,int y1,unsigned colour){word_at(0x7400,x0);word_at(0x7402,y0);word_at(0x7404,x1);word_at(0x7406,y1);r[0x7408]=colour;call(10,0,0x7400,0);}
static void line_oracle(unsigned char*out,int x,int y,int ex,int ey,unsigned c){
 int dx=abs(ex-x),dy=abs(ey-y),sx=x<ex?1:-1,sy=y<ey?1:-1,e=dx-dy;
 for(;;){if(x>=0&&x<320&&y>=0&&y<200)out[y*320+x]=c;if(x==ex&&y==ey)return;int e2=2*e;if(e2> -dy){e-=dy;x+=sx;}if(e2<dx){e+=dx;y+=sy;}}
}
static void note(unsigned channel,unsigned n,unsigned ticks,unsigned volume){r[0x7400]=channel;r[0x7401]=n;word_at(0x7402,ticks);r[0x7404]=volume;call(20,0,0x7400,0);}
static void restored(void){
 require(!gfx[0]&&front==4&&!readback&&!memcmp(pal,saved_pal,8192),"palette/front/mode restored");
 require(!enabled&&!pending&&period==960000&&divider==0x03000000&&!memcmp(ay,saved_ay,14),"AY registers, divider and timer restored");
 if((r[0xefc8]*256+r[0xefc9])!=old_irq||(r[0xedf2]>>4)!=old_page)fprintf(stderr,"IRQ=%04x/%04x page=%02x/%02x saved=%02x%02x/%02x\n",r[0xefc8]*256+r[0xefc9],old_irq,r[0xedf2]>>4,old_page,r[state+28],r[state+29],r[state+30]);
 require((r[0xefc8]*256+r[0xefc9])==old_irq&&(r[0xedf2]>>4)==old_page,"music vector and bank restored");
 require(!r[state+4]&&!r[state+5]&&!r[state+3],"owner released and unlocked");
 require(r[0xefcc]*256+r[0xefcd]>=0xc000,"inactive vector restored to ROM; no resident GAMEBIOS state");
}
static void gfx_test(void){
 call(3,1,0,0);call(4,2,0,0);unsigned char*fb=physical+0x120000,*expected=calloc(64000,1);
 memset(fb,0,64000);pixel(-1,2,5);pixel(320,2,5);pixel(0,-1,5);pixel(0,200,5);require(!memcmp(fb,expected,64000),"outside pixels ignored");
 pixel(319,199,47);expected[63999]=47;call(8,0,0x7400,0);require(result_b==47,"read pixel result");
 rect(-3,-4,8,9,23);for(unsigned y=0;y<5;y++)memset(expected+y*320,23,5);
 rect(318,198,30,20,11);for(unsigned y=198;y<200;y++)memset(expected+y*320+318,11,2);
 rect(-32768,0,2,2,8);rect(32767,32767,2,2,8);
 const int lines[][4]={{-100,17,500,195},{270,210,11,-20},{5,8,5,8},{40,99,250,99},{63,-100,63,300},{300,30,20,100},{20,100,300,30}};
 for(unsigned k=0;k<sizeof(lines)/sizeof(*lines);k++){line(lines[k][0],lines[k][1],lines[k][2],lines[k][3],60+k);line_oracle(expected,lines[k][0],lines[k][1],lines[k][2],lines[k][3],60+k);}
 require(!memcmp(fb,expected,64000),"clipped pixels, rectangles and all line octants");free(expected);
 // E0 wrappers must return the nested SWI result and preserve the public ABI.
 r[0x7400]=2;r[0x7401]=0;r[0x7402]=2;r[0x7403]=3;word_at(0x7404,0);word_at(0x7406,640);word_at(0x7408,7);r[0x740a]=2;
 call(11,0,0x7400,0);for(unsigned y=0;y<2;y++)require(!memcmp(physical+0x130000+640+y*320,fb+y*320,7),"COPY wrapper");
 memset(physical+0x130000,0,64000);physical[0x130000]=81;physical[0x130001]=82;physical[0x130000+320]=83;physical[0x130000+321]=0;
 word_at(0x7400,-1);word_at(0x7402,12);word_at(0x7404,0);word_at(0x7406,2);r[0x7408]=2;r[0x7409]=3;r[0x740a]=2;r[0x740b]=0;
 unsigned untouched=fb[13*320];call(12,0,0x7400,0);require(fb[12*320]==82&&fb[13*320]==untouched,"signed clipped transparent sprite wrapper");
 // Old BIOS font is the independent glyph oracle.
 r[0x7400]=3;r[0x7401]=4;r[0x7402]=5;r[0x7403]=3;call(17,0,0x7400,0);
 r[0x7400]=27;r[0x7401]=6;call(16,0,0x7400,0);call(19,0,0,0);call(13,'A',0,0);
 for(unsigned y=0;y<8;y++)for(unsigned x=0;x<8;x++)require(fb[(32+y)*320+24+x]==((physical[0x10000+6144+'A'*8+y]&(128>>x))?27:6),"native font pixels in framebuffer");
 for(unsigned y=32;y<56;y++)for(unsigned x=24;x<64;x++)fb[y*320+x]=y;
 call(18,1,0,0);for(unsigned y=32;y<56;y++)for(unsigned x=24;x<64;x++)require(fb[y*320+x]==(y<48?y+8:6),"text scroll copies eight pixel rows and clears bottom");
 call(18,3,0,0);for(unsigned y=32;y<56;y++)for(unsigned x=24;x<64;x++)require(fb[y*320+x]==6,"whole-window scroll clears");
 r[0x7400]=3;r[0x7401]=4;call(15,0,0x7400,0);strcpy((char*)r+0x7500,"ABCDE\r\nFG\bH");call(14,0,0x7500,0);
 require(r[state+11]==5&&r[state+12]==6,"wrap, CR/LF and backspace cursor");
 // PAL samples checked against coefficients extracted from original waveform fixture.
 const signed char *coef=(const signed char*)physical; // loaded below from assembled coefficient constants
 size_t sz;unsigned char *coeff=load("build/gamebios/coeff.bin",&sz);require(sz==96,"coefficient fixture");coef=(const signed char*)coeff;
 for(unsigned n=0;n<6;n++){
  unsigned rgb[3]={(n*37+3)&255,(n*53+99)&255,(n*71+11)&255};r[0x7400]=n+5;for(unsigned k=0;k<3;k++)r[0x7401+k]=rgb[k];call(6,0,0x7400,0);
  for(unsigned phase=0;phase<32;phase++){int sum=7936;for(unsigned k=0;k<3;k++)sum+=coef[phase*3+k]*rgb[k];require(pal[(n+5)*32+phase]==((sum>>9)&63),"RGB888 PAL sample calculation");}
 }
 call(5,2,0,0);require(front==2,"front page flipped");call(3,7,0,0);
 for(unsigned channel=0;channel<3;channel++)for(unsigned level=0;level<64;level++)for(unsigned phase=0;phase<32;phase++){
  int sum=(channel==1?768:6400)+coef[phase*3+channel]*((level<<2)|(level>>4));require(pal[(channel*64+level)*32+phase]==((sum>>9)&63),"HAM8 component samples");}
 free(coeff);call(7,0,0x7400,8);call(13,'A',0,8);
 word_at(0x7400,0);word_at(0x7402,0);r[0x7404]=0xc1;call(29,0,0x7400,0);require(fb[0]==0xc1,"encoded HAM byte");call(3,1,0,0);
}
static void audio_test(void){
 static const unsigned periods[]={284,142,252,254};
 for(unsigned clock=0;clock<4;clock++){call(28,clock,0,0);note(1,46,0,9);require((ay[2]|((ay[3]&15)<<8))==periods[clock]&&ay[9]==9&&!(ay[7]&2),"A4 note and chosen PSG clock");}
 call(24,0,0,0);call(28,0,0,0);
 memset(r+0x7400,0,14);r[0x7400]=17;r[0x7407]=0x38;r[0x7408]=3;r[0x7409]=4;r[0x740a]=5;r[0x740d]=255;
 for(unsigned n=0;n<16;n++)call(21,0,0x7400,0);call(21,0,0x7400,7);call(27,0,0,0);require(result_b==16,"exact music queue capacity");
 unsigned env=envelopes;call(23,1,0,0);call(28,1,0,5);call(22,0,0x7400,5);
 note(1,46,3,12);until(virtual_cycles+25000);require(ay[9]==12&&ay[8]==3&&ay[10]==5,"effect merges with music channels");
 until(virtual_cycles+60000);require(ay[9]==4,"effect expiry restores music");require(envelopes==env,"R13 sentinel avoids retrigger");
 call(23,0,0,0);call(27,0,0,0);unsigned paused=result_x,q=result_b;until(virtual_cycles+70000);call(27,0,0,0);require(result_x==paused&&result_b==q&&!ay[8]&&!ay[9]&&!ay[10],"pause retains position and mutes");
 call(26,4,0,0);call(23,1,0,0);until(virtual_cycles+22000);require(!ay[10]&&ay[8]==3,"manual reserved channel silent");
 call(24,0,0,0);r[0x740d]=10;call(21,0,0x7400,0);call(23,1,0,0);env=envelopes;until(virtual_cycles+25000);require(envelopes==env+1,"envelope frame retriggers once");until(virtual_cycles+65000);require(envelopes==env+1,"starved queue holds frame without repeated envelope");
 call(24,0,0,0);r[0x7400]=6;r[0x7401]=7;call(25,0,0x7400,0);require(ay[6]==7,"raw noise register");
 for(unsigned n=0;n<2;n++){uint32_t t=n?24000000:240000;word_at(0x7400,t>>16);word_at(0x7402,t);call(22,0,0x7400,0);require(period==t,"rate limits accepted");}
 word_at(0x7400,0);word_at(0x7402,0);call(22,0,0x7400,1);
}
#ifndef GAMEBIOS_MAIN
#define GAMEBIOS_MAIN main
#endif
int GAMEBIOS_MAIN(int argc,char**argv){
 if(argc!=4)return 2;model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);require(n==ROM_BYTES+512,"paired ROM fixture");
 memcpy(config,rom,HEADER_BYTES);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);image=load(argv[1],&image_size);committed=1;
 MC6800Init();MC6800Reset();until(60000000);key(0x1c);key(0x1c);prompt_wait();r=MC6800GetCpuRam();
 state=r[0xefcc]*256+r[0xefcd];pcb=r[0xec00]*256+r[0xec01];sp_before=SP;require(state>=0xc000,"GAMEBIOS inactive in ROM without a heap allocation");
 native_step_hook=observe;watch_resets=1;call(0,0,0,1);require(result_b==31&&result_x==8608,"discoverable ABI/features/context size");
 if(!cpu_hd){call(1,0,0x5000,3);command("dir c:");printf("PASS GAMEBIOS %s/MC6800 discovery, ISA refusal and native DOS\n",argv[2]);return 0;}
 front=4;for(unsigned k=0;k<8192;k++)pal[k]=saved_pal[k]=(k*17+k/32+5)&63;
 for(unsigned k=0;k<14;k++)ay[k]=saved_ay[k]=(k*5+11)&255;
 old_irq=r[0xefc8]*256+r[0xefc9];old_page=r[0xedf2]>>4;
 call(2,0,0,4);call(30,0,0,1);call(1,0,0xffff,1);
 word_at(0x5000,8608);r[0x5002]=1;r[0x5003]=3;fault_busy=1;call(1,0,0x5000,5);fault_busy=0;fault_audio=1;call(1,0,0x5000,2);fault_audio=0;
 open_context(3);require(!memcmp(r+0x5020,saved_pal,8192),"complete palette backup");call(1,0,0x5000,5);
 word_at(0xec00,pcb+1);call(3,1,0,6);word_at(0xec00,pcb);
 r[state+3]=1;call(3,1,0,5);require(r[state+3]==1,"nested lock retained");r[state+3]=0;
 gfx_test();audio_test();call(2,0,0,0);restored();
 open_context(3);call(3,1,0,0);call(2,0,0,0);restored();
 // Real PGM deliberately omits CLOSE. Native INT38 must reclaim it.
 command("b:gameleak");restored();require(SP==sp_before,"INT38 cleanup balances stack");
 command("dir a:");command("dir b:");command("dir c:");require(SP==sp_before&&!resets&&!fdc_port_accesses,"native DOS works after repeated closes");
 printf("PASS GAMEBIOS %s/HD6303: context, palette, clipping/lines/text/scroll/HAM8, AY queue/notes/mixing/pause/rates and restored DOS (%u jobs)\n",argv[2],jobs);return 0;
}
