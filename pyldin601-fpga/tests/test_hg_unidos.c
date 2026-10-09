// Original BIOS and UniDOS load HG.PGM through their actual PGM relocator.
#include <stdint.h>
static int hg_read_byte(uint16_t a,unsigned char*out);
static int hg_write_byte(uint16_t a,unsigned char d);
#define HG_FIXTURE 1
#define NATIVE_STABILITY_MAIN unused_stability_main
#include "test_native_stability.c"
#undef NATIVE_STABILITY_MAIN

static unsigned char *host_image;static size_t host_size;
static unsigned char tx_fifo[64],rx_fifo[64],header[10],payload[514];
static unsigned tx_read,tx_write,tx_count,rx_read,rx_write,rx_count;
static unsigned hg_control,hg_selected,hg_phase,hg_pos,hg_block,hg_length,hg_operation;
static unsigned hg_reads,hg_writes,hg_times,hg_absent,hg_readonly,hg_corrupt;
static uint32_t hg_next;
static unsigned hg_v2,hg_active;
static unsigned char time_value[6]={0x16,0x69,0x03,0,0x87,0xd9};

static void rx_byte(unsigned char data){
 if(rx_count==64){fprintf(stderr,"fixture RX overflow\n");exit(1);}
 rx_fifo[rx_write++&63]=data;rx_count++;
}
static unsigned char tx_byte(void){
 if(!tx_count){fprintf(stderr,"fixture TX underflow\n");exit(1);}
 tx_count--;return tx_fifo[tx_read++&63];
}
// Functional host credits: an entire packet arrives before the CPU runs again.
// Real TCK framing/status queries are checked independently in mixed HDL.
static void hg_v2_pump(void){
 uint32_t now=MC6800GetCyclesCounter();
 if(!hg_control){hg_active=hg_selected=0;return;}
 if(hg_absent)return;
 if(!hg_active&&(hg_control&1)){hg_active=hg_selected=1;hg_phase=hg_pos=0;hg_next=now+2000;}
 if(!hg_active||(int32_t)(now-hg_next)<0)return;
 hg_next=now+1000;
 if(hg_phase==0&&tx_count){
  header[hg_pos++]=tx_byte();if(hg_pos!=10)return;
  unsigned checksum=0;for(unsigned n=0;n<9;n++)checksum^=header[n];
  if(memcmp(header,"HG\2",3)||header[4]||header[9]!=checksum){fprintf(stderr,"bad native HG v2 header\n");exit(1);}
  hg_operation=header[3];hg_block=le16(header+5);hg_length=le16(header+7);hg_phase=1;hg_pos=0;hg_selected=0;
  if(hg_operation==3){memcpy(payload,time_value,6);hg_times++;}
  else if(hg_operation==1){memcpy(payload,host_image+hg_block*512,hg_length);hg_reads++;}
  if(hg_operation!=2){unsigned sum=0;for(unsigned n=0;n<hg_length;n++)sum+=payload[n];payload[hg_length]=sum;payload[hg_length+1]=(sum>>8)^(hg_corrupt?1:0);}
 }else if(hg_phase==1&&hg_control==27){
  hg_selected=1;rx_byte(hg_readonly&&hg_operation==2?5:0);hg_phase=hg_readonly&&hg_operation==2?4:2;
 }else if(hg_phase==2){
  hg_selected=0;
  unsigned left=hg_length+2-hg_pos,chunk=left<32?left:32;
  if(hg_operation==2&&(hg_control==13||hg_control==45)&&(tx_count>=32||((hg_control&32)&&tx_count>=chunk))){
   for(unsigned n=0;n<chunk;n++)payload[hg_pos++]=tx_byte();
   if(hg_pos==hg_length+2){
    unsigned sum=0;for(unsigned n=0;n<hg_length;n++)sum+=payload[n];
    if(le16(payload+hg_length)!=(sum&65535)){fprintf(stderr,"native v2 WRITE checksum\n");exit(1);}
    memcpy(host_image+hg_block*512,payload,hg_length);hg_writes++;hg_phase=3;
   }
  }else if(hg_operation!=2&&hg_control==11&&rx_count<=32){
   for(unsigned n=0;n<chunk;n++)rx_byte(payload[hg_pos++]);
   if(hg_pos==hg_length+2)hg_phase=4;
  }
 }else if(hg_phase==3&&hg_control==27){hg_selected=1;rx_byte(0);hg_phase=4;}
 else if(hg_phase==4){hg_selected=hg_control==25;}
}
static void hg_pump(void){
 if(hg_v2){hg_v2_pump();return;}
 uint32_t now=MC6800GetCyclesCounter();
 if(hg_absent)return;
 if(!hg_selected&&(hg_control&1)){hg_selected=1;hg_phase=hg_pos=0;hg_next=now+2000;}
 if(!hg_selected||(int32_t)(now-hg_next)<0)return;
 hg_next=now+1000; // byte-completed USB pacing; FIFO tolerates BIOS IRQs
 if(hg_phase==0&&tx_count){
  header[hg_pos++]=tx_byte();if(hg_pos!=10)return;
  unsigned checksum=0;for(unsigned n=0;n<9;n++)checksum^=header[n];
  if(memcmp(header,"HG\1",3)||header[4]||header[9]!=checksum){fprintf(stderr,"bad native HG header\n");exit(1);}
  hg_operation=header[3];hg_block=le16(header+5);hg_length=le16(header+7);hg_phase=1;hg_pos=0;
  if(hg_operation!=3&&(uint64_t)hg_block*512+hg_length>host_size){fprintf(stderr,"native HG range\n");exit(1);}
  if(hg_operation==3){memcpy(payload,time_value,6);hg_times++;}
  else if(hg_operation==1){memcpy(payload,host_image+hg_block*512,hg_length);hg_reads++;}
  if(hg_operation!=2){unsigned sum=0;for(unsigned n=0;n<hg_length;n++)sum+=payload[n];payload[hg_length]=sum;payload[hg_length+1]=(sum>>8)^(hg_corrupt?1:0);}
 }else if(hg_phase==1&&(hg_control&2)){
  rx_byte(hg_readonly&&hg_operation==2?5:0);hg_phase=hg_readonly&&hg_operation==2?4:2;
 }else if(hg_phase==2){
  if(hg_operation==2&&tx_count){
   payload[hg_pos++]=tx_byte();if(hg_pos==hg_length+2){
    unsigned sum=0;for(unsigned n=0;n<hg_length;n++)sum+=payload[n];
    if(le16(payload+hg_length)!=(sum&65535)){fprintf(stderr,"native WRITE checksum\n");exit(1);}
    memcpy(host_image+hg_block*512,payload,hg_length);hg_writes++;hg_phase=3;
   }
  }else if(hg_operation!=2&&(hg_control&2)&&rx_count<64){
   rx_byte(payload[hg_pos++]);if(hg_pos==hg_length+2)hg_phase=4;
  }
 }else if(hg_phase==3&&(hg_control&2)){rx_byte(0);hg_phase=4;}
 else if(hg_phase==4&&!(hg_control&1)){hg_selected=0;}
}
static int hg_read_byte(uint16_t a,unsigned char*out){
 if(a<0xe670||a>0xe673)return 0;hg_pump();
 switch(a&3){
 case 0:*out=rx_count?rx_fifo[rx_read++&63]:255;if(rx_count)rx_count--;break;
 case 1:*out=(hg_v2?16:0)|(rx_count!=0)|(tx_count<64?2:0)|(hg_selected?4:0)|(tx_count==0?8:0);break;
 case 2:*out=hg_control;break;default:*out='H';
 }return 1;
}
static int hg_write_byte(uint16_t a,unsigned char d){
 if(a<0xe670||a>0xe673)return 0;hg_pump();
 if(a==0xe670){if(tx_count==64){fprintf(stderr,"native TX overflow\n");exit(1);}tx_fifo[tx_write++&63]=d;tx_count++;}
 if(a==0xe672){
  if(d&128){tx_read=tx_write=tx_count=rx_read=rx_write=rx_count=0;}
  hg_control=d&(hg_v2?63:7);
 }return 1;
}
static int contains(const char*text){
 unsigned start=crtc[12]*256+crtc[13],stride=crtc[1];
 unsigned step=model_a&&(MC6800GetCpuRam()[0xe629]&2)?2:1,attribute=step==2;
 unsigned char*r=MC6800GetCpuRam();
 for(unsigned y=0;y<25;y++)for(unsigned x=0;x<stride/step;x++){
  unsigned n;for(n=0;text[n];n++)if(r[(start+y*stride+x*step+n*step+attribute)&65535]!=(unsigned char)text[n])break;
  if(!text[n])return 1;
 }return 0;
}
static int native_prompt(void){
 unsigned cursor=crtc[14]*256+crtc[15],step=model_a&&(MC6800GetCpuRam()[0xe629]&2)?2:1;
 unsigned char*r=MC6800GetCpuRam();
 for(unsigned gap=4;gap<=12;gap++){
  unsigned pos=(cursor-gap*step+(step==2))&65535;
  if(r[pos]=='A'&&r[(pos+step)&65535]==':'&&r[(pos+2*step)&65535]=='\\'&&r[(pos+3*step)&65535]=='>')return 1;
 }
 return 0;
}
static void command(const char*text){
 for(;*text;text++){
  const char*letters="abcdefghijklmnopqrstuvwxyz";
  static const unsigned scans[]={0x1e,0x30,0x2e,0x20,0x12,0x21,0x22,0x23,0x17,0x24,0x25,0x26,0x32,0x31,0x18,0x19,0x10,0x13,0x1f,0x14,0x16,0x2f,0x11,0x2d,0x15,0x2c};
  const char*p=strchr(letters,*text);unsigned scan=p?scans[p-letters]:*text=='.'?0x34:*text==' '?0x39:*text==':'?0x27:0;
  if(!scan)exit(2);if(*text==':')KBDModKeyDown(2);key(scan);if(*text==':')KBDModKeyUp(2);until(virtual_cycles+300000);
 }key(0x1c);until(virtual_cycles+1000000);
 uint64_t deadline=virtual_cycles+200000000;
 while(!native_prompt()&&virtual_cycles<deadline)until(virtual_cycles+10000);
 if(!native_prompt()){dump();fprintf(stderr,"HG command timeout\n");exit(1);}
 until(virtual_cycles+100000);

}
static void capture_hg(void){
 unsigned char*r=MC6800GetCpuRam();
 const char*paths[]={"build/hgdisk-ram.bin","build/hgdisk-expected-ram.bin","build/hgdisk-config.bin"};
 for(unsigned n=0;n<3;n++){
  FILE*f=fopen(paths[n],"wb");unsigned size=n==2?96:65536;
  if(!f||fwrite(n==2?config:r,1,size,f)!=size||fclose(f))exit(1);
 }
 FILE*f=fopen("build/hgdisk-context.json","w");if(!f)exit(1);
 fprintf(f,"{\"model_a\":%u,\"pc\":256,\"sp\":%u,\"a\":0,\"b\":0,\"x\":0,\"cc\":192,\"page\":%u,\"mode\":%u,\"crtc\":[",model_a,SP,page,r[0xe629]);
 for(unsigned n=0;n<16;n++)fprintf(f,"%s%u",n?",":"",crtc[n]);fprintf(f,"]}\n");fclose(f);
}
static void direct_io(unsigned op,unsigned block_number,unsigned expected){
 unsigned char*r=MC6800GetCpuRam();unsigned table=0x300,buf=0x4000;
 r[table]=buf>>8;r[table+1]=buf;r[table+2]=4;r[table+3]=block_number>>8;r[table+4]=block_number;
 const unsigned char code[]={0xce,3,0,0x86,0,0x3f,0x40,0x01};
 memcpy(r+0x100,code,sizeof(code));r[0x104]=op;PC=0x100;
 uint64_t deadline=virtual_cycles+20000000;
 while(PC!=0x107&&virtual_cycles<deadline)until(virtual_cycles+1);
 if(PC!=0x107||A!=expected){dump();fprintf(stderr,"HG INT40 op=%u block=%u failed A=%u expected=%u phase=%u ctrl=%u\n",op,block_number,A,expected,hg_phase,hg_control);exit(1);}
}
int main(int argc,char**argv){
 if(argc!=4&&argc!=5)return 2;hg_v2=argc==5&&!strcmp(argv[4],"v2");model_a=!strcmp(argv[3],"601a");MC6800SetMachine(PYLDIN_MACHINE_601);
 size_t size;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&size);
 if(size!=0x51a00)return 1;memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,0x51800);free(rom);
 image=load(argv[1],&image_size);host_image=load(argv[2],&host_size);memcpy(config+64,image+462,32);
 for(unsigned disk=0;disk<2;disk++){
  unsigned off=462+16*disk,base=32+16*disk;memcpy(config+base,image+off+8,8);
  const unsigned char*bpb=image+le32(config+base)*512;unsigned spt=le16(bpb+24),heads=le16(bpb+26),sectors=le16(bpb+19);
  config[base+8]=spt;config[base+10]=heads;config[base+12]=sectors/(spt*heads);
 }
 // Fixed host local time: 2026-10-08 19:14:25.44, exact HG v1 encoding.
 unsigned date=(1u<<14)|(10u<<10)|(8u<<5)|22u,ticks_value=(19*3600+14*60+25)*50+22;
 time_value[0]=date;time_value[1]=date>>8;time_value[2]=ticks_value>>16;time_value[3]=ticks_value>>24;
 time_value[4]=ticks_value;time_value[5]=ticks_value>>8;
 committed=1;MC6800Init();MC6800Reset();i=1;
 until(60000000);key(0x1c);key(0x1c);until(virtual_cycles+1000000);
 if(!contains("A:\\>")){dump();return 1;}watch_resets=1;
 command("b:hg");
 if(!contains("HG 2.0 remote disk E:")||!contains("host date/time synchronized")){dump();return 1;}
 unsigned char*r=MC6800GetCpuRam();
 if(r[0x1c]!=8||r[0x1d]!=10||r[0x1e]!=7||r[0x1f]!=0xea||r[0x1b]!=19||r[0x1a]!=14){fprintf(stderr,"HG date/time conversion mismatch: %02x %02x %02x %02x %02x %02x\n",r[0x1c],r[0x1d],r[0x1e],r[0x1f],r[0x1b],r[0x1a]);return 1;}
 capture_hg();
 const char*commands[]={"dir e:","copy e:hello.txt a:hgtest.txt","copy e:last.txt a:last.txt","copy a:hgtest.txt e:back.txt","copy e:hello.txt e:temp.txt","del e:temp.txt","b:hgtime","dir e:"};
 for(unsigned n=0;n<sizeof(commands)/sizeof(commands[0]);n++){
  command(commands[n]);if(!contains("A:\\>")||contains("Unknown error")||contains("Bad command")||contains("Path not found")||contains("File not found")||resets){dump();fprintf(stderr,"HG command failed: %s\n",commands[n]);return 1;}
 }
 unsigned last=(host_size/512)-1;
 for(unsigned n=0;n<512;n++)host_image[last*512+n]=n^0xa5;
 direct_io(1,last,0);if(memcmp(r+0x4000,host_image+last*512,512))return 1;
 for(unsigned n=0;n<512;n++)r[0x4000+n]=n^0x5a;
 direct_io(2,last,0);if(memcmp(r+0x4000,host_image+last*512,512))return 1;
 hg_readonly=1;direct_io(2,last,1);hg_readonly=0;
 hg_corrupt=1;direct_io(1,last,4);hg_corrupt=0;
 hg_absent=1;direct_io(1,last,0x40);hg_absent=0;
 direct_io(1,last,0);if(memcmp(r+0x4000,host_image+last*512,512))return 1;
 FILE*f=fopen("build/hg-host-after.img","wb");if(!f||fwrite(host_image,1,host_size,f)!=host_size||fclose(f))return 1;
 f=fopen("build/hg-sd-after.img","wb");if(!f||fwrite(image,1,image_size,f)!=image_size||fclose(f))return 1;
 printf("PASS %s/MC6800 HG v%u native UniDOS loaded relocatable HG.PGM, registered E, copied/deleted files, TIME; last sector %u read/write; read-only, bad checksum, absent-host timeout and recovery; %u reads/%u writes/%u TIME, zero resets\n",model_a?"601A":"601",hg_v2?2:1,last,hg_reads,hg_writes,hg_times);
 return 0;
}
