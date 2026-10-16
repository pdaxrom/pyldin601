#define PAINT_UI_HEADER "../build/paint-overlays/PUI.h"
#define PAINT_UI_MAIN unused_paint_ui_main
#include "../build/paint-overlays/OVL.h"
#include "../build/paint-overlays/PIO.h"
static unsigned supervisor;
static unsigned lowest_stack=65535;
static unsigned fault_job,fault_seen;

#define PAINT_ALT_MOUSE_WAIT PIO_MOUSE_WAIT
#define PAINT_OVERLAY_IS_FILE (supervisor&&r[supervisor+OVL_LOAD_API+4]==2)
#include "test_paint_ui.c"
static int overlay_dma_read(uint16_t a,unsigned char*out){
 int yes=paint_dma_read(a,out);
 if(yes&&a==0xe6e0&&fault_job&&paint_jobs>=fault_job&&virtual_cycles>=paint_until){*out|=16;fault_job=0;fault_seen++;}
 return yes;
}
static void overlay_observe(void){
 ui_observe();
 if(base&&PC>=base&&PC<base+PUI_BSS_START&&SP<lowest_stack)lowest_stack=SP;
 if(!supervisor&&PC>=0x100&&PC<0xbc00&&r[PC]==0x20&&!memcmp(r+PC+2,"PNTO",4))supervisor=PC;
 if(supervisor&&PC==supervisor+OVL_LOADER_ERROR)fprintf(stderr,"Overlay supervisor error A=%u cache=%u index=%u\n",A,r[supervisor+OVL_LOAD_CACHED],r[supervisor+OVL_CACHE_INDEX]);
}
static void check_view(void){
 unsigned shift=r[base+PUI_P_VIEW_SHIFT],x0=ramword(base+PUI_P_VIEW_X),y0=r[base+PUI_P_VIEW_Y],doc=r[base+PUI_P_DOC_PAGE]*65536;
 require(shift&&gfx[0]==1&&(front==5||front==12),"zoom uses an independent GPU viewport");
 for(unsigned y=0;y<200;y++)for(unsigned x=0;x<320;x++){
  unsigned want=physical[doc+(y0+(y>>shift))*320+x0+(x>>shift)];
  if(r[base+PUI_VIEW_GRID]&&shift>=2&&((x&((1<<shift)-1))==((1<<shift)-1)||(y&((1<<shift)-1))==((1<<shift)-1)))want=0;
  require(physical[0x100000+front*65536+y*320+x]==want,"zoom samples, replication and pixel grid match canonical pixels");
 }
}
static void control(unsigned scan){KBDModKeyDown(1);key(scan);KBDModKeyUp(1);wait_context(0);}


static void check_ham_view(void){
 unsigned shift=r[base+PUI_P_VIEW_SHIFT],x0=ramword(base+PUI_P_VIEW_X),y0=r[base+PUI_P_VIEW_Y],doc=r[base+PUI_P_DOC_PAGE]*65536;
 for(unsigned y=0;y<200;y++){
  unsigned held[3]={0};
  for(unsigned x=0;x<320;x++){
   unsigned want[3],off=((y0+(y>>shift))*320+x0+(x>>shift))*3;
   for(unsigned j=0;j<3;j++)want[j]=physical[doc+off+j];
   if(r[base+PUI_VIEW_GRID]&&shift>=2&&((x&((1<<shift)-1))==((1<<shift)-1)||(y&((1<<shift)-1))==((1<<shift)-1)))memset(want,0,sizeof want);
   unsigned best=0,best_error=1000;
   for(unsigned cmd=0;cmd<67;cmd++){
    unsigned code=cmd<64?cmd:cmd==64?64+want[2]:cmd==65?128+want[0]:192+want[1],rgb[3];memcpy(rgb,held,sizeof rgb);
    if(code<64){rgb[0]=(code>>4)*21;rgb[1]=((code>>2)&3)*21;rgb[2]=(code&3)*21;}else rgb[code<128?2:code<192?0:1]=code&63;
    unsigned e=0;for(unsigned j=0;j<3;j++)e+=rgb[j]>want[j]?rgb[j]-want[j]:want[j]-rgb[j];if(e<best_error){best_error=e;best=code;}
   }
   require(physical[0x100000+front*65536+y*320+x]==best,"HAM zoom and grid match an independent exhaustive encoder");
   if(best<64){held[0]=(best>>4)*21;held[1]=((best>>2)&3)*21;held[2]=(best&3)*21;}else held[best<128?2:best<192?0:1]=best&63;
  }
 }
}

