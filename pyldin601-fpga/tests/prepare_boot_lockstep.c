// Instruction-by-instruction reference for the unmodified classic BIOS/ROM.
#define main firmware_boot_main
#include "../build/lockstep-devices.inc"
#undef main
int main(int argc,char **argv){
 if(argc!=2)return 2;
 size_t size;unsigned char*rom=load("build/rom.reference",&size);
 if(size!=0x51a00)return 1;
 memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,0x51800);free(rom);
 image=load(argv[1],&image_size);memcpy(config+64,image+462,32);
 for(unsigned d=0;d<2;d++){
  unsigned off=462+16*d,base=32+16*d;memcpy(config+base,image+off+8,8);
  const unsigned char*bpb=image+le32(config+base)*512;
  unsigned spt=le16(bpb+24),heads=le16(bpb+26),sectors=le16(bpb+19);
  config[base+8]=spt;config[base+9]=0;config[base+10]=heads;config[base+11]=0;
  config[base+12]=sectors/(spt*heads);config[base+13]=0;
 }
 committed=1;MC6800Init();memset(MC6800GetCpuRam(),0,65536);MC6800Reset();
 // The classic C reset leaves I=0. Hardware reset sets I=1 (Motorola
 // MC6800 datasheet); correct that reference entry state, not ROM code.
 i=1;
 FILE*f=fopen("build/boot-lockstep-registers.mem","w");
 io_trace=fopen("build/boot-lockstep-io.mem","w");if(!f||!io_trace)return 1;
 for(unsigned step=0;step<=500000;step++){
  unsigned flags=0xc0|h*32|i*16|n*8|z*4|v*2|c;
  fprintf(f,"%04x%04x%04x%02x%02x%02x\n",PC,SP,X,A,B,flags);
  if(step<500000)MC6800Step();
 }
 fclose(f);fclose(io_trace);io_trace=NULL;
 f=fopen("build/boot-lockstep-base.mem","w");if(!f)return 1;
 for(unsigned a=0;a<65536;a++)fprintf(f,"%02x\n",MC6800GetCpuRam()[a]);fclose(f);
 printf("Prepared 500000 real BIOS instructions PC=%04x SP=%04x, no IRQ/keyboard injections\n",PC,SP);
 return 0;
}
