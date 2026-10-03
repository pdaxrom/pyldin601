// Real classic/601A BIOS and UniDOS load and execute the test files on B.
#define NATIVE_STABILITY_MAIN unused_stability_main
#include "test_native_stability.c"
#undef NATIVE_STABILITY_MAIN

static int contains(const char *text){
 unsigned start=crtc[12]*256+crtc[13],stride=crtc[1];
 unsigned step=model_a&&(MC6800GetCpuRam()[0xe629]&2)?2:1,attribute=step==2;
 const unsigned char *ram=MC6800GetCpuRam();
 for(unsigned row=0;row<25;row++)for(unsigned col=0;col<stride/step;col++){
  unsigned n;for(n=0;text[n];n++)if(ram[(start+row*stride+col*step+n*step+attribute)&65535]!=(unsigned char)text[n])break;
  if(!text[n])return 1;
 }return 0;
}
static void send_text(const char *text){
 for(;*text;text++){
  unsigned scan=0;int shifted=0;
  switch(*text){case 'b':scan=0x30;break;case ':':scan=0x27;shifted=1;break;
   case 'h':scan=0x23;break;case 'd':scan=0x20;break;case 't':scan=0x14;break;
   case 'e':scan=0x12;break;case 's':scan=0x1f;break;case 'm':scan=0x32;break;
   case 'u':scan=0x16;break;case 'l':scan=0x26;break;case 'i':scan=0x17;break;case 'p':scan=0x19;break;
   case 'r':scan=0x13;break;default:fprintf(stderr,"unsupported input\n");exit(2);}
  if(shifted)KBDModKeyDown(2);key(scan);if(shifted)KBDModKeyUp(2);
 }key(0x1c);
}
int main(int argc,char**argv){
 if(argc<2||argc>3)return 2;model_a=argc==3&&!strcmp(argv[2],"601a");cpu_hd=1;
 MC6800SetMachine(PYLDIN_MACHINE_HD6303);
 size_t size;unsigned char *rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&size);
 if(size!=0x51a00)return 1;
 memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,0x51800);free(rom);
 image=load(argv[1],&image_size);memcpy(config+64,image+462,32);
 for(unsigned disk=0;disk<2;disk++){
  unsigned off=462+16*disk,base=32+16*disk;memcpy(config+base,image+off+8,8);
  const unsigned char*bpb=image+le32(config+base)*512;
  unsigned spt=le16(bpb+24),heads=le16(bpb+26),sectors=le16(bpb+19);
  config[base+8]=spt;config[base+9]=0;config[base+10]=heads;config[base+11]=0;
  config[base+12]=sectors/(spt*heads);config[base+13]=0;
 }
 committed=1;MC6800Init();MC6800Reset();i=1;
 until(60000000);key(0x1c);key(0x1c);until(virtual_cycles+1000000);
 if(!contains("A:\\>")){dump();fprintf(stderr,"missing initial DOS prompt\n");return 1;}
 watch_resets=1;
 const char*commands[]={"b:hdtest","b:hdmul","b:hdsleep"};
 const char*results[]={"PASS HDTEST: 740 cases","PASS HDMUL: 65536 products","PASS HDSLEEP: 64 wakes"};
 for(unsigned n=0;n<3;n++){
  unsigned reads=fdc_reads;send_text(commands[n]);until(virtual_cycles+20000000);
  if(!contains(results[n])||contains("FAIL HD")||fdc_reads==reads||resets){dump();fprintf(stderr,"UniDOS %s failed\n",commands[n]);return 1;}
  // A further directory command proves the program returned to DOS.
  reads=fdc_reads;send_text("dir");until(virtual_cycles+20000000);
  if(!contains("File(s)")||!contains("A:\\>")||fdc_reads==reads){dump();fprintf(stderr,"DOS did not resume\n");return 1;}
  printf("PASS %s/HD6303 UniDOS loaded %s from B, program passed and DIR resumed\n",model_a?"601A":"601",commands[n]);fflush(stdout);
 }
 return 0;
}
