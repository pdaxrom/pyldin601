/* Execute the delivered JOBs through the original UniDOS, not a host parser. */
static int hg_transport_read(unsigned short,unsigned char*);
static int hg_transport_write(unsigned short,unsigned char);
#define ARCADE_HG 1
#define GAMEBIOS_MAIN unused_gamebios_main
#define DOS_PROMPT_CYCLES 200000000000ULL
#include "test_gamebios.c"
#include "mouse_ui_model.h"
#include "paint_dma_model.h"
#include "../build/paint/PAINT.h"
#include "../host/hg/hg.h"
#define hg_transport_read board_host_read
#define hg_transport_write board_host_write
#include "hg_transport.h"
#undef hg_transport_read
#undef hg_transport_write

static unsigned baud=7,uart_open,paint_base,paint_ready;
static HgVolume board_volume;
static int board_write(unsigned block,const uint8_t*data,unsigned length){return hg_volume_write(&board_volume,block,data,length);}
static int hg_transport_read(unsigned short a,unsigned char*out){
 if(mouse_ui_read_byte(a,out))return 1;
 if(a<0xe644||a>0xe647)return board_host_read(a,out);
 *out=(a&3)==0?'U':(a&3)==1?baud:(a&3)==2?2:255;return 1;
}
static int hg_transport_write(unsigned short a,unsigned char d){
 if(mouse_ui_write_byte(a,d))return 1;
 if(a<0xe644||a>0xe647)return board_host_write(a,d);
 if((a&3)==1)baud=d;
 if((a&3)==2&&d==0x15)uart_open++;
 return 1;
}
static void job_observe(void){
 observe();
 if(!paint_base&&PC>=0x100&&PC<0xbc00&&r[PC]==0x20&&!memcmp(r+PC+2,"PNT1",4))paint_base=PC;
 if(paint_base&&PC==paint_base+PNT_PAINT_READY)paint_ready=1;
}
static void screen(const char*text){
 uint64_t end=virtual_cycles+200000000000ULL;
 do{until(virtual_cycles+1009);if(contains(text))return;}while(virtual_cycles<end);
 fprintf(stderr,"Missing screen: %s\n",text);require(0,"JOB reaches its next stage");
}
static void pause_at(const char*text){
 screen(text);
 uint64_t end=virtual_cycles+5000000;
 while(PC!=(model_a?0xf397:0xf39d)&&virtual_cycles<end)until(virtual_cycles+1);
 require(PC==(model_a?0xf397:0xf39d),"PAUSE waits on the real keyboard, not JOB input");
}
static void type_job(const char*text){
 /* The same key mapping as command(), without waiting for a DOS prompt. */
 const char*letters="abcdefghijklmnopqrstuvwxyz";
 const unsigned scans[]={0x1e,0x30,0x2e,0x20,0x12,0x21,0x22,0x23,0x17,0x24,0x25,0x26,0x32,0x31,0x18,0x19,0x10,0x13,0x1f,0x14,0x16,0x2f,0x11,0x2d,0x15,0x2c};
 for(;*text;text++){
  const char*p=strchr(letters,*text);unsigned s=p?scans[p-letters]:*text==':'?0x27:*text=='\\'?0x2b:*text==' '?0x39:*text>='1'&&*text<='9'?*text-'1'+2:*text=='0'?11:0;
  require(s,"board JOB launch character");
  if(*text==':')KBDModKeyDown(2);key(s);if(*text==':')KBDModKeyUp(2);
 }key(0x1c);
}
int main(int argc,char**argv){
 if(argc!=6)return 2;
 model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);
 require(n==ROM_BYTES+512,"ROM fixture size");memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 require(!hg_volume_open(&board_volume,argv[5],true,HG_MAX_SECTORS,false),"open separate HG test directory");
 host_image=board_volume.image;host_size=board_volume.size;host_write=board_write;hg_v2=1;
 image=load(argv[1],&image_size);committed=1;MC6800Init();MC6800Reset();
 r=MC6800GetCpuRam();dma_mmio_read=paint_dma_read;dma_mmio_write=paint_dma_write;native_step_hook=job_observe;
 until(60000000);key(0x1c);key(0x1c);prompt_wait();watch_resets=1;
 unsigned drive=0;while(drive<8&&(r[0xeb03+drive*2]||r[0xeb04+drive*2]))drive++;
 require(drive<8,"free drive for HG");command("b:hg");require(contains("HG 2.0 remote disk"),"real resident HG loaded before the JOB");
 char cmd[80],prompt[32];snprintf(cmd,sizeof cmd,"%c:",'a'+drive);
 dos_prompt_text=">";command(cmd);command("cd boardchk");
 snprintf(prompt,sizeof prompt,"%c:\\BOARDCHK>",'A'+drive);dos_prompt_text=prompt;
 command("handles 16");snprintf(cmd,sizeof cmd,"%c:\\rel1017\\cvm\\ramload /cvm",'a'+drive);command(cmd);
 require(contains("Loaded ZCODEVM"),"VM preloaded in the main shell before JOB");
 unsigned sp0=SP,banks0=free_banks();
 snprintf(cmd,sizeof cmd,"check %c:\\rel1017 %c:\\rel1017\\cvm %c:",'a'+drive,'a'+drive,'a'+drive);type_job(cmd);
 pause_at("No RESET during this JOB.");key(0x1c);
 const char*messages[]={"PASS: RAM allocator, 64 KiB, SWI/IRQ.",
  "PASS: DMA 8K copy/fill, PAL restored.","CVM TEST PASS",
  "There were 0 errors in compilation.","CVM HELLO PASS",NULL,
  "OBJECT PASS","OHELP","OBJECT PASS",NULL,NULL,"C MIXED PASS","C ABI PASS"};
 for(unsigned stage=1;stage<=13;stage++){
  char marker[32];snprintf(marker,sizeof marker,"JA%02u READY",stage);pause_at(marker);
  if(messages[stage-1])require(contains(messages[stage-1]),"actual diagnostic success is visible before PAUSE");
  require(!contains("FAIL")&&!contains("Insufficient memory")&&!contains("Bad command"),"no diagnostic failure at stage boundary");
  printf("PASS native JOB stage %02u\n",stage);fflush(stdout);key(0x1c);
 }
 pause_at("JCHK06 READY");
 require(contains("JCHK AUTO END"),"nested AUTO.JOB returns to CHECK.JOB");
 puts("PASS automatic JOB reached NC stage");fflush(stdout);
 key(0x1c);screen("Name");screen("Left");until(virtual_cycles+200000);
 /* NC drive browsing can change the global DOS working drive. */
 type_job("b:");until(virtual_cycles+2000000);key(0x44);
 pause_at("JCHK07 READY");key(0x1c);
 uint64_t end=virtual_cycles+100000000;
 while(!paint_ready&&virtual_cycles<end)until(virtual_cycles+1009);
 require(paint_ready,"packaged PAINT starts from the JOB");until(virtual_cycles+200000);key(0x44);
 pause_at("JCHK08 READY");key(0x1c);screen("F10Exit");
 require(uart_open==1&&baud==6,"JOB starts packaged UART at 9600");key(0x44);
 screen("JCHK CHECK END");prompt_wait();
 require(SP==sp0&&free_banks()==banks0,"JOB and all applications restore stack and RAMMAN leases");
 require(!resets&&!fdc_port_accesses,"JOB leaves native UniDOS stable");
 require(!sd_writes,"HG JOB never changes the installed SD release");
 require(!hg_volume_sync(&board_volume),"publish HG files after JOB returns");
 FILE*f=fopen(argv[4],"wb");require(f!=NULL,"save private test result");
 require(fwrite(board_volume.image,1,board_volume.size,f)==board_volume.size,"save complete HG volume");fclose(f);
 hg_volume_close(&board_volume);
 printf("PASS native JOB %s/%s: resident HG/VM, nested scripts, parameters, tools, NC/PAINT/UART and return to DOS\n",argv[2],argv[3]);
 return 0;
}
