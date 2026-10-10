// Original native BIOS/UniDOS, real relocatable HD6303 PGM and keyboard ABI.
// The separate production HDL bench checks electrical DMA and actual CPU.
#include <stdint.h>
static int hg_read_byte(uint16_t a,unsigned char*out);
static int hg_write_byte(uint16_t a,unsigned char d);
#define HG_FIXTURE 1
#define NATIVE_STABILITY_MAIN unused_stability_main
#include "test_native_stability.c"
#undef NATIVE_STABILITY_MAIN

static unsigned char gfx[16];
static uint64_t ready_at;
static unsigned version=3,frames,copies,keyed,fail_command,enabled_count;
static int balls[3][4]={{0,0,2,1},{288,168,-3,-2},{12,10,3,2}};
static unsigned valid[2];
static unsigned char background(unsigned x,unsigned y){return ((x/20+y/20)&1)?0x4a:0x25;}
static unsigned char sprite(unsigned x,unsigned y,unsigned ball){
 static const unsigned left[]={12,10,8,6,5,4,3,2,2,1,1,1,0,0,0,0,0,0,0,0,1,1,1,2,2,3,4,5,6,8,10,12};
 static const unsigned colours[]={0xe0,0x1c,3};
 if(x<left[y]||x>=32-left[y])return 0;
 return x>=8&&x<12&&y>=8&&y<12?255:colours[ball];
}
static void check_frame(unsigned page){
 if(copies!=(valid[page]?3:0)||keyed!=3){fprintf(stderr,"animation performs unexpected copies: %u opaque, %u keyed\n",copies,keyed);exit(1);}
 unsigned char*buf=physical+0x100000+page*65536;
 for(unsigned y=0;y<200;y++)for(unsigned x=0;x<320;x++){
  unsigned expected=background(x,y);
  for(unsigned b=0;b<3;b++){
   int sx=x-balls[b][0],sy=y-balls[b][1];
   if(sx>=0&&sx<32&&sy>=0&&sy<32){unsigned c=sprite(sx,sy,b);if(c)expected=c;}
  }
  if(buf[y*320+x]!=expected){fprintf(stderr,"frame %u page %u pixel %u,%u got %02x expected %02x\n",frames,page,x,y,buf[y*320+x],expected);exit(1);}
 }
 for(unsigned y=0;y<200;y++)for(unsigned x=0;x<320;x++)
  if(physical[0x130000+y*320+x]!=background(x,y)){fprintf(stderr,"background damaged\n");exit(1);}
 for(unsigned b=0;b<3;b++)for(unsigned y=0;y<32;y++)for(unsigned x=0;x<32;x++)
  if(physical[0x120000+y*320+b*32+x]!=sprite(x,y,b)){fprintf(stderr,"atlas damaged\n");exit(1);}
 valid[page]=1;copies=keyed=0;frames++;
 for(unsigned b=0;b<3;b++)for(unsigned axis=0;axis<2;axis++){
  int n=balls[b][axis]+balls[b][axis+2],max=axis?168:288;
  if(n<0){n=0;balls[b][axis+2]=-balls[b][axis+2];}
  if(n>max){n=max;balls[b][axis+2]=-balls[b][axis+2];}
  balls[b][axis]=n;
 }
}
static int hg_read_byte(uint16_t a,unsigned char*out){
 if(a<0xe650||a>0xe65f)return 0;
 *out=a==0xe65e?'G':a==0xe65f?version:a==0xe650?(gfx[0]|(virtual_cycles<ready_at?128:0)):gfx[a&15];return 1;
}
static int hg_write_byte(uint16_t a,unsigned char d){
 if(a<0xe650||a>0xe65f)return 0;unsigned p=a&15;
 if(p==0){gfx[0]=d&1;if(d&1)enabled_count++;return 1;}
 if(virtual_cycles<ready_at){fprintf(stderr,"SPRITES register write while busy\n");exit(1);}
 gfx[p]=d;if(p!=1)return 1;
 unsigned sp=gfx[4],dp=gfx[5],so=gfx[6]+256*gfx[7],dest=gfx[8]+256*gfx[9],w=gfx[10]+256*gfx[11],h=gfx[12];
 if(d==3){
  if(gfx[0])check_frame(dp);
  gfx[2]=dp;ready_at=(virtual_cycles/20000+1)*20000;return 1;
 }
 if(!w||w>320||!h||h>200||sp>15||dp>15||dest+320*(h-1)+w>64000||((d==2||d==6)&&so+320*(h-1)+w>64000))exit(1);
 if(d==fail_command){gfx[0]|=16;return 1;}
 unsigned char*dst=physical+0x100000+dp*65536;
 if(d==1){for(unsigned y=0;y<h;y++)memset(dst+dest+y*320,gfx[3],w);}
 else if(d==2||d==6){
  unsigned char*src=physical+0x100000+sp*65536,*snapshot=malloc(w*h);
  for(unsigned y=0;y<h;y++)memcpy(snapshot+y*w,src+so+y*320,w);
  for(unsigned y=0;y<h;y++)for(unsigned x=0;x<w;x++)
   if(d==2||snapshot[y*w+x]!=gfx[3])dst[dest+y*320+x]=snapshot[y*w+x];
  free(snapshot);
  if(gfx[0]){if(d==6)keyed++;else copies++;if(w!=32||h!=32)exit(1);}
 }else exit(1);
 ready_at=virtual_cycles+w*h/4+10;return 1;
}
static int contains(const char*text){
 unsigned start=crtc[12]*256+crtc[13],stride=crtc[1],step=model_a&&(MC6800GetCpuRam()[0xe629]&2)?2:1;
 unsigned char*r=MC6800GetCpuRam();
 for(unsigned y=0;y<25;y++)for(unsigned x=0;x<stride/step;x++){
  unsigned n;for(n=0;text[n];n++)if(r[(start+y*stride+(x+n)*step+(step==2))&65535]!=(unsigned char)text[n])break;
  if(!text[n])return 1;
 }return 0;
}
static int prompt(void){return PC>=0xf380&&PC<=0xf3a8&&contains("A:\\>");}
static void wait_dos(void){
 uint64_t deadline=virtual_cycles+20000000;
 while(!prompt()&&virtual_cycles<deadline)until(virtual_cycles+10000);
 if(!prompt()||gfx[0]||resets){dump();fprintf(stderr,"SPRITES did not restore DOS\n");exit(1);}
}
static void command(void){key(0x30);KBDModKeyDown(2);key(0x27);KBDModKeyUp(2);key(0x1f);key(0x19);key(0x13);key(0x17);key(0x14);key(0x12);key(0x1f);key(0x1c);}
static void run_demo(void){
 int initial[3][4]={{0,0,2,1},{288,168,-3,-2},{12,10,3,2}};
 memcpy(balls,initial,sizeof balls);memset(valid,0,sizeof valid);frames=copies=keyed=0;
 command();uint64_t deadline=virtual_cycles+30000000;
 while(frames<400&&virtual_cycles<deadline)until(virtual_cycles+10000);
 if(frames<400){dump();fprintf(stderr,"animation stopped at %u frames\n",frames);exit(1);}
 key(0x01);wait_dos();if(!contains("returned to UniDOS"))exit(1);
 printf("PASS %s/HD6303 SPRITES: %u full frames, transparency/overlap, 4-edge bounces, both page histories, no trails, ESC/native keyboard/PGM/DOS\n",model_a?"601A":"601",frames);fflush(stdout);
}
int main(int argc,char**argv){
 if(argc!=3)return 2;model_a=!strcmp(argv[2],"601a");cpu_hd=1;MC6800SetMachine(PYLDIN_MACHINE_HD6303);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);
 if(n!=(ROM_BYTES+512))return 1;memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load(argv[1],&image_size);memcpy(config+64,image+462,32);
