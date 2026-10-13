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
static unsigned fault_busy,fault_audio,fault_divider,fault_palette,gfx_failed;
static unsigned gfx_revision=6;
static unsigned char raw_bytes[64];
static unsigned raw_head,raw_count,raw_overflow,keyboard_raw_missing,raw_capture,keyboard_capture_missing;
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
#ifdef ARCADE_HG
 if(hg_transport_read(a,out))return 1;
#endif

 if(a>=0xe6b0&&a<=0xe6b3){*out=0xff;if(!keyboard_raw_missing)switch(a&3){case 0:*out='R';break;case 1:*out=(raw_count!=0)|((raw_count==64)<<5)|(raw_overflow<<7)|(raw_capture<<6);break;case 2:if(raw_count){*out=raw_bytes[raw_head++&63];raw_count--;}break;case 3:*out=raw_count;}return 1;}
 if(a>=0xe650&&a<=0xe65f){unsigned p=a&15;
  *out=p==0?gfx[0]|(gfx_failed?16:0)|((fault_busy||virtual_cycles<gfx_ready)?128:0):p==2?front:p==14?(readback?pal[paladdr]:(fault_palette&&PC>=0xf640&&PC<0xf900?0:'G')):p==15?gfx_revision:gfx[p];return 1;}
 if(a>=0xe610&&a<=0xe61f){*out=ay[a&15];return 1;}
 if(a>=0xe690&&a<=0xe69f){unsigned p=a&15;audio_update();*out=0;
  if(p==0)*out=enabled|(pending<<7)|(overrun<<6)|(fault_divider<<5);
  else if(p==1)*out=fault_audio?0xff:0x59;
  else if(p>=2&&p<=5)*out=period>>(8*(5-p));
  else if(p>=11&&p<=14)*out=divider>>(8*(14-p));return 1;}
 return 0;
}
static int hg_write_byte(uint16_t a,unsigned char d){
#ifdef ARCADE_HG
 if(hg_transport_write(a,d))return 1;
#endif

 if(a>=0xe6b0&&a<=0xe6b3){if(a==0xe6b3&&!keyboard_raw_missing){if(d&1)raw_head=raw_count=0;if(d&2)raw_overflow=0;if(d&4&&!keyboard_capture_missing)raw_capture=1;if(d&8)raw_capture=0;}return 1;}
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
 if(!p){gfx[0]=d&15;if(!(d&7))raw_capture=0;return 1;}
 if(p==2){paladdr=(paladdr&0x1f00)|d;return 1;}
 if(p==13){paladdr=((d&31)<<8)|(paladdr&255);return 1;}
 if(p==14){pal[paladdr]=d&63;paladdr=(paladdr+1)&8191;return 1;}
 if(p==15){readback=d&1;if(d&2)paladdr=(paladdr+1)&8191;return 1;}
 require(!fault_busy&&virtual_cycles>=gfx_ready,"graphics parameters written only while idle");gfx[p]=d;
 if(p!=1)return 1;jobs++;
 // Production failed is sticky across mode writes, and clears only when
 // the engine accepts its next command. An invalid command touches no RAM.
 gfx_failed=0;
 if(d<1||d>6){gfx_failed=1;gfx_ready=virtual_cycles+7;return 1;}
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
static unsigned service_invoke(unsigned service,unsigned a,unsigned b,unsigned x){
 unsigned pc0=PC,sp0=SP,a0=A,b0=B,x0=X,h0=h,i0=i,n0=n,z0=z,v0=v,c0=c,page0=page;
 r[0x210]=0x3f;r[0x211]=service;r[0x212]=1;PC=0x210;A=a;B=b;X=x;
 uint64_t deadline=virtual_cycles+15000000;
 do{until(virtual_cycles+1);require(virtual_cycles<deadline,"GAMEBIOS returns");}while(PC!=0x212);
 unsigned result=A;result_b=B;result_x=X;
 require(SP==sp0&&page==page0,"GAMEBIOS preserves stack and ROM page");
 require(h==h0&&i==i0&&n==n0&&z==z0&&v==v0&&c==c0,"GAMEBIOS preserves actual returned CCR");
 PC=pc0;A=a0;B=b0;X=x0;return result;
}
static unsigned game_invoke(unsigned a,unsigned b,unsigned x){return service_invoke(0xe6,a,b,x);}
static unsigned free_banks(void){require(service_invoke(0xe5,0,0,0)==1,"RAMMAN available");return result_b;}
static void bank_move(unsigned sb,unsigned db,unsigned src,unsigned dst,unsigned bytes,unsigned status){
 r[0x7b00]=sb;r[0x7b01]=db;word_at(0x7b02,src);word_at(0x7b04,dst);word_at(0x7b06,bytes);
 unsigned old_group=ram_group;
 unsigned actual=service_invoke(0xe8,1,0x55,0x7b00);
 if(actual!=status)fprintf(stderr,"BANKCOPY %u/%u %04x/%04x n%u got%u expected%u\n",sb,db,src,dst,bytes,actual,status);
 require(actual==status&&result_b==0x55&&result_x==0x7b00&&ram_group==old_group,"BANKCOPY result, B/X/group preserved");
}
static void bankcopy_test(void){
 require(service_invoke(0xe8,0,0,0)==1&&result_b==7&&result_x==8192,"native fixed-ROM copy service discovery");
 if(!cpu_hd){bank_move(255,255,0x8000,0x9000,1,3);return;}
 require(service_invoke(0xe5,1,111,0x7a00)==0,"own copy-test banks");
 for(unsigned k=0;k<8192;k++)r[0x8000+k]=(k*17+k/31+3)&255;
 unsigned char expected[8192];memcpy(expected,r+0x8000,sizeof expected);
 bank_move(255,0,0x8000,0,8192,0);require(!memcmp(physical+0x22000,expected,8192),"ordinary RAM to bank");
 bank_move(0,110,0,0,8192,0);require(!memcmp(physical+0xfe000,expected,8192),"bank to bank across final partial group");
 memset(r+0x8000,0,8192);bank_move(110,255,0,0x8000,8192,0);require(!memcmp(r+0x8000,expected,8192),"bank to ordinary RAM");
 memmove(expected+1,expected,8191);bank_move(110,110,0,1,8191,0);require(!memcmp(physical+0xfe000,expected,8192),"backwards bank memmove");
 memmove(expected,expected+7,8185);bank_move(110,110,7,0,8185,0);require(!memcmp(physical+0xfe000,expected,8192),"forwards bank memmove");
 bank_move(255,255,0x8000,0x9000,256,0);require(!memcmp(r+0x9000,r+0x8000,256),"ordinary RAM copy");
 unsigned char bytes[512];memcpy(bytes,r+0x8000,512);memmove(bytes+1,bytes,511);bank_move(255,255,0x8000,0x8001,511,0);require(!memcmp(bytes,r+0x8000,512),"overlapping ordinary RAM copy");
 bank_move(0,110,31,19,0,0);bank_move(0,110,8191,7,2,1);bank_move(0,110,7,8191,2,1);
 bank_move(111,110,0,0,1,1);bank_move(0,255,0,0xbdff,2,1);bank_move(255,0,0xfffe,0,4,1);bank_move(0,110,0,0,8193,1);
 require(!memcmp(physical+0xfe000,expected,8192),"invalid/zero copy writes nothing");
 require(service_invoke(0xe5,2,0,0x7a00)==0&&free_banks()==111,"copy service allocates no memory");
}
static unsigned call(unsigned op,unsigned b,unsigned x,unsigned expected){
 unsigned g=ram_group,old_i=i;unsigned a=game_invoke(op,b,x);
 if(a!=expected){fprintf(stderr,"E6 op%u B%u X%04x: got %u expected %u, state=%04x owner=%04x lock=%u\n",op,b,x,a,expected,state,r[state+4]*256+r[state+5],r[state+3]);require(0,"GAMEBIOS status");}
 require(ram_group==g&&i==old_i,"RAM group and interrupt mask retained");
 if(op!=0&&op!=8&&op!=27)require(result_b==b&&result_x==x,"B and X preserved");return a;
}
static void open_context(unsigned flags){word_at(0x5000,416);r[0x5002]=2;r[0x5003]=flags;call(1,0,0x5000,0);}
static void rect(int x,int y,unsigned w,unsigned height,unsigned colour){word_at(0x7400,x);word_at(0x7402,y);word_at(0x7404,w);r[0x7406]=height;r[0x7407]=colour;call(9,0,0x7400,0);}
static void pixel(int x,int y,unsigned colour){word_at(0x7400,x);word_at(0x7402,y);r[0x7404]=colour;call(7,0,0x7400,0);}
static void line(int x0,int y0,int x1,int y1,unsigned colour){word_at(0x7400,x0);word_at(0x7402,y0);word_at(0x7404,x1);word_at(0x7406,y1);r[0x7408]=colour;call(10,0,0x7400,0);}
static void line_oracle(unsigned char*out,int x,int y,int ex,int ey,unsigned c){
 int dx=abs(ex-x),dy=abs(ey-y),sx=x<ex?1:-1,sy=y<ey?1:-1,e=dx-dy;
 for(;;){if(x>=0&&x<320&&y>=0&&y<200)out[y*320+x]=c;if(x==ex&&y==ey)return;int e2=2*e;if(e2> -dy){e-=dy;x+=sx;}if(e2<dx){e+=dx;y+=sy;}}
}
static void sprite_edges(void){
 static const int xs[]={-32768,-320,-17,-16,-1,0,1,303,304,319,320,32767};
 static const int ys[]={-32768,-200,-11,-10,-1,0,1,189,190,199,200,32767};
 unsigned char*src=physical+0x130000,*dst=physical+0x120000,*expected=malloc(64000);
 const unsigned offset=10*320+13,w=17,height=11;
 for(unsigned k=0;k<64000;k++)src[k]=k%7?(k*17+9)&255:0;
 word_at(0x7404,offset);word_at(0x7406,w);r[0x7408]=height;
 r[0x7409]=3;r[0x740a]=2;r[0x740b]=0;
 for(unsigned a=0;a<sizeof xs/sizeof*xs;a++)for(unsigned b=0;b<sizeof ys/sizeof*ys;b++){
  memset(dst,37,64000);memset(expected,37,64000);
  word_at(0x7400,xs[a]);word_at(0x7402,ys[b]);call(12,0,0x7400,0);
  for(unsigned y=0;y<height;y++)for(unsigned x=0;x<w;x++){
   int dx=xs[a]+x,dy=ys[b]+y;unsigned colour=src[offset+y*320+x];
   if(dx>=0&&dx<320&&dy>=0&&dy<200&&colour)expected[dy*320+dx]=colour;
  }
  require(!memcmp(dst,expected,64000),"independent keyed-sprite clipping at all edges/extreme coordinates");
 }
 word_at(0x7400,0);word_at(0x7402,0);unsigned before=jobs;
 word_at(0x7404,65535);call(12,0,0x7400,0);
 word_at(0x7404,offset);word_at(0x7406,0);call(12,0,0x7400,0);
 word_at(0x7406,321);call(12,0,0x7400,0);
 word_at(0x7406,w);r[0x7408]=0;call(12,0,0x7400,0);
 r[0x7408]=201;call(12,0,0x7400,0);
 require(jobs==before,"invalid sprite dimensions/source execute no hardware command");
 r[0x7408]=height;r[0x7409]=16;call(12,0,0x7400,1);
 r[0x7409]=3;r[0x740a]=16;call(12,0,0x7400,1);
 free(expected);
}
static void note(unsigned channel,unsigned n,unsigned ticks,unsigned volume){r[0x7400]=channel;r[0x7401]=n;word_at(0x7402,ticks);r[0x7404]=volume;call(20,0,0x7400,0);}
static void restored(void){
 require(!raw_capture,"exclusive keyboard capture released on exit/cleanup");
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
 // Local blitter operations preserve the public ABI without another ROM.
 r[0x7400]=2;r[0x7401]=0;r[0x7402]=2;r[0x7403]=3;word_at(0x7404,0);word_at(0x7406,640);word_at(0x7408,7);r[0x740a]=2;
 call(11,0,0x7400,0);for(unsigned y=0;y<2;y++)require(!memcmp(physical+0x130000+640+y*320,fb+y*320,7),"local COPY");
 memset(physical+0x130000,0,64000);physical[0x130000]=81;physical[0x130001]=82;physical[0x130000+320]=83;physical[0x130000+321]=0;
 word_at(0x7400,-1);word_at(0x7402,12);word_at(0x7404,0);word_at(0x7406,2);r[0x7408]=2;r[0x7409]=3;r[0x740a]=2;r[0x740b]=0;
 unsigned untouched=fb[13*320];call(12,0,0x7400,0);require(fb[12*320]==82&&fb[13*320]==untouched,"local signed clipped transparent sprite");
 sprite_edges();
 // Old BIOS font is the independent glyph oracle.
 r[0x7400]=3;r[0x7401]=4;r[0x7402]=5;r[0x7403]=3;call(17,0,0x7400,0);
 r[0x7400]=27;r[0x7401]=6;call(16,0,0x7400,0);call(19,0,0,0);call(13,'A',0,0);
 for(unsigned y=0;y<8;y++)for(unsigned x=0;x<8;x++)require(fb[(32+y)*320+24+x]==((physical[0x10000+6144+'A'*8+y]&(128>>x))?27:6),"native font pixels in framebuffer");
 uint64_t glyph_cycles=0;unsigned glyph_jobs=0;
 for(unsigned ch=32;ch<256;ch++){
  r[0x7400]=3;r[0x7401]=4;call(15,0,0x7400,0);
  uint64_t before=virtual_cycles;unsigned jb=jobs;call(13,ch,0,0);
  glyph_cycles+=virtual_cycles-before;glyph_jobs+=jobs-jb;
  for(unsigned y=0;y<8;y++)for(unsigned x=0;x<8;x++)
   require(fb[(32+y)*320+24+x]==((physical[0x10000+6144+ch*8+y]&(128>>x))?27:6),"all printable native glyphs preserve foreground/background");
 }
 printf("GLYPHS %s: 224 characters, %llu CPU cycles, %u graphics jobs\n",model_a?"601A":"601",(unsigned long long)glyph_cycles,glyph_jobs);fflush(stdout);
 for(unsigned y=32;y<56;y++)for(unsigned x=24;x<64;x++)fb[y*320+x]=y;
 call(18,1,0,0);for(unsigned y=32;y<56;y++)for(unsigned x=24;x<64;x++)require(fb[y*320+x]==(y<48?y+8:6),"text scroll copies eight pixel rows and clears bottom");
 call(18,3,0,0);for(unsigned y=32;y<56;y++)for(unsigned x=24;x<64;x++)require(fb[y*320+x]==6,"whole-window scroll clears");
 r[0x7400]=3;r[0x7401]=4;call(15,0,0x7400,0);strcpy((char*)r+0x7500,"ABCDE\r\nFG\bH");call(14,0,0x7500,0);
 require(r[state+11]==5&&r[state+12]==6,"wrap, CR/LF and backspace cursor");
 // PAL samples checked against coefficients extracted from original waveform fixture.
 signed char coeff[96];unsigned entries=0,value;int ch;
 FILE*source=fopen("firmware/gfx/PALCOEF.ASM","r");require(source!=NULL,"PAL coefficient source");
 while((ch=fgetc(source))!=EOF)if(ch=='$'){
  require(entries<96&&fscanf(source,"%2x",&value)==1,"coefficient data syntax");coeff[entries++]=value;
 }
 fclose(source);require(entries==96,"complete independent coefficient table");const signed char*coef=coeff;
 for(unsigned n=0;n<6;n++){
  unsigned rgb[3]={(n*37+3)&255,(n*53+99)&255,(n*71+11)&255};r[0x7400]=n+5;for(unsigned k=0;k<3;k++)r[0x7401+k]=rgb[k];call(6,0,0x7400,0);
  for(unsigned phase=0;phase<32;phase++){int sum=7936;for(unsigned k=0;k<3;k++)sum+=coef[phase*3+k]*rgb[k];require(pal[(n+5)*32+phase]==((sum>>9)&63),"RGB888 PAL sample calculation");}
 }
 call(5,2,0,0);require(front==2,"front page flipped");call(3,7,0,0);
 for(unsigned channel=0;channel<3;channel++)for(unsigned level=0;level<64;level++)for(unsigned phase=0;phase<32;phase++){
  int sum=(channel==1?768:6400)+coef[phase*3+channel]*((level<<2)|(level>>4));require(pal[(channel*64+level)*32+phase]==((sum>>9)&63),"HAM8 component samples");}
 call(7,0,0x7400,8);call(13,'A',0,8);
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
static void batch_entry(unsigned n,unsigned op,unsigned b,unsigned ptr){unsigned p=0x7800+4*n;r[p]=op;r[p+1]=b;word_at(p+2,ptr);}
static void batch_test(void){
 call(3,1,0,0);call(30,0,0xffff,0);call(30,33,0x7800,1);call(30,2,0xbdfc,1);call(30,1,0xffff,1);
 word_at(0x7600,5);word_at(0x7602,7);word_at(0x7604,4);r[0x7606]=2;r[0x7607]=99;
 r[0x7610]=2;r[0x7611]=0;r[0x7612]=1;r[0x7613]=2;word_at(0x7614,7*320+5);word_at(0x7616,10*320+9);word_at(0x7618,4);r[0x761a]=2;
 batch_entry(0,4,1,0);batch_entry(1,9,0,0x7600);batch_entry(2,11,0,0x7610);call(30,3,0x7800,0);
 for(unsigned y=0;y<2;y++)for(unsigned x=0;x<4;x++)require(physical[0x110000+(7+y)*320+5+x]==99&&physical[0x120000+(10+y)*320+9+x]==99,"batch target/rectangle/nested COPY execute in order");
 const unsigned forbidden[]={0,1,2,3,5,6,8,20,21,24,30,255};unsigned jb=jobs;
 for(unsigned k=0;k<sizeof forbidden/sizeof*forbidden;k++){batch_entry(0,forbidden[k],0,0x7600);call(30,1,0x7800,1);}require(jobs==jb,"non-graphics and recursive batch operations are refused");
 word_at(0x7620,15);word_at(0x7622,17);r[0x7624]=43;
 batch_entry(0,7,0,0x7620);batch_entry(1,30,0,0);batch_entry(2,9,0,0x7600);jb=jobs;call(30,3,0x7800,1);
 require(jobs==jb+1&&physical[0x110000+17*320+15]==43,"batch stops on first error and retains prior completed work");
 batch_entry(0,9,0,0x7600);fault_busy=1;call(30,1,0x7800,2);fault_busy=0;
 // Long text batch crosses many musical IRQs. Foreground scratch must not
 // alias the IRQ's note/queue pointers; preserve B/X/CCR/page on return.
 word_at(0x7400,14);word_at(0x7402,0xa600);call(22,0,0x7400,0);
 memset(r+0x7400,0,14);r[0x7407]=0x38;r[0x7408]=4;r[0x740d]=255;call(21,0,0x7400,0);call(23,1,0,0);
 unsigned ticks=r[state+24]*256+r[state+25];for(unsigned k=0;k<32;k++)batch_entry(k,13,'W',0);
 call(30,32,0x7800,0);require(r[state+24]*256+r[state+25]>ticks,"musical IRQ continues during a full batch");call(24,0,0,0);
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
 native_step_hook=observe;watch_resets=1;call(0,0,0,2);require(result_b==63&&result_x==416,"discoverable ABI/features/context size");
 bankcopy_test();
 if(!cpu_hd){call(1,0,0x5000,3);command("dir c:");printf("PASS GAMEBIOS %s/MC6800 discovery, ISA refusal and native DOS\n",argv[2]);return 0;}
 front=4;for(unsigned k=0;k<8192;k++)pal[k]=saved_pal[k]=(k*17+k/32+5)&63;
 for(unsigned k=0;k<14;k++)ay[k]=saved_ay[k]=(k*5+11)&255;
 old_irq=r[0xefc8]*256+r[0xefc9];old_page=r[0xedf2]>>4;
 call(2,0,0,4);call(31,0,0,1);call(1,0,0xffff,1);
 word_at(0x5000,8608);r[0x5002]=1;r[0x5003]=3;call(1,0,0x5000,1);
 word_at(0x5000,416);r[0x5002]=2;r[0x5003]=3;fault_busy=1;call(1,0,0x5000,5);fault_busy=0;fault_audio=1;call(1,0,0x5000,2);fault_audio=0;
 require(free_banks()==111,"all banks initially free");
 fault_palette=1;call(1,0,0x5000,2);fault_palette=0;restored();
 require(free_banks()==111,"pre-copy failure frees palette bank without modifying unsaved AY");
 open_context(2);require(free_banks()==111,"audio-only context allocates no palette bank");call(2,0,0,0);restored();
 r[0x5003]=3;
 require(service_invoke(0xe5,1,111,0x7a00)==0,"exhaust RAM pool");
 call(1,0,0x5000,7);require(free_banks()==0&&!enabled&&!gfx[0],"failed OPEN retains hardware and existing allocation");
 require(service_invoke(0xe5,2,0,0x7a00)==0&&free_banks()==111,"release original full-pool lease");
 require(service_invoke(0xe5,1,110,0x7a00)==0,"force palette into final partial RAM group");
 memset(r+0x51a0,0xa5,256);open_context(3);
 require(r[0x5006]==1&&r[0x5007]==110&&r[0x5008]==1,"palette uses last RAMMAN bank");
 require(!memcmp(physical+0x22000+r[0x5007]*8192,saved_pal,8192),"complete banked palette backup");
 for(unsigned k=0;k<256;k++)require(r[0x51a0+k]==0xa5,"compact context stays within 416 bytes");
 require(free_banks()==0,"video owns exactly one palette bank");call(1,0,0x5000,5);
 word_at(0xec00,pcb+1);call(3,1,0,6);word_at(0xec00,pcb);
 r[state+3]=1;call(3,1,0,5);require(r[state+3]==1,"nested lock retained");r[state+3]=0;
 gfx_test();audio_test();batch_test();call(2,0,0,0);restored();
 require(free_banks()==1,"CLOSE releases only palette bank");
 require(service_invoke(0xe5,2,0,0x7a00)==0&&free_banks()==111,"foreign-purpose lease retained through game");
 // A failed raw job must not poison cleanup or the next video owner.
 open_context(3);call(3,1,0,0);
 hg_write_byte(0xe651,0xff);until(virtual_cycles+10);require(gfx_failed,"hardware command error latched");
 call(3,1,0,2);require(gfx_failed,"MODE reports an active-context fault rather than hiding it");
 call(2,0,0,0);restored();require(!gfx_failed,"CLOSE restores front and clears prior completed fault");
 hg_write_byte(0xe651,0xff);until(virtual_cycles+10);
 require(gfx_failed&&!gfx[0],"disabled mode retains hardware error as on board");
 open_context(3);require(!gfx_failed&&front==4,"OPEN acknowledges prior fault with a read-only command");
 call(3,1,0,0);call(2,0,0,0);restored();
 open_context(3);call(3,1,0,0);call(2,0,0,0);restored();
 // A real PGM closes its own context before returning through native INT38.
 command("b:gameexit");restored();require(SP==sp_before,"application CLOSE and INT38 balance stack");
 require(free_banks()==111,"application releases its palette bank");
 command("dir a:");command("dir b:");command("dir c:");require(SP==sp_before&&!resets&&!fdc_port_accesses,"native DOS works after repeated closes");
 printf("PASS GAMEBIOS %s/HD6303: context, palette, clipping/lines/text/scroll/HAM8, AY queue/notes/mixing/pause/rates and restored DOS (%u jobs)\n",argv[2],jobs);return 0;
}
