// Run the original BIOS and original keyboard emulator against the DRB model.
#define NATIVE_STABILITY_MAIN unused_stability_main
#include "test_native_stability.c"
#undef NATIVE_STABILITY_MAIN

static void run_bios(unsigned cycles){until(virtual_cycles+cycles);}
static void switch_key(unsigned scan,unsigned old,unsigned caps){
 KBDKeyDown(scan);
 uint64_t deadline=virtual_cycles+2000000;
 while(virtual_cycles<deadline){
  until(virtual_cycles+100);
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
 image=load("images/sd.img",&image_size);memcpy(config+64,image+462,32);
 committed=1;MC6800Init();MC6800Reset();run_bios(60000000);
 key(0x1c);key(0x1c);wait_prompt();
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
