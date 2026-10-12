// Actual PGM loader, SDK tile atlas and game with independent full-frame oracle.
#define GAMEBIOS_MAIN unused_gamebios_main
#include "test_gamebios.c"
#include "../build/game/arkanoid_labels.h"
#include "../build/game/sdktest_labels.h"
static unsigned app,frames,hits,irq_started,max_irq,ui_state;
static unsigned at(unsigned offset){return r[app+offset]*256+r[app+offset+1];}
static void game_frame(unsigned dp){
 if(!gfx[0]||dp>1||!app||r[app+GAME_HS_UI_ACTIVE]||!r[app+GAME_VALID+dp])return;
 unsigned x=at(GAME_BALL_X),y=at(GAME_BALL_Y),p=at(GAME_PADDLE);
 require(x+8<=320&&y+8<=200&&p<=272,"game sprite coordinates");
 unsigned char *bg=physical+0x130000,*fb=physical+0x100000+dp*65536;
 for(unsigned row=0;row<200;row++)for(unsigned col=0;col<320;col++){
  unsigned expected=bg[row*320+col];
  if(r[app+GAME_BONUS_ACTIVE]&&col>=at(GAME_BONUS_X)&&col<at(GAME_BONUS_X)+8&&row>=at(GAME_BONUS_Y)&&row<at(GAME_BONUS_Y)+8)expected=r[app+GAME_BONUS_ACTIVE]==2?2:4;
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
 char hud[48];snprintf(hud,sizeof hud,"PYLDIN  ARKANOID  SCORE %05u LIFE: %u",at(GAME_SCORE),r[app+GAME_LIVES]);
 for(unsigned dy=0;dy<8;dy++)for(unsigned col=0;col<320;col++){
  unsigned ch=col/8,bit=col&7,expected=0;
  if(ch>=1&&ch<=strlen(hud))expected=(physical[0x10000+6144+(unsigned char)hud[ch-1]*8+dy]&(128>>bit))?7:0;
  if(bg[(8+dy)*320+col]!=expected){fprintf(stderr,"HUD frame%u score%u life%u x%u y%u got%u expected%u\n",frames,at(GAME_SCORE),r[app+GAME_LIVES],col,dy,bg[(8+dy)*320+col],expected);require(0,"HUD score/life and static labels match native font");}
 }
}
#ifndef GAME_UI_TIMEOUT
#define GAME_UI_TIMEOUT 200000000
#endif
static void wait_ui(unsigned target){uint64_t d=virtual_cycles+GAME_UI_TIMEOUT;while(ui_state!=target&&virtual_cycles<d)until(virtual_cycles+1009);require(ui_state==target,"graphical score/name screen reached");}
static void finish_ui(void){ui_state=0;raw_key(0,0,0x76);raw_key(0,1,0x76);uint64_t d=virtual_cycles+15000000;while(!ui_state&&virtual_cycles<d)until(virtual_cycles+1009);require(ui_state,"game returns to record UI");if(ui_state==2){ui_state=0;key(0x1c);wait_ui(1);}ui_state=0;key(0x01);prompt_wait();}
static void type_game(void){key(0x30);KBDModKeyDown(2);key(0x27);KBDModKeyUp(2);
 const unsigned scans[]={0x1e,0x13,0x25,0x1e,0x31,0x18,0x17,0x20};for(unsigned k=0;k<8;k++)key(scans[k]);ui_state=0;key(0x1c);if(cpu_hd){wait_ui(1);ui_state=0;key(0x39);if(keyboard_raw_missing||keyboard_capture_missing){uint64_t d=virtual_cycles+200000000;while((PC!=(model_a?0xf397:0xf39d)||!contains("needs raw PS/2 capture FPGA"))&&virtual_cycles<d)until(virtual_cycles+1009);}}}
static void wait_frames(unsigned n){uint64_t deadline=virtual_cycles+200000000;while(frames<n&&virtual_cycles<deadline)until(virtual_cycles+1000);if(frames<n)fprintf(stderr,"app=%04x PCoff=%04x frames=%u ui=%u mus=%u lease=%u kind=%u state=%04x\n",app,PC-app,frames,ui_state,r[app+GAME_MUS_LOADED],r[app+GAME_MUS_MEMORY_LEASE+2],r[app+GAME_MUS_KIND],state);require(frames>=n,"game renders frames");}
static void game_observe(void){
 observe();
 if(app&&PC==app+GAME_HS_WAIT)ui_state=1;if(app&&PC==app+GAME_HS_NAME_KEY)ui_state=2;
 if(!app&&PC<0xc000&&r[PC]==0x3f&&r[PC+1]==0xe6&&A==1&&X>=GAME_SDK_CONTEXT+0x100&&X<0xbe00&&r[X]==(8608>>8)&&r[X+1]==(8608&255)&&r[X+2]==1)app=X-GAME_SDK_CONTEXT;
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
 // The previous process may have left disabled video with a sticky error.
 // The SDK also has to recover on the installed older GAMEBIOS ROM.
 gfx_failed=1;type_game();
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
 // Impact position selects a continuous angle; spin can reverse centre hits.
 // Independent properties check variety, symmetry and nearly constant speed.
 int stationary[45];unsigned distinct=0;
 for(int offset=-22;offset<=22;offset++){
  raw_key(1,1,0x6b);raw_key(1,1,0x74);word_at(app+GAME_PADDLE,136);
  word_at(app+GAME_BALL_X,156+offset);word_at(app+GAME_BALL_Y,180);
  word_at(app+GAME_VELOCITY_X,0);word_at(app+GAME_VELOCITY_Y,512);
  r[app+GAME_BALL_FRACTION_X]=r[app+GAME_BALL_FRACTION_Y]=0;
  wait_frames(frames+1);int vx=(int16_t)at(GAME_VELOCITY_X),vy=(int16_t)at(GAME_VELOCITY_Y);
  stationary[offset+22]=vx;
  if(offset==-22||vx!=stationary[offset+21])distinct++;
  require(vy<=-300&&vx*vx+vy*vy>575000&&vx*vx+vy*vy<605000,"rebound stays upward with near-constant speed");
  require(at(GAME_BALL_Y)==182,"paddle crossing snaps ball above its surface");
 }
 require(distinct>=40,"adjacent impact points produce many distinct angles");
 for(unsigned k=0;k<22;k++)require(stationary[k]==-stationary[44-k],"stationary impact angles mirror around paddle centre");
 const struct {int incoming,move,offset,vx;} bounce_cases[]={
  {512,0,0,64},{512,-4,0,-128},{512,4,0,256},
  {-512,0,0,-64},{-512,4,0,128},{-512,-4,0,-256},
  {512,0,-24,-512},{512,0,24,640},
  {-512,0,-24,-640},{-512,0,24,512},
  {512,-4,-24,-704},{-512,4,24,704}
 };
 for(unsigned k=0;k<sizeof bounce_cases/sizeof bounce_cases[0];k++){
  raw_key(1,1,0x6b);raw_key(1,1,0x74);int move=bounce_cases[k].move;
  if(move)raw_key(1,0,move<0?0x6b:0x74);word_at(app+GAME_PADDLE,136);
  word_at(app+GAME_BALL_X,156+move+bounce_cases[k].offset-bounce_cases[k].incoming/256);
  word_at(app+GAME_BALL_Y,180);word_at(app+GAME_VELOCITY_X,bounce_cases[k].incoming);word_at(app+GAME_VELOCITY_Y,512);
  r[app+GAME_BALL_FRACTION_X]=r[app+GAME_BALL_FRACTION_Y]=0;wait_frames(frames+1);
  require((int16_t)at(GAME_VELOCITY_X)==bounce_cases[k].vx,"stationary/opposing/aligned motion changes the same impact");
  require((int16_t)at(GAME_PADDLE_DELTA)==move,"spin uses actual paddle displacement");
 }
 raw_key(1,1,0x6b);raw_key(1,1,0x74);raw_key(1,0,0x6b);
 word_at(app+GAME_PADDLE,0);word_at(app+GAME_BALL_X,18);word_at(app+GAME_BALL_Y,180);word_at(app+GAME_VELOCITY_X,512);word_at(app+GAME_VELOCITY_Y,512);
 r[app+GAME_BALL_FRACTION_X]=r[app+GAME_BALL_FRACTION_Y]=0;wait_frames(frames+1);
 require(!at(GAME_PADDLE_DELTA)&&at(GAME_VELOCITY_X)==64,"clamped paddle has zero spin");
 raw_key(1,1,0x6b);raw_key(1,0,0x74);
 word_at(app+GAME_PADDLE,272);word_at(app+GAME_BALL_X,294);word_at(app+GAME_BALL_Y,180);word_at(app+GAME_VELOCITY_X,-512);word_at(app+GAME_VELOCITY_Y,512);
 r[app+GAME_BALL_FRACTION_X]=r[app+GAME_BALL_FRACTION_Y]=0;wait_frames(frames+1);
 require(!at(GAME_PADDLE_DELTA)&&(int16_t)at(GAME_VELOCITY_X)==-64,"right clamp also has zero spin");raw_key(1,1,0x74);
 for(int magnitude=256;magnitude<=768;magnitude+=512){
  word_at(app+GAME_BALL_X,200);word_at(app+GAME_BALL_Y,20);word_at(app+GAME_VELOCITY_X,256);word_at(app+GAME_VELOCITY_Y,-magnitude);
  r[app+GAME_BALL_FRACTION_X]=r[app+GAME_BALL_FRACTION_Y]=0;wait_frames(frames+1);
  require(at(GAME_BALL_Y)==20&&at(GAME_VELOCITY_Y)==(unsigned)magnitude,"ceiling preserves fractional speed/angle");
 }
 word_at(app+GAME_BALL_X,140);word_at(app+GAME_BALL_Y,120);word_at(app+GAME_VELOCITY_X,384);word_at(app+GAME_VELOCITY_Y,0);
 r[app+GAME_BALL_FRACTION_X]=r[app+GAME_BALL_FRACTION_Y]=0;wait_frames(frames+5);
 require(at(GAME_BALL_X)==147&&r[app+GAME_BALL_FRACTION_X]==128,"fractional velocity accumulates without rounding drift");
 // A ball already below the paddle cannot be caught by a horizontal overlap.
 word_at(app+GAME_PADDLE,136);word_at(app+GAME_BALL_X,156);word_at(app+GAME_BALL_Y,185);word_at(app+GAME_VELOCITY_X,0);word_at(app+GAME_VELOCITY_Y,256);
 wait_frames(frames+1);require(at(GAME_BALL_Y)==186&&at(GAME_VELOCITY_Y)==256,"no rebound from underneath paddle");
 // Side and top entries reflect different axes, then exercise decimal carry.
 word_at(app+GAME_BALL_X,58);word_at(app+GAME_BALL_Y,40);word_at(app+GAME_VELOCITY_X,512);word_at(app+GAME_VELOCITY_Y,0);
 r[app+GAME_BALL_FRACTION_X]=r[app+GAME_BALL_FRACTION_Y]=0;wait_frames(frames+1);
 require(!r[app+GAME_BRICKS+1]&&at(GAME_SCORE)==10&&(int16_t)at(GAME_VELOCITY_X)==-512&&!at(GAME_VELOCITY_Y),"brick side reflects horizontal velocity");
 word_at(app+GAME_BALL_X,40);word_at(app+GAME_BALL_Y,33);word_at(app+GAME_VELOCITY_X,0);word_at(app+GAME_VELOCITY_Y,768);
 wait_frames(frames+1);require(!r[app+GAME_BRICKS]&&at(GAME_SCORE)==20&&(int16_t)at(GAME_VELOCITY_Y)==-768,"brick top reflects vertical velocity");
 const unsigned next_bricks[]={2,3,4,5,6,7,8,9};
 for(unsigned k=0;k<sizeof next_bricks/sizeof next_bricks[0];k++){
  unsigned id=next_bricks[k];word_at(app+GAME_BALL_X,30+(id%8)*32);word_at(app+GAME_BALL_Y,38+(id/8)*8);
  word_at(app+GAME_VELOCITY_X,512);word_at(app+GAME_VELOCITY_Y,512);wait_frames(frames+1);
  require(at(GAME_SCORE)==30+10*k&&r[app+GAME_REMAINING]==37-k,"each hit updates cached decimal digits");
 }
 require(at(GAME_SCORE)==100,"cached HUD handles 090 to 100 carry and unchanged zero");
 word_at(app+GAME_BALL_X,2);word_at(app+GAME_BALL_Y,190);word_at(app+GAME_PADDLE,272);word_at(app+GAME_VELOCITY_Y,512);
 wait_frames(frames+3);require(r[app+GAME_LIVES]==2&&!r[app+GAME_LAUNCHED],"miss loses one life and waits for launch");
 // At higher/fractional downward speed a miss can land at y=194. The old
 // frame recorded that off-screen 8x8 sprite; restoring it two frames later
 // sent COPY beyond the 64000-byte framebuffer and aborted the game.
 const unsigned miss_speed[]={768,665},miss_fraction[]={0,128};
 for(unsigned k=0;k<2;k++){
  r[app+GAME_LIVES]=3;r[app+GAME_LAUNCHED]=1;word_at(app+GAME_BALL_X,2);word_at(app+GAME_BALL_Y,191);
  word_at(app+GAME_PADDLE,272);word_at(app+GAME_VELOCITY_X,0);
  word_at(app+GAME_VELOCITY_Y,miss_speed[k]);r[app+GAME_BALL_FRACTION_Y]=miss_fraction[k];
  wait_frames(frames+4);
  require(r[app+GAME_LIVES]==2&&!r[app+GAME_LAUNCHED],"fast/fractional miss and final life survive both buffer restores");
  require(at(GAME_BALL_Y)==182&&at(GAME_BALL_X)==292,"miss returns ball to paddle before drawing/history");
 }
 finish_ui();restored();require(SP==sp_before&&contains("returned to UniDOS"),"physical ESC restores DOS");
 app=frames=0;type_game();wait_frames(3);require(r[app+GAME_LIVES]==3&&r[app+GAME_REMAINING]==40&&!at(GAME_SCORE),"second run starts fresh");finish_ui();restored();
 keyboard_raw_missing=1;app=frames=0;type_game();prompt_wait();keyboard_raw_missing=0;restored();require(!frames&&contains("needs raw PS/2 capture FPGA"),"older FPGA gets a clear refusal with context cleanup");
 keyboard_capture_missing=1;app=frames=0;type_game();prompt_wait();keyboard_capture_missing=0;restored();require(!frames&&contains("needs raw PS/2 capture FPGA"),"old raw FIFO without capture is refused");
 app=frames=0;type_game();wait_frames(3);for(unsigned k=0;k<65;k++)raw_byte(0x1c);prompt_wait();restored();require(!raw_count&&!raw_overflow,"raw overflow flushes safely and restores DOS");require(contains("OP=FE STATUS=02 RAW=40"),"failure identifies raw overflow and capture before cleanup");
 native_step_hook=observe;flip_hook=sdk_frame;command("b:sdktest");restored();require(sdk_frames==8&&contains("PASS: SDK tiles and scrolling"),"SDK map, all scroll directions, boundary no-op and invalid arguments");
 command("dir a:");command("dir b:");command("dir c:");printf("PASS ARKANOID %s: SDK/tile atlas, full-frame oracle, continuous held/released keys, edges/opposites/SPACE, moving-paddle angles/speed/clamps, collisions/lives, music/effects, ESC/relaunch/DIR (%u jobs)\n",argv[2],jobs);return 0;
}
