// The actual resident HG consumes ordinary RAM and dispatches native file APIs.
// Mouse/DMA remain the same independently exercised MMIO models as other tests.
#define PAINT_EXTERNAL_TRANSPORT 1
#define PAINT_UI_MAIN unused_paint_ui_main
#define PAINT_UI_HEADER "../build/paint/PAINTF.h"
#include "test_paint_ui.c"
#include "../host/hg/hg.h"
#define hg_transport_read paint_host_read
#define hg_transport_write paint_host_write
#include "hg_transport.h"
#undef hg_transport_read
#undef hg_transport_write
static HgVolume volume;
static unsigned lowest_stack=65535;
static void hg_observe(void){ui_observe();if(base&&PC>=base&&PC<base+PUI_BSS_START&&SP<lowest_stack)lowest_stack=SP;}
static int durable_write(unsigned block,const uint8_t*data,unsigned length){return hg_volume_write(&volume,block,data,length);}
static int hg_transport_read(uint16_t a,unsigned char*out){return mouse_ui_read_byte(a,out)||paint_host_read(a,out);}
static int hg_transport_write(uint16_t a,unsigned char d){return mouse_ui_write_byte(a,d)||paint_host_write(a,d);}
int main(int argc,char**argv){
 if(argc!=7)return 2;
 require(!hg_volume_open(&volume,argv[5],true,HG_MAX_SECTORS,false),"open private HG directory");
 host_image=volume.image;host_size=volume.size;host_write=durable_write;hg_v2=1;
 model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");unsigned native=atoi(argv[4]);MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load(argv[1],&image_size);committed=1;dma_mmio_read=paint_dma_read;dma_mmio_write=paint_dma_write;MC6800Init();MC6800Reset();r=MC6800GetCpuRam();until(60000000);key(0x1c);key(0x1c);prompt_wait();
 unsigned drive=0;while(drive<8&&ramword(0xeb03+drive*2))drive++;
 command("b:hg");require(contains("HG 2.0 remote disk"),"install real HG resident");
 dos_prompt_text=">";char change[]={(char)('a'+drive),':',0};command(change);
 command("handles 16");
 unsigned sp0=SP,heap0=ramword(0xee1e),banks=free_banks(),mode0=r[0xed12];
 unsigned rv=0,rp=0;if(!strcmp(argv[6],"missing")){invoke(0x2e,0xe5,0,0);rv=result_x;rp=result_b;invoke(0x2f,0xe5,0,0);}
 printf("HG Paint %s/%s native%u %s: SP%04x heap%04x\n",argv[2],argv[3],native,argv[6],sp0,heap0);fflush(stdout);
 native_step_hook=hg_observe;watch_resets=1;
 unsigned nc=!strcmp(argv[6],"nc");
 if(nc){text("nc");key(0x1c);until(virtual_cycles+20000000);}
 text(native?"pghg":"paint");key(0x1c);wait_context(0);
 key(0x3f);wait_context(5);modal_text(6,6,"Drawing tool");modal_selection(6,8,"1  Freehand brush");key(1);wait_context(0);
 require(r[base+PUI_P_FRAME_OWNED]==!native,"HG Paint frame ownership");
 require(r[base+PUI_BACKEND_BANKED]==(strcmp(argv[6],"missing")!=0),"HG Paint RAMMAN/fallback");
 mouse(20,20,0);mouse(20,20,1);mouse(80,50,1);mouse(80,50,0);
 require(r[base+PUI_P_MODIFIED],"HG-launched Paint accepts mouse strokes");
 key(0x3c);wait_context(2);text("hgtest.pcx");key(0x1c);wait_context(0);require(!r[base+PUI_P_MODIFIED],"Save through real HG native filesystem");
 key(0x3d);wait_context(2);key(0x1c);wait_context(0);require(!r[base+PUI_P_MODIFIED],"Open through real HG native filesystem");
 format(model_a?1:0);format(2);format(3);format(4);
 key(0x44);
 if(nc){until(virtual_cycles+20000000);key(0x44);}
 prompt_wait();
 if(rv)invoke(0x2f,0xe5,rp,rv);
 require(return_seen==1&&!resets&&SP==sp0&&ramword(0xee1e)==heap0&&free_banks()==banks&&r[0xed12]==mode0,"HG Paint restores resident parent resources");
 require(lowest_stack>=0x200,"HG Paint retains stack space above the native low-memory boundary");
 command("pntcore");require(contains("Run PAINT.PGM")&&!resets&&SP==sp0&&ramword(0xee1e)==heap0,"unpacked core rejects a direct launch safely");
 command("pglow");
 if(!contains("Paint:")||resets||SP!=sp0||ramword(0xee1e)!=heap0)fprintf(stderr,"OOM probe: output%u resets%u SP%04x/%04x heap%04x/%04x\n",contains("Paint:"),resets,SP,sp0,ramword(0xee1e),heap0);
 require(contains("Paint:")&&!resets&&SP==sp0&&ramword(0xee1e)==heap0,"packed loader rejects insufficient memory without low-stack wrap");
 require(hg_reads&&hg_writes&&!hg_volume_sync(&volume),"HG traffic durably synchronized");hg_volume_close(&volume);
 printf("PASS Paint actual HG %s/%s native%u %s: startup, mouse, Save/Open, format switching, parent cleanup; lowest core stack %04x\n",argv[2],argv[3],native,argv[6],lowest_stack);return 0;
}
