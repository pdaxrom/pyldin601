// Full native startup, event dispatch, modal focus and process cleanup.
// File actions deliberately remain a UI fixture until PNTFILE is tested.
#include <stdint.h>
static int hg_transport_read(uint16_t,unsigned char*);
static int hg_transport_write(uint16_t,unsigned char);
#define ARCADE_HG 1
#define GAMEBIOS_MAIN unused_gamebios_main
#include "test_gamebios.c"
#include "mouse_ui_model.h"
#include "paint_dma_model.h"
#ifndef PAINT_UI_HEADER
#define PAINT_UI_HEADER "../build/paint/PUI.h"
#endif
#include PAINT_UI_HEADER
#ifdef PAINT_OVERLAY_HEADER
#include PAINT_OVERLAY_HEADER
#include "../build/paint/PNTOVL.h"
#define PAINT_ALT_MOUSE_WAIT PIO_MOUSE_WAIT
#define PAINT_OVERLAY_IS_FILE (ramword(base+PUI_P_OVER_CALL)&&r[ramword(base+PUI_P_OVER_CALL)-POV_LOADER_SWITCH+POV_LOAD_API+4]==2)
#endif
#ifndef PAINT_EXTERNAL_TRANSPORT
static int hg_transport_read(uint16_t a,unsigned char*out){return mouse_ui_read_byte(a,out);}
static int hg_transport_write(uint16_t a,unsigned char b){return mouse_ui_write_byte(a,b);}
#endif
static unsigned base,ready,return_seen;
static unsigned ramword(unsigned p){return r[p]*256+r[p+1];}
// Follow the display registers, not the software's intended framebuffer.
// Native graphics discards the low three base-address bits in INT12/CRTC.
static unsigned displayed_frame(void){return ((crtc[12]*256+crtc[13])*8)&65535;}
static void modal_glyphs(unsigned col,unsigned row,const char*text,unsigned inverse){
 unsigned frame=displayed_frame(),pitch=crtc[1]*8;
 require(frame==ramword(base+PUI_P_FRAME)&&!(frame&7),"native dialog framebuffer agrees with the actual CRTC origin");
 require(pitch==(model_a?640:320)&&crtc[6]==25,"native dialog has its expected hardware pitch and height");
 for(;*text;text++,col++)for(unsigned y=0;y<8;y++){
  unsigned at=(frame+row*pitch+col*8+y)&65535;
  unsigned char expected=physical[0x11800+(unsigned char)*text*8+y]^(inverse?255:0);
  if(r[at]!=expected)fprintf(stderr,"Dialog glyph %02x col%u row%u scan%u: CRTC base%04x logical%04x actual%02x expected%02x\n",(unsigned char)*text,col,row,y,frame,ramword(base+PUI_P_FRAME),r[at],expected);
  require(r[at]==expected,"complete modal glyph is visible at the hardware raster address");
 }
}
static void modal_text(unsigned col,unsigned row,const char*text){modal_glyphs(col,row,text,1);}
static void modal_selection(unsigned col,unsigned row,const char*text){modal_glyphs(col,row,text,0);}
static void ui_observe(void){
 if(!base&&PC>=0x100&&PC<0xbc00&&r[PC]==0x20&&!memcmp(r+PC+2,"PNT1",4))base=PC;
 if(base&&PC==base+PUI_PAINT_READY)ready=1;
 if(base&&PC==base+PUI_PAINT_RESTORED){
  if(r[base+PUI_P_OLD_SAVED])require(!memcmp(r+ramword(base+PUI_P_FRAME),physical+0x1d0000,ramword(base+PUI_P_FRAME_BYTES)),"Paint restores parent native bitmap byte for byte");
  return_seen++;
 }
}
static void wait_context(unsigned context){
 uint64_t end=virtual_cycles+200000000;
 do{until(virtual_cycles+1);
  unsigned wait_entry=PUI_MOUSE_WAIT;
#ifdef PAINT_ALT_MOUSE_WAIT
  if(PAINT_OVERLAY_IS_FILE)wait_entry=PAINT_ALT_MOUSE_WAIT;
#endif
  if(ready&&r[base+PUI_MOUSE_CONTEXT]==context&&PC>=base+wait_entry&&PC<base+wait_entry+112){
   if(r[base+PUI_P_UI_ACTIVE]&&!gfx[0])require(displayed_frame()==ramword(base+PUI_P_FRAME),"every modal uses the actual aligned CRTC framebuffer");
   return;
  }
 }while(virtual_cycles<end);
 fprintf(stderr,"Paint base=%04x ready=%u kind=%u error=%u UI=%u context=%u expected=%u\n",base,ready,r[base+PUI_P_KIND],r[base+PUI_P_ERROR],r[base+PUI_P_UI_ACTIVE],r[base+PUI_MOUSE_CONTEXT],context);
 require(0,"Paint reaches its expected native input context");
}
static void text(const char*s){
 const char*letters="abcdefghijklmnopqrstuvwxyz";const unsigned keys[]={0x1e,0x30,0x2e,0x20,0x12,0x21,0x22,0x23,0x17,0x24,0x25,0x26,0x32,0x31,0x18,0x19,0x10,0x13,0x1f,0x14,0x16,0x2f,0x11,0x2d,0x15,0x2c};
 for(;*s;s++){const char*p=strchr(letters,*s);unsigned k=p?keys[p-letters]:*s==':'?0x27:*s=='.'?0x34:*s==' '?0x39:*s=='\\'?0x2b:*s>='1'&&*s<='9'?*s-'1'+2:*s=='0'?0xb:0;require(k,"Paint test input key");if(*s==':')KBDModKeyDown(2);key(k);if(*s==':')KBDModKeyUp(2);}
}
static void mouse(unsigned x,unsigned y,unsigned buttons){
 mouse_ui_enabled=1;r[base+PUI_MOUSE_PRESENT]=1;
 word_at(base+PUI_MOUSE_X,x?x-1:0);word_at(base+PUI_MOUSE_Y,y);
 mouse_ui_push(8|buttons);mouse_ui_push(x?1:0);mouse_ui_push(0);
 until(virtual_cycles+200000);wait_context(r[base+PUI_MOUSE_CONTEXT]);
}
static void modal_image(const char*name){
 char path[100];snprintf(path,sizeof path,"build/paint/ui-%s-%s.ppm",model_a?"601a":"601",name);FILE*f=fopen(path,"wb");require(f!=NULL,"UI snapshot");
 unsigned width=crtc[1]*8,frame=displayed_frame();fprintf(f,"P6\n%u 200\n255\n",width);
 for(unsigned y=0;y<200;y++)for(unsigned x=0;x<width;x++){unsigned char c=(r[(frame+(y>>3)*width+(y&7)+(x>>3)*8)&65535]>>(7-(x&7)))&1?230:0;unsigned char rgb[]={c,c,c};fwrite(rgb,1,3,f);}fclose(f);
 if(r[base+PUI_P_FRAME_OWNED]){
  snprintf(path,sizeof path,"build/paint/ui-%s-%s-ram.bin",model_a?"601a":"601",name);f=fopen(path,"wb");require(f&&fwrite(r,1,65536,f)==65536&&!fclose(f),"native RAM snapshot for actual video RTL");
  unsigned char cfg[20]={model_a,r[0xe629]};memcpy(cfg+2,crtc,16);cfg[18]=r[base+PUI_P_FRAME];cfg[19]=r[base+PUI_P_FRAME+1];
  snprintf(path,sizeof path,"build/paint/ui-%s-%s-config.bin",model_a?"601a":"601",name);f=fopen(path,"wb");require(f&&fwrite(cfg,1,sizeof cfg,f)==sizeof cfg&&!fclose(f),"native CRTC snapshot for actual video RTL");
 }
}
static void format(unsigned kind){
 unsigned modified=r[base+PUI_P_MODIFIED];key(0x40);
 if(modified){wait_context(3);key(0x15);}
 wait_context(5);key(2+kind);wait_context(0);
 require(r[base+PUI_P_KIND]==kind&&!r[base+PUI_P_MODIFIED],"New chooses and initializes requested image format");
}
#ifndef PAINT_UI_MAIN
#define PAINT_UI_MAIN main
#endif
int PAINT_UI_MAIN(int argc,char**argv){
 if(argc!=5)return 2;model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");unsigned native=atoi(argv[4]);MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load(argv[1],&image_size);committed=1;dma_mmio_read=paint_dma_read;dma_mmio_write=paint_dma_write;MC6800Init();MC6800Reset();r=MC6800GetCpuRam();until(60000000);key(0x1c);key(0x1c);prompt_wait();
 unsigned sp0=SP,heap0=ramword(0xee1e),bank0=free_banks(),mode0=r[0xed12],page0=page,group0=ram_group;
 unsigned char palette[8192];for(unsigned k=0;k<8192;k++)palette[k]=pal[k]=(k*11+k/17)&63;
 native_step_hook=ui_observe;watch_resets=1;text(native?"b:pgraph":"b:paintui");key(0x1c);wait_context(0);
 require(r[base+PUI_P_KIND]==3&&gfx[0]==1&&!r[base+PUI_P_MODIFIED],"Paint starts indexed with clean image");
 require(r[base+PUI_P_FRAME_OWNED]==!native,"Paint reuses a parent-owned native screen");
 unsigned document=r[base+PUI_P_DOC_PAGE]*65536;
 for(unsigned k=0;k<64000;k++)require(!physical[document+k],"initial canvas is empty");
 key(0x3b);wait_context(4);require(r[base+PUI_P_UI_ACTIVE]&&!gfx[0],"Help uses native modal window");modal_image("help");modal_text(6,6," Paint");key(1);wait_context(0);
 require(gfx[0]==1&&front==r[base+PUI_P_FRONT_PAGE],"modal restores indexed canvas page");
 mouse(20,20,0);mouse(20,20,1);mouse(100,50,1);mouse(100,50,0);
 require(r[base+PUI_P_MODIFIED]&&physical[document+20*320+10]==255&&physical[document+50*320+50]==255,"real mouse packets draw an interpolated stroke");
 key(0x41);wait_context(0);require(!r[base+PUI_P_MODIFIED],"F7 restores clean document generation");
 key(0x42);wait_context(0);require(r[base+PUI_P_MODIFIED],"F8 reapplies changed generation");
 unsigned pointer_y=ramword(base+PUI_MOUSE_Y);key(0x50);wait_context(0);require(ramword(base+PUI_MOUSE_Y)==pointer_y+1,"Down moves the canvas pointer down");key(0x48);wait_context(0);require(ramword(base+PUI_MOUSE_Y)==pointer_y,"Up moves the canvas pointer up");
 key(1);wait_context(3);modal_text(6,6,"Paint");modal_image("exit");key(1);wait_context(0);require(r[base+PUI_P_MODIFIED]&&gfx[0]==1,"Escape cancels the exit dialog and retains the canvas");
 key(0x3f);wait_context(5);key(0x50);wait_context(5);key(0x1c);wait_context(0);require(r[base+PUI_P_TOOL]==1,"Down chooses the following tool");key(0x3f);wait_context(5);key(0x48);wait_context(5);key(0x1c);wait_context(0);require(!r[base+PUI_P_TOOL],"Up chooses the preceding tool");
 for(unsigned k=0;k<3;k++){key(0x3f);wait_context(5);modal_text(6,6,"Drawing tool");modal_selection(6,8,"1  Freehand brush");modal_image("tools");key(1);wait_context(0);require(gfx[0]==1&&r[base+PUI_P_MODIFIED],"F5/Escape restores the unchanged indexed document");}
 key(0x3f);wait_context(5);modal_text(6,6,"Drawing tool");mouse(7*(model_a?8:16)+3,10*8+3,0);mouse(7*(model_a?8:16)+3,10*8+3,1);wait_context(0);require(r[base+PUI_P_TOOL]==2,"mouse chooses Rectangle from tool window");mouse(100,50,0);
 unsigned old_colour=r[base+PUI_P_FG];
 key(0x3e);wait_context(10);require(gfx[0]==1&&front==5,"F4 shows the 256-colour picker page");
 for(unsigned cell=0;cell<256;cell++)for(unsigned corner=0;corner<4;corner++)require(physical[0x150000+((cell>>4)*12+(corner&1?11:0))*320+(cell&15)*20+(corner&2?19:0)]==cell,"F4 palette has 256 intact swatches at the displayed page");
 key(1);wait_context(0);require(r[base+PUI_P_FG]==old_colour,"Escape from F4 retains the previous colour");
 key(0x3e);wait_context(10);mouse(2*(4*20+10),5*12+6,0);mouse(2*(4*20+10),5*12+6,1);wait_context(0);require(r[base+PUI_P_FG]==0x54,"picker selects the pointed palette cell");mouse(100,50,0);
 mouse(80,80,1);mouse(80,80,0);require(physical[r[base+PUI_P_DOC_PAGE]*65536+80*320+40]==0x54,"the chosen palette index is used by the next drawing operation");
 key(0x3e);wait_context(10);key(0x4d);wait_context(10);key(0x50);wait_context(10);key(0x1c);wait_context(0);if(r[base+PUI_P_FG]!=0x65)fprintf(stderr,"Palette keyboard choice: %02x expected65\n",r[base+PUI_P_FG]);require(r[base+PUI_P_FG]==0x65,"palette arrows and Enter choose the same visible cell as the mouse");
 format(0);require(r[base+PUI_P_PREVIEW_EXT]==model_a,"320 mono uses a supported preview on either model");
 mouse(20,20,0);mouse(20,20,1);mouse(90,40,0); // Rectangle commits at release.
 require(r[base+PUI_P_MODIFIED],"native/extended monochrome shape changes the document");
 unsigned frame=ramword(base+PUI_P_FRAME),framebytes=ramword(base+PUI_P_FRAME_BYTES);unsigned char*bitmap=malloc(framebytes);memcpy(bitmap,r+frame,framebytes);
 key(0x3b);wait_context(4);key(1);wait_context(0);
 if(!model_a)require(!memcmp(bitmap,r+frame,framebytes),"native canvas survives a modal byte for byte");free(bitmap);
 if(model_a){format(1);format(2);}else format(2);
 format(4);require(gfx[0]==7,"HAM8 selects hardware component decoding");
 key(0x3e);wait_context(2);require(r[base+PUI_P_UI_ACTIVE],"HAM colour input owns modal focus");modal_text(6,6,"Colour");modal_image("rgb");
 key(1);wait_context(0);require(gfx[0]==7,"RGB dialog Cancel restores HAM canvas");
 key(0x3e);wait_context(2);key(0x47);for(unsigned k=0;k<6;k++)key(0x53);text("3f0000");key(0x1c);wait_context(0);require(r[base+PUI_P_FG_RGB]==63&&!r[base+PUI_P_FG_RGB+1]&&!r[base+PUI_P_FG_RGB+2],"HAM F4 accepts RGB666 input and chooses red");
 key(0x44);prompt_wait();
 if(resets||SP!=sp0||ramword(0xee1e)!=heap0||free_banks()!=bank0||r[0xed12]!=mode0||page!=page0||ram_group!=group0)
  fprintf(stderr,"Paint exit resets%u SP%04x/%04x heap%04x/%04x banks%u/%u video%u/%u selectors%u,%u/%u,%u\n",resets,SP,sp0,ramword(0xee1e),heap0,free_banks(),bank0,r[0xed12],mode0,page,ram_group,page0,group0);
 require(return_seen==1&&!resets&&SP==sp0&&ramword(0xee1e)==heap0&&free_banks()==bank0&&r[0xed12]==mode0&&page==page0&&ram_group==group0,"Paint child/parent exit restores native memory, video, stack and leases");
 require(!memcmp(palette,pal,8192)&&!mouse_ui_lines&&!(mouse_ui_index&128),"exit restores PAL table and releases PS2 pins and pointer");
 printf("PASS Paint UI %s/%s start%s: native streamed startup, frame reuse, mouse stroke, Undo/Redo, tool/colour/format windows, HAM input focus, palette/video/heap/pointer cleanup\n",argv[2],argv[3],argv[4]);return 0;
}
