// Native UniDOS PGM loading, gameplay and persistent scores on both machines.
#ifdef ARCADE_HG
#define _POSIX_C_SOURCE 200809L
#define _DARWIN_C_SOURCE
#include <stdint.h>
#include <dirent.h>
#include <unistd.h>
#include "../host/hg/hg.h"
static int hg_transport_read(uint16_t a,unsigned char*out);
static int hg_transport_write(uint16_t a,unsigned char d);
#endif
#define GAME_APP_MAIN unused_app_main
#include "test_game_app.c"
#include "../build/game/xonix_labels.h"
#ifdef ARCADE_HG
#include "hg_transport.h"
static HgVolume arcade_volume;
static int arcade_host_write(unsigned block,const uint8_t*data,unsigned length){return hg_volume_write(&arcade_volume,block,data,length);}
#endif
static unsigned xo,xf,which,app_drive=1;
static unsigned graphics_live,ui_frames;
static uint64_t xo_start_cycle,xo_first_cycle;static unsigned xo_start_under;
static unsigned off(unsigned ar,unsigned xr){return app+(which?xr:ar);}
static unsigned read16(unsigned addr){return r[addr]*256+r[addr+1];}
static void arcade_observe(void){
 observe();
 unsigned context_offset=which?XO_SDK_CONTEXT:GAME_SDK_CONTEXT;
 // CLOSE retains an old context pointer. Discover this PGM from its own
 // validated OPEN call, including when HG relocates it to another address.
 if(!app&&PC<0xc000&&r[PC]==0x3f&&r[PC+1]==0xe6&&A==1&&X>=context_offset+0x100&&X<0xbe00&&read16(X)==416&&r[X+2]==2)app=X-context_offset;
 if(app&&PC==off(GAME_HS_PANEL_DONE,XO_HS_PANEL_DONE))graphics_live=1;
 if(app&&PC==off(GAME_SDK_CLOSE,XO_SDK_CLOSE))graphics_live=0;
 if(graphics_live){
  require(gfx[0]!=0,"graphics remains enabled from intro through game/records/restart");
  if(PC<0xc000&&r[PC]==0x3f)require(r[PC+1]!=0x22&&r[PC+1]!=0x23,"no text BIOS output while game graphics is live");
 }
 if(app&&PC==off(GAME_HS_WAIT,XO_HS_WAIT))ui_state=1;
 if(app&&PC==off(GAME_HS_NAME_KEY,XO_HS_NAME_KEY))ui_state=2;

}
static void ui_text(unsigned char*fb,unsigned col,unsigned row,const char*s,unsigned fg,unsigned bg){
 for(;*s;s++,col++)for(unsigned y=0;y<8;y++)for(unsigned x=0;x<8;x++){
  require(col<40&&row<25,"UI text fits framebuffer");
  fb[(row*8+y)*320+col*8+x]=(physical[0x10000+6144+(unsigned char)*s*8+y]&(128>>x))?fg:bg;
 }
}
static void ui_center(unsigned char*fb,unsigned row,const char*s,unsigned fg,unsigned bg){ui_text(fb,(40-strlen(s))/2,row,s,fg,bg);}
static void ui_preview(const unsigned char*fb){
 const char*dir=getenv("P601_UI_CAPTURE");if(!dir)return;
 char path[512];snprintf(path,sizeof path,"%s/%s-%s.ppm",dir,which?"xonix":"arkanoid",r[off(GAME_HS_UI_ACTIVE,XO_HS_UI_ACTIVE)]==2?"name":"records");
 FILE*f=fopen(path,"wb");require(f!=NULL,"create graphical UI preview");fprintf(f,"P6\n320 200\n255\n");
 const unsigned char colours[][3]={{8,12,24},{20,30,53},{67,220,250},{239,246,255},{255,195,62},{124,145,183}};
 for(unsigned k=0;k<64000;k++){require(fb[k]>=240&&fb[k]<=245,"UI uses its own palette");require(fwrite(colours[fb[k]-240],1,3,f)==3,"write UI preview pixels");}
 require(!fclose(f),"close UI preview");
}
static void check_ui(void){
 require(gfx[0]==1&&front==5&&!raw_capture,"score/name UI uses indexed graphics and character input");
 unsigned char expected[64000];memset(expected,240,sizeof expected);
 for(unsigned y=8;y<192;y++)memset(expected+y*320+16,y<40?242:241,288);
 memset(expected+48*320+32,245,256);
 ui_center(expected,2,which?"PYLDIN XONIX":"PYLDIN ARKANOID",240,242);
 char text[40];
 if(r[off(GAME_HS_UI_ACTIVE,XO_HS_UI_ACTIVE)]==2){
  ui_center(expected,7,"NEW HIGH SCORE!",244,241);
  snprintf(text,sizeof text,"%05u",read16(off(GAME_HS_SCORE,XO_HS_SCORE)));ui_center(expected,10,text,244,241);
  memset(text,' ',13);unsigned n=r[off(GAME_HS_NAME_LENGTH,XO_HS_NAME_LENGTH)];require(n<=12,"graphical name bound");memcpy(text,r+off(GAME_HS_PLAYER,XO_HS_PLAYER),n);text[n]='_';text[13]=0;
  ui_text(expected,13,13,text,243,241);
  ui_center(expected,16,"NAME: UP TO 12 CHARACTERS",245,241);
  ui_center(expected,18,"BACKSPACE: EDIT   ENTER: SAVE",245,241);
 }else{
  ui_center(expected,4,"HIGH SCORES",244,241);ui_text(expected,6,6," #  PLAYER            SCORE",245,241);
  unsigned table=off(GAME_HS_TABLE,XO_HS_TABLE);
  for(unsigned k=0;k<10;k++){
   unsigned entry=table+8+15*k,fg=k?243:244;
   snprintf(text,sizeof text,"%2u",k+1);ui_text(expected,6,7+k,text,fg,241);
   ui_text(expected,10,7+k,r[entry+2]?(char*)r+entry+2:"---",fg,241);
   snprintf(text,sizeof text,"%05u",read16(entry));ui_text(expected,28,7+k,text,fg,241);
  }
  ui_text(expected,8,18,"LAST SCORE:",243,241);
  snprintf(text,sizeof text,"%05u",read16(off(GAME_HS_SCORE,XO_HS_SCORE)));ui_text(expected,23,18,text,243,241);
  unsigned status=r[off(GAME_HS_UI_STATUS,XO_HS_UI_STATUS)];
  if(status)ui_center(expected,19,status==1?"HIGH SCORE SAVED":"DISK SAVE FAILED - SCORE IN MEMORY",245,241);
  if(!r[off(GAME_MUS_LOADED,XO_MUS_LOADED)])ui_center(expected,20,"MUSIC UNAVAILABLE",245,241);
  ui_center(expected,21,"SPACE / ENTER: PLAY",242,241);ui_center(expected,22,"ESC: RETURN TO UNIDOS",242,241);
 }
 const unsigned char*actual=physical+0x150000;
 for(unsigned k=0;k<sizeof expected;k++)if(actual[k]!=expected[k]){fprintf(stderr,"UI game%u state%u x%u y%u actual%u expected%u\n",which,r[off(GAME_HS_UI_ACTIVE,XO_HS_UI_ACTIVE)],k%320,k/320,actual[k],expected[k]);require(0,"graphical UI matches independent full framebuffer/font oracle");}
 ui_preview(actual);
 ui_frames++;
}
static void arcade_flip(unsigned dp){
 if(app&&dp==5){
  if(which&&r[app+XO_HS_UI_ACTIVE]==3){require(gfx[0]==1,"loading card remains graphical");return;}
  check_ui();return;
 }
 if(app&&r[off(GAME_HS_UI_ACTIVE,XO_HS_UI_ACTIVE)])return;
 if(!app||dp>1||!gfx[0])return;
 if(!which){game_frame(dp);return;}
 if(gfx[0]!=15)return; // Initial VBL flip precedes enabling layered HAM8.
 unsigned char*bg=physical+0x130000,*fb=physical+0x100000+dp*65536;
 // Exact byte oracle: revealed cells retain the original HAM8 stream.
 for(unsigned row=0;row<200;row++)for(unsigned col=0;col<320;col++){
  unsigned value=bg[row*320+col];
  unsigned px=r[app+XO_XO_PLAYER_X]*8,py=r[app+XO_XO_PLAYER_Y]*8;
  if(col>=px&&col<px+8&&row>=py&&row<py+8)value=63;
  for(unsigned k=0;k<2;k++){
   unsigned ex=r[app+XO_XO_ENEMY+2*k]*8,ey=r[app+XO_XO_ENEMY+2*k+1]*8;
   if(col>=ex&&col<ex+8&&row>=ey&&row<ey+8)value=48;
  }
  if(fb[row*320+col]!=value){fprintf(stderr,"XO f%u p%u x%u y%u got%u expected%u\n",xf,dp,col,row,fb[row*320+col],value);require(0,"Xonix frame matches terrain/actors without trails");}
 }
 xf++;
 if(xo_start_cycle&&!xo_first_cycle)xo_first_cycle=virtual_cycles;
}
static void type_app(const char*name){
 const char*letters="abcdefghijklmnopqrstuvwxyz";const unsigned scans[]={0x1e,0x30,0x2e,0x20,0x12,0x21,0x22,0x23,0x17,0x24,0x25,0x26,0x32,0x31,0x18,0x19,0x10,0x13,0x1f,0x14,0x16,0x2f,0x11,0x2d,0x15,0x2c};
 key(scans[app_drive]);KBDModKeyDown(2);key(0x27);KBDModKeyUp(2);
 for(;*name;name++){const char*p=strchr(letters,*name);require(p!=NULL||*name=='\\',"valid app name");key(p?scans[p-letters]:0x2b);}
 ui_state=0;key(0x1c);wait_ui(1);check_ui();
}
static void music_oracle(void){
 size_t size;unsigned char*data=load(which?"build/games-next/LEDSTRM1.raw":"build/games-next/WARHAWK.raw",&size);
 unsigned lease=off(GAME_MUS_MEMORY_LEASE,XO_MUS_MEMORY_LEASE);require(r[lease+2]==(size+8191)/8192,"music owns exactly the required paged RAM banks");
 require(!r[off(GAME_ML_LEASE,XO_ML_LEASE)+2],"temporary LH5 scratch banks released before gameplay");
 for(unsigned k=0;k<size;k++){unsigned id=r[lease+3+k/8192];require(id<111&&physical[0x22000+id*8192+k%8192]==data[k],"complete native LH5 output matches independent 7z oracle");}free(data);
 if(which){data=load("build/games-next/LENA.raw",&size);require(size==64000&&!memcmp(data,physical+0x180000,size),"native IFF/ByteRun1 preserves every original HAM8 byte");require(gfx[0]==15,"Xonix uses lossless HAM8 background with palette overlays");free(data);}
}
static void play(void){ui_state=0;if(which){xo_start_under=read16(state+26);xo_start_cycle=virtual_cycles;xo_first_cycle=0;}key(0x39);uint64_t d=virtual_cycles+200000000;unsigned before=which?xf:frames;while((which?xf:frames)<before+4&&virtual_cycles<d)until(virtual_cycles+1009);require((which?xf:frames)>=before+4,"actual arcade PGM starts");require(raw_capture&&enabled&&r[off(GAME_MUS_LOADED,XO_MUS_LOADED)],"game holds raw input and decodes genuine LH5 music");if(which){printf("XONIX cached first frame: %llu us at 1 MHz model\n",(unsigned long long)(xo_first_cycle-xo_start_cycle));require(xo_first_cycle-xo_start_cycle<600000,"cached Xonix first frame below 600 ms at 1 MHz model");require(read16(state+26)==xo_start_under,"cached Xonix start adds no music underruns");xo_start_cycle=0;}music_oracle();}
static void step_frames(unsigned count){unsigned initial=which?xf:frames;uint64_t d=virtual_cycles+20000000;while((which?xf:frames)<initial+count&&virtual_cycles<d)until(virtual_cycles+1009);require((which?xf:frames)>=initial+count,"arcade frames continue");}
static void end_score(unsigned score,const char*name,unsigned char*table){
 if(ui_state!=2){word_at(off(GAME_SCORE,XO_XO_SCORE),score);ui_state=0;raw_key(0,0,0x76);raw_key(0,1,0x76);wait_ui(2);}check_ui();
 // Real key editing: AB<Backspace>C => AC. Twelve-character limit separately.
 key(0x1e);key(0x30);key(0x0e);key(0x2e);check_ui();ui_state=0;key(0x1c);wait_ui(1);check_ui();
 unsigned t=off(GAME_HS_TABLE,XO_HS_TABLE);require(read16(t+8)==score&&!strcmp((char*)r+t+10,name),"score and edited uppercase name ranked");memcpy(table,r+t,160);
 require(r[off(GAME_HS_UI_STATUS,XO_HS_UI_STATUS)]==1,"native DOS writes/verifies record and reports it in graphics");
 // SPACE restarts inside the same open context; no text-mode interlude.
 play();require(!read16(off(GAME_SCORE,XO_XO_SCORE))&&r[off(GAME_LIVES,XO_XO_LIVES)]==3,"graphical table starts a fresh round with reset score/lives");
 ui_state=0;raw_key(0,0,0x76);raw_key(0,1,0x76);wait_ui(1);check_ui();
 ui_state=0;key(0x01);prompt_wait();restored();require(SP==sp_before,"game returns with native stack balanced");
}
#ifndef ARCADE_MAIN
#define ARCADE_MAIN main
#endif
int ARCADE_MAIN(int argc,char**argv){
 if(argc!=3&&argc!=4)return 2;model_a=!strcmp(argv[2],"601a");cpu_hd=1;MC6800SetMachine(PYLDIN_MACHINE_HD6303);
 size_t sz;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&sz);require(sz==ROM_BYTES+512,"ROM bundle");memcpy(config,rom,HEADER_BYTES);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);image=load(argv[1],&image_size);committed=1;
