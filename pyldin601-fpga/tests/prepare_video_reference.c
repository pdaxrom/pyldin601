// Expected pixels are drawn by the original classic MC6845 emulator.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "core/mc6800.h"
#include "core/mc6845.h"
static byte ram[65536],font[2048];
byte*MC6800GetCpuRam(void){return ram;}
PyldinMachine MC6800GetMachine(void){return PYLDIN_MACHINE_601;}
byte*loadCharGenRom(dword n){return font;}
void SuperIoDrawVideo(void*v,int w,int h){}
#include "core/mc6845.c"
static void reg(unsigned n,unsigned value){MC6845WriteByte(0,n);MC6845WriteByte(1,value);}
int main(void){
 FILE*f=fopen("rtl/font_boot.mem","r");if(!f)return 1;
 for(int n=0;n<2048;n++){unsigned v;if(fscanf(f,"%x",&v)!=1)return 1;font[n]=v;}fclose(f);MC6845Init();
 const char*names[]={"text","graphics","text-wrap","graphics-wrap","text-end","graphics-end"};
 for(unsigned test=0;test<6;test++){
  unsigned mode=test&1,wrap=test>=2;
  unsigned start=mode?(wrap?0x1ff0:0x400):(wrap?0xff00:0xf100),stride=mode?48:42;
  if(test>=4)start=mode?0x1fff:0xffff;
  for(unsigned n=0;n<65536;n++)ram[n]=mode?(n*37u+(n>>8)):(wrap?33+(n*19u+(n>>8))%90:32);
  if(!mode&&!wrap){memcpy(ram+start+3*stride,"Enter new date:",15);memcpy(ram+start+7*stride,"A:\\>",4);}
  MC6845SetupScreen(mode?0x20:1);reg(1,stride);reg(6,25);reg(10,6);reg(11,7);reg(12,start>>8);reg(13,start);
  // BIOS uses +2 for text and +1 for graphics, including nonzero screen origins.
  unsigned cell=start+7*stride+4;
  // The renderer wraps text after FFFE and graphics before the FFF8 cell.
  // Place the cursor on the same visible cell after that wrap as well.
  if(mode&&cell>=0x1fff)cell-=0x1fff;
  if(!mode&&cell>=0xffff)cell-=start==0xffff?0x1000:0x0fff;
  unsigned cursor=cell+(mode?1:2);reg(14,cursor>>8);reg(15,cursor);
  unsigned short frame[448*224];memset(frame,0,sizeof(frame));MC6845DrawScreen(frame,448,224);
  char path[80];snprintf(path,sizeof(path),"build/cursor-%s.mem",names[test]);
  f=fopen(path,"w");if(!f)return 1;
  for(unsigned y=0;y<200;y++)for(unsigned x=0;x<320;x++)fprintf(f,"%02x\n",frame[y*448+64+x]?49:15);
  fclose(f);
  snprintf(path,sizeof(path),"build/cursor-%s-ram.mem",names[test]);f=fopen(path,"w");if(!f)return 1;
  for(unsigned n=0;n<65536;n++)fprintf(f,"%02x\n",ram[n]);fclose(f);
 }
 puts("Prepared cursor pixel references from original mc6845.c");return 0;
}
