// Boot unchanged BIOS/UniDOS and native ROM/RAM-disk drivers alongside the
// FPGA SD extension. Check DIR C: before any other command, then the real DOS
// file API across all ROM banks and interleaved SD/electronic-disk operations.
#define NATIVE_STABILITY_MAIN unused_stability_main
#include "test_native_stability.c"
#undef NATIVE_STABILITY_MAIN
static void require(int ok,const char*message){
 if(!ok){dump();fprintf(stderr,"FAIL %s\n",message);exit(1);}
}
static int contains(const char*text){
 unsigned start=crtc[12]*256+crtc[13],stride=crtc[1];
 unsigned step=model_a&&(MC6800GetCpuRam()[0xe629]&2)?2:1;
 unsigned char*r=MC6800GetCpuRam();
 for(unsigned y=0;y<25;y++)for(unsigned x=0;x<stride/step;x++){
  unsigned k;for(k=0;text[k];k++)if(r[(start+y*stride+(x+k)*step+(step==2))&65535]!=(unsigned char)text[k])break;
  if(!text[k])return 1;
 }return 0;
}
static void prompt_wait(void){
 uint64_t deadline=virtual_cycles+15000000;
 do{until(virtual_cycles+10000);if(PC>=0xf380&&PC<=0xf3a8&&contains("A:\\>"))return;}while(virtual_cycles<deadline);
 require(0,"command returned to DOS prompt");
}
static void command(const char*text){
 const char*letters="abcdefghijklmnopqrstuvwxyz";
 static const unsigned scans[]={0x1e,0x30,0x2e,0x20,0x12,0x21,0x22,0x23,0x17,0x24,0x25,0x26,0x32,0x31,0x18,0x19,0x10,0x13,0x1f,0x14,0x16,0x2f,0x11,0x2d,0x15,0x2c};
 for(;*text;text++){
  const char*p=strchr(letters,*text);unsigned scan=p?scans[p-letters]:*text=='.'?0x34:*text==' '?0x39:*text==':'?0x27:*text=='/'?0x35:*text>='1'&&*text<='9'?*text-'1'+2:*text=='0'?0x0b:0;
  require(scan!=0,"test command has valid keys");
  if(*text==':')KBDModKeyDown(2);key(scan);if(*text==':')KBDModKeyUp(2);
 }key(0x1c);prompt_wait();
}
static void rom_directory(void){
 unsigned before=sd_reads;
 command("dir c:");
 require(sd_reads==before,"ROM directory does not access SD");
 require(contains("MS-RAMDRIVE")&&contains("13 File(s)")&&contains("7680 bytes free"),"complete original ROM directory");
 require(contains("UNARC")&&contains("BASIC"),"original ROM filenames");
}
static unsigned result_b,result_x;
static unsigned invoke(unsigned op,unsigned a,unsigned b,unsigned x){
 unsigned pc0=PC,sp0=SP,a0=A,b0=B,x0=X,h0=h,i0=i,n0=n,z0=z,v0=v,c0=c,page0=page;
 unsigned char*r=MC6800GetCpuRam();r[0x210]=0x3f;r[0x211]=op;r[0x212]=1;
 PC=0x210;A=a;B=b;X=x;
 uint64_t deadline=virtual_cycles+15000000;
 do{until(virtual_cycles+1);require(virtual_cycles<deadline,"DOS API returns");}while(PC!=0x212);
 unsigned result=A;result_b=B;result_x=X;
 require(SP==sp0&&page==page0,"DOS API preserves stack and ROM page");
 PC=pc0;A=a0;B=b0;X=x0;h=h0;i=i0;n=n0;z=z0;v=v0;c=c0;
 return result;
}
static void word_at(unsigned address,unsigned value){
 unsigned char*r=MC6800GetCpuRam();r[address]=value>>8;r[address+1]=value;
}
static void file_check(const char*name,const unsigned char*expected,unsigned size){
 unsigned char*r=MC6800GetCpuRam();strcpy((char*)r+0x3100,name);
 word_at(0x3000,0x3100);word_at(0x3002,0);
 require(invoke(0x4a,1,0,0x3000)==0,"open native disk file");unsigned handle=result_b;
 require(invoke(0x51,handle,0,0x3004)==0,"file size API");
 require(((uint32_t)r[0x3004]<<24|r[0x3005]<<16|r[0x3006]<<8|r[0x3007])==size,"original file size");
 for(unsigned offset=0;offset<size;){
  unsigned length=size-offset>512?512:size-offset;
  word_at(0x3000,0x4000);word_at(0x3002,length);
  require(invoke(0x4c,handle,0,0x3000)==0&&result_x==length,"native file read");
  require(!memcmp(r+0x4000,expected+offset,length),"file data matches original ROM across bank boundaries");offset+=length;
 }
 require(invoke(0x4e,handle,0,0)==0,"close native disk file");
}
static unsigned fat_next(const unsigned char*fat,unsigned cluster){
 unsigned off=cluster+cluster/2,v=le16(fat+off);return cluster&1?v>>4:v&4095;
}
static void all_rom_files(void){
 unsigned char volume[320*512],file[70000];
 // Native EPROMs: 64 KiB bank 1, then 32 KiB banks 2..4, mirrored in the
 // physical 64 KiB slots. Build a linear oracle from the original ROM bytes.
 memcpy(volume,physical+0x20000,65536);
 for(unsigned bank=2;bank<=4;bank++)memcpy(volume+65536+(bank-2)*32768,physical+0x10000+bank*65536,32768);
 unsigned root=(le16(volume+14)+volume[16]*le16(volume+22))*512;
 unsigned data=root+((le16(volume+17)*32+511)/512)*512;
 unsigned unit=volume[13]*512,count=0,before=sd_reads;
 for(unsigned entry=root;entry<root+le16(volume+17)*32&&volume[entry];entry+=32){
  const unsigned char*e=volume+entry;if(e[0]==0xe5||e[11]&0x18)continue;
  char name[16]="c:",*p=name+2;
  for(unsigned k=0;k<8&&e[k]!=' ';k++)*p++=e[k];*p++='.';
  for(unsigned k=8;k<11&&e[k]!=' ';k++)*p++=e[k];*p=0;
  unsigned size=le32(e+28),cluster=le16(e+26),offset=0;require(size<=sizeof file,"ROM file fits oracle");
  while(offset<size){
   unsigned length=size-offset>unit?unit:size-offset,source=data+(cluster-2)*unit;
   require(cluster>=2&&source+length<=sizeof volume,"original ROM FAT chain bounds");
   memcpy(file+offset,volume+source,length);offset+=length;cluster=fat_next(volume+le16(volume+14)*512,cluster);
  }
  require(cluster>=0xff8,"original FAT end marker");file_check(name,file,size);count++;
 }
 require(count==13&&sd_reads==before,"all 13 ROM files read without SD");
}
#ifndef ROMDISK_MAIN
#define ROMDISK_MAIN main
#endif
int ROMDISK_MAIN(int argc,char**argv){
 if(argc!=4)return 2;model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t size;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&size);
 require(size==0x51a00,"ROM fixture size");memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,0x51800);free(rom);
 image=load(argv[1],&image_size);memcpy(config+64,image+462,32);
 committed=1;MC6800Init();MC6800Reset();until(60000000);key(0x1c);key(0x1c);prompt_wait();watch_resets=1;
 rom_directory();all_rom_files();
 unsigned char*r=MC6800GetCpuRam();unsigned rom_header=r[0xbf80]*256+r[0xbf81];
 require(rom_header>=0x100&&rom_header<0xbe00&&r[rom_header+6]==14,"native ROM driver header retained");
 for(unsigned round=0;round<8;round++){
  unsigned before=sd_reads;command("dir a:");command("dir b:");require(sd_reads>before,"both SD directories read");
  require(invoke(0x17,0x80,0,0x3000)==0,"SD remount");
  require(r[0xbf80]*256+r[0xbf81]==rom_header,"SD init preserves native ROM driver pointer");rom_directory();
 }
 command("copy c:pascal.job d:rcheck.job");
 const unsigned char job[]="copy ue.cmd d:\r\nd:\r\nc:unarc c:pas.arc *.*\r\ndir";
 file_check("d:RCHECK.JOB",job,sizeof job-1);command("dir d:");require(contains("RCHECK"),"electronic disk directory");
 command("type d:rcheck.job");require(contains("copy ue.cmd d:")&&contains("c:unarc c:pas.arc"),"copied file text");
 command("del d:rcheck.job");rom_directory();all_rom_files();
 require(!resets&&!fdc_port_accesses,"zero resets or removed FDC accesses");
 printf("PASS native %s/%s: initial DIR C, all 13 original files across ROM banks, repeated A/B/C and SD remount, electronic disk copy/read/type/delete, zero resets\n",argv[2],argv[3]);return 0;
}
