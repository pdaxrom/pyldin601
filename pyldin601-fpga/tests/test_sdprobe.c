/* Real PGM, native DOS loader/console, software CPU and scripted SPI cards. */
#define COMPACT_FIXTURE 1
#define DIRECT_SD_FIXTURE 1
#define ROMDISK_MAIN unused_romdisk_main
#include "test_romdisk_unidos.c"
#undef ROMDISK_MAIN

static unsigned scenario,probe_cmd0[4],probe_cmd8[4],probe_acmd[4],profile_seen;
static unsigned probe_divider=255,probe_profile,probe_started;
static uint64_t last_probe_cmd0;
static void observe(unsigned op,uint32_t arg){
 if(!probe_started)return;
 require(op==0||op==8||op==55||op==41||op==58,"probe never sends sector/write/erase commands after card swap");
 if(op==0){
  if(!profile_seen||spi_div!=probe_divider||
     (probe_profile==2&&virtual_cycles-last_probe_cmd0>1000000)){
   if(profile_seen)probe_profile++;
   require(probe_profile<4,"four bounded diagnostic profiles");
   probe_divider=spi_div;profile_seen++;
  }
  /* The fourth profile has the same divider but a 64-tick startup delay. */
  last_probe_cmd0=virtual_cycles;
  require(spi_div==(probe_profile==0?29:probe_profile==1?59:119),"SPI frequencies 400/200/100/100 kHz");
  probe_cmd0[probe_profile]++;
  sd_init_never=scenario==1||(scenario==0&&spi_div==29)?1:0;
 }
 if(op==8){probe_cmd8[probe_profile]++;require(arg==0x1aa,"CMD8 check pattern and voltage");}
 if(op==41){probe_acmd[probe_profile]++;require(arg==(sdsc?0:0x40000000),"ACMD41 HCS follows CMD8 support");}
 sd_bad_r7=scenario==3;
}
static void type_probe(void){
 const unsigned scans[]={0x30,0x27,0x1f,0x20,0x19,0x13,0x18,0x30,0x12};
 for(unsigned n=0;n<sizeof scans/sizeof scans[0];n++){
  if(n==1)KBDModKeyDown(2);
  key(scans[n]);
  if(n==1)KBDModKeyUp(2);
 }
 key(0x1c);
}
int main(int argc,char**argv){
 if(argc!=5)return 2;
 model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");scenario=atoi(argv[4]);
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t length;unsigned char *rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&length);
 require(length==ROM_BYTES+512,"current paged ROM length");
 memcpy(config,rom,HEADER_BYTES);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load(argv[1],&image_size);committed=1;
 MC6800Init();MC6800Reset();until(60000000);key(0x1c);key(0x1c);prompt_wait();
 unsigned before_writes=sd_writes;
 type_probe();
 until(virtual_cycles+2000000);
 require(contains("Replace SD with test card; press ENTER."),"native DOS loads probe and waits for card replacement");
 unsigned before_reads=sd_reads;
 probe_started=1;sd_command_observer=observe;sd_init_allow_slow=1;sdsc=scenario==2;
 /* The original native volumes remain mounted, but the app must never
    touch them again after Enter. The private image is checked unchanged. */
 uint32_t image_crc=0xffffffff;
 for(size_t n=0;n<image_size;n++)image_crc=crc_byte(image_crc,image[n]);
 key(0x1c);
 uint64_t deadline=virtual_cycles+50000000;
 while(!contains("SDPROBE DONE - POWER OFF")&&virtual_cycles<deadline)until(virtual_cycles+10007);
 require(virtual_cycles<deadline,"diagnostic finishes with bounded retry loops");
 require(profile_seen==4,"all four profiles were exercised");
 for(unsigned n=0;n<4;n++){
  require(probe_cmd0[n]>0&&probe_cmd0[n]<=101,"CMD0 is retried within its deadline");
  if(scenario==1||(!n&&scenario==0))require(!probe_cmd8[n]&&!probe_acmd[n],"silent CMD0 never advances to later commands");
  else if(scenario==3)require(probe_cmd8[n]&&!probe_acmd[n],"bad R7 is shown without advancing initialization");
  else require(probe_cmd8[n]&&probe_acmd[n],"responsive card reaches ACMD41");
 }
 require(sd_reads==before_reads&&sd_writes==before_writes,"no sector I/O or disk writes after replacement");
 uint32_t after_crc=0xffffffff;
 for(size_t n=0;n<image_size;n++)after_crc=crc_byte(after_crc,image[n]);
 require(after_crc==image_crc,"all SD image bytes unchanged");
 unsigned char *ram=MC6800GetCpuRam();
 deadline=virtual_cycles+2000000;
 while(!(PC<0xc000&&ram[PC]==0x20&&ram[PC+1]==0xfe)&&virtual_cycles<deadline)
  until(virtual_cycles+1009);
 require(PC<0xc000&&ram[PC]==0x20&&ram[PC+1]==0xfe&&i,"probe halts with IRQs masked instead of returning to stale DOS volumes");
 require(spi_control==0x23&&!resets&&!fdc_port_accesses,"card deselected, no reset or removed FDC calls");
 if(scenario==1)require(contains("PH=01 C0=FF C8=FF"),"screen explains the board CMD0 timeout");
 else if(scenario==3)require(contains("PH=02 C0=01 C8=01")&&contains("E=03"),"screen diagnoses corrupt CMD8 pattern");
 else require(contains("PH=04 C0=01 C8=")&&contains("OCR="),"screen contains initialization result and OCR");
 printf("PASS SDPROBE %s/%s scenario %u: native loader/console, bounded frequency sweep, read-only protocol, unchanged SD, terminal halt\n",argv[2],argv[3],scenario);
 return 0;
}
