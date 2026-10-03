// Execute the standalone diagnostic on the original classic MC6800 core.
// Reuse only the device/memory model from the boot firmware test.
#define main firmware_boot_main
#include "test_firmware.c"
#undef main
int main(int argc,char**argv){
 size_t n;unsigned char*b=load("build/sram-test.bin",&n);if(n!=4096)return 2;
 memcpy(resident,b,n);free(b);MC6800Init();memset(physical,0xcc,sizeof(physical));
 memset(MC6800GetCpuRam(),0xcc,65536);MC6800Reset();
 unsigned fault=argc>1;uint32_t fault_address=0x1fffff;
 // Inject into the last byte immediately after the diagnostic fills its range.
 // Thus both byte lanes and the complete high address range have been written.
 unsigned injected=0;unsigned long long steps=0;
 while(debug!=0xd1&&debug!=0xee&&steps++<1000000000ULL){
  if(fault&&!injected&&all_writes==2086912){physical[fault_address]^=0x80;injected=1;}
  MC6800Step();
 }
 if(fault){
  const unsigned char*ram=MC6800GetCpuRam();
  if(!injected||debug!=0xee||memcmp(ram+0x630,"FAIL AT 1FFFFF EXPECT 55 GOT D5",29)){
   fprintf(stderr,"diagnostic failed to report fault pc=%04x debug=%02x\n",PC,debug);return 1;}
  puts("PASS SRAM diagnostic reports last-byte corruption with physical address/expected/actual");return 0;
 }
 if(debug!=0xd1||all_writes!=2086912*5||aperture_reads!=all_writes){
  fprintf(stderr,"SRAM diagnostic failed pc=%04x debug=%02x writes=%u reads=%u steps=%llu\n",PC,debug,all_writes,aperture_reads,steps);return 1;}
 for(unsigned a=0x2000;a<sizeof(physical);a++){
  unsigned char actual=a<65536?MC6800GetCpuRam()[a]:physical[a];
  unsigned char expected=a>=0x61000&&a<0x61800?0xcc:a>>16;
  if(actual!=expected){fprintf(stderr,"diagnostic final memory mismatch at %06x\n",a);return 1;}
 }
 if(memcmp(MC6800GetCpuRam()+0x5e0,"ALL FIVE PATTERNS OK. ROUNDS 0001",31))return 1;
 printf("PASS original MC6800 executes five complete SRAM patterns: 2038 KiB, %u writes + %u readbacks, %llu steps\n",all_writes,aperture_reads,steps);
 return 0;
}