#ifdef ARCADE_HG
 char host_dir[]="/tmp/p601-arcade-hg-XXXXXX";require(mkdtemp(host_dir)!=NULL,"create isolated C-host directory");
 const char*assets[]={"ARKANOID.PGM","XONIX.PGM","WARHAWK.YM","LEDSTRM1.YM","LENA.IFF"};
 for(unsigned k=0;k<5;k++){char src[256],dst[256];snprintf(src,sizeof src,"build/game/%s",assets[k]);snprintf(dst,sizeof dst,"%s/%s",host_dir,assets[k]);size_t n;unsigned char*d=load(src,&n);FILE*f=fopen(dst,"wb");require(f&&fwrite(d,1,n,f)==n&&!fclose(f),"prepare host asset");free(d);}
 require(!hg_volume_open(&arcade_volume,host_dir,true,HG_MAX_SECTORS,false),"open actual C host volume");host_image=arcade_volume.image;host_size=arcade_volume.size;host_write=arcade_host_write;hg_v2=1;
#endif
 MC6800Init();MC6800Reset();until(60000000);key(0x1c);key(0x1c);prompt_wait();r=MC6800GetCpuRam();state=r[0xefcc]*256+r[0xefcd];pcb=r[0xec00]*256+r[0xec01];sp_before=SP;
