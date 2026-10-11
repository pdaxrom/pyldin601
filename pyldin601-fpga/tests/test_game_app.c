// Actual PGM loader, SDK tile atlas and game with independent full-frame oracle.
#define GAMEBIOS_MAIN unused_gamebios_main
#include "test_gamebios.c"
#include "../build/game/arkanoid_labels.h"
#include "../build/game/sdktest_labels.h"
static unsigned app,frames,hits,irq_started,max_irq;
static unsigned at(unsigned offset){return r[app+offset]*256+r[app+offset+1];}
static void game_frame(unsigned dp){
 if(!gfx[0]||dp>1||!app||!r[app+GAME_VALID+dp])return;
 unsigned x=at(GAME_BALL_X),y=at(GAME_BALL_Y),p=at(GAME_PADDLE);
 require(x+8<=320&&y+8<=200&&p<=272,"game sprite coordinates");
 unsigned char *bg=physical+0x130000,*fb=physical+0x100000+dp*65536;
 for(unsigned row=0;row<200;row++)for(unsigned col=0;col<320;col++){
  unsigned expected=bg[row*320+col];
  if(col>=x&&col<x+8&&row>=y&&row<y+8){unsigned sx=col-x,sy=row-y;if((sy>=2&&sy<6)||(sx>=2&&sx<6))expected=7;}
  if(row>=190&&row<195&&col>=p&&col<p+48)expected=6;
  if(fb[row*320+col]!=expected){fprintf(stderr,"frame %u p%u x%u y%u got%u expected%u ball%u,%u paddle%u\n",frames,dp,col,row,fb[row*320+col],expected,x,y,p);require(0,"full framebuffer has no trails");}
 }
 unsigned alive=0;
 for(unsigned row=0;row<5;row++)for(unsigned col=0;col<8;col++){
  unsigned id=r[app+GAME_BRICKS+row*8+col];alive+=!!id;
  for(unsigned dy=0;dy<8;dy++)for(unsigned dx=0;dx<32;dx++)require(bg[(40+row*8+dy)*320+32+col*32+dx]==(id&&dy<7&&(dx&7)<7?id:0),"tile map/dirty brick update matches atlas");
 }
 require(alive==r[app+GAME_REMAINING],"brick count matches tile map");frames++;
 // HUD is checked against the native font, independently of cached glyphs.
 char hud[48];snprintf(hud,sizeof hud,"PULDIN  ARKANOID  SCORE %03u LIFE: %u",at(GAME_SCORE),r[app+GAME_LIVES]);
 for(unsigned dy=0;dy<8;dy++)for(unsigned col=0;col<320;col++){
  unsigned ch=col/8,bit=col&7,expected=0;
  if(ch>=1&&ch<=strlen(hud))expected=(physical[0x10000+6144+(unsigned char)hud[ch-1]*8+dy]&(128>>bit))?7:0;
  if(bg[(8+dy)*320+col]!=expected){fprintf(stderr,"HUD frame%u score%u life%u x%u y%u got%u expected%u\n",frames,at(GAME_SCORE),r[app+GAME_LIVES],col,dy,bg[(8+dy)*320+col],expected);require(0,"HUD score/life and static labels match native font");}
 }
}
static void type_game(void){key(0x30);KBDModKeyDown(2);key(0x27);KBDModKeyUp(2);
 const unsigned scans[]={0x1e,0x13,0x25,0x1e,0x31,0x18,0x17,0x20};for(unsigned k=0;k<8;k++)key(scans[k]);key(0x1c);}
