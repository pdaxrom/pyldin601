// Run the original BIOS and original keyboard emulator against the DRB model.
#define main firmware_boot_main
#include "test_firmware.c"
#undef main

static void run_bios(unsigned steps){
 for(unsigned n=0;n<steps;n++){
  // Let the reset path establish its stack before the first external IRQ.
  if(n%5000==4999){tick=128;KBDUpdate();MC6800SetInterrupt(1);}
  MC6800Step();
 }
}
static void switch_key(unsigned scan,unsigned old,unsigned caps){
 KBDKeyDown(scan);
 // The original BIOS can be inside a floppy retry while the key is pending.
 for(unsigned n=0;n<2000000;n++){
  if(n%5000==0){tick=128;KBDUpdate();MC6800SetInterrupt(1);}
  MC6800Step();
  if((caps?caps_off:(MC6800GetCpuRam()[0xe629]&1))!=old)break;
 }
 if((caps?caps_off:(MC6800GetCpuRam()[0xe629]&1))==old){
  fprintf(stderr,"BIOS did not toggle scan %02x pc=%04x\n",scan,PC);exit(1);
 }
 unsigned changed=caps?caps_off:(MC6800GetCpuRam()[0xe629]&1);
 KBDKeyUpCode(scan);run_bios(2000000);
 if((caps?caps_off:(MC6800GetCpuRam()[0xe629]&1))!=changed){
  fprintf(stderr,"release toggled BIOS a second time\n");exit(1);
 }
}
int main(void){
 size_t size;unsigned char*rom=load("build/rom.reference",&size);
 if(size!=0x51a00)return 1;
 memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,0x51800);free(rom);
 image=load("build/test-sd.img",&image_size);memcpy(config+64,image+462,32);
 committed=1;MC6800Init();MC6800Reset();run_bios(2000000);
 if(!(MC6800GetCpuRam()[0xe629]&1)||cyrMode){
  fprintf(stderr,"BIOS lost initial Latin layout mode=%02x pc=%04x\n",MC6800GetCpuRam()[0xe629],PC);return 1;
 }
 unsigned video=MC6800GetCpuRam()[0xe629]&0xfe;
 switch_key(0x46,1,0);if(cyrMode!=4)return 1;
 switch_key(0x46,0,0);if(cyrMode!=0)return 1;
 if((MC6800GetCpuRam()[0xe629]&0xfe)!=video)return 1;
 unsigned initial_caps=caps_off;
 switch_key(0x3a,initial_caps,1);switch_key(0x3a,!initial_caps,1);
 switch_key(0x46,1,0);MC6800Reset();run_bios(2000000);
 if(!(MC6800GetCpuRam()[0xe629]&1)||cyrMode)return 1;
 puts("PASS original UniBIOS Latin startup/reset, FB LAT/CYR twice, FC Caps twice and preserved video bits");
 return 0;
}
