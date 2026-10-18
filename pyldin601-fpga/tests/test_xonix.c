// Real UniDOS/PGM: config parsing, cached level cycling and uninterrupted AY.
#define ARCADE_MAIN unused_arcade_main
#define GAME_UI_TIMEOUT 1000000000
#include "test_arcade.c"
static const char *scenario;
static unsigned load_calls,transition_io,transition_mode,watch_transition,cancelled;
static unsigned load_pending,load_sp;
static void xo_probe(void){
 arcade_observe();
 if(!app)return;
 // An IRQ before the first instruction presents the same entry PC again
 // after RTI. Count once the callee actually advances on its original stack.
 if(load_pending&&PC!=app+XO_HI_LOAD&&PC<0xc000&&SP==load_sp){load_calls++;load_pending=0;}
 if(PC==app+XO_HI_LOAD){load_pending=1;load_sp=SP;}
 if(watch_transition&&PC<0xc000&&r[PC]==0x3f){
  if(r[PC+1]==0x4a||r[PC+1]==0x4c)transition_io++;
  if(r[PC+1]==0xe6&&A==3&&B==7)transition_mode++;
 }
 if(!cancelled&&!strcmp(scenario,"cancel")&&r[app+XO_HS_UI_ACTIVE]==3&&r[app+XO_HI_OPENED]){
  cancelled=1;KBDKeyDown(0x01);
 }
}
static void level_up(unsigned expected){
 unsigned level=r[app+XO_XO_LEVEL];word_at(app+XO_XO_CLAIMED,655);
 r[app+XO_XO_ENEMY]=5;r[app+XO_XO_ENEMY+1]=10;
 r[app+XO_XO_ENEMY+2]=10;r[app+XO_XO_ENEMY+3]=15;
 memset(r+app+XO_XO_DIRECTION,0,4);watch_transition=1;
 raw_key(1,0,0x72);uint64_t deadline=virtual_cycles+30000000;
 while(r[app+XO_XO_LEVEL]==level&&virtual_cycles<deadline)until(virtual_cycles+1009);
 require(r[app+XO_XO_LEVEL]==level+1,"real capture advances the level");
 raw_key(1,1,0x72);step_frames(4);watch_transition=0;
 require(r[app+XO_XO_PICTURE_PAGE]==expected,"level selects the configured cached picture");
 require(!read16(state+26),"level change keeps AY queue fed");
}
int main(int argc,char**argv){
 if(argc!=4)return 2;scenario=argv[3];which=1;
 model_a=!strcmp(argv[2],"601a");cpu_hd=1;MC6800SetMachine(PYLDIN_MACHINE_HD6303);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);
 memcpy(config,rom,HEADER_BYTES);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load(argv[1],&image_size);committed=1;MC6800Init();MC6800Reset();until(60000000);
 key(0x1c);key(0x1c);prompt_wait();r=MC6800GetCpuRam();state=read16(0xefcc);pcb=read16(0xec00);sp_before=SP;
 for(unsigned k=0;k<8192;k++)pal[k]=saved_pal[k]=(k*11+7)&63;
 for(unsigned k=0;k<14;k++)ay[k]=saved_ay[k]=k&15;
 front=4;old_irq=read16(0xefc8);old_page=r[0xedf2]>>4;native_step_hook=xo_probe;flip_hook=arcade_flip;
 if(!strcmp(scenario,"long")||!strcmp(scenario,"many")||!strcmp(scenario,"large")||!strcmp(scenario,"badpic")||!strcmp(scenario,"cancel")){
  command("b:xonix");
  if(!strcmp(scenario,"badpic"))require(contains("XONIX: background"),"bad image reports a safe error");
  else if(!strcmp(scenario,"cancel")){KBDKeyUpCode(0x01);require(cancelled&&contains("XONIX: returned"),"ESC cancels cold loading safely");}
  else require(contains("invalid XONIX.CFG"),"oversized config fails safely");
  if(app)restored();
  else require(!gfx[0]&&!enabled&&!raw_capture&&front==4&&
               !memcmp(pal,saved_pal,8192)&&!memcmp(ay,saved_ay,14)&&
               read16(0xefc8)==old_irq,"config refusal never opens or changes GAMEBIOS");
  require(SP==sp_before,"failure/cancel balances native stack");
  command("dir a:");command("dir b:");command("dir c:");printf("PASS XONIX %s/%s: safe refusal/cancel, cleanup and DIR\n",argv[2],scenario);return 0;
 }
 type_app("xonix");unsigned count=!strcmp(scenario,"two")?2:!strcmp(scenario,"ten")?10:1;
 if(r[app+XO_XC_N]!=count||load_calls!=count)fprintf(stderr,"XONIX load count: configured=%u calls=%u expected=%u\n",r[app+XO_XC_N],load_calls,count);
 require(r[app+XO_XC_N]==count&&load_calls==count,"every configured picture is preloaded exactly once");
 size_t size;unsigned char*source=load("build/games-next/LENA.raw",&size);
 require(size==64000&&!memcmp(source,physical+0x180000,size),"first cached HAM8 image is lossless");free(source);
 if(count>1){source=load("build/xonix-start/ALT.raw",&size);require(!memcmp(source,physical+0x160000,size),"second cached image is independently decoded");free(source);}
 unsigned char*cache=malloc(10*65536);require(cache!=NULL,"cache snapshot");memcpy(cache,physical+0x160000,10*65536);
 watch_transition=1;play();watch_transition=0;
 require(r[app+XO_XO_PICTURE_PAGE]==8,"first level starts from the first entry");
 level_up(count>1?6:8);level_up(count==2?8:count==10?7:8);
 require(load_calls==count&&!transition_io&&!transition_mode,"play and level changes perform no file reads or HAM-palette generation");
 require(!memcmp(cache,physical+0x160000,10*65536),"cached backgrounds survive real capture/level changes");free(cache);
 finish_ui();restored();require(SP==sp_before,"native stack restored after score UI");
 command("dir a:");command("dir b:");command("dir c:");
 printf("PASS XONIX %s/%s: %u cached images, cyclic levels, no load-time AY underrun, no disk/mode work at start, cleanup and DIR\n",argv[2],scenario,count);return 0;
}
