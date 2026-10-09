// Execute INT E0 through the unchanged 601/601A BIOS banked SWI dispatcher.
// Peripheral model checks register order, busy waits and resulting rectangles.
#include <stdint.h>
static int hg_read_byte(uint16_t a,unsigned char*out);
static int hg_write_byte(uint16_t a,unsigned char d);
#define HG_FIXTURE 1
#define NATIVE_STABILITY_MAIN unused_stability_main
#include "test_native_stability.c"
#undef NATIVE_STABILITY_MAIN
static unsigned char gfx[16],ay[16];
static unsigned ay_writes[16],jobs,timeout_hw,hw_error;
static uint64_t ready_at;
static void require(int ok,const char*s){if(!ok){fprintf(stderr,"FAIL %s PC=%04x\n",s,PC);exit(1);}}
static int hg_read_byte(uint16_t a,unsigned char*out){
 if(a>=0xe610&&a<0xe620){*out=ay[a&15];return 1;}
 if(a<0xe650||a>0xe65f)return 0;
 *out=a==0xe65e?'G':a==0xe65f?5:a==0xe650?
  gfx[0]|(timeout_hw||virtual_cycles<ready_at?128:0)|hw_error:gfx[a&15];return 1;
}
static int hg_write_byte(uint16_t a,unsigned char d){
 if(a>=0xe610&&a<0xe620){ay[a&15]=d;ay_writes[a&15]++;return 1;}
 if(a<0xe650||a>0xe65f)return 0;
 require(!timeout_hw&&virtual_cycles>=ready_at,"no MMIO writes during busy");
 gfx[a&15]=d;if(a!=0xe651)return 1;
 jobs++;ready_at=virtual_cycles+10000;
 if(d==3){gfx[2]=gfx[5];return 1;}
 require(d==1||d==2||d==6,"valid blitter command");
 unsigned so=gfx[6]+256*gfx[7],dest=gfx[8]+256*gfx[9],w=gfx[10]+256*gfx[11],h=gfx[12];
 if(!w||w>320||!h||h>200||dest+320*(h-1)+w>64000||
    (d!=1&&so+320*(h-1)+w>64000)){hw_error=16;return 1;}
 unsigned char*src=physical+0x100000+gfx[4]*65536,*dst=physical+0x100000+gfx[5]*65536;
 for(unsigned y=0;y<h;y++)for(unsigned x=0;x<w;x++)
  if(d==1||d==2||src[so+y*320+x]!=gfx[3])dst[dest+y*320+x]=d==1?gfx[3]:src[so+y*320+x];
 return 1;
}
static unsigned invoke(unsigned function,unsigned b,unsigned x){
 unsigned char*r=MC6800GetCpuRam(),saved=page;
 unsigned char native_state[2];memcpy(native_state,r+0xed7c,2);
 r[0x210]=0x3f;r[0x211]=0xe0;r[0x212]=1;
 PC=0x210;SP=0xbdff;A=function;B=b;X=x;i=0;
 uint64_t limit=virtual_cycles+5000000;
 do{until(virtual_cycles+1);require(virtual_cycles<limit,"service returns");}while(PC!=0x212);
 require(SP==0xbdff&&page==saved&&X==x,"service preserves stack, X and ROM page");
 require(!memcmp(r+0xed7c,native_state,2),"service preserves pseudo-RS/line-input state");
 require(!fdc_port_accesses,"no removed FDC accesses");return A;
}
static void put16(unsigned char*p,int v){p[0]=(unsigned)v>>8;p[1]=v;}
#ifndef EXTENSION_SERVICES_MAIN
#define EXTENSION_SERVICES_MAIN main
#endif
int EXTENSION_SERVICES_MAIN(int argc,char**argv){
 if(argc!=3)return 2;model_a=!strcmp(argv[1],"601a");cpu_hd=!strcmp(argv[2],"hd6303");
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);
 require(n==0x51a00,"ROM size");memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,0x51800);free(rom);
 image=load("images/sd.img",&image_size);memcpy(config+64,image+462,32);
 committed=1;MC6800Init();MC6800Reset();until(60000000);
 require(invoke(0,0,0x3000)==1&&B==15,"API version/features");
 require(invoke(7,0,0x3000)==1,"unknown function rejected");
 require(invoke(1,1,0x3000)==0&&gfx[0]==1,"indexed mode");
 require(invoke(1,7,0x3000)==0&&gfx[0]==7,"HAM8 mode");
 require(invoke(1,3,0x3000)==1&&gfx[0]==7,"removed HAM6 rejected");
 require(invoke(2,15,0x3000)==0&&gfx[2]==15,"waited page flip");
 require(invoke(2,16,0x3000)==1,"invalid page rejected");
 unsigned char*r=MC6800GetCpuRam(),*p=r+0x3000;
 p[0]=1;p[1]=0x25;p[2]=0;p[3]=2;put16(p+4,0);put16(p+6,0);put16(p+8,320);p[10]=200;
 require(invoke(3,0,0x3000)==0,"whole frame fill");
 for(unsigned v=0;v<64000;v++)require(physical[0x120000+v]==0x25,"fill data");
 for(unsigned v=0;v<64000;v++)physical[0x110000+v]=v%7?((v*17)&255):0;
 p[0]=6;p[1]=0;p[2]=1;put16(p+4,2*320+5);put16(p+6,9*320+13);put16(p+8,17);p[10]=11;
 require(invoke(3,0,0x3000)==0,"transparent rectangle");
 for(unsigned y=0;y<11;y++)for(unsigned x=0;x<17;x++){
  unsigned v=physical[0x110000+(y+2)*320+x+5];
  require(physical[0x120000+(y+9)*320+x+13]==(v?v:0x25),"colour key preserves destination");
 }
 p[0]=99;require(invoke(3,0,0x3000)==1,"invalid command");
 p[0]=2;p[3]=16;require(invoke(3,0,0x3000)==1,"invalid blit page");
 p[3]=2;put16(p+8,321);require(invoke(3,0,0x3000)==2,"hardware argument error propagated");hw_error=0;
 timeout_hw=1;require(invoke(2,0,0x3000)==2,"bounded hardware timeout");timeout_hw=0;
 const int xs[]={-32768,-33,-32,-31,-1,0,1,288,289,319,320,32767};
 const int ys[]={-32768,-33,-32,-31,-1,0,1,168,169,199,200,32767};
 for(unsigned xi=0;xi<sizeof xs/sizeof*xs;xi++)for(unsigned yi=0;yi<sizeof ys/sizeof*ys;yi++){
  int x=xs[xi],y=ys[yi],left=x<0?0:x,top=y<0?0:y,right=x+32>320?320:x+32,bottom=y+32>200?200:y+32;
  put16(p,x);put16(p+2,y);put16(p+4,640);put16(p+6,32);p[8]=32;p[9]=1;p[10]=2;p[11]=0;
  unsigned before=jobs,status=invoke(4,0,0x3000);
  if(!cpu_hd){require(status==3&&jobs==before,"clipping requires HD6303");continue;}
  require(status==0,"clip success");
  if(right<=left||bottom<=top){require(jobs==before,"fully invisible no-op");continue;}
  require(jobs==before+1&&gfx[1]==6&&gfx[4]==1&&gfx[5]==2,"clipped keyed copy");
  require(gfx[6]+256*gfx[7]==640+(top-y)*320+left-x,"clipped source");
  require(gfx[8]+256*gfx[9]==top*320+left&&gfx[10]+256*gfx[11]==right-left&&gfx[12]==bottom-top,"clipped destination/size");
 }
 for(unsigned k=0;k<14;k++)p[k]=k*17;
 require(invoke(5,0,0x3000)==0,"music frame");
 for(unsigned k=0;k<14;k++)require(ay[k]==p[k]&&ay_writes[k]==1,"all AY registers in frame");
 p[13]=255;require(invoke(5,0,0x3000)==0&&ay_writes[13]==1,"FF envelope sentinel");
 p[13]=12;require(invoke(5,0,0x3000)==0&&invoke(5,0,0x3000)==0&&ay_writes[13]==3,"same shape retriggers");
 require(invoke(6,0,0x3000)==0&&ay[7]==63&&!ay[8]&&!ay[9]&&!ay[10],"AY silence");
 require(invoke(1,0,0x3000)==0&&gfx[0]==0,"return to native video");
 printf("PASS banked INT E0 %s/%s: mode, flip, keyed COPY, 144 clipping/corner/extreme coordinates, busy/error/timeout, AY frame/sentinel/retrigger/silence, native SWI/page/stack\n",argv[1],argv[2]);return 0;
}
