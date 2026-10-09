// Original BIOS/UniDOS loads the real relocatable HAM.PGM with 8192-byte BSS.
// The HDL test separately checks production CPU, SRAM pads and PAL table RAM.
#include <stdint.h>
static int hg_read_byte(uint16_t a,unsigned char*out);
static int hg_write_byte(uint16_t a,unsigned char d);
#define HG_FIXTURE 1
#define NATIVE_STABILITY_MAIN unused_stability_main
#include "test_native_stability.c"
#undef NATIVE_STABILITY_MAIN

static unsigned char gfx[16],palette[8192],original[8192],components[6144];
static unsigned pal_address,read_mode,version=5,enabled_count,fail_command,jobs,checks;
static uint64_t ready_at;
static unsigned char expected_pixel(unsigned page,unsigned x,unsigned y){
 if(y>=192)return 0;
 unsigned row=y/3,col=x/5,sub=x%5;

 return sub==0?0x80+col:sub==1?0xc0+row:0x40+((row+col)&63);
}
static void check_images(void){
 if(memcmp(palette,components,6144)){fprintf(stderr,"native HAM component tables differ\n");exit(1);}
 for(unsigned p=0;p<1;p++)for(unsigned y=0;y<200;y++)for(unsigned x=0;x<320;x++){
  unsigned got=physical[0x100000+p*65536+y*320+x],want=expected_pixel(p,x,y);
  if(got!=want){fprintf(stderr,"HAM page %u pixel %u,%u got %02x expected %02x\n",p,x,y,got,want);exit(1);}
  checks++;
 }
}
static int hg_read_byte(uint16_t a,unsigned char*out){
 if(a<0xe650||a>0xe65f)return 0;
 *out=a==0xe65e?(read_mode?palette[pal_address]:'G'):a==0xe65f?version:a==0xe650?(gfx[0]|(virtual_cycles<ready_at?128:0)):gfx[a&15];return 1;
}
static int hg_write_byte(uint16_t a,unsigned char d){
 if(a<0xe650||a>0xe65f)return 0;unsigned p=a&15;
 if(p==0){gfx[0]=d&7;if(d&1){enabled_count++;check_images();if(gfx[0]!=7)exit(1);}return 1;}
 if(p==2){pal_address=(pal_address&0x1f00)|d;return 1;}
 if(p==13){pal_address=(pal_address&255)|((d&31)<<8);return 1;}
 if(p==14){palette[pal_address]=d&63;pal_address=(pal_address+1)&8191;return 1;}
 if(p==15){read_mode=d&1;if(d&2)pal_address=(pal_address+1)&8191;return 1;}
 if(virtual_cycles<ready_at){fprintf(stderr,"HAM register write while busy\n");exit(1);}
 gfx[p]=d;if(p!=1)return 1;jobs++;
 unsigned dp=gfx[5],dest=gfx[8]+256*gfx[9],w=gfx[10]+256*gfx[11],h=gfx[12];
 if(d==3){gfx[2]=dp;ready_at=(virtual_cycles/20000+1)*20000;return 1;}
 if(d!=1||!w||w>320||!h||h>200||dp>0||dest+320*(h-1)+w>64000)exit(1);
 if(d==fail_command){gfx[0]|=16;return 1;}
 for(unsigned y=0;y<h;y++)memset(physical+0x100000+dp*65536+dest+y*320,gfx[3],w);
 ready_at=virtual_cycles+w*h/4+10;return 1;
}
static int contains(const char*text){
 unsigned start=crtc[12]*256+crtc[13],stride=crtc[1],step=model_a&&(MC6800GetCpuRam()[0xe629]&2)?2:1;
 unsigned char*r=MC6800GetCpuRam();
 for(unsigned y=0;y<25;y++)for(unsigned x=0;x<stride/step;x++){
  unsigned n;for(n=0;text[n];n++)if(r[(start+y*stride+(x+n)*step+(step==2))&65535]!=(unsigned char)text[n])break;
  if(!text[n])return 1;
 }return 0;
}
static int prompt(void){return PC>=0xf380&&PC<=0xf3a8&&contains("A:\\>");}
static void wait_dos(void){
 uint64_t deadline=virtual_cycles+20000000;
 while(!prompt()&&virtual_cycles<deadline)until(virtual_cycles+10000);
 if(!prompt()||gfx[0]||resets){dump();fprintf(stderr,"HAM did not restore DOS\n");exit(1);}
}
static void command(void){key(0x30);KBDModKeyDown(2);key(0x27);KBDModKeyUp(2);key(0x23);key(0x1e);key(0x32);key(0x1c);}
static void wait_enable(unsigned count){
 uint64_t deadline=virtual_cycles+30000000;
 while(enabled_count<count&&virtual_cycles<deadline)until(virtual_cycles+10000);
 if(enabled_count!=count){fprintf(stderr,"HAM count=%u wanted=%u jobs=%u gfx=%u page=%u ready=%llu\n",enabled_count,count,jobs,gfx[0],gfx[2],(unsigned long long)ready_at);dump();fprintf(stderr,"HAM never enabled\n");exit(1);}
}
static void restored(void){
 if(read_mode||memcmp(palette,original,8192)){fprintf(stderr,"HAM palette not restored\n");exit(1);}
}
static void run_demo(void){
 unsigned before=enabled_count;
 command();wait_enable(before+1);
 if(gfx[0]!=7)exit(1);
 key(0x01);wait_dos();restored();if(!contains("returned to UniDOS"))exit(1);
 printf("PASS %s/HD6303 HAM.PGM: all native component tables, 64000 page bytes, HAM8, ESC/palette restore/native keyboard/PGM BSS/DOS\n",model_a?"601A":"601");fflush(stdout);
}
int main(int argc,char**argv){
 if(argc!=3)return 2;model_a=!strcmp(argv[2],"601a");cpu_hd=1;MC6800SetMachine(PYLDIN_MACHINE_HD6303);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);
 if(n!=0x51a00)return 1;memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,0x51800);free(rom);
 image=load(argv[1],&image_size);memcpy(config+64,image+462,32);
 for(unsigned disk=0;disk<2;disk++){
  unsigned off=462+16*disk,base=32+16*disk;memcpy(config+base,image+off+8,8);
  const unsigned char*bpb=image+le32(config+base)*512;unsigned spt=le16(bpb+24),heads=le16(bpb+26),sectors=le16(bpb+19);
  config[base+8]=spt;config[base+10]=heads;config[base+12]=sectors/(spt*heads);
 }
 committed=1;MC6800Init();MC6800Reset();i=1;until(60000000);key(0x1c);key(0x1c);until(virtual_cycles+1000000);wait_dos();watch_resets=1;
 size_t table_size;unsigned char*table=load("build/ham/components.bin",&table_size);if(table_size!=6144)return 1;memcpy(components,table,6144);free(table);
 for(unsigned a=0;a<8192;a++)original[a]=palette[a]=(a*17+(a>>5)*7)&63;
 run_demo();run_demo();
 version=4;unsigned before=enabled_count;command();wait_dos();restored();if(enabled_count!=before||!contains("FPGA graphics v5"))return 1;version=5;
 cpu_hd=0;MC6800SetMachine(PYLDIN_MACHINE_601);command();wait_dos();restored();if(!contains("HD6303 EXTENSION Y"))return 1;
 cpu_hd=1;MC6800SetMachine(PYLDIN_MACHINE_HD6303);fail_command=1;command();wait_dos();restored();if(!contains("graphics error; palette restored"))return 1;
 key(0x20);key(0x17);key(0x13);key(0x1c);wait_dos();
 printf("PASS %s HAM repeated calls, older FPGA/MC6800 guards, failed FILL palette recovery and DIR; %u checked pixels; zero resets\n",model_a?"601A":"601",checks);return 0;
}
