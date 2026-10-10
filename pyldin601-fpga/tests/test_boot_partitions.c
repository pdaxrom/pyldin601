// Execute native BIOS boot selection; no boot-sector code is executed.
#define PARTITION_FIXTURE 1
#define COMPACT_FIXTURE 1
#define DIRECT_SD_FIXTURE 1
#define ROMDISK_MAIN unused_romdisk_main
#include "test_romdisk_unidos.c"
#undef ROMDISK_MAIN
int main(int argc,char**argv){
 if(argc!=5)return 2;model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");boot_partition=strtoul(argv[4],0,10);
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);
 memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load(argv[1],&image_size);committed=1;MC6800Init();MC6800Reset();until(60000000);
 unsigned char*r=MC6800GetCpuRam();unsigned work=r[0xbf80]*256+r[0xbf81];
 unsigned expected=r[0xbf82];unsigned mapped=0;
 for(unsigned k=0;k<expected;k++){unsigned char*rec=r+work+512+k*24;if(rec[11]==0)mapped=rec[8];}
 printf("BOOT mapped=%u explicit=%u %s/%s\n",mapped,boot_partition,argv[2],argv[3]);
 require(!fdc_port_accesses,"no floppy ports");return 0;
}
