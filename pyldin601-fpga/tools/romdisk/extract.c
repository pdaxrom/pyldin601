/* Extract archived software by running the original UniDOS UNARC.CMD.
 * The host does not reimplement ARC compression or alter archive contents. */
#define LEGACY_FIXTURE 1
#define ROMDISK_MAIN romdisk_test_main
#include "../../tests/test_romdisk_unidos.c"
int main(int argc,char **argv){
 if(argc!=3){fprintf(stderr,"usage: extract ARCHIVE.ARC OUTPUT.img\n");return 2;}
 MC6800SetMachine(PYLDIN_MACHINE_601);
 size_t size;unsigned char*rom=load("build/legacy-rom.reference",&size);
 require(size==0x51a00,"legacy extraction fixture");
 memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,0x51800);free(rom);
 image=load("images/sd.img",&image_size);memcpy(config+64,image+462,32);
 committed=1;MC6800Init();MC6800Reset();until(60000000);key(0x1c);key(0x1c);prompt_wait();
 require(invoke(0x44,3,0,0)==0,"select extraction RAM disk");
 char line[100];snprintf(line,sizeof line,"C:UNARC C:%s *.*",argv[1]);
 const char*letters="abcdefghijklmnopqrstuvwxyz";
 static const unsigned scans[]={0x1e,0x30,0x2e,0x20,0x12,0x21,0x22,0x23,0x17,0x24,0x25,0x26,0x32,0x31,0x18,0x19,0x10,0x13,0x1f,0x14,0x16,0x2f,0x11,0x2d,0x15,0x2c};
 for(char*p=line;*p;p++){
  char ch=*p>='A'&&*p<='Z'?*p+32:*p;const char*l=strchr(letters,ch);
  unsigned scan=l?scans[l-letters]:ch=='.'?0x34:ch==' '?0x39:ch==':'?0x27:ch=='*'?9:ch>='1'&&ch<='9'?ch-'1'+2:ch=='0'?11:0;
  require(scan,"valid extraction command");if(ch==':'||ch=='*')KBDModKeyDown(2);key(scan);if(ch==':'||ch=='*')KBDModKeyUp(2);
 }
 key(0x1c);uint64_t deadline=virtual_cycles+500000000;
 while(!(PC>=0xf380&&PC<=0xf3a8)&&virtual_cycles<deadline)until(virtual_cycles+10000);
 require(virtual_cycles<deadline,"native archive extraction returns");
 require(invoke(0x5c,0,0,0)==0,"flush extracted files");
 FILE*f=fopen(argv[2],"wb");require(f&&fwrite(physical+0x80000,1,512*1024,f)==512*1024&&!fclose(f),"save extraction disk");
 dump();return 0;
}
