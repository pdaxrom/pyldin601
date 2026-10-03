// Reproduce DIR -> MON -> repeated U with the original CPU and ROMs.
// Capture a monitor input context for the actual VHDL CPU/SRAM/PS2 test.
#define NATIVE_STABILITY_MAIN native_stability_main
#include "test_native_stability.c"
static void save(const char*path,const void*data,size_t size){
 FILE*f=fopen(path,"wb");if(!f||fwrite(data,1,size,f)!=size)exit(1);fclose(f);
}
static void input_context(void){
 for(unsigned steps=0;steps<1000000;steps++){
  if(PC==0xf39c&&!i)return;
  unsigned cycles=MC6800Step();virtual_cycles+=cycles;
 }
 dump();fprintf(stderr,"Monitor input context not reached\n");exit(1);
}
int main(int argc,char**argv){
 if(argc<2||argc>3)return 2;unsigned dos=argc==3&&!strcmp(argv[2],"dir");
 size_t size;unsigned char*rom=load("build/rom.reference",&size);
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
 key(0x1c);wait_prompt();watch_resets=1;
 for(unsigned cmd=0;cmd<(dos?0:2);cmd++){
  key(0x20);key(0x17);key(0x13);key(0x1c);wait_prompt();
 }
 if(!dos){key(0x32);key(0x18);key(0x31);key(0x1c);until(virtual_cycles+500000);}
 dump();input_context();
 save("build/session-ram.bin",MC6800GetCpuRam(),65536);
 save("build/session-config.bin",config,96);
 FILE*f=fopen("build/session-context.json","w");if(!f)return 1;
 fprintf(f,"{\"pc\":%u,\"sp\":%u,\"a\":%u,\"b\":%u,\"x\":%u,\"cc\":%u,\"page\":%u,\"mode\":%u,\"crtc\":[",PC,SP,A,B,X,0xc0|h*32|i*16|n*8|z*4|v*2|c,page,MC6800GetCpuRam()[0xe629]);
 for(unsigned r=0;r<16;r++)fprintf(f,"%s%u",r?",":"",crtc[r]);fprintf(f,"]}\n");fclose(f);
 unsigned before=fdc_reads;
 if(dos){
  for(unsigned cmd=0;cmd<4;cmd++){
   unsigned reads=fdc_reads;
   key(0x20);key(0x17);key(0x13);key(0x1c);wait_prompt();
   if(fdc_reads==reads)return 1;
  }
 }else{
  KBDModKeyDown(2);
  for(unsigned u=0;u<16;u++){key(0x16);key(0x1c);}
  KBDModKeyUp(2);
 }
 input_context();dump();
 if(resets||(!dos&&fdc_reads!=before)){fprintf(stderr,"Unexpected reset/disk reads in native monitor\n");return 1;}
 save("build/session-expected-ram.bin",MC6800GetCpuRam(),65536);
 save("build/session-expected-crtc.bin",crtc,16);
 unsigned start=crtc[12]*256+crtc[13];unsigned char screen[1000];
 for(unsigned y=0;y<25;y++)memcpy(screen+y*40,MC6800GetCpuRam()+start+y*crtc[1],40);
 save("build/session-screen.bin",screen,1000);
 printf("PASS native %s; zero resets; context SP=%04x\n",dos?"four completed DIR commands":"DIR x2 -> MON -> U x16",SP);
 return 0;
}
