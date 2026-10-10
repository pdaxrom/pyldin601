// Original BIOS/UniDOS loads the real UniAS PGM and dispatches banked INT E0.
#define EXTENSION_SERVICES_MAIN extension_services_main
#include "test_extension_services.c"
static int contains(const char*s){
 unsigned char*r=MC6800GetCpuRam();unsigned start=crtc[12]*256+crtc[13],stride=crtc[1];
 unsigned step=model_a&&(r[0xe629]&2)?2:1;
 for(unsigned y=0;y<25;y++)for(unsigned x=0;x<stride/step;x++){
  unsigned n;for(n=0;s[n];n++)if(r[(start+y*stride+(x+n)*step+(step==2))&65535]!=(unsigned char)s[n])break;
  if(!s[n])return 1;
 }return 0;
}
static void wait_dos(void){
 uint64_t end=virtual_cycles+15000000;
 while(!(PC>=0xf380&&PC<=0xf3a8&&contains("A:\\>"))&&virtual_cycles<end)until(virtual_cycles+10000);
 require(virtual_cycles<end,"AY returns to DOS prompt");
}
static void command(void){key(0x30);KBDModKeyDown(2);key(0x27);KBDModKeyUp(2);key(0x1e);key(0x15);key(0x1c);}
int main(int argc,char**argv){
 if(argc!=2)return 2;model_a=!strcmp(argv[1],"601a");cpu_hd=1;
 MC6800SetMachine(PYLDIN_MACHINE_HD6303);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);
 require(n==(ROM_BYTES+512),"ROM size");memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load("build/ay/sd.img",&image_size);memcpy(config+64,image+462,32);
 committed=1;MC6800Init();MC6800Reset();until(60000000);key(0x1c);key(0x1c);wait_dos();watch_resets=1;
 for(unsigned run=0;run<2;run++){
  unsigned before=ay_writes[0];command();
  uint64_t end=virtual_cycles+10000000;
  while(ay_writes[0]==before&&virtual_cycles<end)until(virtual_cycles+1000);
  require(ay_writes[0]==before+1,"first music frame");
  const unsigned periods[]={478,426,379,358,319,284,253,239};
  uint64_t previous=virtual_cycles;
  for(unsigned note=0;note<8;note++){
   until(virtual_cycles+10000);
   unsigned period=ay[0]+256*ay[1];
   require(period==periods[note],"melody period");
   require(ay[2]+256*ay[3]==period/2&&ay[4]+256*ay[5]==(period/2)*4,"octave and bass periods");
   require(ay[7]==0x38&&ay[8]==12&&ay[9]==8&&ay[10]==6&&!ay_writes[13],"three tones, volumes, envelope sentinel");
   if(note==7)break;
   unsigned count=ay_writes[0];end=virtual_cycles+600000;
   while(ay_writes[0]==count&&virtual_cycles<end)until(virtual_cycles+1000);
   require(ay_writes[0]==count+1,"next note");
   uint64_t elapsed=virtual_cycles-previous;
   require(elapsed>480000&&elapsed<520000,"half-second pacing from 50 Hz BIOS clock");previous=virtual_cycles;
  }
  key(0x01);wait_dos();require(ay[7]==63&&!ay[8]&&!ay[9]&&!ay[10]&&contains("AY: stopped."),"ESC silences and restores UniDOS");
 }
 unsigned count=ay_writes[0];cpu_hd=0;MC6800SetMachine(PYLDIN_MACHINE_601);command();wait_dos();
 require(ay_writes[0]==count&&contains("enable HD6303"),"MC6800 guard");
 cpu_hd=1;MC6800SetMachine(PYLDIN_MACHINE_HD6303);
 key(0x20);key(0x17);key(0x13);key(0x1c);wait_dos();require(!resets,"no reset after music and DIR");
 printf("PASS %s AY.PGM: native PGM relocation/INT E0, two plays, three independent tone periods, 50 Hz half-second pacing, ESC/silence, MC6800 guard and DIR\n",argv[1]);return 0;
}
