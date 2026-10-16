// Actual native BIOS/UniDOS + UART.PGM. Electrical formats/divisors/FIFOs are
// checked independently by tb_uart; this fixture checks native application I/O.
#define COMPACT_FIXTURE 1
#define DIRECT_SD_FIXTURE 1
#define HG_FIXTURE 1
static int hg_read_byte(unsigned short,unsigned char*);
static int hg_write_byte(unsigned short,unsigned char);
#define ROMDISK_MAIN unused_romdisk_main
#include "test_romdisk_unidos.c"
#undef ROMDISK_MAIN
#include "../build/input/UART.h"
#ifndef UART_MMIO_CUSTOM
static unsigned present=1,baud=7,configured,control,rx_count,rx_head,error_flags,tx_count;
static unsigned char rx[64],tx[128];static uint64_t tx_ready;
static int hg_read_byte(unsigned short a,unsigned char*out){
 if(a<0xe644||a>0xe647)return 0;
 switch(a&3){
 case 0:*out=present?'U':255;break;case 1:*out=baud;break;
 case 2:*out=(virtual_cycles>=tx_ready?2:0)|(rx_count!=0)|error_flags;break;
 default:*out=255;if(rx_count){*out=rx[rx_head++];rx_count--;}error_flags=0;break;
 }return 1;
}
static int hg_write_byte(unsigned short a,unsigned char d){
 if(a<0xe644||a>0xe647)return 0;
 switch(a&3){
 case 1:baud=d;break;
 case 2:control=d;if(d==3){rx_count=rx_head=0;tx_ready=virtual_cycles;}if(d==0x15)configured++;break;
 case 3:require(virtual_cycles>=tx_ready&&tx_count<sizeof tx,"terminal waits for TX holding capacity");tx[tx_count++]=d;tx_ready=virtual_cycles+30000;break;
 }return 1;
}
#endif
static void type_text(const char*s){
 const char*letters="abcdefghijklmnopqrstuvwxyz";
 const unsigned scans[]={0x1e,0x30,0x2e,0x20,0x12,0x21,0x22,0x23,0x17,0x24,0x25,0x26,0x32,0x31,0x18,0x19,0x10,0x13,0x1f,0x14,0x16,0x2f,0x11,0x2d,0x15,0x2c};
 for(;*s;s++){const char*p=strchr(letters,*s);unsigned scan=p?scans[p-letters]:*s==':'?0x27:*s==' '?0x39:*s>='1'&&*s<='9'?*s-'1'+2:*s=='0'?11:0;require(scan,"UART test command character");if(*s==':')KBDModKeyDown(2);key(scan);if(*s==':')KBDModKeyUp(2);}
}
#ifndef UART_MMIO_CUSTOM
int main(int argc,char**argv){
 if(argc!=5)return 2;model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");const char*rate=argv[4];
 if(!strcmp(rate,"missing"))present=0;
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);
 memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);image=load(argv[1],&image_size);committed=1;
 MC6800Init();MC6800Reset();until(60000000);key(0x1c);key(0x1c);prompt_wait();
 if(model_a)invoke(0x12,4,0,0);
 unsigned original_sp=SP,original_himem=MC6800GetCpuRam()[0xee1e]*256+MC6800GetCpuRam()[0xee1f];
 configured=tx_count=0;char command_text[80];snprintf(command_text,sizeof command_text,"b:uart%s%s",!strcmp(rate,"default")||!strcmp(rate,"missing")?"":" ",!strcmp(rate,"default")||!strcmp(rate,"missing")?"":rate);
 type_text(command_text);key(0x1c);
 if(!present||!strcmp(rate,"bad")){
  prompt_wait();require(!configured,"missing hardware/invalid arguments do not configure UART");
  require(contains(present?"UART [150..115200]":"UART hardware is unavailable."),"terminal reports an explicit launch error");
 }else{
  uint64_t end=virtual_cycles+20000000;while(!configured&&virtual_cycles<end)until(virtual_cycles+1009);
  require(configured==1&&control==0x15,"terminal configures 8N1 through native MMIO");
  const char*rates[]={"150","300","600","1200","2400","4800","9600","19200","38400","57600","115200"};unsigned wanted=7;
  if(strcmp(rate,"default")){for(wanted=0;wanted<11&&strcmp(rate,rates[wanted]);wanted++);}
  require(baud==wanted,"CLI rate selects the exact hardware baud code");
  memcpy(rx,"FROM HOST",9);rx_count=9;rx_head=0;error_flags=0x70;
  end=virtual_cycles+2000000;while((rx_count||!contains("FROM HOST"))&&virtual_cycles<end)until(virtual_cycles+1009);
  require(!rx_count&&contains("FROM HOST"),"serial RX reaches the native console");
  type_text("abc");key(0x1c);key(0x0f);key(0x0e);key(0x3c);type_text("z");
  until(virtual_cycles+200000);key(1);prompt_wait();
  const unsigned char expected[]={'a','b','c',13,9,8,'z'};
  require(tx_count==sizeof expected&&!memcmp(tx,expected,sizeof expected),"keyboard bytes, Enter/Tab/Backspace and F2 echo preserve TX order");
  require(contains("UART closed.")&&contains("UART RX errors"),"RX error summary remains visible after exit");
 }
 require(SP==original_sp&&MC6800GetCpuRam()[0xee1e]*256+MC6800GetCpuRam()[0xee1f]==original_himem,"terminal exits without stack/heap leaks");
 printf("PASS native UART %s/%s rate=%s: CLI, RX, TX backpressure/order, local echo, errors, cleanup\n",argv[2],argv[3],rate);return 0;
}
#endif
