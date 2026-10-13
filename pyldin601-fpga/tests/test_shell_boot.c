// Original disk-sector priority and the registered INT01 ROM fallback.
#define DIRECT_SD_FIXTURE 1
#define ROMDISK_MAIN unused_romdisk_main
#include "test_romdisk_unidos.c"
#undef ROMDISK_MAIN
#include "../build/partitions/shell_labels.h"
#include "../build/partitions/unibios_labels.h"
static unsigned sector_entries,rom_entries,disk_entries,sector_address;
static unsigned monitor_entries,register_entries;
static unsigned read_error,no_vector;
static void boot_observe(void){
 if(PC==0x150)sector_entries++;
 if(PC==SH_SHELL_START&&page==15){rom_entries++;runtime_no_token=0;}
 if(PC==0x1000)disk_entries++;
 if(page==8&&PC==UB_MONITOR0)monitor_entries++;
 if(page==8&&PC==UB_REGDUMP0)register_entries++;
 if(read_error&&PC==sector_address)runtime_no_token=1;
 if(no_vector&&PC==sector_address){
  unsigned char*r=MC6800GetCpuRam();r[0xee02]=r[0xee03]=0;r[0xed80]&=0xf0;
 }
}
static void monitor_wait(unsigned after){
 uint64_t deadline=virtual_cycles+2000000;
 do{
  until(virtual_cycles+1009);
  if(monitor_entries>after&&page==8&&PC==(model_a?0xf397:0xf39d))return;
 }while(virtual_cycles<deadline);
 require(0,"UniBIOS monitor reaches keyboard input");
}
static void monitor_commands(void){
 monitor_wait(0);unsigned saved_sp=SP;
 for(unsigned k=0;k<3;k++){
  unsigned entries=monitor_entries,registers=register_entries;
  // '?' is the native monitor's register-display command.
  KBDModKeyDown(2);key(0x35);KBDModKeyUp(2);key(0x1c);
  monitor_wait(entries);
  require(register_entries==registers+1&&contains("SP=")&&contains("CC="),
          "monitor accepts register-display command after failed shell boot");
  require(SP==saved_sp,"monitor commands do not leak the abandoned boot stack");
 }
}
int main(int argc,char**argv){
 if(argc!=5&&argc!=6)return 2;
 model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t size;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&size);
 require(size==ROM_BYTES+512,"boot ROM length");
 memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 if(!strcmp(argv[4],"disk-only"))memset(physical+0x1e000,255,8192);
 if(!strcmp(argv[4],"missing"))memset(physical+0x1e000,255,8192);
 read_error=!strcmp(argv[4],"read-error");
 no_vector=!strcmp(argv[4],"no-vector");
 if(read_error||no_vector){
  FILE*f=fopen(model_a?"build/partitions/BIOS_A.ROM.LST":"build/partitions/BIOS.ROM.LST","r");
  require(f!=NULL,"native boot listing");char line[512];
  while(fgets(line,sizeof line,f))if(sscanf(line,"NATIVE_BOOT_SECTOR =$%x",&sector_address)==1)break;
  fclose(f);require(sector_address>=0xf000,"native sector label");
 }
 if(argc==6)boot_partition=strtoul(argv[5],0,10);
 image=load(argv[1],&image_size);committed=1;native_step_hook=boot_observe;
 MC6800Init();
 for(unsigned warm=0;warm<2;warm++){
  sector_entries=rom_entries=disk_entries=monitor_entries=register_entries=0;
  MC6800Reset();until(virtual_cycles+60000000);
  if(no_vector){
   require(contains("BOOT: no system")&&!sector_entries&&!rom_entries&&!disk_entries,
           "zero INT01 reports no system without executing address zero");
   monitor_commands();
  }else if(!strcmp(argv[4],"missing")){
   require(contains("UniBIOS")&&page==8&&!sector_entries&&!rom_entries&&!disk_entries,
           "without a disk loader or UniShell the registered INT01 monitor runs");
   monitor_commands();
  }else if(!strcmp(argv[4],"no-file")){
   require(sector_entries==1&&!rom_entries&&!disk_entries&&!monitor_entries&&
           contains("Non-System disk or disk error"),
           "original native sector with no file asks for a replacement disk");
   watch_resets=1;resets=0;key(0x1c);until(virtual_cycles+60000000);
   require(resets&&sector_entries==2&&!rom_entries&&!disk_entries&&!monitor_entries&&
           contains("Non-System disk or disk error"),
           "original sector retries BIOS boot after a key, without entering monitor");
   watch_resets=0;
  }else{
   key(0x1c);key(0x1c);prompt_wait();
   unsigned saved_sp=SP;command("dir a:");command("dir b:");command("dir c:");
   unsigned char*r=MC6800GetCpuRam();unsigned work=r[0xbf80]*256+r[0xbf81],drive=255;
   for(unsigned k=0;k<r[0xbf82];k++)if(r[work+512+24*k+8]==3)drive=r[work+512+24*k+11];
   require(drive<8,"program volume mounted after boot selection");
   char program[24];snprintf(program,sizeof program,"%c:ramalloc",'a'+drive);command(program);
   require(SP==saved_sp&&contains("PASS: RAM allocator, 64 KiB, SWI/IRQ"),
                               "disk/ROM shell can load and return from PGM");
   require(disk_entries==1,"one complete shell startup");
   if(!strcmp(argv[4],"rom")||read_error)
    require(!sector_entries&&rom_entries==1,"invalid/unreadable sector falls back to ROM INT01");
   else require(sector_entries==1&&!rom_entries,"disk boot has priority, including without UniShell");
  }
 }
 const char*checks=no_vector||!strcmp(argv[4],"missing")
  ?"working monitor, register commands and balanced stack"
  :!strcmp(argv[4],"no-file")?"original sector replacement prompt and key-triggered retry"
  :"boot priority and file/program APIs";
 printf("PASS shell boot %s/%s %s partition %u: cold/warm Reset, %s\n",argv[2],argv[3],argv[4],boot_partition,checks);
 return 0;
}
