// Execute production canvas/Undo transport while native BIOS interrupts run.
#define GAMEBIOS_MAIN unused_gamebios_main
#include "test_gamebios.c"
#include "paint_dma_model.h"
#include "../build/paint/PCTEST.h"
static unsigned base;
static unsigned paint_call(unsigned offset,unsigned a,unsigned x){
 unsigned pc0=PC,sp0=SP,a0=A,b0=B,x0=X,h0=h,i0=i,n0=n,z0=z,v0=v,c0=c,p0=page,g0=ram_group;
 r[SP--]=pc0;r[SP--]=pc0>>8;PC=base+offset;A=a;X=x;
 uint64_t deadline=virtual_cycles+200000000;
 do{until(virtual_cycles+1);require(virtual_cycles<deadline,"Paint canvas returns in bounded time");}while(PC!=pc0);
 unsigned status=A;
 require(SP==sp0&&page==p0&&ram_group==g0&&i==i0,"Paint canvas preserves stack, selectors and IRQ mask");
 PC=pc0;A=a0;B=b0;X=x0;h=h0;i=i0;n=n0;z=z0;v=v0;c=c0;return status;
}
static void seen(void){if(!base&&PC>=0x100&&PC<0xb000&&r[PC]==0x20&&!memcmp(r+PC+2,"PCT1",4))base=PC;}
static unsigned u16(unsigned off){return r[base+off]*256+r[base+off+1];}
static void set16(unsigned off,unsigned n){word_at(base+off,n);}
static void expected(unsigned kind,unsigned width,const unsigned char*src,unsigned char*out,unsigned*count,unsigned ext){
 *count=0;if(ext&&kind!=4){for(unsigned x=0;x<width;x++)out[(*count)++]=src[x]&(kind==0?1:kind==2?3:255);return;}
 if(kind<3){unsigned bits=kind==2?2:1,unit=8/bits;for(unsigned x=0;x<width;x+=unit){unsigned v=0;for(unsigned j=0;j<unit;j++)v=v<<bits|(src[x+j]&((1<<bits)-1));out[(*count)++]=v;}return;}
 unsigned held[3]={0};
 for(unsigned x=0;x<320;x++){
  unsigned chosen=0,least=1000;
  for(unsigned k=0;k<67;k++){
   unsigned code=k<64?k:k==64?64+(src[3*x+2]&63):k==65?128+(src[3*x]&63):192+(src[3*x+1]&63);
   unsigned rgb[3]={held[0],held[1],held[2]};if(code<64){rgb[0]=(code>>4)*21;rgb[1]=((code>>2)&3)*21;rgb[2]=(code&3)*21;}else rgb[code<128?2:code<192?0:1]=code&63;
   unsigned e=0;for(unsigned j=0;j<3;j++){unsigned v=src[x*3+j]&63;e+=v>rgb[j]?v-rgb[j]:rgb[j]-v;}
   if(e<least){least=e;chosen=code;}
  }
  out[(*count)++]=chosen;if(chosen<64){held[0]=(chosen>>4)*21;held[1]=((chosen>>2)&3)*21;held[2]=(chosen&3)*21;}else held[chosen<128?2:chosen<192?0:1]=chosen&63;
 }
}
static void test_palette(void){
 signed char coeff[96];unsigned entries=0,value;int ch;
 FILE*source=fopen("firmware/gfx/PALCOEF.ASM","r");require(source!=NULL,"PAL coefficients");
 while((ch=fgetc(source))!=EOF)if(ch=='$'){require(entries<96&&fscanf(source,"%2x",&value)==1,"PAL coefficient syntax");coeff[entries++]=value;}
 fclose(source);require(entries==96,"all PAL gains");
 for(unsigned old_read=0;old_read<2;old_read++){
  unsigned char original[8192];for(unsigned k=0;k<8192;k++)original[k]=pal[k]=(k*13+(k>>5))&63;readback=old_read;
  require(!paint_call(PCT_PALETTE_SAVE,0,0)&&r[base+PCT_P_PALETTE_SAVED]&&readback==old_read,"palette snapshot restores its original port read mode");
  require(!memcmp(original,physical+0x1f0000,8192),"palette snapshot uses separate graphics SRAM");
  for(unsigned pattern=0;pattern<3;pattern++){
   r[base+PCT_P_KIND]=3;require(!paint_call(PCT_PALETTE_DEFAULT,0,0),"initialize RGB332 palette");
   unsigned char*rgb=r+base+PCT_P_PALETTE;
   for(unsigned colour=0;colour<256;colour++)for(unsigned j=0;j<3;j++){
    if(pattern==0)require(rgb[colour*3+j]==(j==0?(colour>>5)*9:j==1?((colour>>2)&7)*9:(colour&3)*21),"default RGB332 palette levels");
    else rgb[colour*3+j]=pattern==1?((colour>>j)&1)*63:(colour*17+j*37+(colour>>2))&63;
   }
   require(!paint_call(PCT_PALETTE_INDEX,0,0),"portable indexed PAL generator");
   for(unsigned colour=0;colour<256;colour++)for(unsigned phase=0;phase<32;phase++){
    int sum=7936;for(unsigned j=0;j<3;j++){unsigned v=rgb[colour*3+j];sum+=coeff[phase*3+j]*((v<<2)|(v>>4));}
    require(pal[colour*32+phase]==((sum>>9)&63),"every generated indexed sample matches signed Q9 oracle");
   }
  }
  require(!paint_call(PCT_PALETTE_HAM,0,0),"portable HAM8 PAL generator");
  for(unsigned channel=0;channel<3;channel++)for(unsigned level=0;level<64;level++)for(unsigned phase=0;phase<32;phase++){
   int sum=(channel==1?768:6400)+coeff[phase*3+channel]*((level<<2)|(level>>4));
   require(pal[(channel*64+level)*32+phase]==((sum>>9)&63),"all HAM component samples match signed Q9 oracle");
  }
  require(!paint_call(PCT_PALETTE_RESTORE,0,0)&&!r[base+PCT_P_PALETTE_SAVED]&&readback==old_read&&!memcmp(pal,original,8192),"palette cleanup restores every original sample and port state");
 }
}
static unsigned strokes;
static uint64_t ham_pixel_cycles,ham_full_cycles;
static void event(unsigned x,unsigned y,unsigned buttons,unsigned wide){
 set16(PCT_P_EVENT_X,wide?x:2*x);r[base+PCT_P_EVENT_Y]=y;r[base+PCT_P_EVENT_BUTTONS]=buttons;
 require(!paint_call(PCT_DRAW_EVENT,0,0),"native drawing event completes");
}
static void oracle_dot(unsigned char*doc,unsigned width,unsigned kind,int x,int y,unsigned brush,const unsigned char*colour){
 for(unsigned j=0;j<brush;j++)for(unsigned k=0;k<brush;k++){
  int xx=x+(int)k-(int)(brush/2),yy=y+(int)j-(int)(brush/2);if(xx<0||xx>=(int)width||yy<0||yy>=200)continue;
  memcpy(doc+(yy*width+xx)*(kind==4?3:1),colour,kind==4?3:1);
 }
}
static void oracle_line(unsigned char*doc,unsigned width,unsigned kind,int x,int y,int ex,int ey,unsigned brush,const unsigned char*colour){
 int dx=abs(ex-x),sx=x<ex?1:-1,dy=-abs(ey-y),sy=y<ey?1:-1,error=dx+dy;
 for(;;){oracle_dot(doc,width,kind,x,y,brush,colour);if(x==ex&&y==ey)break;int e2=2*error;if(e2>=dy){error+=dy;x+=sx;}if(e2<=dx){error+=dx;y+=sy;}}
}
static void compare_drawing(const unsigned char*doc,unsigned width,unsigned kind,unsigned ext,unsigned frame){
 unsigned stride=width*(kind==4?3:1),page=r[base+PCT_P_DOC_PAGE];
 require(!memcmp(physical+page*65536,doc,stride*200),"drawn canonical pixels match independent geometric oracle");
 unsigned char row[640];unsigned count;
 for(unsigned y=0;y<200;y++){
  expected(kind,width,doc+y*stride,row,&count,ext);
  if(ext)require(!memcmp(physical+0x100000+r[base+PCT_P_FRONT_PAGE]*65536+y*320,row,count),"drawing refreshes all changed extended preview rows");
  else for(unsigned x=0;x<count;x++)require(r[frame+(y>>3)*(model_a?640:320)+(y&7)+x*8]==row[x],"drawing refreshes packed native preview pixels");
 }
}
static void test_drawing(unsigned kind,unsigned width,unsigned ext,unsigned frame){
 unsigned stride=width*(kind==4?3:1);unsigned char*doc=calloc(stride,200);require(doc!=NULL,"drawing oracle");
 require(!paint_call(PCT_CANVAS_BLANK,0,0),"start empty drawing");r[base+PCT_P_CACHED_Y]=255;r[base+PCT_P_ROW_DIRTY]=0;
 unsigned char fg[3]={kind<2?1:kind==2?3:219,12,47},bg[3]={0,0,0};if(kind==4)fg[0]=63;
 r[base+PCT_P_FG]=fg[0];r[base+PCT_P_BG]=0;memcpy(r+base+PCT_P_FG_RGB,fg,3);memcpy(r+base+PCT_P_BG_RGB,bg,3);
 r[base+PCT_P_BRUSH]=1;r[base+PCT_P_TOOL]=0;
 const unsigned points[][4]={{1,1,318,198},{318,1,1,198},{318,198,1,1},{1,198,318,1},{319,100,0,100},{160,199,160,0},{0,199,319,199},{0,0,319,0}};
 for(unsigned k=0;k<sizeof points/sizeof points[0];k++){
  unsigned x=points[k][0],y=points[k][1],ex=points[k][2],ey=points[k][3];if(kind==1){x*=2;ex*=2;}
  event(x,y,1,kind==1);event(ex,ey,1,kind==1);event(ex,ey,0,kind==1);
  oracle_line(doc,width,kind,x,y,ex,ey,1,fg);compare_drawing(doc,width,kind,ext,frame);strokes++;
 }
 // A full-width horizontal stroke has >256 changed pixels: the dirty flag
 // must remain Boolean rather than wrapping to zero in a byte counter.
 event(width-1,50,1,kind==1);event(0,50,1,kind==1);event(0,50,0,kind==1);
 oracle_line(doc,width,kind,width-1,50,0,50,1,fg);compare_drawing(doc,width,kind,ext,frame);strokes++;
 r[base+PCT_P_BRUSH]=7;
 event(0,0,1,kind==1);event(width-1,0,1,kind==1);event(width-1,0,0,kind==1);
 oracle_line(doc,width,kind,0,0,width-1,0,7,fg);compare_drawing(doc,width,kind,ext,frame);strokes++;
 r[base+PCT_P_BRUSH]=1;
 for(unsigned tool=1;tool<=3;tool++){
  r[base+PCT_P_TOOL]=tool;event(110,90,1,kind==1);event(17,19,1,kind==1);event(17,19,0,kind==1);
  if(tool==1)oracle_line(doc,width,kind,110,90,17,19,1,fg);
  else for(unsigned y=19;y<=90;y++)for(unsigned x=17;x<=110;x++)if(tool==3||x==17||x==110||y==19||y==90)oracle_dot(doc,width,kind,x,y,1,fg);
  compare_drawing(doc,width,kind,ext,frame);strokes++;
 }
 r[base+PCT_P_TOOL]=0;event(10,50,2,kind==1);event(100,50,2,kind==1);event(100,50,0,kind==1);
 oracle_line(doc,width,kind,10,50,100,50,1,bg);compare_drawing(doc,width,kind,ext,frame);strokes++;
 r[base+PCT_P_FG]=0;memset(r+base+PCT_P_FG_RGB,0,3);event(30,30,4,kind==1);event(30,30,0,kind==1);
 require(kind==4?!memcmp(r+base+PCT_P_FG_RGB,fg,3):r[base+PCT_P_FG]==fg[0],"middle button picks canonical index/RGB colour");
 require(!paint_call(PCT_DRAW_FINISH,0,0),"finishing brush flushes its row before a modal");free(doc);
}
static void test_ham_partial(unsigned frame){
 unsigned char*doc=calloc(192000,1);require(doc!=NULL,"incremental HAM oracle");require(!paint_call(PCT_CANVAS_BLANK,0,0),"blank incremental HAM image");
 r[base+PCT_P_CACHED_Y]=255;r[base+PCT_P_ROW_DIRTY]=0;r[base+PCT_P_TOOL]=0;r[base+PCT_P_BRUSH]=1;
 const unsigned ys[]={0,1,7,8,31,127,198,199};
 for(unsigned k=0;k<8;k++){
  unsigned y=ys[k];for(unsigned x=0;x<320;x++){doc[y*960+x*3]=y==198?13:(x*19+y*3)&63;doc[y*960+x*3+1]=y==198?38:(x*3+y*17)&63;doc[y*960+x*3+2]=(x*7+y*29)&63;}
  memcpy(r+base+PCT_P_ROW,doc+y*960,960);require(!paint_call(PCT_CANVAS_STORE,y,0)&&!paint_call(PCT_CANVAS_SHOW,y,0),"prepare complex encoded HAM background");
 }
 unsigned char colour[3]={11,37,62};memcpy(r+base+PCT_P_FG_RGB,colour,3);
 const unsigned xs[]={0,1,5,17,159,160,254,255,256,318,319};
 for(unsigned k=0;k<22;k++){
  unsigned x=xs[k%11],y=ys[k%8];uint64_t before=virtual_cycles;event(x,y,1,0);uint64_t cost=virtual_cycles-before;if(cost>ham_pixel_cycles)ham_pixel_cycles=cost;event(x,y,0,0);
  oracle_dot(doc,320,4,x,y,1,colour);compare_drawing(doc,320,4,1,frame);strokes++;
 }
 memcpy(r+base+PCT_P_ROW,doc+31*960,960);uint64_t before=virtual_cycles;require(!paint_call(PCT_CANVAS_SHOW,31,0),"full HAM reference encode");ham_full_cycles=virtual_cycles-before;
 require(ham_pixel_cycles<ham_full_cycles,"incremental HAM stroke including Undo snapshot is faster than one full row");r[base+PCT_P_CACHED_Y]=255;free(doc);
}
static uint32_t io_at(unsigned label){unsigned char*p=r+base+label;return (uint32_t)p[0]<<24|p[1]<<16|p[2]<<8|p[3];}
static void input_open(const char*path){
 strcpy((char*)r+0x1000,path);word_at(0x1100,0x1000);word_at(0x1102,0);
 require(!invoke(0x4a,1,0,0x1100),"native input file for buffered stream");r[base+PCT_IO_HANDLE]=result_b;
 require(!paint_call(PCT_IO_BEGIN,0,0),"initialize bounded input stream");
}
static void test_io(void){
 set16(PCT_P_FILE_BUFFER,base+PCT_FILE_BUFFER);
 unsigned length=256*513;unsigned char*oracle=malloc(length);require(oracle!=NULL,"stream oracle");for(unsigned k=0;k<length;k++)oracle[k]=k;
 input_open("b:stream.bin");require(io_at(PCT_IO_SIZE)==length,"buffered reader gets full 32-bit file size");
 unsigned offsets[]={0,1,511,512,513,65023,65535,65536,66048,131300};
 for(unsigned k=0;k<sizeof offsets/sizeof offsets[0];k++){
  unsigned at=offsets[k];word_at(base+PCT_P_ROW,at>>16);word_at(base+PCT_P_ROW+2,at);
  require(!paint_call(PCT_IO_SEEK,0,base+PCT_P_ROW)&&io_at(PCT_IO_POSITION)==at,"seek discards prefetched bytes at 64K boundaries");
  unsigned n=length-at<513?length-at:513;set16(PCT_IO_COUNT,n);
  require(!paint_call(PCT_IO_READ,0,base+PCT_P_ROW)&&!memcmp(r+base+PCT_P_ROW,oracle+at,n)&&io_at(PCT_IO_POSITION)==at+n,"buffered row read matches independent disk bytes");
 }
 require(paint_call(PCT_IO_GET,0,0)==65&&r[base+PCT_IO_ERROR]==65,"truncated/overlong input is a bounded format error");
 require(paint_call(PCT_IO_CLOSE,0,0)==65&&!r[base+PCT_IO_LIVE],"input close retains first error and releases the handle");
 strcpy((char*)r+0x1000,"b:output.bin");word_at(0x1100,0x1000);word_at(0x1102,0);
 require(!invoke(0x4b,0,0,0x1100),"create independent stream output");r[base+PCT_IO_HANDLE]=result_b;require(!paint_call(PCT_IO_BEGIN,1,0),"initialize buffered output");
 for(unsigned at=0;at<length;){unsigned n=length-at<513?length-at:513;memcpy(r+base+PCT_P_ROW,oracle+at,n);set16(PCT_IO_COUNT,n);require(!paint_call(PCT_IO_WRITE,0,base+PCT_P_ROW),"buffered output crosses sector boundaries");at+=n;require(io_at(PCT_IO_POSITION)==at,"output position is a full 32-bit byte count");}
 require(!paint_call(PCT_IO_CLOSE,0,0)&&!r[base+PCT_IO_LIVE],"flush and close the last partial sector");file_check("b:output.bin",oracle,length);
 free(oracle);
}
static void output_open(const char*path){
 strcpy((char*)r+0x1000,path);word_at(0x1100,0x1000);word_at(0x1102,0);
 require(!invoke(0x4b,0,0,0x1100),"create codec output");r[base+PCT_IO_HANDLE]=result_b;require(!paint_call(PCT_IO_BEGIN,1,0),"initialize codec output stream");
}
static void dump_file(const char*path,const char*output){
 strcpy((char*)r+0x1000,path);word_at(0x1100,0x1000);word_at(0x1102,0);require(!invoke(0x4a,1,0,0x1100),"reopen closed codec output");unsigned handle=result_b;
 require(!invoke(0x51,handle,0,0x1104),"codec output size");unsigned size=(uint32_t)r[0x1104]<<24|r[0x1105]<<16|r[0x1106]<<8|r[0x1107];
 FILE*f=fopen(output,"wb");require(f!=NULL,"codec host validation artifact");
 while(size){unsigned count=size>512?512:size;word_at(0x1100,base+PCT_P_ROW);word_at(0x1102,count);require(!invoke(0x4c,handle,0,0x1100)&&result_x==count,"read complete codec output after closing");require(fwrite(r+base+PCT_P_ROW,1,count,f)==count,"write codec validation artifact");size-=count;}
 require(!invoke(0x4e,handle,0,0),"close verified codec output");fclose(f);
}
static void test_pcx(const char*model,const char*cpu){
 for(unsigned number=0;number<6;number++){
  if(number==1&&!model_a)continue;
  char path[120];snprintf(path,sizeof path,"b:pcx%u.pcx",number);input_open(path);
  require(!paint_call(PCT_PCX_READ,0,0)&&!paint_call(PCT_IO_CLOSE,0,0),"native PCX decoder accepts packed/planar/indexed image");
  unsigned kind=number==5?2:number==4?3:number;require(r[base+PCT_P_KIND]==kind,"PCX pixel depth chooses matching canvas format");
  snprintf(path,sizeof path,"build/paint/PCX%u.raw",number);size_t size;unsigned char*raw=load(path,&size);
  require(size==(number==1?640u:320u)*200&&!memcmp(raw,physical+0x190000,size),"native PCX decoder preserves all source indices and ignores row padding");free(raw);
  snprintf(path,sizeof path,"build/paint/PCX%u.pal",number);unsigned char*palette=load(path,&size);require(size==768&&!memcmp(palette,r+base+PCT_P_PALETTE,768),"PCX header/trailer palette decodes exact RGB666 entries");free(palette);
  output_open("b:save.pcx");unsigned written=paint_call(PCT_PCX_WRITE,0,0),closed=paint_call(PCT_IO_CLOSE,0,0);
  if(written||closed)fprintf(stderr,"PCX%u write=%u close=%u error=%u row=%u pos=%u\n",number,written,closed,r[base+PCT_IO_ERROR],r[base+PCT_FILE_ROW],io_at(PCT_IO_POSITION));
  require(!written&&!closed,"native PCX encoder flushes a complete standard image");
  snprintf(path,sizeof path,"build/paint/pcx-%s-%s-%u.pcx",model,cpu,number);dump_file("b:save.pcx",path);
 }
 input_open("b:pcxbad.pcx");require(paint_call(PCT_PCX_READ,0,0)==65,"PCX palette marker corruption returns a format error");require(paint_call(PCT_IO_CLOSE,0,0)==65,"invalid PCX closes its native input handle");
}
static void test_iff(const char*model,const char*cpu){
 for(unsigned number=0;number<2;number++){
  char path[160];snprintf(path,sizeof path,"b:iff%u.iff",number);input_open(path);
  require(!paint_call(PCT_IFF_READ,0,0)&&!paint_call(PCT_IO_CLOSE,0,0),"ILBM decoder accepts raw/ByteRun1 HAM8 and out-of-order chunks");
  snprintf(path,sizeof path,"build/paint/IFF%u.raw",number);size_t bytes;unsigned char*raw=load(path,&bytes);require(bytes==192000&&!memcmp(raw,physical+0x190000,bytes),"native HAM decoder reconstructs arbitrary CMAP/modify commands into exact RGB666");
  strcpy((char*)r+base+PCT_P_MODULE_PATH,"b:pntham.pgm");require(!paint_call(PCT_BACKEND_LOAD,0,base+PCT_P_MODULE_PATH),"load HAM module for standard ILBM export");
  unsigned char*visible=malloc(192000);require(visible!=NULL,"visible HAM oracle");
  for(unsigned y=0;y<200;y++){
   unsigned char codes[320];unsigned count;expected(4,320,raw+y*960,codes,&count,1);unsigned held[3]={0};
   for(unsigned x=0;x<320;x++){unsigned code=codes[x];if(code<64){held[0]=(code>>4)*21;held[1]=((code>>2)&3)*21;held[2]=(code&3)*21;}else held[code<128?2:code<192?0:1]=code&63;for(unsigned j=0;j<3;j++)visible[y*960+x*3+j]=held[j];}
  }
  snprintf(path,sizeof path,"build/paint/iff-%s-%s-%u-visible.raw",model,cpu,number);FILE*f=fopen(path,"wb");require(f&&fwrite(visible,1,192000,f)==192000,"HAM oracle artifact");fclose(f);free(visible);free(raw);
  output_open("b:save.iff");require(!paint_call(PCT_IFF_WRITE,0,0)&&!paint_call(PCT_IO_CLOSE,0,0),"ILBM encoder writes all eight planes with valid standard chunks");
  paint_call(PCT_BACKEND_CLOSE,0,0);snprintf(path,sizeof path,"build/paint/iff-%s-%s-%u.iff",model,cpu,number);dump_file("b:save.iff",path);
 }
 input_open("b:iffbad.iff");require(paint_call(PCT_IFF_READ,0,0)==65&&paint_call(PCT_IO_CLOSE,0,0)==65,"ByteRun1 run beyond a row is a bounded error");
}
int main(int argc,char**argv){
 if(argc!=4)return 2;model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load(argv[1],&image_size);committed=1;dma_mmio_read=paint_dma_read;dma_mmio_write=paint_dma_write;
 MC6800Init();MC6800Reset();r=MC6800GetCpuRam();until(60000000);key(0x1c);key(0x1c);prompt_wait();unsigned sp0=SP,banks=free_banks();
 native_step_hook=seen;
 key(0x30);KBDModKeyDown(2);key(0x27);KBDModKeyUp(2);key(0x19);key(0x2e);key(0x14);key(0x12);key(0x1f);key(0x14);key(0x1c);
 uint64_t start_deadline=virtual_cycles+10000000;
 while(!base&&virtual_cycles<start_deadline)until(virtual_cycles+1009);
 require(base!=0,"native canvas probe launched");while(PC!=base+PCT_PROBE_READY)until(virtual_cycles+1);
 r[base+PCT_P_MODEL]=model_a;unsigned frame=u16(PCT_P_FRAME);require(frame&&frame<base,"native screen allocation precedes backend");
 unsigned cases=0,rows=0;
 for(unsigned kind=0;kind<5;kind++){
  if(kind==1&&!model_a){unsigned old=r[base+PCT_P_KIND];require(paint_call(PCT_CANVAS_CONFIG,kind,0)==65&&r[base+PCT_P_KIND]==old,"601 rejects wide mono before changing format");continue;}
  require(!paint_call(PCT_CANVAS_CONFIG,kind,0),"canvas config accepts supported format");
  unsigned width=kind==1?640:320,stride=width*(kind==4?3:1),ext=kind>=3||(!model_a&&kind==2)||(model_a&&kind==0);
  require(u16(PCT_P_WIDTH)==width&&u16(PCT_P_STRIDE)==stride&&r[base+PCT_P_PREVIEW_EXT]==(kind==4?7:ext),"canonical width/stride and hardware preview chosen by model");
  r[base+PCT_P_DOC_PAGE]=0x12;r[base+PCT_P_UNDO_PAGE]=0x16;r[base+PCT_P_FRONT_PAGE]=0;r[base+PCT_P_UNDO_FRONT]=1;
  memset(r+base+PCT_P_SERIAL,0,16);r[base+PCT_P_HAVE_UNDO]=r[base+PCT_P_HAVE_REDO]=0;
  strcpy((char*)r+base+PCT_P_MODULE_PATH,kind==4?"b:pntham.pgm":ext?"b:pntrgb.pgm":"b:pntnat.pgm");
  require(!paint_call(PCT_BACKEND_LOAD,0,base+PCT_P_MODULE_PATH),"load actual preview module");
  memset(physical+0x120000,0xa5,192001);memset(physical+0x100000,0xa5,64001);memset(r+frame,0xa5,u16(PCT_P_FRAME_BYTES));
  require(!paint_call(PCT_CANVAS_BLANK,0,0),"blank canonical image and preview via flat DMA");
  for(unsigned k=0;k<stride*200;k++)require(!physical[0x120000+k],"blank clears entire canonical image");require(physical[0x120000+stride*200]==0xa5,"blank respects canonical bounds");
  unsigned framebytes=ext?64000:model_a?16000:8000;
  for(unsigned k=0;k<framebytes;k++)require(!(ext?physical[0x100000+k]:r[frame+k]),"blank clears whole preview");
  unsigned char pixels[960],want[640];unsigned lines[]={0,1,7,8,31,127,198,199};
  for(unsigned k=0;k<sizeof lines/sizeof lines[0];k++){
   unsigned y=lines[k],count;for(unsigned x=0;x<stride;x++)pixels[x]=(x*37+y*19)^(x>>2);
   memcpy(r+base+PCT_P_ROW,pixels,stride);require(!paint_call(PCT_CANVAS_STORE,y,0),"store canonical row");
   require(!memcmp(physical+0x120000+y*stride,pixels,stride),"canonical linear row address handles 64K crossings");
   memset(r+base+PCT_P_ROW,0,stride);require(!paint_call(PCT_CANVAS_READ,y,0)&&!memcmp(r+base+PCT_P_ROW,pixels,stride),"read canonical row to ordinary buffer");
   expected(kind,width,pixels,want,&count,ext);require(!paint_call(PCT_CANVAS_SHOW,y,0),"encode then transfer preview row");
   if(ext)require(!memcmp(physical+0x100000+y*320,want,count),"extended indexed/HAM preview row matches oracle");
   else for(unsigned x=0;x<count;x++)require(r[frame+(y>>3)*(model_a?640:320)+(y&7)+x*8]==want[x],"native packed preview has correct CRTC interleave");
   rows++;
  }
  unsigned char*doc=malloc(stride*200),*preview=malloc(framebytes);memcpy(doc,physical+0x120000,stride*200);memcpy(preview,ext?physical+0x100000:r+frame,framebytes);
  require(!paint_call(PCT_CANVAS_SNAPSHOT,0,0)&&r[base+PCT_P_HAVE_UNDO]&&!r[base+PCT_P_HAVE_REDO]&&r[base+PCT_P_MODIFIED],"checkpoint creates exactly one modified document generation");
  require(!memcmp(doc,physical+0x160000,stride*200)&&!memcmp(preview,physical+0x110000,framebytes),"snapshot retains canonical and encoded image");
  require(!paint_call(PCT_CANVAS_BLANK,0,0),"change current image after snapshot");
  require(!paint_call(PCT_CANVAS_UNDO,0,0)&&!r[base+PCT_P_HAVE_UNDO]&&r[base+PCT_P_HAVE_REDO]&&!r[base+PCT_P_MODIFIED],"Undo restores saved serial and enables Redo");
  require(!memcmp(doc,physical+0x160000,stride*200)&&!memcmp(preview,ext?physical+0x110000:r+frame,framebytes),"Undo switches exact canonical and visible snapshots");
  require(!paint_call(PCT_CANVAS_UNDO,1,0)&&r[base+PCT_P_HAVE_UNDO]&&!r[base+PCT_P_HAVE_REDO]&&r[base+PCT_P_MODIFIED],"Redo reapplies serial and enables Undo");
  for(unsigned x=0;x<stride*200;x++)require(!physical[0x120000+x],"Redo restores changed canonical pixels");
  if(ext)require(front==0,"Redo flips to changed preview page at VBL");
  test_drawing(kind,width,ext,frame);
  if(kind==4)test_ham_partial(frame);
  paint_call(PCT_BACKEND_CLOSE,0,0);free(doc);free(preview);cases++;
 }
 test_palette();
 test_io();
 test_pcx(argv[2],argv[3]);
 test_iff(argv[2],argv[3]);
 PC=base+PCT_PROBE_EXIT;prompt_wait();require(SP==sp0&&free_banks()==banks,"canvas/module cleanup restores DOS stack and bank leases");
 printf("PASS Paint canvas %s/%s: %u formats, %u row boundaries, %u strokes, %u flat DMA jobs, geometric/preview oracle, Undo/Redo, 61440 PAL samples, 131328-byte native stream/seek/EOF/flush, cleanup/IRQs; HAM worst pixel %llu cycles, full row %llu\n",argv[2],argv[3],cases,rows,strokes,paint_jobs,(unsigned long long)ham_pixel_cycles,(unsigned long long)ham_full_cycles);return 0;
}