#ifdef ARCADE_HG
 app_drive=0;while(app_drive<8&&read16(0xeb03+app_drive*2))app_drive++;require(app_drive<8,"free HG drive");command("b:hg");require(read16(0xeb03+app_drive*2)&&hg_times,"native resident HG driver/time installed");sp_before=SP;
#endif
 for(unsigned k=0;k<8192;k++)pal[k]=saved_pal[k]=(k*11+7)&63;for(unsigned k=0;k<14;k++)ay[k]=saved_ay[k]=k&15;
 front=4;old_irq=read16(0xefc8);old_page=r[0xedf2]>>4;native_step_hook=arcade_observe;flip_hook=arcade_flip;
 unsigned char table[160];
 // Refuse an older FPGA before OPEN, music, bank allocation or video changes.
 which=1;gfx_revision=5;command("b:xonix");
 require(!app&&!gfx[0]&&!enabled&&!raw_capture&&!jobs&&front==4&&
         !memcmp(pal,saved_pal,8192)&&!memcmp(ay,saved_ay,14),
         "Xonix refuses FPGA v5 without altering context/video/audio");
 gfx_revision=6;which=0;
#ifndef ARCADE_HG
 // Test the optional-song path independently of durable score generations.
 if(argc==3){
 command("md b:silent");command("copy b:arkanoid.pgm b:silent\\arkanoid.pgm");
 which=0;app=frames=0;type_app("\\silent\\arkanoid");require(!r[app+GAME_MUS_LOADED],"no song is accepted as optional");
 ui_state=0;key(0x39);wait_frames(4);require(raw_capture,"silent game still captures held keys");
 ui_state=0;raw_key(0,0,0x76);raw_key(0,1,0x76);wait_ui(1);check_ui();ui_state=0;key(0x01);prompt_wait();restored();
 app=frames=0;
 }
