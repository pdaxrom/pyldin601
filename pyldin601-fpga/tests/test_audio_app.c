// Run the actual HD6303 PGM in native UniDOS. Compare every AY frame with
// independent fixtures, including page crossings, rate, envelope and cleanup.
#define COMPACT_FIXTURE 1
#define DIRECT_SD_FIXTURE 1
#define HG_FIXTURE 1
#include <stdint.h>
static int hg_read_byte(uint16_t a,unsigned char *out);
static int hg_write_byte(uint16_t a,unsigned char d);
#define ROMDISK_MAIN unused_romdisk_main
#include "test_romdisk_unidos.c"
#ifdef GFXMUSIC_FIXTURE
#include "../build/audio/gfxmusic_labels.h"
#else
#include "../build/audio/yplay_labels.h"
#endif
#undef ROMDISK_MAIN

static unsigned char ay_regs[16],*oracle;
static size_t oracle_size;
static unsigned char *unpacked;
static size_t unpacked_size;
static unsigned app_base,original_irq,saved_page,saved_group,restored,frames_played;
static unsigned rate,factor,loop_frame,loop_mode,envelope_writes,pause_checks;
static uint64_t frame_times[4096];
static unsigned reads_at_play;
static uint64_t handler_start,max_handler,transfer_start,max_transfer;
static unsigned system_timer,system_calls;
static uint32_t music_period=480000,music_shadow=480000,music_counter;
static uint32_t chip_divider=0x01800000,chip_shadow=0x01800000;
static unsigned music_enabled,music_pending,music_overrun;
static unsigned missing_audio,stuck_divider;
static uint64_t music_last;
static unsigned held_tokens[3],held_count;
static unsigned char held_banks[111],held_data[16384];
static unsigned manager_state;
static unsigned ram_call(unsigned op,unsigned count,unsigned desc){
 unsigned char*r=MC6800GetCpuRam();unsigned pc=PC,sp=SP,x=X,a=A,b=B;
 unsigned ch=h,ci=i,cn=n,cz=z,cv=v,cc=c;
 r[0x210]=0x3f;r[0x211]=0xe5;PC=0x210;A=op;B=count;X=desc;
 uint64_t limit=virtual_cycles+3000000;
 while(PC!=0x212){until(virtual_cycles+1);require(virtual_cycles<limit,"RAM manager returns");}
 unsigned result=A;require(SP==sp,"RAM manager stack balanced");
 PC=pc;SP=sp;X=x;A=a;B=b;h=ch;i=ci;n=cn;z=cz;v=cv;c=cc;return result;
}
static void music_update(void){
 uint64_t elapsed=virtual_cycles-music_last;music_last=virtual_cycles;
 if(!music_enabled)return;
 uint64_t count=(uint64_t)music_counter+elapsed*24;
 if(count>=music_period){if(music_pending||count>=2ULL*music_period)music_overrun=1;music_pending=1;}
 music_counter=count%music_period;
}

