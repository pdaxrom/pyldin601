// Original BIOS and UniDOS load HG.PGM through their actual PGM relocator.
#include <stdint.h>
#include "../host/hg/hg.h"
static int hg_read_byte(uint16_t a,unsigned char*out);
static int hg_write_byte(uint16_t a,unsigned char d);
#define HG_FIXTURE 1
#define NATIVE_STABILITY_MAIN unused_stability_main
#include "test_native_stability.c"
#undef NATIVE_STABILITY_MAIN

static unsigned hg_drive;
#include "hg_transport.h"
static int hg_read_byte(uint16_t a,unsigned char*out){return hg_transport_read(a,out);}
static int hg_write_byte(uint16_t a,unsigned char d){return hg_transport_write(a,d);}
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
  char character=(*text=='e'&&text[1]==':')?'a'+hg_drive:*text;
  const char*p=strchr(letters,character);unsigned scan=p?scans[p-letters]:*text=='.'?0x34:*text==' '?0x39:*text==':'?0x27:*text=='*'?0x09:*text=='\\'?0x2b:*text=='_'?0x0c:0;
  if(!scan)exit(2);if(*text==':'||*text=='*'||*text=='_')KBDModKeyDown(2);key(scan);if(*text==':'||*text=='*'||*text=='_')KBDModKeyUp(2);until(virtual_cycles+300000);
 }key(0x1c);until(virtual_cycles+1000000);
 uint64_t deadline=virtual_cycles+800000000;
 while(!native_prompt()&&virtual_cycles<deadline)until(virtual_cycles+10000);
 if(!native_prompt()){dump();fprintf(stderr,"A=%02x B=%02x X=%04x CC=%u/%u/%u/%u/%u/%u heap=%02x%02x pcbytes=",A,B,X,h,i,n,z,v,c,MC6800GetCpuRam()[0xee1a],MC6800GetCpuRam()[0xee1b]);for(unsigned j=0;j<24;j++)fprintf(stderr,"%02x ",MC6800GetCpuRam()[(PC+j)&65535]);fprintf(stderr,"\nCOPY buffer=%02x%02x size=%02x%02x, lomem/himem=%02x%02x/%02x%02x\n",MC6800GetCpuRam()[0xece1],MC6800GetCpuRam()[0xece2],MC6800GetCpuRam()[0xece3],MC6800GetCpuRam()[0xece4],MC6800GetCpuRam()[0xee1c],MC6800GetCpuRam()[0xee1d],MC6800GetCpuRam()[0xee1e],MC6800GetCpuRam()[0xee1f]);fprintf(stderr,"HG command timeout phase=%u pos=%u op=%u len=%u block=%u control=%u active=%u selected=%u tx=%u rx=%u now=%u next=%u reads=%u writes=%u\n",hg_phase,hg_pos,hg_operation,hg_length,hg_block,hg_control,hg_active,hg_selected,tx_count,rx_count,MC6800GetCyclesCounter(),hg_next,hg_reads,hg_writes);exit(1);}
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
 fprintf(f,"{\"model_a\":%u,\"pc\":256,\"sp\":%u,\"a\":0,\"b\":0,\"x\":0,\"cc\":192,\"page\":%u,\"mode\":%u,\"hg_drive\":%u,\"crtc\":[",model_a,SP,page,r[0xe629],hg_drive);
 for(unsigned n=0;n<16;n++)fprintf(f,"%s%u",n?",":"",crtc[n]);fprintf(f,"]}\n");fclose(f);
}
static void live_host_update(const char*text,unsigned repeats){
 HgFiles files={0};if(hg_fat_files(host_image,host_size,&files)<0)exit(1);
 HgFile*file=hg_find(&files,"LIVE.TXT");
 if(!file){HgFile f={0};strcpy(f.name,"LIVE.TXT");strcpy(f.host,"LIVE.TXT");f.attr=0x20;f.date=0x5d49;if(hg_file_copy(&files,&f)<0)exit(1);file=hg_find(&files,"LIVE.TXT");}
 free(file->data);unsigned n=strlen(text);file->size=n*repeats;file->data=malloc(file->size);if(!file->data)exit(1);
 for(unsigned i=0;i<repeats;i++)memcpy(file->data+i*n,text,n);
 if(hg_fat_update(host_image,host_size,&files)<0)exit(1);hg_files_free(&files);
}
static void direct_io(unsigned op,unsigned block_number,unsigned expected){
 unsigned char*r=MC6800GetCpuRam();unsigned table=0x300,buf=0x4000;
 r[table]=buf>>8;r[table+1]=buf;r[table+2]=hg_drive;r[table+3]=block_number>>8;r[table+4]=block_number;
 const unsigned char code[]={0xce,3,0,0x86,0,0x3f,0x40,0x01};
 memcpy(r+0x100,code,sizeof(code));r[0x104]=op;PC=0x100;
 uint64_t deadline=virtual_cycles+20000000;
 while(PC!=0x107&&virtual_cycles<deadline)until(virtual_cycles+1);
 if(PC!=0x107||A!=expected){dump();fprintf(stderr,"HG INT40 op=%u block=%u failed A=%u expected=%u phase=%u ctrl=%u\n",op,block_number,A,expected,hg_phase,hg_control);exit(1);}
}
#ifndef HG_UNIDOS_MAIN
#define HG_UNIDOS_MAIN main
#endif
int HG_UNIDOS_MAIN(int argc,char**argv){
 if(argc!=4&&argc!=5)return 2;hg_v2=argc==5&&!strcmp(argv[4],"v2");model_a=!strcmp(argv[3],"601a");MC6800SetMachine(PYLDIN_MACHINE_601);
 size_t size;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&size);
 if(size!=(ROM_BYTES+512))return 1;memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load(argv[1],&image_size);host_image=load(argv[2],&host_size);
 // Fixed host local time: 2026-10-08 19:14:25.44, exact HG v1 encoding.
 unsigned date=(1u<<14)|(10u<<10)|(8u<<5)|22u,ticks_value=(19*3600+14*60+25)*50+22;
 time_value[0]=date;time_value[1]=date>>8;time_value[2]=ticks_value>>16;time_value[3]=ticks_value>>24;
 time_value[4]=ticks_value;time_value[5]=ticks_value>>8;
 committed=1;MC6800Init();MC6800Reset();i=1;
 until(60000000);key(0x1c);key(0x1c);until(virtual_cycles+1000000);
 if(!contains("A:\\>")){dump();return 1;}watch_resets=1;
 unsigned char*r=MC6800GetCpuRam();
 hg_drive=0;while(hg_drive<8&&(r[0xeb03+hg_drive*2]||r[0xeb04+hg_drive*2]))hg_drive++;
 command("b:hg");
 char greeting[80];snprintf(greeting,sizeof(greeting),"HG 2.0 remote disk %c:",'A'+hg_drive);
 if(!contains(greeting)||!contains("host date/time synchronized")){dump();return 1;}
 if(r[0x1c]!=8||r[0x1d]!=10||r[0x1e]!=7||r[0x1f]!=0xea||r[0x1b]!=19||r[0x1a]!=14){fprintf(stderr,"HG date/time conversion mismatch: %02x %02x %02x %02x %02x %02x\n",r[0x1c],r[0x1d],r[0x1e],r[0x1f],r[0x1b],r[0x1a]);return 1;}
 capture_hg();
 const char*commands[]={"dir e:","copy e:hello.txt a:hgtest.txt","copy e:last.txt a:last.txt","copy a:hgtest.txt e:back.txt","copy e:hello.txt e:temp.txt","del e:temp.txt","b:hgtime","dir e:"};
 for(unsigned n=0;n<sizeof(commands)/sizeof(commands[0]);n++){
  command(commands[n]);if(!contains("A:\\>")||contains("Unknown error")||contains("Bad command")||contains("Path not found")||contains("File not found")||resets){dump();fprintf(stderr,"HG command failed: %s\n",commands[n]);return 1;}
 }
 // Production C FAT updater changes a mounted disk between native DOS commands.
 // INT 5C must invalidate cached FAT/root sectors without reinstalling HG.PGM.
 live_host_update("First host update\r\n",1);command("dir e:");
 if(!contains("LIVE")){dump();fprintf(stderr,"native DIR missed live host addition\n");return 1;}
 command("copy e:live.txt a:live.txt");
 live_host_update("Second host update\r\n",500);command("copy e:live.txt a:liveb.txt");
 if(contains("Unknown error")||resets){dump();return 1;}
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
 printf("PASS %s/MC6800 HG v%u native UniDOS loaded relocatable HG.PGM, registered drive %c, copied/deleted files, TIME, live host addition/replacement without remount; last sector %u read/write; read-only, bad checksum, absent-host timeout and recovery; %u reads/%u writes/%u TIME, zero resets\n",model_a?"601A":"601",hg_v2?2:1,'A'+hg_drive,last,hg_reads,hg_writes,hg_times);
 return 0;
}