#ifdef LEGACY_FIXTURE
 for(unsigned disk=0;disk<2;disk++){
  unsigned off=462+16*disk,base=32+16*disk;memcpy(config+base,image+off+8,8);
  const unsigned char*bpb=image+le32(config+base)*512;unsigned spt=le16(bpb+24),heads=le16(bpb+26),sectors=le16(bpb+19);
  config[base+8]=spt;config[base+10]=heads;config[base+12]=sectors/(spt*heads);
 }
#endif
 committed=1;MC6800Init();MC6800Reset();i=1;until(60000000);key(0x1c);key(0x1c);until(virtual_cycles+1000000);wait_dos();watch_resets=1;
 run_demo();run_demo();
 version=2;unsigned before=enabled_count;command();wait_dos();if(enabled_count!=before||!contains("update FPGA"))return 1;version=3;
 cpu_hd=0;MC6800SetMachine(PYLDIN_MACHINE_601);command();wait_dos();if(!contains("enable HD6303"))return 1;
 cpu_hd=1;MC6800SetMachine(PYLDIN_MACHINE_HD6303);fail_command=6;command();wait_dos();if(!contains("graphics command failed"))return 1;
 key(0x20);key(0x17);key(0x13);key(0x1c);wait_dos();
 printf("PASS %s SPRITES repeated calls, older FPGA/MC6800 guards, error recovery and DIR; zero resets\n",model_a?"601A":"601");return 0;
}
