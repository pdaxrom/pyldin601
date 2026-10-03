#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "core/mc6800.h"
byte*allocateCpuRam(dword n){return calloc(1,n);}
int SuperIoInit(void){return 0;}int SuperIoFinish(void){return 0;}void SuperIoReset(void){}void SuperIoUpdate(void){}
int SuperIoReadByte(word a,byte*d){return 0;}int SuperIoWriteByte(word a,byte d){return 0;}
int SWIemulator(int n,byte*a,byte*b,word*x,byte*t,word*pc){return 0;}
#include "core/mc6800.c"
int main(int argc,char**argv){
 if(argc!=3&&argc!=4)return 2;FILE*f=fopen(argv[1],"rb");if(!f)return 2;if(argc==4)MC6800SetMachine(PYLDIN_MACHINE_HD6303);MC6800Init();
 if(fread(MEM,1,65536,f)!=65536)return 2;fclose(f);MC6800Reset();
 unsigned n,delay=0;for(n=0;n<1000000&&MEM[0xefff]!=0xaa;n++){if(MEM[0xeffe]==1&&++delay==20)MC6800SetInterrupt(1);MC6800Step();}
 if(MEM[0xefff]!=0xaa){fprintf(stderr,"reference did not halt PC=%04x\n",PC);return 1;}
 f=fopen(argv[2],"w");if(!f)return 2;for(unsigned a=0;a<65536;a++)fprintf(f,"%02x\n",MEM[a]);fclose(f);return 0;
}
