// Capture a real DOS time-input context from the original emulator. This lets
// mixed HDL test the actual BIOS IRQ without simulating a minute of disk boot.
#define NATIVE_STABILITY_MAIN native_stability_main
#include "test_native_stability.c"
static void save(const char*path,const void*data,size_t n){FILE*f=fopen(path,"wb");if(!f||fwrite(data,1,n,f)!=n)exit(1);fclose(f);}
int main(int argc,char**argv){
 if(argc<2||argc>3)return 2;size_t size;unsigned char*rom=load("build/rom.reference",&size);
 memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,0x51800);free(rom);
 image=load(argv[1],&image_size);memcpy(config+64,image+462,32);
 for(unsigned d=0;d<2;d++){
  unsigned off=462+16*d,base=32+16*d;memcpy(config+base,image+off+8,8);
  const unsigned char*bpb=image+le32(config+base)*512;
  unsigned spt=le16(bpb+24),heads=le16(bpb+26),sectors=le16(bpb+19);
  config[base+8]=spt;config[base+9]=0;config[base+10]=heads;config[base+11]=0;
  config[base+12]=sectors/(spt*heads);config[base+13]=0;
 }
 committed=1;MC6800Init();MC6800Reset();until(60000000);key(0x1c);until(62000000);
 for(unsigned steps=0;steps<1000000&&(PC!=0xf39c||i);steps++){
  unsigned cycles=MC6800Step();virtual_cycles+=cycles;
 }
 if(PC!=0xf39c||i){dump();return 1;}
 const word input_sp=SP; // DOS allocation depends on the available drives.
 if(argc==3){
  // Native BIOS clock structure: centiseconds, seconds, minutes, hours.
  // Cross the two-hour boundary on the first tick, without changing ROM.
  MC6800GetCpuRam()[0x18]=98;MC6800GetCpuRam()[0x19]=59;
  MC6800GetCpuRam()[0x1a]=59;MC6800GetCpuRam()[0x1b]=1;
 }
 save("build/runtime-ram.bin",MC6800GetCpuRam(),65536);
 save("build/runtime-config.bin",config,96);
 FILE*f=fopen("build/runtime-context.json","w");
 fprintf(f,"{\"pc\":%u,\"sp\":%u,\"a\":%u,\"b\":%u,\"x\":%u,\"cc\":%u,\"page\":%u,\"mode\":%u,\"crtc\":[",PC,SP,A,B,X,0xc0|h*32|i*16|n*8|z*4|v*2|c,page,MC6800GetCpuRam()[0xe629]);
 for(unsigned r=0;r<16;r++)fprintf(f,"%s%u",r?",":"",crtc[r]);fprintf(f,"]}\n");fclose(f);
 // Reference changes from twenty complete IRQ handlers, without software
 // model patches to the IRQ code or the clock variables.
 unsigned irqs=0;while(irqs<20){
  if(!i&&PC==0xf39c&&SP==input_sp){tick=128;MC6800SetInterrupt(1);irqs++;}
  MC6800Step();
 }
 while(i||SP!=input_sp)MC6800Step();
 save("build/runtime-expected-ram.bin",MC6800GetCpuRam(),65536);
 printf("Prepared DOS input context PC=%04x SP=%04x and twenty native BIOS IRQ handlers\n",PC,SP);
 return 0;
}