#endif
 which=0;type_app("arkanoid");play();
#ifdef ARCADE_HG
 for(unsigned game=0;game<2;game++){
  if(game){which=1;app=xf=0;type_app("xonix");play();}
  end_score(game?23456:12345,"AC",table);require(!hg_volume_sync(&arcade_volume),"durable HG sync");host_image=arcade_volume.image;
  char path[256];snprintf(path,sizeof path,"%s/%s",host_dir,game?"XONSCORE.DAT":"ARKSCORE.DAT");size_t n;unsigned char*d=load(path,&n);require(n==160&&!memcmp(d,table,n),"native game records written byte-exact to C host folder");free(d);
  app=0;type_app(game?"xonix":"arkanoid");require(read16(off(GAME_HS_TABLE,XO_HS_TABLE)+8)==(game?23456:12345),"game reloads durable HG records");ui_state=0;key(0x01);prompt_wait();restored();
 }
 require(hg_reads&&hg_writes,"both HG read/write paths exercised");hg_volume_close(&arcade_volume);
 DIR*dir=opendir(host_dir);require(dir!=NULL,"host cleanup");struct dirent*e;while((e=readdir(dir))){if(!strcmp(e->d_name,".")||!strcmp(e->d_name,".."))continue;char path[512];snprintf(path,sizeof path,"%s/%s",host_dir,e->d_name);require(!unlink(path),"remove owned fixture file");}closedir(dir);require(!rmdir(host_dir),"remove owned fixture directory");
 printf("PASS ARCADE HG %s: native HG.PGM, both games/assets/LH5, C host-folder score writes/reloads and restored DOS\n",argv[2]);return 0;
