// Run the actual UniAS .CMD bytes, with minimal UniDOS console service stubs.
// Expectations are in the program; this runner does not calculate ALU results.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "core/mc6800.h"
static int done, failed, skipped, fault, cpu_hd=1;
static unsigned products;
byte *allocateCpuRam(dword n){return calloc(1,n);}
int SuperIoInit(void){return 0;}int SuperIoFinish(void){return 0;}
void SuperIoReset(void){}void SuperIoUpdate(void){}
int SuperIoReadByte(word a,byte*d){if(a==0xe6a0){*d=0x80|(cpu_hd?2:0);return 1;}return 0;}
int SuperIoWriteByte(word a,byte d){return 0;}
int SWIemulator(int number,byte*a,byte*b,word*x,byte*t,word*pc){
 if(number==0x23){
  const char *s=(const char*)MC6800GetCpuRam()+*x;
  if(!memchr(s,0,65536-*x))return 0;
  if(!strncmp(s,"FAIL",4))failed=1;
  if(!strncmp(s,"SKIP",4))skipped=1;
  fputs(s,stdout);
 }else if(number==0x22)putchar(*a);
 else if(number==0x38)done=1;
 else return 0;
 return 1;
}
#include "core/mc6800.c"
int main(int argc,char**argv){
 if(argc<2||argc>3)return 2;
 if(argc==3){fault=!strcmp(argv[2],"fault");cpu_hd=strcmp(argv[2],"classic")!=0;}
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);MC6800Init();
 FILE*f=fopen(argv[1],"rb");if(!f)return 2;
 size_t size=fread(MEM+0x100,1,0x9f00,f);if(!feof(f)||!size)return 2;fclose(f);
 PC=0x100;SP=0xbfff;i=0;MEM[0x80]=0x9a;MEM[0x81]=0xbc;
 unsigned long step;
 for(step=0;step<20000000&&!done;step++){
  unsigned op=MC6800MemReadByte(PC);
  MC6800Step();
  if(op==0x3d){products++;if(fault)B^=1;}
 }
 if(!done||SP!=0xbfff||MEM[0x80]!=0x9a||MEM[0x81]!=0xbc){
  fprintf(stderr,"program timeout/state leak PC=%04x SP=%04x ZP=%02x%02x\n",PC,SP,MEM[0x80],MEM[0x81]);return 1;
 }
 if(!cpu_hd)return skipped&&!failed?0:1;
 if(fault)return failed?0:1;
 if(failed||skipped)return 1;
 if(strstr(argv[1],"HDMUL")&&products!=65536){fprintf(stderr,"only %u MUL cases\n",products);return 1;}
 printf("PASS executable %s: %lu instructions, %u MUL operations, restored SP/direct RAM\n",argv[1],step,products);
 return 0;
}