static int hg_read_byte(uint16_t a,unsigned char *out){
#ifdef GFXMUSIC_FIXTURE
 if(gfxmusic_gfx_read(a,out))return 1;
#endif
 if(a>=0xe690&&a<=0xe69f){
  music_update();unsigned off=a&15;*out=0;
  if(off==0)*out=(music_pending<<7)|(music_overrun<<6)|(stuck_divider<<5)|music_enabled;
  else if(off==1)*out=missing_audio?0xff:0x59;
  else if(off>=2&&off<=5)*out=music_period>>(8*(5-off));
  else if(off>=11&&off<=14)*out=chip_divider>>(8*(14-off));
  return 1;
 }
 if(a>=0xe610&&a<0xe620){*out=ay_regs[a&15];return 1;}return 0;
}
static unsigned frame_index(unsigned n){
 unsigned count=oracle_size/14;
 if(n<count)return n;
 require(loop_mode&&loop_frame<count,"no music frames past EOF");
 return loop_frame+(n-count)%(count-loop_frame);
}
static int hg_write_byte(uint16_t a,unsigned char d){
#ifdef GFXMUSIC_FIXTURE
 if(gfxmusic_gfx_write(a,d))return 1;
#endif
 if(a>=0xe690&&a<=0xe69f){
  music_update();unsigned off=a&15;
  if(off==0){music_enabled=d&1;if(d&2)music_pending=music_overrun=0;if(!(d&1)||(d&4))music_counter=music_pending=music_overrun=0;}
  else if(off>=2&&off<=5){unsigned shift=8*(5-off);music_shadow=(music_shadow&~(255U<<shift))|((uint32_t)d<<shift);}
  else if(off==6&&(d&1)){require(music_shadow,"nonzero music timer period");music_period=music_shadow;music_counter=music_pending=music_overrun=0;}
  else if(off>=11&&off<=14){unsigned shift=8*(14-off);chip_shadow=(chip_shadow&~(255U<<shift))|((uint32_t)d<<shift);}
  else if(off==15&&(d&1)){require(chip_shadow>=0x01800000,"safe music clock divisor");chip_divider=chip_shadow;}
  return 1;
 }
 if(a<0xe610||a>=0xe620)return 0;
 ay_regs[a&15]=d;
 if(!app_base)return 1;
 if(a==0xe61c){
  require(frames_played<4096,"bounded audio capture");
  const unsigned char *f=oracle+14*frame_index(frames_played);
  unsigned char expected[13];memcpy(expected,f,13);
  if(memcmp(ay_regs,expected,13)){
   fprintf(stderr,"frame %u expected:",frames_played);for(unsigned k=0;k<13;k++)fprintf(stderr," %02x",expected[k]);
   fprintf(stderr,"\ngot:");for(unsigned k=0;k<13;k++)fprintf(stderr," %02x",ay_regs[k]);fputc('\n',stderr);
   require(0,"AY frame matches original dump, unchanged");
  }
  uint32_t expected_div=factor==256?0x01800000:factor==512?0x03000000:factor==289?0x01b11101:0x01ad1acd;
  require(chip_divider==expected_div&&music_period==(24000000+rate/2)/rate,"file clock and rate programmed into hardware");
  require(sd_reads==reads_at_play,"no SD access during playback IRQ");
  frame_times[frames_played++]=virtual_cycles;
 }else if(a==0xe61d){
  require(frames_played>0,"envelope write follows frame");
  const unsigned char *f=oracle+14*frame_index(frames_played-1);
  require(f[13]!=255&&d==f[13],"R13 sentinel and shape retrigger");envelope_writes++;
 }
 return 1;
}
static void observe(void){
 // Physical IRQ is level-sensitive. Inspect the fixture latch without
 // calling KBDCheckKey: that read toggles the native keyboard handshake.
 music_update();if(!i&&(music_pending||tick||(keyReady&&!keyConsumed)))MC6800SetInterrupt(1);
 unsigned char *r=MC6800GetCpuRam();unsigned vector=(r[0xefc8]<<8)|r[0xefc9];
 if(PC==system_timer)system_calls++;
 if(!app_base&&vector!=original_irq){
  app_base=vector-YP_IRQ_PLAYER;
  unsigned lease=app_base+YP_MEMORY_LEASE;
  require(!r[app_base+YP_LH_LEASE+2],"temporary dictionary/Huffman banks released before playback");
  require(unpacked_size<=909312&&r[lease+2]>=(unpacked_size+8191)/8192,"song owns enough banks");
  unsigned seen[111]={0};
  for(unsigned bank=0;bank<r[lease+2];bank++){
   unsigned id=r[lease+3+bank];require(id<111&&!seen[id]&&!held_banks[id],"distinct song banks never overlap another owner");seen[id]=1;
  }
  for(size_t k=0;k<unpacked_size;k++){
   unsigned id=r[lease+3+k/8192],got=physical[0x22000+id*8192+(k%8192)];
   if(got!=unpacked[k]){fprintf(stderr,"decoded offset %zu bank %u: got %02x expected %02x\n",k,id,got,unpacked[k]);require(0,"complete decoded/compacted file matches independent SRAM oracle");}
  }
  saved_page=r[app_base+YP_SAVED_PAGE];saved_group=r[app_base+YP_SAVED_GROUP];
  reads_at_play=sd_reads;
  const char *snapshot=getenv("AUDIO_SNAPSHOT");
  if(snapshot){
   FILE *f=fopen(snapshot,"wb");require(f!=NULL,"open IRQ fixture");
   unsigned values[]={vector,app_base+YP_QUEUE_FILL,app_base+YP_WRITE_FRAME,app_base+YP_FRAME_SENT,app_base+YP_UNDERRUNS,rate};
   unsigned char header[20]={0};for(unsigned k=0;k<6;k++){header[2*k]=values[k]>>8;header[2*k+1]=values[k];}
   uint32_t period=(24000000+rate/2)/rate;for(unsigned k=0;k<4;k++)header[12+k]=period>>(24-8*k);
   header[16]=SP>>8;header[17]=SP;
   require(fwrite(header,1,20,f)==20&&fwrite(r,1,0xf000,f)==0xf000&&fwrite(physical+0x20000,1,4096,f)==4096&&fwrite(physical+0x10000,1,65536,f)==65536&&fwrite(physical+0x22000,1,909312,f)==909312,"write IRQ fixture");
   fclose(f);
  }
 }
 if(app_base&&PC==app_base+YP_IRQ_PLAYER){
  require(i,"music IRQ runs with hardware interrupts masked");handler_start=virtual_cycles;
 }
 if(app_base&&PC==app_base+YP_WRITE_FRAME)transfer_start=virtual_cycles;
 if(transfer_start&&PC==app_base+YP_FRAME_SENT){uint64_t elapsed=virtual_cycles-transfer_start;if(elapsed>max_transfer)max_transfer=elapsed;transfer_start=0;}
 if(handler_start&&PC==app_base+YP_IRQ_RETURN){
  uint64_t elapsed=virtual_cycles-handler_start;if(elapsed>max_handler)max_handler=elapsed;handler_start=0;
  require(elapsed<500,"music IRQ consists only of queue and register transfer");
 }
 if(app_base&&!restored&&PC==app_base+YP_RETURN_TO_DOS){
  require(page==saved_page&&ram_group==saved_group,"both page registers restored before DOS exit");restored++;
 }
#ifdef GFXMUSIC_FIXTURE
 gfxmusic_observe();
#endif
}
static void type_run(const char *text){
 const char *letters="abcdefghijklmnopqrstuvwxyz";
 const unsigned scans[]={0x1e,0x30,0x2e,0x20,0x12,0x21,0x22,0x23,0x17,0x24,0x25,0x26,0x32,0x31,0x18,0x19,0x10,0x13,0x1f,0x14,0x16,0x2f,0x11,0x2d,0x15,0x2c};
 for(;*text;text++){
  const char *p=strchr(letters,*text);
  unsigned scan=p?scans[p-letters]:*text=='.'?0x34:*text==' '?0x39:*text==':'?0x27:*text=='/'?0x35:*text>='1'&&*text<='9'?*text-'1'+2:*text=='0'?0x0b:0;
  require(scan,"valid command key");if(*text==':')KBDModKeyDown(2);key(scan);if(*text==':')KBDModKeyUp(2);
 }key(0x1c);
}
int main(int argc,char **argv){
 if(argc!=11)return 2;
 model_a=!strcmp(argv[2],"601a");cpu_hd=1;rate=atoi(argv[5]);factor=atoi(argv[6]);loop_frame=atoi(argv[7]);loop_mode=atoi(argv[8]);
 const char *expected_error=argv[9];
 MC6800SetMachine(PYLDIN_MACHINE_HD6303);
 size_t n;unsigned char *rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);
 require(n==ROM_BYTES+512,"paired ROM fixture");memcpy(config,rom,HEADER_BYTES);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 if(getenv("AUDIO_ROM_SWAP")){unsigned char temp[8192];memcpy(temp,physical+0x14000,8192);memcpy(physical+0x14000,physical+0x16000,8192);memcpy(physical+0x16000,temp,8192);}
 image=load(argv[1],&image_size);committed=1;
 oracle=load(argv[4],&oracle_size);
 unpacked=load(argv[10],&unpacked_size);
 MC6800Init();MC6800Reset();until(60000000);key(0x1c);key(0x1c);prompt_wait();
 unsigned char *r=MC6800GetCpuRam(),preserved[0x12000];memcpy(preserved,physical+0x10000,sizeof preserved);
 manager_state=r[0xefca]*256+r[0xefcb];require(manager_state>=0x100&&manager_state+240<=0xbe00,"resident allocator available");
 const char *ram_mode=getenv("AUDIO_RAM");
 if(ram_mode){
  held_count=strcmp(ram_mode,"fragmented")?1:3;
  for(unsigned k=0;k<held_count;k++){
   unsigned desc=0x3000+k*128;require(ram_call(1,held_count==1?(!strcmp(ram_mode,"scratch")?110:111):1,desc)==0,"reserve foreign banks");
   held_tokens[k]=r[desc]*256+r[desc+1];
  }
  if(held_count==3){require(ram_call(2,0,0x3080)==0,"make a physical hole");held_tokens[1]=0;
   for(unsigned k=0;k<8192;k++){physical[0x22000+k]=held_data[k]=(k*7+13)&255;physical[0x26000+k]=held_data[8192+k]=(k*17+9)&255;}
  }
  memcpy(held_banks,r+manager_state+112,111);
 }
 unsigned sp_before=SP;original_irq=(r[0xefc8]<<8)|r[0xefc9];system_timer=(r[0xee0a]<<8)|r[0xee0b];unsigned irq_before=irq_count;
 const char *fault=getenv("AUDIO_FAULT");
 if(fault){
  if(!strcmp(fault,"missing"))missing_audio=1;
  else if(!strcmp(fault,"stuck"))stuck_divider=1;
  else if(!strcmp(fault,"busy")){music_enabled=1;music_period=0x7fffffff;chip_divider=0x03000000;}
  else require(0,"known audio fault");
 }
 unsigned original_enabled=music_enabled;uint32_t original_period=music_period,original_divider=chip_divider;
 unsigned char original_ay[16];memcpy(original_ay,ay_regs,16);