int main(int argc,char**argv){
 if(argc!=6)return 2;model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");unsigned native=atoi(argv[4]);MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load(argv[1],&image_size);committed=1;dma_mmio_read=overlay_dma_read;dma_mmio_write=paint_dma_write;MC6800Init();MC6800Reset();r=MC6800GetCpuRam();until(60000000);key(0x1c);key(0x1c);prompt_wait();
 unsigned sp0=SP,heap0=ramword(0xee1e),banks0=free_banks();invoke(0x2e,0xe5,0,0);unsigned rv=result_x,rp=result_b;unsigned char foreign[114];
 if(!strcmp(argv[5],"missing"))invoke(0x2f,0xe5,0,0);
 if(!strcmp(argv[5],"busy")){require(!invoke(0xe5,1,banks0,0x9000),"reserve every RAMMAN bank");memcpy(foreign,r+0x9000,banks0+3);}
 native_step_hook=overlay_observe;watch_resets=1;text(native?"b:pgraph":"b:paintui");key(0x1c);wait_context(0);
 require(r[base+PUI_BACKEND_BANKED]==!strcmp(argv[5],"banked"),"enhanced Paint keeps its ordinary RAM fallback");
 mouse(20,20,0);mouse(20,20,1);mouse(80,50,1);mouse(80,50,0);
 unsigned char*expected=malloc(64000);memcpy(expected,physical+r[base+PUI_P_DOC_PAGE]*65536,64000);
 fault_job=paint_jobs+2;key(0x3c);wait_context(4);key(1);wait_context(0);require(fault_seen==1&&!memcmp(expected,physical+r[base+PUI_P_DOC_PAGE]*65536,64000),"failed code DMA restores a complete edit overlay and preserves the document");
 key(0x3c);wait_context(2);key(0x47);for(unsigned k=0;k<80&&r[base+PUI_EDIT_LENGTH];k++)key(0x53);text("b:ovl.pcx");key(0x1c);wait_context(0);require(!r[base+PUI_P_MODIFIED],"file overlay saves the editing overlay's document");
 key(0x3c);wait_context(2);key(0x47);for(unsigned k=0;k<80&&r[base+PUI_EDIT_LENGTH];k++)key(0x53);text("b:bad:bad.pcx");key(0x1c);wait_context(4);key(1);wait_context(0);require(!r[base+PUI_P_MODIFIED]&&!memcmp(expected,physical+r[base+PUI_P_DOC_PAGE]*65536,64000),"malformed drive syntax is rejected before native file publication");
 for(unsigned k=0;k<3;k++){
  mouse(20,100,0);mouse(20,100,1);mouse(200,100,1);mouse(200,100,0);require(r[base+PUI_P_MODIFIED],"edit overlay survives previous disk operation");
  key(0x3d);wait_context(3);key(0x15);wait_context(2);key(0x1c);wait_context(0);
  require(!r[base+PUI_P_MODIFIED]&&!memcmp(expected,physical+r[base+PUI_P_DOC_PAGE]*65536,64000),"repeated overlay swaps preserve BSS, filename, canonical bytes and saved generation");
 }
 key(0x3f);wait_context(5);modal_text(6,13,"6  Select rectangle");mouse(7*(model_a?8:16)+3,13*8+3,0);mouse(7*(model_a?8:16)+3,13*8+3,1);wait_context(0);require(r[base+PUI_P_TOOL]==5,"mouse selects the sixth F5 tool");mouse(100,50,0);key(0x30);wait_context(0);
 for(unsigned level=1;level<4;level++){
  if(level==1){key(0x43);wait_context(5);key(7);}else key(0x2c);wait_context(0);require(r[base+PUI_P_VIEW_SHIFT]==level,"F9 and Z choose the next zoom level");check_view();
  if(level==2){key(0x22);wait_context(0);check_view();key(0x22);wait_context(0);check_view();}
  if(level==1){unsigned px=ramword(base+PUI_P_VIEW_X)+75,py=r[base+PUI_P_VIEW_Y]+50;mouse(300,100,0);mouse(300,100,1);mouse(300,100,0);require(physical[r[base+PUI_P_DOC_PAGE]*65536+py*320+px]==255,"magnified painting edits the pointed canonical pixel");check_view();key(0x41);wait_context(0);check_view();require(!r[base+PUI_P_MODIFIED],"Undo from a zoomed viewport restores the saved generation");}
 }
 key(0x26);wait_context(0);check_view();key(0x25);wait_context(0);check_view();
 key(0x2c);wait_context(0);require(!r[base+PUI_P_VIEW_SHIFT]&&front==r[base+PUI_P_FRONT_PAGE],"zoom cycle restores the untouched native preview");
 key(0x1f);wait_context(0);mouse(20,20,0);mouse(20,20,1);mouse(100,60,1);mouse(100,60,0);
 require(r[base+PUI_P_SEL_ACTIVE]&&ramword(base+PUI_P_SEL_LEFT)==10&&ramword(base+PUI_P_SEL_RIGHT)==50&&r[base+PUI_P_SEL_TOP]==20&&r[base+PUI_P_SEL_BOTTOM]==60,"drag selects a normalized logical rectangle");
 mouse(100,60,1);mouse(20,20,1);mouse(20,20,0);require(ramword(base+PUI_P_SEL_LEFT)==10&&ramword(base+PUI_P_SEL_RIGHT)==50&&r[base+PUI_P_SEL_TOP]==20&&r[base+PUI_P_SEL_BOTTOM]==60,"reverse drag retains normalized rectangle bounds");
 require(!r[base+PUI_P_MODIFIED]&&!memcmp(expected,physical+r[base+PUI_P_DOC_PAGE]*65536,64000),"selection outline does not modify the document or saved generation");
 control(0x2e);require(r[base+PUI_P_CLIP_VALID]&&!r[base+PUI_P_MODIFIED],"Ctrl+C copies the selected rectangle without changing the image");
 unsigned char *pasted=malloc(64000);memcpy(pasted,expected,64000);for(unsigned y=0;y<41;y++)memcpy(pasted+(100+y)*320+200,expected+(20+y)*320+10,41);
 mouse(400,100,0);control(0x2f);require(r[base+PUI_P_MODIFIED]&&!memcmp(pasted,physical+r[base+PUI_P_DOC_PAGE]*65536,64000),"Ctrl+V pastes canonical pixels at the pointer");
 key(0x41);wait_context(0);require(!memcmp(expected,physical+r[base+PUI_P_DOC_PAGE]*65536,64000),"one Undo removes the complete Paste");key(0x42);wait_context(0);require(!memcmp(pasted,physical+r[base+PUI_P_DOC_PAGE]*65536,64000),"one Redo restores the complete Paste");key(0x41);wait_context(0);
 mouse(638,199,0);control(0x2f);require(ramword(base+PUI_P_SEL_LEFT)==319&&ramword(base+PUI_P_SEL_RIGHT)==319&&r[base+PUI_P_SEL_BOTTOM]==199,"Paste clips its selection and pixels to the image edges");key(0x41);wait_context(0);
 mouse(20,20,0);mouse(20,20,1);mouse(100,60,1);mouse(100,60,0);control(0x2d);for(unsigned y=20;y<=60;y++)for(unsigned x=10;x<=50;x++)require(!physical[r[base+PUI_P_DOC_PAGE]*65536+y*320+x],"Cut clears the selected pixels with the background colour");key(0x41);wait_context(0);require(!memcmp(expected,physical+r[base+PUI_P_DOC_PAGE]*65536,64000)&&!r[base+PUI_P_MODIFIED],"Cut is one reversible image operation");free(pasted);
 free(expected);
 format(4);r[base+PUI_P_FG_RGB]=53;r[base+PUI_P_FG_RGB+1]=12;r[base+PUI_P_FG_RGB+2]=41;key(0x30);wait_context(0);mouse(40,30,0);mouse(40,30,1);mouse(120,70,1);mouse(120,70,0);
 unsigned char*ham=malloc(192000);memcpy(ham,physical+r[base+PUI_P_DOC_PAGE]*65536,192000);mouse(40,30,0);key(0x2c);wait_context(0);check_ham_view();key(0x2c);wait_context(0);check_ham_view();
 key(0x2c);wait_context(0);key(0x2c);wait_context(0);key(0x1f);wait_context(0);mouse(40,30,0);mouse(40,30,1);mouse(120,70,1);mouse(120,70,0);control(0x2e);mouse(400,100,0);control(0x2f);
 for(unsigned y=0;y<41;y++)for(unsigned x=0;x<41;x++)require(!memcmp(physical+r[base+PUI_P_DOC_PAGE]*65536+((100+y)*320+200+x)*3,ham+((30+y)*320+20+x)*3,3),"HAM clipboard retains complete RGB666 triplets across pages");key(0x41);wait_context(0);require(!memcmp(ham,physical+r[base+PUI_P_DOC_PAGE]*65536,192000),"HAM Paste Undo restores all canonical bytes");control(0x1e);control(0x2e);require(!memcmp(ham,physical+0x190000,192000),"full HAM clipboard preserves all three canonical pages");free(ham);
 if(model_a){format(1);key(0x30);wait_context(0);mouse(638,199,0);mouse(638,199,1);mouse(638,199,0);key(0x2c);wait_context(0);require(r[base+PUI_P_VIEW_SHIFT]==1&&ramword(base+PUI_P_VIEW_X)==320,"640-wide mono viewport reaches its right edge");control(0x1e);control(0x2e);require(r[base+PUI_P_CLIP_VALID],"full 640x200 clipboard spans RAM pages");}
 key(0x44);if(r[base+PUI_P_MODIFIED]){wait_context(3);key(0x15);}prompt_wait();
 if(!strcmp(argv[5],"missing"))invoke(0x2f,0xe5,rp,rv);
 if(!strcmp(argv[5],"busy")){memcpy(r+0x9000,foreign,banks0+3);require(!invoke(0xe5,2,0,0x9000),"release foreign RAMMAN reservation");}
 require(!resets&&return_seen==1&&SP==sp0&&ramword(0xee1e)==heap0&&free_banks()==banks0&&lowest_stack>=0x200,"resident overlay supervisor restores stack, ordinary heap and bank leases");
 printf("PASS Paint overlays %s/%s start%u %s: native file/edit swapping, zoom/grid, selection/clipboard, save/reopen, cleanup, stack%04x\n",argv[2],argv[3],native,argv[5],lowest_stack);return 0;
}
