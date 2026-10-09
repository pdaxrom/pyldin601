// Execute the assembled HD6303 routine against independent integer intervals.
#define main unused_cpu_reference_main
#include "test_cpu_reference.c"
#undef main
#include "clip_symbols.h"
static unsigned checks,random_state=0x6016303;
static unsigned random_word(void){random_state=random_state*1664525+1013904223;return random_state>>16;}
static void put(unsigned at,unsigned value){MEM[at]=value>>8;MEM[at+1]=value;}
static unsigned get(unsigned at){return MEM[at]*256+MEM[at+1];}
static void check(int x,int y,unsigned src,unsigned width,unsigned height){
 put(CLIP_X,x);put(CLIP_Y,y);put(CLIP_SRC,src);put(CLIP_WIDTH,width);MEM[CLIP_HEIGHT]=height;
 PC=0x800;SP=0xbfff;X=0x1234;i=1;
 for(unsigned steps=0;PC!=0x803&&steps<1000;steps++)MC6800Step();
 if(PC!=0x803||X!=0x1234||SP!=0xbfff){fprintf(stderr,"clip call did not return/preserve X/SP\n");exit(1);}
 int left=x<0?0:x,top=y<0?0:y,right=x+(int)width,bottom=y+(int)height;
 if(right>320)right=320;if(bottom>200)bottom=200;
 int valid=width>0&&width<=320&&height>0&&height<=200&&src+320*(height-1)+width<=64000;
 int visible=valid&&left<right&&top<bottom;
 if(c!=!visible||(!visible&&(get(CLIP_DRAW_WIDTH)||MEM[CLIP_DRAW_HEIGHT]))||
    (visible&&(get(CLIP_SOURCE)!=src+(top-y)*320+(left-x)||get(CLIP_DESTINATION)!=top*320+left||get(CLIP_DRAW_WIDTH)!=(unsigned)(right-left)||MEM[CLIP_DRAW_HEIGHT]!=(unsigned)(bottom-top)))){
  fprintf(stderr,"clip mismatch x=%d y=%d src=%u width=%u height=%u C=%u\n",x,y,src,width,height,c);exit(1);
 }
 checks++;
}
int main(int argc,char**argv){
 if(argc!=2)return 2;FILE*f=fopen(argv[1],"rb");if(!f)return 2;
 unsigned char header[16];if(fread(header,1,16,f)!=16)return 2;
 unsigned count=header[2]*256+header[3],offset=header[4]*256+header[5],length=header[6]*256+header[7];
 unsigned char*pgm=calloc(1,offset+length);memcpy(pgm,header,16);
 if(fread(pgm+16,1,offset+length-16,f)!=offset+length-16)return 2;fclose(f);
 MC6800SetMachine(PYLDIN_MACHINE_HD6303);MC6800Init();memcpy(MEM+0x2000,pgm+offset,length);
 for(unsigned k=0;k<count;k++){unsigned at=pgm[16+k*2]*256+pgm[17+k*2];MEM[0x2000+at]+=0x20;}
 MEM[0x800]=0xbd;MEM[0x801]=GFX_CLIP>>8;MEM[0x802]=GFX_CLIP&255;free(pgm);
 for(int at=-32768;at<=32767;at++){check(at,-16,32,32,32);check(150,at,64,32,32);}
 const int axes[]={-32768,-321,-201,-33,-32,-31,-1,0,1,168,169,199,200,201,288,289,319,320,321,32767};
 const unsigned widths[]={0,1,32,319,320,321,65535},heights[]={0,1,32,199,200,201,255},sources[]={0,32,63999,64000,65535};
 for(unsigned x=0;x<sizeof axes/sizeof*axes;x++)for(unsigned y=0;y<sizeof axes/sizeof*axes;y++)
  for(unsigned w=0;w<sizeof widths/sizeof*widths;w++)for(unsigned hgt=0;hgt<sizeof heights/sizeof*heights;hgt++)
   for(unsigned src=0;src<sizeof sources/sizeof*sources;src++)check(axes[x],axes[y],sources[src],widths[w],heights[hgt]);
 for(unsigned k=0;k<20000;k++){int x=(short)random_word(),y=(short)random_word();unsigned src=random_word(),w=random_word()%322,hgt=random_word()%202;check(x,y,src,w,hgt);}
 printf("PASS assembled HD6303 GFXCLIP: %u cases, all signed X/Y, four edges/corners, zero/invalid dimensions, source overflow, random rectangles, preserved X/SP\n",checks);return 0;
}