#ifdef GFXMUSIC_FIXTURE
 gfxmusic_reset();
#endif
 native_step_hook=observe;watch_resets=1;
 char cmd[120];snprintf(cmd,sizeof cmd,
#ifdef GFXMUSIC_FIXTURE
 "b:gfxmusic b:%s%s%s",
#else
 "b:yplay b:%s%s%s",
#endif
 argv[3],loop_mode?" /l":"",strstr(argv[3],"wait")?" /a":"");
 type_run(cmd);
 if(!strcmp(expected_error,"stopped"))key(1);
 if(strcmp(expected_error,"-")){
#ifdef GFXMUSIC_FIXTURE
  // Graphics initialization polls the keyboard through the same BIOS
  // routine as DOS. Its old prompt is still on screen during loading;
  // wait for the actual diagnostic before accepting that input PC.
  uint64_t deadline=virtual_cycles+100000000;
  while(!contains(expected_error)&&virtual_cycles<deadline)until(virtual_cycles+10000);
#endif
  prompt_wait();require(contains(expected_error),"malformed file is rejected with useful error");require(!frames_played&&!app_base,"bad file never hooks IRQ or plays");
 }else{
  uint64_t deadline=virtual_cycles+1500000000ULL;
  while(frames_played<10&&virtual_cycles<deadline)until(virtual_cycles+1000);
  require(frames_played>=10,"music starts after load and validation");
  // Pause stops music; the independent PAL timer and keyboard keep running.
  key(0x39);unsigned at_pause=frames_played;
  require(r[app_base+YP_PAUSED]&&ay_regs[7]==63&&!ay_regs[8]&&!ay_regs[9]&&!ay_regs[10],"SPACE pauses and silences");
#ifdef GFXMUSIC_FIXTURE
  unsigned paused_frames=gfxmusic_frames();
#endif
  until(virtual_cycles+250000);require(frames_played==at_pause&&irq_count>irq_before,"pause keeps native timer running");pause_checks++;
#ifdef GFXMUSIC_FIXTURE
  require(gfxmusic_frames()==paused_frames,"SPACE also freezes graphics");
#endif
  key(0x39);require(!r[app_base+YP_PAUSED],"SPACE resumes");
  unsigned target=loop_mode?130:oracle_size/14>100?100:oracle_size/14;
#ifdef GFXMUSIC_FIXTURE
  if(loop_mode)target=400;
#endif
  deadline=virtual_cycles+1000000ULL*(target+10)/rate+5000000;
  while(frames_played<target&&virtual_cycles<deadline)until(virtual_cycles+1000);
  require(frames_played==target,"all expected music frames");
  if(loop_mode||oracle_size/14>100){key(1);}else{
   deadline=virtual_cycles+1000000;while(!r[app_base+YP_STOPPED]&&virtual_cycles<deadline)until(virtual_cycles+1000);
  }
  prompt_wait();require(restored==1,"one balanced DOS return");
  require((r[0xefc8]<<8|r[0xefc9])==original_irq&&SP==sp_before,"native timer and SP restored");
  unsigned expected_writes=0;for(unsigned k=0;k<frames_played;k++)if(oracle[14*frame_index(k)+13]!=255)expected_writes++;
  require(envelope_writes==expected_writes,"exact envelope retriggers, FF not written");
  require(!r[app_base+YP_UNDERRUNS]&&!music_overrun,"no missing frames or unacknowledged timer overruns");
  // For the stable section after resume, compare 50/60/100-Hz scheduling.
  unsigned first=at_pause+20;
  if(frames_played>first+20){
   uint64_t elapsed=frame_times[first+20]-frame_times[first];
   uint64_t expected=20000000/rate;
   require(elapsed+21000>expected&&elapsed<expected+21000,"file frame rate independent of foreground/DOS");
  }
 }
 require(!memcmp(preserved,physical+0x10000,sizeof preserved),"ROM/BIOS/font unchanged");
 require(!memcmp(held_banks,r+manager_state+112,111),"every app exit releases only its own banks");
 if(held_count==3)require(!memcmp(held_data,physical+0x22000,8192)&&!memcmp(held_data+8192,physical+0x26000,8192),"foreign song data unchanged");
 if(SP!=sp_before||(r[0xefc8]<<8|r[0xefc9])!=original_irq)fprintf(stderr,"exit SP=%04x/%04x IRQ=%04x/%04x\n",SP,sp_before,r[0xefc8]<<8|r[0xefc9],original_irq);
 require(SP==sp_before&&(r[0xefc8]<<8|r[0xefc9])==original_irq,"timer and stack preserved on every exit path");
 require((r[0xee0a]<<8|r[0xee0b])==system_timer,"PAL system timer vector unchanged");
 require(music_enabled==original_enabled&&!music_pending&&chip_divider==original_divider&&music_period==original_period,"music timer and clock restored on exit");
 if((fault&&strcmp(fault,"stuck"))
#ifdef GFXMUSIC_FIXTURE
 ||getenv("GFX_FAULT")
#endif
 )require(!memcmp(ay_regs,original_ay,16),"unavailable hardware or busy owner is untouched");
 else require(ay_regs[7]==63&&!ay_regs[8]&&!ay_regs[9]&&!ay_regs[10],"exit is silent");
 command("dir a:");command("dir b:");command("dir c:");
 require(!resets&&!fdc_port_accesses,"no reset or removed disk controller access");
 printf("PASS %s %s: %u frames/%u envelope writes, %u-Hz, clock factor %u, pause=%u, max IRQ=%llu/transfer=%llu cycles, no playback disk I/O, cleanup/DIR\n",argv[2],argv[3],frames_played,envelope_writes,rate,factor,pause_checks,(unsigned long long)max_handler,(unsigned long long)max_transfer);
#ifdef GFXMUSIC_FIXTURE
 gfxmusic_finish_check(cmd);
#endif
 require(!memcmp(held_banks,r+manager_state+112,111),"repeat launch releases only song banks");
 for(unsigned k=0;k<held_count;k++)if(held_tokens[k]){
  r[0x3000]=held_tokens[k]>>8;r[0x3001]=held_tokens[k];r[0x3002]=1;
  require(ram_call(2,0,0x3000)==0,"original owner releases retained banks");
 }
 require(r[manager_state+6]==111,"all RAM reclaimed");
 return 0;
}
