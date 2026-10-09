// Real native BIOS, UniDOS file API and PGM relocator. The graphics MMIO model
// checks commands; the separate HDL test runs the same PGM on production RTL.
#include <stdint.h>
static int hg_read_byte(uint16_t a,unsigned char*out);
static int hg_write_byte(uint16_t a,unsigned char d);
#define HG_FIXTURE 1
#define NATIVE_STABILITY_MAIN unused_stability_main
#include "test_native_stability.c"
#undef NATIVE_STABILITY_MAIN

static unsigned char gfx[16];
static uint64_t ready_at;
static unsigned jobs,shown,absent;
static unsigned char palette[8192],previous_palette[8192],palette_mode;
static unsigned palette_address,palette_writes,palette_reads,version=3;
static int hg_read_byte(uint16_t a,unsigned char*out){
 if(a<0xe650||a>0xe65f)return 0;
 if(a==0xe65e&&palette_mode){*out=palette[palette_address];palette_reads++;}
 else *out=a==0xe65e?(absent?255:'G'):a==0xe65f?version:a==0xe650?(gfx[0]|(virtual_cycles<ready_at?128:0)):gfx[a&15];return 1;
}
static int hg_write_byte(uint16_t a,unsigned char d){
 if(a<0xe650||a>0xe65f)return 0;
 unsigned p=a&15;
 if(p==2){palette_address=(palette_address&0x1f00)|d;return 1;}
 if(p==13){palette_address=(palette_address&255)|((d&31)<<8);return 1;}
 if(p==14){palette[palette_address]=d&63;palette_address=(palette_address+1)&8191;palette_writes++;return 1;}
 if(p==15){palette_mode=d&1;if(d&2)palette_address=(palette_address+1)&8191;return 1;}
 if(p==0){gfx[0]=d&1;if(gfx[0])shown++;return 1;}
 if(virtual_cycles<ready_at){fprintf(stderr,"VIEW wrote graphics while busy\n");exit(1);}
 gfx[p]=d;
 if(p==1){
  unsigned page=gfx[5],dest=gfx[8]+256*gfx[9],width=gfx[10]+256*gfx[11],height=gfx[12];
  if(page>15||dest>=64000){fprintf(stderr,"VIEW invalid destination\n");exit(1);}
  unsigned char*buf=physical+0x100000+page*65536;
  if(d==1){
   if(!width||width>320||!height||height>200||dest+320*(height-1)+width>64000){fprintf(stderr,"VIEW invalid FILL\n");exit(1);}
   for(unsigned y=0;y<height;y++)memset(buf+dest+y*320,gfx[3],width);
  }else if(d==4)buf[dest]=gfx[3];else if(d==3)gfx[2]=page;else{fprintf(stderr,"VIEW unexpected command %u\n",d);exit(1);}
  jobs++;ready_at=virtual_cycles+(d==3?20000:d==1?width*height/4+1:10);
 }return 1;
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
static void type_command(const char*text){
 const char*letters="abcdefghijklmnopqrstuvwxyz";
 static const unsigned scans[]={0x1e,0x30,0x2e,0x20,0x12,0x21,0x22,0x23,0x17,0x24,0x25,0x26,0x32,0x31,0x18,0x19,0x10,0x13,0x1f,0x14,0x16,0x2f,0x11,0x2d,0x15,0x2c};
 for(;*text;text++){
  const char*p=strchr(letters,*text);unsigned scan=p?scans[p-letters]:*text=='.'?0x34:*text==' '?0x39:*text==':'?0x27:0;
  if(!scan)exit(2);if(*text==':')KBDModKeyDown(2);key(scan);if(*text==':')KBDModKeyUp(2);
 }key(0x1c);
}
static void finish_prompt(void){
 uint64_t deadline=virtual_cycles+20000000;
 while(!prompt()&&virtual_cycles<deadline)until(virtual_cycles+10000);
 if(!prompt()||gfx[0]||resets||palette_mode||memcmp(palette,previous_palette,8192)){dump();fprintf(stderr,"VIEW failed to restore console/palette\n");exit(1);}
}
static void show(const char*name){
 char cmd[80],path[100];snprintf(cmd,sizeof(cmd),"b:view b:%s.pcx",name);unsigned count=shown;
 type_command(cmd);uint64_t deadline=virtual_cycles+200000000;
 while(shown==count&&virtual_cycles<deadline)until(virtual_cycles+10000);
 if(shown==count){dump();fprintf(stderr,"VIEW did not display %s; jobs=%u\n",name,jobs);exit(1);}
 snprintf(path,sizeof(path),"build/view/%s.indices",name);for(char*p=path+11;*p&&*p!='.';p++)if(*p>='a'&&*p<='z')*p-=32;
 size_t n;unsigned char*expected=load(path,&n);
 unsigned char*actual=physical+0x100000+gfx[2]*65536;
 for(unsigned p=0;p<64000;p++)if(actual[p]!=expected[p]){fprintf(stderr,"VIEW %s pixel %u expected %02x got %02x\n",name,p,expected[p],actual[p]);exit(1);}free(expected);
 snprintf(path,sizeof(path),"build/view/%s.palette",name);for(char*p=path+11;*p&&*p!='.';p++)if(*p>='a'&&*p<='z')*p-=32;
 expected=load(path,&n);if(n!=8192)return exit(1);
 for(unsigned p=0;p<8192;p++)if(abs((int)palette[p]-expected[p])>1||palette[p]==0){fprintf(stderr,"VIEW %s PAL sample %u expected %u got %u\n",name,p,expected[p],palette[p]);exit(1);}free(expected);
 key(0x01);finish_prompt();
 if(!contains("returned to UniDOS")){dump();exit(1);}
 printf("PASS %s/HD6303 native UniDOS VIEW %s: 64000 indices, 8192 RGB888 PAL samples within 1 DAC code, palette restored, PGM/BSS/file API/ESC, zero resets\n",model_a?"601A":"601",name);fflush(stdout);
}
int main(int argc,char**argv){
 if(argc!=3&&argc!=4)return 2;model_a=!strcmp(argv[2],"601a");cpu_hd=1;MC6800SetMachine(PYLDIN_MACHINE_HD6303);
 for(unsigned p=0;p<8192;p++)previous_palette[p]=palette[p]=(p*31+p/32+11)&63;
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);
 if(n!=0x51a00)return 1;memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,0x51800);free(rom);
 image=load(argv[1],&image_size);memcpy(config+64,image+462,32);
 for(unsigned disk=0;disk<2;disk++){
  unsigned off=462+16*disk,base=32+16*disk;memcpy(config+base,image+off+8,8);
  const unsigned char*bpb=image+le32(config+base)*512;unsigned spt=le16(bpb+24),heads=le16(bpb+26),sectors=le16(bpb+19);
  config[base+8]=spt;config[base+10]=heads;config[base+12]=sectors/(spt*heads);
 }
 committed=1;MC6800Init();MC6800Reset();i=1;until(60000000);key(0x1c);key(0x1c);until(virtual_cycles+1000000);
 finish_prompt();watch_resets=1;
 if(argc==4){show(argv[3]);type_command("dir b:");finish_prompt();return 0;}
 show("odd");show("full");show("runs");show("fractal");show("odd");
 const char*bad[]={"planes","bits","width","height","stride","small","pal","zero","cross","cut","short","trunc","wrap","order","bigpad"};
 for(unsigned k=0;k<sizeof(bad)/sizeof(bad[0]);k++){
  char cmd[80];unsigned count=shown;snprintf(cmd,sizeof(cmd),"b:view b:%s.pcx",bad[k]);type_command(cmd);finish_prompt();
  if(shown!=count||(!contains("unsupported or truncated")&&!contains("corrupt or truncated"))){dump();fprintf(stderr,"VIEW accepted bad PCX %s\n",bad[k]);return 1;}
 }
 type_command("b:view b:absent.pcx");finish_prompt();if(!contains("cannot open picture"))return 1;
 type_command("b:view");finish_prompt();if(!contains("Usage: VIEW"))return 1;
 absent=1;type_command("b:view b:odd.pcx");finish_prompt();if(!contains("graphics extension is absent"))return 1;absent=0;
 version=1;type_command("b:view b:odd.pcx");finish_prompt();if(!contains("update FPGA"))return 1;
 version=2;show("odd");version=3;
 cpu_hd=0;MC6800SetMachine(PYLDIN_MACHINE_601);type_command("b:view b:odd.pcx");finish_prompt();if(!contains("enable HD6303"))return 1;
 cpu_hd=1;MC6800SetMachine(PYLDIN_MACHINE_HD6303);show("odd");
 type_command("dir b:");finish_prompt();
 printf("PASS %s VIEW malformed headers/RLE, >64KiB seek, padding, missing file/args/hardware, MC6800 guard, repeated runs and native DIR; %u jobs\n",model_a?"601A":"601",jobs);
 return 0;
}
