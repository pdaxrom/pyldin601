// Capture the actual UniDOS-loaded PGM at an instruction boundary. The HDL
// resumes it with RTI; neither the game nor production RTL gains debug code.
#define GAME_APP_MAIN unused_game_app_main
#include "test_game_app.c"
static void save_perf(const char *path,const void *data,size_t size){
 FILE *f=fopen(path,"wb");require(f&&fwrite(data,1,size,f)==size&&!fclose(f),"write performance snapshot");
}
int main(int argc,char **argv){
 if(argc!=4)return 2;
 model_a=!strcmp(argv[2],"601a");cpu_hd=1;MC6800SetMachine(PYLDIN_MACHINE_HD6303);
 size_t size;unsigned char *rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&size);
 memcpy(config,rom,HEADER_BYTES);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load(argv[1],&image_size);committed=1;MC6800Init();MC6800Reset();until(60000000);
 key(0x1c);key(0x1c);prompt_wait();r=MC6800GetCpuRam();state=r[0xefcc]*256+r[0xefcd];
 pcb=r[0xec00]*256+r[0xec01];native_step_hook=game_observe;flip_hook=game_frame;type_game();wait_frames(4);
 uint64_t deadline=virtual_cycles+1000000;
 while(PC!=app+GAME_FRAME_LOOP||i){until(virtual_cycles+1);require(virtual_cycles<deadline,"capture game loop");}
 require(page==7&&!raw_count,"game snapshot outside SWI and raw queue empty");
 r[app+GAME_BALL_FRACTION_X]=r[app+GAME_BALL_FRACTION_Y]=0;
 r[app+GAME_LAUNCHED]=1;word_at(app+GAME_BALL_X,140);word_at(app+GAME_BALL_Y,140);
 if(!strcmp(argv[3],"brick")){word_at(app+GAME_BALL_X,62);word_at(app+GAME_BALL_Y,38);word_at(app+GAME_VELOCITY_Y,512);}
 if(!strcmp(argv[3],"miss")){word_at(app+GAME_BALL_X,2);word_at(app+GAME_BALL_Y,191);word_at(app+GAME_PADDLE,272);word_at(app+GAME_VELOCITY_X,0);word_at(app+GAME_VELOCITY_Y,768);}
 char path[256];snprintf(path,sizeof path,"build/game-perf/%s-%s-ram.bin",argv[2],argv[3]);save_perf(path,r,65536);
 snprintf(path,sizeof path,"build/game-perf/%s-%s-fb.bin",argv[2],argv[3]);save_perf(path,physical+0x100000,4*65536);
 snprintf(path,sizeof path,"build/game-perf/%s-%s-pages.bin",argv[2],argv[3]);save_perf(path,physical+0x22000,0xde000);
 snprintf(path,sizeof path,"build/game-perf/%s-%s-config.bin",argv[2],argv[3]);save_perf(path,config,96);
 snprintf(path,sizeof path,"build/game-perf/%s-%s-context.json",argv[2],argv[3]);FILE *f=fopen(path,"w");require(f!=NULL,"open context");
 fprintf(f,"{\"pc\":%u,\"sp\":%u,\"a\":%u,\"b\":%u,\"x\":%u,\"cc\":%u,\"page\":%u,\"mode\":%u,\"app\":%u,\"front\":%u,\"period\":%u,\"divider\":%u,\"crtc\":[",PC,SP,A,B,X,0xc0|h*32|i*16|n*8|z*4|v*2|c,page,r[0xe629],app,front,period,divider);
 for(unsigned k=0;k<16;k++)fprintf(f,"%s%u",k?",":"",crtc[k]);fprintf(f,"]}\n");require(!fclose(f),"close context");
 printf("Prepared ARKANOID %s/%s PC=%04x app=%04x\n",argv[2],argv[3],PC,app);return 0;
}
