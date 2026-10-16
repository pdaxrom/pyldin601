// Execute assembled ROMs with omitted modules and swapped 16-KiB halves.
// Service tests reuse independent GPU/PAL/audio models, not ROM code.
#define GAMEBIOS_MAIN unused_gamebios_main
#include "test_gamebios.c"
#undef GAMEBIOS_MAIN

static unsigned native_value(unsigned address){return r[address]*256+r[address+1];}
static void omit(unsigned slot){memset(physical+0x10000+(slot-8)*8192,255,8192);}
static void swap_halves(unsigned slot){
 unsigned char temp[8192],*p=physical+0x10000+(slot-8)*8192;
 memcpy(temp,p,8192);memcpy(p,p+8192,8192);memcpy(p+8192,temp,8192);
}
static void native_copy_without_extensions(void){
 require(service_invoke(0xe8,0,0,0)==1&&result_b==7&&result_x==8192,
         "native E8 exists independently of ROM extensions");
 require((r[0xedf4]>>4)==0&&native_value(0xefd0)>=0xf000,
         "E8 registered in fixed BIOS before extension initialization");
 for(unsigned k=0;k<32;k++)r[0x8000+k]=k*7+3;
 unsigned char expected[32];memcpy(expected,r+0x8000,32);
 unsigned saved_page=page,saved_group=ram_group;page=6;ram_group=18;
 bank_move(255,110,0x8000,31,32,0);
 bank_move(110,255,31,0x8100,32,0);
 require(!memcmp(expected,r+0x8100,32)&&page==6&&ram_group==18,
         "native copy preserves page/group without SD, RAMMAN or GAMEBIOS");
 page=saved_page;ram_group=saved_group;
}
int main(int argc,char**argv){
 if(argc!=4)return 2;
 model_a=!strcmp(argv[1],"601a");cpu_hd=!strcmp(argv[2],"hd6303");
 const char*mode=argv[3],*message=NULL;
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t size;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&size);
 require(size==ROM_BYTES+512,"module fixture length");
 memcpy(config,rom,HEADER_BYTES);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load("images/sd.img",&image_size);committed=1;
 if(!strcmp(mode,"no-pages")){memset(physical+0x10000,255,65536);message="BOOT: SDPARTS error";}
 else if(!strcmp(mode,"no-parts")){omit(10);message="BOOT: SDPARTS error";}
 else if(!strcmp(mode,"no-raw")){omit(11);message="BOOT: SDPARTS error";}
 else if(!strcmp(mode,"no-shell")){omit(15);unsigned start=le32(image+462+8);image[(start+1)*512-2]=0x55;image[(start+1)*512-1]=0xaa;message="UniBIOS";}
 else if(!strcmp(mode,"no-kernel")){omit(12);message="BOOT: no system";}
 else if(!strcmp(mode,"no-game"))omit(14);
 else if(!strcmp(mode,"relocated")){swap_halves(10);swap_halves(14);}
 else require(!strcmp(mode,"no-e0"),"known module test");
 MC6800Init();MC6800Reset();until(60000000);r=MC6800GetCpuRam();
 native_copy_without_extensions();
 require(!fdc_port_accesses,"removed disk-controller ports stay unused");
 if(message){
  require(contains(message),"missing module has an explicit boot error");
  unsigned saved_sp=SP;watch_resets=1;until(virtual_cycles+2000000);
  require(!resets&&SP==saved_sp,"missing module does not recurse through Reset or leak stack");
 }else{
  key(0x1c);key(0x1c);prompt_wait();
  pcb=native_value(0xec00);state=native_value(0xefcc);sp_before=SP;
  command("dir a:");command("dir b:");command("dir c:");
  if(!strcmp(mode,"no-game"))require(!native_value(0xefca)&&!native_value(0xefcc),
                                        "shell works without RAMMAN and GAMEBIOS");
  else{
   if(!strcmp(mode,"relocated"))require((r[0xedf3]&15)==10&&(r[0xedf0]&15)==11&&
                                        (r[0xedf3]>>4)==15&&(r[0xedf1]&15)==14,
                                        "registration follows each swapped ROM half");
   // Absent E0 must not affect GAMEBIOS COPY, clipping, text or music.
   word_at(0xefc0,0);r[0xedf0]&=15;
   if(cpu_hd){
    unsigned initial_free=free_banks();
    front=4;for(unsigned k=0;k<8192;k++)pal[k]=saved_pal[k]=(k*17+5)&63;
    for(unsigned k=0;k<14;k++)ay[k]=saved_ay[k]=(k*5+11)&255;
    old_irq=native_value(0xefc8);old_page=r[0xedf2]>>4;
    native_step_hook=observe;open_context(3);
    gfx_test();audio_test();batch_test();call(2,0,0,0);restored();
    require(free_banks()==initial_free,"application CLOSE owns complete release");
    const char*games[]={"b:arkanoid","b:xonix"};
    for(unsigned k=0;k<2;k++){
     fault_palette=1;command(games[k]);fault_palette=0;restored();
     require(free_banks()==initial_free,"both games release loaded music after OPEN failure without shell cleanup");
    }
   }else call(0,0,0,2);
  }
  command("dir a:");require(SP==sp_before,"DOS stack intact after independent services");
 }
 printf("PASS independent ROMs %s/%s %s\n",argv[1],argv[2],mode);
 return 0;
}