#endif
 if(argc==4){word_at(app+GAME_SCORE,1000);ui_state=0;raw_key(0,0,0x76);raw_key(0,1,0x76);wait_ui(2);ui_state=0;key(0x1c);wait_ui(1);check_ui();require(r[app+GAME_HS_UI_STATUS]==2&&read16(app+GAME_HS_TABLE+8)==1000,"full disk retains score in memory and reports failure in graphics");ui_state=0;key(0x01);prompt_wait();restored();puts("PASS ARCADE full FAT12 disk returns safely");return 0;}
 // Clear the last brick through actual collision, preserve score/lives in level 2.
 memset(r+app+GAME_BRICKS,0,40);r[app+GAME_BRICKS]=1;r[app+GAME_REMAINING]=1;
 for(unsigned y=40;y<80;y++)memset(physical+0x130000+y*320+32,0,256);
 for(unsigned y=0;y<7;y++)for(unsigned x=0;x<32;x++)physical[0x130000+(40+y)*320+32+x]=(x&7)<7?1:0;
 // Keep both display buffers consistent; normal renderer restores dirty areas.
 memcpy(physical+0x100000,physical+0x130000,64000);memcpy(physical+0x110000,physical+0x130000,64000);
 r[app+GAME_VALID]=r[app+GAME_VALID+1]=0;r[app+GAME_LAUNCHED]=1;word_at(app+GAME_BALL_X,40);word_at(app+GAME_BALL_Y,33);word_at(app+GAME_VELOCITY_X,0);word_at(app+GAME_VELOCITY_Y,768);
 // Disable oracle during deliberately injected tile state until next level.
 flip_hook=NULL;uint64_t d=virtual_cycles+20000000;while(r[app+GAME_LEVEL]!=2&&virtual_cycles<d)until(virtual_cycles+1009);require(r[app+GAME_LEVEL]==2&&read16(app+GAME_SCORE)==10&&r[app+GAME_LIVES]==3,"brick clearance advances level, preserves score/lives");
 flip_hook=arcade_flip;step_frames(4);require(r[app+GAME_REMAINING]==20,"second layout has gaps");
 // Falling pickup catch is an actual frame update, not a direct life assignment.
 r[app+GAME_LIVES]=2;r[app+GAME_BONUS_ACTIVE]=1;word_at(app+GAME_BONUS_X,read16(app+GAME_PADDLE)+10);word_at(app+GAME_BONUS_Y,182);step_frames(1);require(r[app+GAME_LIVES]==3&&!r[app+GAME_BONUS_ACTIVE],"bonus grants life on paddle overlap");
 r[app+GAME_BONUS_ACTIVE]=2;word_at(app+GAME_BONUS_X,read16(app+GAME_PADDLE)+10);word_at(app+GAME_BONUS_Y,182);step_frames(1);require(read16(app+GAME_SCORE)==60&&r[app+GAME_LIVES]==3,"points bonus preserves lives and adds 50");
 // The last actual missed ball enters the record UI without pressing ESC.
 word_at(app+GAME_SCORE,12345);r[app+GAME_LIVES]=1;r[app+GAME_LAUNCHED]=1;
 word_at(app+GAME_BALL_X,2);word_at(app+GAME_BALL_Y,191);word_at(app+GAME_PADDLE,272);word_at(app+GAME_VELOCITY_X,0);word_at(app+GAME_VELOCITY_Y,768);
 ui_state=0;wait_ui(2);require(!r[app+GAME_LIVES],"last lost Arkanoid ball opens records");
 end_score(12345,"AC",table);file_check("b:ARKSCORE.DAT",table,160);
 app=frames=0;type_app("arkanoid");require(read16(app+GAME_HS_TABLE+8)==12345&&!strcmp((char*)r+app+GAME_HS_TABLE+10,"AC"),"new process loads disk high scores into graphics table");
 ui_state=0;key(0x01);prompt_wait();restored();
 which=1;app=0;xf=0;type_app("xonix");play();
 require(r[app+XO_XO_LIVES]==3&&read16(app+XO_XO_CLAIMED)==0,"Xonix initial territory/lives");
 r[app+XO_XO_ENEMY]=5;r[app+XO_XO_ENEMY+1]=10;r[app+XO_XO_ENEMY+2]=10;r[app+XO_XO_ENEMY+3]=15;memset(r+app+XO_XO_DIRECTION,0,4);
 raw_key(1,0,0x72);d=virtual_cycles+30000000;while(!read16(app+XO_XO_CLAIMED)&&virtual_cycles<d)until(virtual_cycles+1009);raw_key(1,1,0x72);step_frames(3);
 require(read16(app+XO_XO_CLAIMED)==437&&read16(app+XO_XO_SCORE)==4370,"multi-source flood captures side without enemies plus trail");
 for(unsigned y=1;y<24;y++)for(unsigned x=1;x<39;x++)require(r[app+XO_XO_MAP+y*40+x]==(x>=20?1:0),"reachable water remains, closed territory becomes land");
 for(unsigned y=8;y<192;y++)require(!memcmp(physical+0x130000+y*320+168,physical+0x180000+y*320+168,144),"claimed cells reveal source HAM8 image");
 // Retracing the live cut loses a life; redraw clears it on both pages.
 raw_key(1,0,0x75);step_frames(6);raw_key(1,1,0x75);raw_key(1,0,0x6b);step_frames(3);raw_key(1,1,0x6b);raw_key(1,0,0x74);step_frames(3);raw_key(1,1,0x74);
 // Player can safely return to land; force enemy onto a live cut for collision.
 r[app+XO_XO_MAP+10*40+5]=2;r[app+XO_XO_CUT]=1;step_frames(3);require(r[app+XO_XO_LIVES]==2&&!r[app+XO_XO_CUT],"enemy touching trail loses life and clears cut");
 raw_key(0,0,0x29);until(virtual_cycles+60000);require(r[app+XO_XO_PAUSED]&&!enabled,"Xonix SPACE pauses audio and game");raw_key(0,1,0x29);unsigned frozen=xf;until(virtual_cycles+120000);require(xf==frozen,"Xonix pause freezes frames");raw_key(0,0,0x29);raw_key(0,1,0x29);step_frames(3);
 end_score(23456,"AC",table);file_check("b:XONSCORE.DAT",table,160);
 app=0;xf=0;type_app("xonix");require(read16(app+XO_HS_TABLE+8)==23456,"Xonix table reloads from disk");play();step_frames(4);
 // Simulate a read-only card on a qualifying second score. Previous generation survives.
 sd_deny_write=1;word_at(app+XO_XO_SCORE,30000);ui_state=0;raw_key(0,0,0x76);raw_key(0,1,0x76);wait_ui(2);ui_state=0;key(0x1c);wait_ui(1);check_ui();require(r[app+XO_HS_UI_STATUS]==2,"read-only failure reported graphically without losing in-memory score");require(read16(app+XO_HS_TABLE+8)==30000,"failed save retains in-memory table");sd_deny_write=0;ui_state=0;key(0x01);prompt_wait();restored();file_check("b:XONSCORE.DAT",table,160);

 // Damaged/truncated newer slot must not replace the previous valid table.
 app=0;type_app("xonix");require(read16(app+XO_HS_TABLE+8)==23456,"failed newer generation falls back to old disk table");ui_state=0;key(0x01);prompt_wait();restored();
 // Launch from a different DOS drive and a nested game directory.
 command("md b:games");
 command("copy b:xonix.pgm b:games\\xonix.pgm");
 command("copy b:ledstrm1.ym b:games\\ledstrm1.ym");
 command("copy b:lena.iff b:games\\lena.iff");

 app=0;xf=0;type_app("\\games\\xonix");require(!read16(app+XO_HS_TABLE+8),"nested game has independent table");play();
 end_score(54321,"AC",table);file_check("b:games\\XONSCORE.DAT",table,160);
 app=0;type_app("\\games\\xonix");require(read16(app+XO_HS_TABLE+8)==54321,"nested table loads from actual game directory");play();
 // Last enemy/trail collision enters records; overlong names are bounded.
 word_at(app+XO_XO_SCORE,65535);r[app+XO_XO_LIVES]=1;r[app+XO_XO_MAP+10*40+5]=2;r[app+XO_XO_CUT]=1;
 r[app+XO_XO_ENEMY]=5;r[app+XO_XO_ENEMY+1]=10;memset(r+app+XO_XO_DIRECTION,0,4);
 ui_state=0;wait_ui(2);require(!r[app+XO_XO_LIVES],"last Xonix life opens records");
 const unsigned name_keys[]={0x1e,0x30,0x2e,0x20,0x12,0x21,0x22,0x23,0x17,0x24,0x25,0x26,0x32,0x31,0x18,0x19};
 for(unsigned k=0;k<16;k++)key(name_keys[k]);ui_state=0;key(0x1c);wait_ui(1);
 check_ui();require(r[app+XO_HS_UI_STATUS]==1&&!strcmp((char*)r+app+XO_HS_TABLE+10,"ABCDEFGHIJKL")&&read16(app+XO_HS_TABLE+8)==65535,"name limited to 12 characters, maximum score and alternate slot saved");
 memcpy(table,r+app+XO_HS_TABLE,160);ui_state=0;key(0x01);prompt_wait();restored();file_check("b:games\\XONSCORE.BAK",table,160);
 command("dir a:");command("dir b:");command("dir c:");printf("PASS ARCADE %s: graphical table/name/save status, no native-mode interludes, in-context restart, optional music, gameplay, persistent scores, read-only safety and restored DOS (%u UI frames)\n",argv[2],ui_frames);return 0;
}
