// Actual NC supervisor, panels, Paint and resident HG, without EXEC stubs.
#define PAINT_EXTERNAL_TRANSPORT 1
#define PAINT_UI_MAIN unused_paint_ui_main
#define PAINT_UI_HEADER "../build/paint/PAINTF.h"
#define PAINT_OVERLAY_HEADER "../build/paint/PAINTIO.h"
#include "test_paint_ui.c"
#include "../build/nc/NC.h"
#include "../build/nc/NCMAIN.h"
#include "../host/hg/hg.h"
#define hg_transport_read image_host_read
#define hg_transport_write image_host_write
#include "hg_transport.h"
#undef hg_transport_read
#undef hg_transport_write

static HgVolume volume;
static unsigned nc,core,core_armed,core_count,load_error,low_stack=65535;
static unsigned char nc_sig[24],core_sig[24],nc_mask[24],core_mask[24];
static int durable_write(unsigned block,const uint8_t*data,unsigned length){return hg_volume_write(&volume,block,data,length);}
static int hg_transport_read(uint16_t a,unsigned char*out){return mouse_ui_read_byte(a,out)||image_host_read(a,out);}
static int hg_transport_write(uint16_t a,unsigned char d){return mouse_ui_write_byte(a,d)||image_host_write(a,d);}
static void sig(const char*name,unsigned char*s,unsigned char*m){
 size_t n;unsigned char*p=load(name,&n);unsigned count=p[2]*256+p[3],off=p[4]*256+p[5];memcpy(s,p+off,24);memset(m,255,24);
 for(unsigned k=0;k<count;k++){unsigned at=p[16+2*k]*256+p[17+2*k];if(at<24)m[at]=0;}free(p);
}
static int match(unsigned pc,unsigned char*s,unsigned char*m){for(unsigned k=0;k<24;k++)if((r[(pc+k)&65535]&m[k])!=(s[k]&m[k]))return 0;return 1;}
static void image_observe(void){
 ui_observe();
 if(base&&PC>=base&&PC<base+PUI_BSS_START&&SP<low_stack)low_stack=SP;
 if(PC>=0x100&&PC<0xbc00){
  if(!nc&&r[PC]==nc_sig[0]&&match(PC,nc_sig,nc_mask))nc=PC;
  if(core_armed&&r[PC]==core_sig[0]&&match(PC,core_sig,core_mask)){core=PC;core_count++;core_armed=0;}
 }
 if(nc&&PC==nc+NC_RELOAD)core_armed=1;
 if(nc&&PC==nc+NC_FATAL)load_error=A;
}
static void panels(unsigned count){
 uint64_t end=virtual_cycles+200000000;
 do{until(virtual_cycles+1);if(core_count>=count&&core&&PC==core+NCMAIN_MOUSE_KEY_POLL)return;}while(virtual_cycles<end);
 fprintf(stderr,"NC image nc%04x core%04x count%u/%u Paint%04x PC%04x\n",nc,core,core_count,count,base,PC);
 require(0,"NC panels resume after the image process exits");
}
static void panel_key(unsigned scan){key(scan);panels(core_count);}
static unsigned char*catalog(void){unsigned ptr=ramword(core+NCMAIN_CACHEPTR);return r[core+NCMAIN_CACHE_LEASE_OPEN]?physical+0x22000+r[core+NCMAIN_CACHE_LEASE+3]*8192+(ptr&8191):r+ptr;}
static void select_image(const char*name){
 panel_key(0x47);unsigned count=r[core+NCMAIN_PCOUNT],k;
 for(k=0;k<count;k++)if(!memcmp(catalog()+k*NCMAIN_ENTRY_SIZE,name,11))break;
 require(k<count,"image is available in the nested active panel");
 for(unsigned j=0;j<k;j++)panel_key(0x50);
 require(!memcmp(catalog()+r[core+NCMAIN_PCUR]*NCMAIN_ENTRY_SIZE,name,11),"image selected with the real panel keyboard");
}
static void open_image(const char*name,unsigned scan,unsigned readonly,unsigned kind){
 select_image(name);base=ready=0;key(scan);wait_context(0);
 require(r[base+PUI_P_READONLY]==readonly&&r[base+PUI_P_KIND]==kind&&!r[base+PUI_P_MODIFIED],"F3/Enter view and F4 edit choose the correct native image mode");
 require((gfx[0]&1)||!r[base+PUI_P_PREVIEW_EXT],"image is displayed");
}
static void close_image(const char*name){
 unsigned next=core_count+1,dirty=r[base+PUI_P_MODIFIED];key(0x44);if(dirty){wait_context(3);key(0x15);}panels(next);
 require(!memcmp(catalog()+r[core+NCMAIN_PCUR]*NCMAIN_ENTRY_SIZE,name,11),"return retains the selected filename after panel reload");
 unsigned state=ramword(core+NCMAIN_OWNER);
 require(strstr((char*)r+state+NC_S_PATHS,"IMAGES\\SUB\\")!=NULL,"return retains the nested active directory");
 base=ready=0;
}
static void control_key(unsigned scan){KBDModKeyDown(1);key(scan);KBDModKeyUp(1);wait_context(0);}
static void readonly_checks(unsigned bytes){
 unsigned char*original=malloc(bytes);memcpy(original,physical+r[base+PUI_P_DOC_PAGE]*65536,bytes);
 mouse(20,20,0);mouse(20,20,1);mouse(100,70,1);mouse(100,70,0);mouse(20,20,2);mouse(20,20,0);
 for(unsigned scan=0x3c;scan<=0x42;scan++)if(scan!=0x3d){key(scan);wait_context(0);}
 control_key(0x1e);control_key(0x2e);control_key(0x2d);control_key(0x2f);control_key(0x2c);control_key(0x15);
 key(0x39);wait_context(0);key(0x50);wait_context(0);key(0x39);wait_context(0);
 require(!r[base+PUI_P_MODIFIED]&&!memcmp(original,physical+r[base+PUI_P_DOC_PAGE]*65536,bytes),"read-only mouse, keyboard, Save, New, Undo/Redo, Cut/Paste do not change the document");
 control_key(0x20);key(0x2c);wait_context(0);require(r[base+PUI_P_VIEW_SHIFT]==1,"viewer can zoom");key(0x22);wait_context(0);key(0x26);wait_context(0);
 key(0x43);wait_context(5);modal_text(6,6," Image viewer");modal_selection(6,8,"1  Open image");modal_text(6,12,"5  Exit");key(1);wait_context(0);
 key(0x3b);wait_context(4);key(1);wait_context(0);
 key(0x3d);wait_context(2);key(0x1c);wait_context(0);
 require(r[base+PUI_P_READONLY]&&!r[base+PUI_P_MODIFIED],"viewer retains read-only mode after another file-overlay Open");
 require(!memcmp(original,physical+r[base+PUI_P_DOC_PAGE]*65536,bytes),"viewer zoom, grid, menus and help preserve canonical pixels");free(original);
}
int main(int argc,char**argv){
 if(argc!=7)return 2;
 require(!hg_volume_open(&volume,argv[5],true,HG_MAX_SECTORS,false),"open private image association HG");host_image=volume.image;host_size=volume.size;host_write=durable_write;hg_v2=1;
 model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load(argv[1],&image_size);committed=1;dma_mmio_read=paint_dma_read;dma_mmio_write=paint_dma_write;MC6800Init();MC6800Reset();r=MC6800GetCpuRam();until(60000000);key(0x1c);key(0x1c);prompt_wait();
 unsigned drive=0;while(drive<8&&ramword(0xeb03+drive*2))drive++;
 command("b:hg");dos_prompt_text=">";char change[]={(char)('a'+drive),':',0};command(change);command("handles 16");command("cd images\\sub");
 unsigned sp0=SP,heap0=ramword(0xee1e),banks=free_banks(),rv=0,rp=0;
 if(!strcmp(argv[6],"missing")){invoke(0x2e,0xe5,0,0);rv=result_x;rp=result_b;invoke(0x2f,0xe5,0,0);}
 if(!(atoi(argv[4])&3))invoke(0x12,atoi(argv[4]),atoi(argv[4])?0:0x71,0);
 unsigned mode0=r[0xed12];sig("build/nc/NC.PGM",nc_sig,nc_mask);sig("build/nc/NCMAIN.PGM",core_sig,core_mask);native_step_hook=image_observe;watch_resets=1;
 char line[81];snprintf(line,sizeof line,"%c:\\%s%s",'a'+drive,!strcmp(argv[6],"long")?"longdir1\\longdir2\\longdir3\\longdir4\\longdir5\\longdir6\\":"",(atoi(argv[4])&3)?"nigraph":"nc");text(line);key(0x1c);
 if(!strcmp(argv[6],"low-gfx")){
  until(virtual_cycles+20000000);require(load_error==66&&!core_count&&!base,"601A native framebuffer plus HG reports panel load OOM without running partial code");key(1);prompt_wait();goto finished;
 }
 panels(1);
 if(!strcmp(argv[6],"no-paint")){
  select_image("PCX3    PCX");key(0x3d);until(virtual_cycles+10000000);require(!base&&contains("NC:")&&contains("Press a key"),"missing Paint reports a readable error from the small supervisor");key(1);panels(2);
 }else{
  open_image("PCX3    PCX",0x3d,1,3);readonly_checks(64000);close_image("PCX3    PCX");
  open_image("HAM     IFF",0x1c,1,4);readonly_checks(192000);close_image("HAM     IFF");
  open_image("HAM     LBM",0x3d,1,4);close_image("HAM     LBM");
  open_image("PCX3    PCX",0x3e,0,3);mouse(20,20,0);mouse(20,20,1);mouse(80,50,1);mouse(80,50,0);require(r[base+PUI_P_MODIFIED],"associated F4 editor accepts mouse strokes");
  char expected_path[160];snprintf(expected_path,sizeof expected_path,"build/nc-images/saved-%s-%s-%s-%s.raw",argv[2],argv[3],argv[4],argv[6]);FILE*f=fopen(expected_path,"wb");require(f&&fwrite(physical+r[base+PUI_P_DOC_PAGE]*65536,1,64000,f)==64000&&!fclose(f),"save independent expected pixels");
  key(0x3c);wait_context(2);key(0x47);for(unsigned k=0;k<80&&r[base+PUI_EDIT_LENGTH];k++)key(0x53);text("saved.pcx");key(0x1c);wait_context(0);require(!r[base+PUI_P_MODIFIED],"F4 Save publishes through the selected panel HG directory");close_image("PCX3    PCX");
  open_image("HAM     IFF",0x3e,0,4);mouse(20,20,0);mouse(20,20,1);mouse(80,50,1);mouse(80,50,0);require(r[base+PUI_P_MODIFIED],"associated HAM F4 editor works on both CPUs");close_image("HAM     IFF");
  if(!strcmp(argv[6],"long")){
   select_image("LONGNAMEPCX");unsigned next=core_count;key(0x3d);until(virtual_cycles+10000000);require(!base&&contains("Invalid name"),"overlong association command reports an error without buffer overflow");key(1);panels(next);
  }
 }
 key(0x44);prompt_wait();if(rv)invoke(0x2f,0xe5,rp,rv);
finished:
 require(r[0xed12]==mode0,"NC restores the original native video mode");
 require(!resets&&SP==sp0&&ramword(0xee1e)==heap0&&free_banks()==banks,"NC/image chain restores DOS stack, heap and banks");
 require(low_stack>=0x200,"NC+HG image processing preserves ordinary stack headroom");require(!hg_volume_sync(&volume),"sync image association HG writes");hg_volume_close(&volume);
 printf("PASS NC images %s/%s video%s %s: %s; stack%04x\n",argv[2],argv[3],argv[4],argv[6],!strcmp(argv[6],"low-gfx")?"panel load OOM cleanup":"F3/Enter read-only, F4 editing, PCX/IFF/LBM, nested paths, selection, resources",low_stack);return 0;
}
