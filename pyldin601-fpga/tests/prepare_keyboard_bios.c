// Capture either original BIOS inside UniDOS's keyboard input routine.
#define NATIVE_STABILITY_MAIN native_stability_main
#include "test_native_stability.c"
static void save_keyboard(const char *path,const void *data,size_t n){
 FILE *f=fopen(path,"wb");if(!f||fwrite(data,1,n,f)!=n||fclose(f))exit(1);
}
int main(int argc,char **argv){
 if(argc!=3)return 2;
 model_a=!strcmp(argv[2],"601a");
 size_t size;unsigned char *rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&size);
 memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,0x51800);free(rom);
 image=load(argv[1],&image_size);memcpy(config+64,image+462,32);
 for(unsigned d=0;d<2;d++){
  unsigned off=462+16*d,base=32+16*d;memcpy(config+base,image+off+8,8);
  const unsigned char *bpb=image+le32(config+base)*512;
  unsigned spt=le16(bpb+24),heads=le16(bpb+26),sectors=le16(bpb+19);
  config[base+8]=spt;config[base+9]=0;config[base+10]=heads;config[base+11]=0;
  config[base+12]=sectors/(spt*heads);config[base+13]=0;
 }
 committed=1;MC6800Init();MC6800Reset();until(60000000);key(0x1c);until(62000000);
 const unsigned char *ram=MC6800GetCpuRam();
 unsigned entry=ram[0xee22]*256+ram[0xee23],input_pc=0;
 for(unsigned p=entry;p<entry+96;p++){
  const unsigned char *code=physical+0x60000+p-0xf000;
  if(code[0]==0x0e&&code[1]==0x01&&code[2]==0x0f){input_pc=p+2;break;}
 }
 for(unsigned steps=0;steps<1000000&&(PC!=input_pc||i);steps++)MC6800Step();
 if(!input_pc||PC!=input_pc||i){dump();return 1;}
 save_keyboard("build/keyboard-ram.bin",ram,65536);
 save_keyboard("build/keyboard-expected-ram.bin",ram,65536);
 save_keyboard("build/keyboard-config.bin",config,96);
 FILE *f=fopen("build/keyboard-context.json","w");if(!f)return 1;
 fprintf(f,"{\"model_a\":%u,\"pc\":%u,\"sp\":%u,\"a\":%u,\"b\":%u,\"x\":%u,\"cc\":%u,\"page\":%u,\"mode\":%u,\"crtc\":[",model_a,PC,SP,A,B,X,0xc0|h*32|i*16|n*8|z*4|v*2|c,page,ram[0xe629]);
 for(unsigned r=0;r<16;r++)fprintf(f,"%s%u",r?",":"",crtc[r]);fprintf(f,"]}\n");fclose(f);
 printf("Prepared native %s DOS keyboard context PC=%04x SP=%04x\n",model_a?"601A":"601",PC,SP);
 return 0;
}
