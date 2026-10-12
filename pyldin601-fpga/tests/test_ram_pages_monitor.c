// Execute the shipped monitor breakpoint on native BIOS/UniDOS. Breakpoint
// abandons the SWI frame instead of using RTI; repeated traps must not leak SP.
#define COMPACT_FIXTURE 1
#define DIRECT_SD_FIXTURE 1
#define ROMDISK_MAIN unused_romdisk_main
#include "test_romdisk_unidos.c"
#include "../build/partitions/unibios_labels.h"
#undef ROMDISK_MAIN
int main(int argc,char **argv){
 if(argc!=4)return 2;
 model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char *rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);
 memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load(argv[1],&image_size);committed=1;
 MC6800Init();MC6800Reset();until(60000000);key(0x1c);key(0x1c);prompt_wait();
 unsigned char *monitor=physical+0x10000;
 unsigned entry=0;
 for(unsigned a=0;a<6141;a++)if(monitor[a]==0x30&&monitor[a+1]==0xee&&monitor[a+2]==9){
  require(!entry,"unique monitor frame entry");entry=0xc000+a;
 }
 require(entry!=0,"patched native monitor present");
 unsigned char *r=MC6800GetCpuRam();
 word_at(0xee00,entry);r[0xed80]=(r[0xed80]&15)|0x80;
 for(unsigned run=0;run<32;run++){
  PC=0x210;SP=0x7000;A=0xa5;B=0x5a;X=0x8123;
  i=1;r[0]=0;r[0x210]=0x3f;r[0x211]=0;
  page=4;ram_group=9;
  uint64_t deadline=virtual_cycles+1000000;
  do{until(virtual_cycles+1);require(virtual_cycles<deadline,"monitor trap reaches command loop");}while(PC!=UB_MONITOR0);
  require(SP==0x7000,"monitor discards complete SWI frame without stack leak");
  require(r[0x28]==2&&r[0x29]==0x12,"monitor records correct trapped PC");
  require(r[6]==0xa5&&r[5]==0x5a&&r[7]==0x81&&r[8]==0x23,"monitor retains trapped A/B/X");
  require(!r[0]&&page==8&&!ram_group,"monitor owns ROM page 8/group 0 with balanced inDOS");
 }
 printf("PASS monitor %s/%s: 32 native breakpoints, correct PC/registers, no SWI frame or stack leak\n",argv[2],argv[3]);
 return 0;
}