static void wait_frames(unsigned n){uint64_t deadline=virtual_cycles+10000000;while(frames<n&&virtual_cycles<deadline)until(virtual_cycles+1000);require(frames>=n,"game renders frames");}
static void game_observe(void){
 observe();unsigned context=r[state+6]*256+r[state+7];if(!app&&context>=GAME_SDK_CONTEXT+0x100&&context<0xbe00&&r[state+4]*256+r[state+5]!=pcb&&r[state+4]*256+r[state+5]!=0)app=context-GAME_SDK_CONTEXT;
}
static unsigned sdk_frames;
static void sdk_frame(unsigned dp){
 observe();if(!gfx[0])return;require(dp==0,"SDK destination page");
 unsigned context=r[state+6]*256+r[state+7],base=context-SDK_SDK_CONTEXT;
 unsigned cx=r[base+SDK_MAP+4],cy=r[base+SDK_MAP+5];
 unsigned char *fb=physical+0x100000;
 for(unsigned y=0;y<200;y++)for(unsigned x=0;x<320;x++){
  unsigned value=x>=40&&x<72&&y>=48&&y<72?(cy+(y-48)/8)*8+cx+(x-40)/8:0;
  if(fb[y*320+x]!=value){fprintf(stderr,"SDK phase%u camera%u,%u x%u y%u got%u expected%u\n",r[base+SDK_PHASE],cx,cy,x,y,fb[y*320+x],value);require(0,"four-direction scrolling window");}
 }
 sdk_frames++;
}
#ifndef GAME_APP_MAIN
#define GAME_APP_MAIN main
#endif
int GAME_APP_MAIN(int argc,char**argv){
 if(argc!=4)return 2;model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t size;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&size);require(size==ROM_BYTES+512,"ROM bundle");memcpy(config,rom,HEADER_BYTES);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);image=load(argv[1],&image_size);committed=1;
 MC6800Init();MC6800Reset();until(60000000);key(0x1c);key(0x1c);prompt_wait();r=MC6800GetCpuRam();state=r[0xefcc]*256+r[0xefcd];pcb=r[0xec00]*256+r[0xec01];sp_before=SP;
 for(unsigned k=0;k<8192;k++)pal[k]=saved_pal[k]=(k*11+7)&63;for(unsigned k=0;k<14;k++)ay[k]=saved_ay[k]=k&15;
 front=4;old_irq=r[0xefc8]*256+r[0xefc9];old_page=r[0xedf2]>>4;native_step_hook=game_observe;flip_hook=game_frame;
 type_game();
 if(!cpu_hd){prompt_wait();require(contains("needs HD6303"),"game refuses MC6800");command("dir c:");puts("PASS ARKANOID MC6800 refusal and DOS");return 0;}
 wait_frames(4);require(raw_capture,"game holds exclusive keyboard capture");require(!r[app+GAME_LAUNCHED]&&r[app+GAME_LIVES]==3&&r[app+GAME_REMAINING]==40&&enabled,"initial game waits for launch and plays music");
 // No native key events are sent: movement must parse raw make/break, without
 // debounce or typematic. Every visible frame advances exactly four pixels.
 unsigned p=at(GAME_PADDLE);
 raw_key(1,0,0x6b);for(unsigned k=0;k<7;k++){wait_frames(frames+1);require(at(GAME_PADDLE)==p-4*(k+1),"continuous left, four pixels every frame");}
 raw_key(1,1,0x6b);wait_frames(frames+3);require(at(GAME_PADDLE)==p-28,"release stops movement immediately");
 raw_key(1,0,0x74);for(unsigned k=0;k<7;k++){wait_frames(frames+1);require(at(GAME_PADDLE)==p-28+4*(k+1),"continuous right, four pixels every frame");}
 raw_key(1,0,0x6b);wait_frames(frames+5);require(at(GAME_PADDLE)==p,"opposite directions cancel");
 raw_key(1,1,0x74);wait_frames(frames+40);require(!at(GAME_PADDLE),"left edge clamps");
 raw_key(1,1,0x6b);raw_key(1,0,0x74);wait_frames(frames+70);require(at(GAME_PADDLE)==272,"right edge clamps");
 raw_key(1,1,0x74);wait_frames(frames+2);word_at(app+GAME_PADDLE,136);
 raw_key(0,0,0x29);raw_key(0,1,0x29);wait_frames(frames+10);require(r[app+GAME_LAUNCHED]&&!r[app+GAME_PAUSED]&&at(GAME_BALL_Y)<182,"SPACE tap between frames launches once");
 wait_frames(frames+2);
 raw_key(0,0,0x29);until(virtual_cycles+60000);require(r[app+GAME_PAUSED]&&!enabled,"SPACE press pauses");
 unsigned frozen=frames,x=at(GAME_BALL_X),y=at(GAME_BALL_Y),pp=at(GAME_PADDLE);
 raw_key(0,0,0x29);raw_key(0,0,0x1c);until(virtual_cycles+120000);require(r[app+GAME_PAUSED]&&frames==frozen&&at(GAME_BALL_X)==x&&at(GAME_BALL_Y)==y&&at(GAME_PADDLE)==pp&&!enabled,"held SPACE and direction do not unpause or move");
 raw_key(0,1,0x29);raw_key(0,1,0x1c);until(virtual_cycles+30000);require(r[app+GAME_PAUSED],"SPACE release retains pause");
 raw_key(0,0,0x29);wait_frames(frozen+3);require(!r[app+GAME_PAUSED]&&enabled,"second physical SPACE press resumes");
 raw_key(0,1,0x29);
 // Raw aliases must preserve the other physical key on break. Pause/Print
 // Screen sequences must not leave SHIFT/CTRL logically down.
 raw_key(0,0,0x1c);raw_key(1,0,0x6b);raw_key(0,1,0x1c);wait_frames(frames+1);
 require(r[app+GAME_SDK_HELD]==1,"arrow survives alias release");raw_key(1,1,0x6b);
 raw_key(0,0,0x12);raw_key(0,0,0x59);raw_key(0,1,0x12);
 raw_key(0,0,0x14);raw_key(1,0,0x14);raw_key(0,1,0x14);wait_frames(frames+1);
 require(r[app+GAME_SDK_HELD]==192,"right modifier survives left release");
 raw_key(0,1,0x59);raw_key(1,1,0x14);
 const unsigned char pause[]={0xe1,0x14,0x77,0xe1,0xf0,0x14,0xf0,0x77};
 for(unsigned k=0;k<sizeof pause;k++)raw_byte(pause[k]);raw_key(1,0,0x12);raw_key(1,1,0x12);wait_frames(frames+1);
 require(!r[app+GAME_SDK_HELD],"Pause/fake SHIFT ignored and modifiers release");
 // Actual moving paddle impacts: same hit point, opposite/aligned motion.
 // Expected outcomes are explicit gameplay cases, not an implementation copy.
 const struct {int incoming,move,offset,vx,vy;} bounce_cases[]={
  { 2, 0, 0, 2,-2},{ 2,-4, 0, 0,-3},{ 2, 4, 0, 3,-1},
  {-2, 0, 0,-2,-2},{-2, 4, 0, 0,-3},{-2,-4, 0,-3,-1},
  { 2, 0,-24,-1,-3},{ 2, 0,24,3,-1},
  {-2, 0,-24,-3,-1},{-2, 0,24,1,-3},
  { 2,-4,-24,-3,-1},{-2,4,24,3,-1},
  { 0, 0, 0, 0,-3},{ 3,-4,0,1,-3},{-3,4,0,-1,-3}
 };
 for(unsigned k=0;k<sizeof bounce_cases/sizeof bounce_cases[0];k++){
  raw_key(1,1,0x6b);raw_key(1,1,0x74);
  const int move=bounce_cases[k].move;
  if(move)raw_key(1,0,move<0?0x6b:0x74);
  word_at(app+GAME_PADDLE,136);
  word_at(app+GAME_BALL_X,136+move+20+bounce_cases[k].offset-bounce_cases[k].incoming);
  word_at(app+GAME_BALL_Y,180);word_at(app+GAME_VELOCITY_X,bounce_cases[k].incoming);word_at(app+GAME_VELOCITY_Y,2);
  wait_frames(frames+1);
  require((int16_t)at(GAME_VELOCITY_X)==bounce_cases[k].vx&&(int16_t)at(GAME_VELOCITY_Y)==bounce_cases[k].vy,"impact point plus stationary/opposing/aligned paddle changes angle");
  require(at(GAME_BALL_Y)==182&&(int16_t)at(GAME_PADDLE_DELTA)==move,"rebound snaps to top, spin uses actual displacement");
 }
 // A held direction at a clamped edge is a stationary paddle, not fake spin.
 raw_key(1,1,0x6b);raw_key(1,1,0x74);raw_key(1,0,0x6b);
 word_at(app+GAME_PADDLE,0);word_at(app+GAME_BALL_X,18);word_at(app+GAME_BALL_Y,180);word_at(app+GAME_VELOCITY_X,2);word_at(app+GAME_VELOCITY_Y,2);wait_frames(frames+1);
 require(!at(GAME_PADDLE_DELTA)&&at(GAME_VELOCITY_X)==2&&(int16_t)at(GAME_VELOCITY_Y)==-2,"clamped paddle has zero spin");
 raw_key(1,1,0x6b);raw_key(1,0,0x74);
 word_at(app+GAME_PADDLE,272);word_at(app+GAME_BALL_X,294);word_at(app+GAME_BALL_Y,180);word_at(app+GAME_VELOCITY_X,-2);word_at(app+GAME_VELOCITY_Y,2);wait_frames(frames+1);
 require(!at(GAME_PADDLE_DELTA)&&(int16_t)at(GAME_VELOCITY_X)==-2&&(int16_t)at(GAME_VELOCITY_Y)==-2,"right clamp also has zero spin");
 raw_key(1,1,0x74);
 for(int magnitude=1;magnitude<=3;magnitude+=2){
  word_at(app+GAME_BALL_X,200);word_at(app+GAME_BALL_Y,20);word_at(app+GAME_VELOCITY_X,1);word_at(app+GAME_VELOCITY_Y,-magnitude);wait_frames(frames+1);
  require(at(GAME_BALL_Y)==20&&at(GAME_VELOCITY_Y)==(unsigned)magnitude,"ceiling preserves rebound speed/angle");
 }
 // Select a controlled trajectory; check collisions against the known grid.
 word_at(app+GAME_BALL_X,62);word_at(app+GAME_BALL_Y,38);word_at(app+GAME_VELOCITY_X,2);word_at(app+GAME_VELOCITY_Y,2);
 wait_frames(frames+4);require(!r[app+GAME_BRICKS+1]&&r[app+GAME_REMAINING]==39&&at(GAME_SCORE)==10,"brick collision and score");
 const unsigned next_bricks[]={0,2,3,4,5,6,7,8,9};
 for(unsigned k=0;k<sizeof next_bricks/sizeof next_bricks[0];k++){
  unsigned id=next_bricks[k];word_at(app+GAME_BALL_X,30+(id%8)*32);word_at(app+GAME_BALL_Y,38+(id/8)*8);
  word_at(app+GAME_VELOCITY_X,2);word_at(app+GAME_VELOCITY_Y,2);wait_frames(frames+1);
  require(at(GAME_SCORE)==20+10*k&&r[app+GAME_REMAINING]==38-k,"each hit updates cached decimal digits");
 }
 require(at(GAME_SCORE)==100,"cached HUD handles 090 to 100 carry and unchanged zero");
 word_at(app+GAME_BALL_X,2);word_at(app+GAME_BALL_Y,190);word_at(app+GAME_PADDLE,272);word_at(app+GAME_VELOCITY_Y,2);
 wait_frames(frames+3);require(r[app+GAME_LIVES]==2&&!r[app+GAME_LAUNCHED],"miss loses one life and waits for launch");
 raw_key(0,0,0x76);prompt_wait();raw_key(0,1,0x76);restored();require(SP==sp_before&&contains("returned to UniDOS"),"physical ESC restores DOS");
 app=frames=0;type_game();wait_frames(3);require(r[app+GAME_LIVES]==3&&r[app+GAME_REMAINING]==40&&!at(GAME_SCORE),"second run starts fresh");raw_key(0,0,0x76);prompt_wait();raw_key(0,1,0x76);restored();
 keyboard_raw_missing=1;app=frames=0;type_game();prompt_wait();keyboard_raw_missing=0;restored();require(!frames&&contains("needs raw PS/2 capture FPGA"),"older FPGA gets a clear refusal with context cleanup");
 keyboard_capture_missing=1;app=frames=0;type_game();prompt_wait();keyboard_capture_missing=0;restored();require(!frames&&contains("needs raw PS/2 capture FPGA"),"old raw FIFO without capture is refused");
 app=frames=0;type_game();wait_frames(3);for(unsigned k=0;k<65;k++)raw_byte(0x1c);prompt_wait();restored();require(!raw_count&&!raw_overflow,"raw overflow flushes safely and restores DOS");require(contains("OP=FE STATUS=02 RAW=40"),"failure identifies raw overflow and capture before cleanup");
 native_step_hook=observe;flip_hook=sdk_frame;command("b:sdktest");restored();require(sdk_frames==8&&contains("PASS: SDK tiles and scrolling"),"SDK map, all scroll directions, boundary no-op and invalid arguments");
 command("dir a:");command("dir b:");command("dir c:");printf("PASS ARKANOID %s: SDK/tile atlas, full-frame oracle, continuous held/released keys, edges/opposites/SPACE, moving-paddle angles/speed/clamps, collisions/lives, music/effects, ESC/relaunch/DIR (%u jobs)\n",argv[2],jobs);return 0;
}
