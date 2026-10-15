// Assemble real firmware using UNIAS.CMD, the banked VM and native UniDOS.
#define COMPACT_FIXTURE 1
#define DIRECT_SD_FIXTURE 1
#define DOS_PROMPT_CYCLES 200000000000ULL
#define ROMDISK_MAIN unused_romdisk_main
#include "test_romdisk_unidos.c"
#undef ROMDISK_MAIN

static unsigned vm_group,vm_page;
static uint64_t progress_at;
static unsigned char hd_opcode[256];
static void observe_assembly(void){
 if(!cpu_hd&&ram_group==vm_group&&page==vm_page&&PC>=0xc000&&PC<0xe000)
  require(!hd_opcode[MC6800MemReadByte(PC)],"MC6800 VM uses only classic CPU instructions");
 if(virtual_cycles>=progress_at){
  printf("Progress: %llu reference cycles\n",(unsigned long long)virtual_cycles);fflush(stdout);
  progress_at=virtual_cycles+4000000000ULL;
 }
}


int main(int argc,char**argv){
 if(argc!=5)return 2;
 model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t size;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&size);
 require(size==ROM_BYTES+512,"ROM size");memcpy(config,rom,HEADER_BYTES);
 memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load(argv[1],&image_size);committed=1;MC6800Init();MC6800Reset();
 until(60000000);key(0x1c);key(0x1c);prompt_wait();watch_resets=1;
 // XONIX pass 2 simultaneously holds nested inputs, a listing and two PGM
 // streams, in addition to the standard handles. Expand before loading the
 // resident VM, while UniDOS can safely allocate permanent handle records.
 command("handles 16");require(MC6800GetCpuRam()[0xeb15]>=16,"expanded native DOS handle table");
 command("b:ramload /cvm");require(contains("Loaded ZCODEVM"),"load selected VM");
 require(invoke(0xef,0,0,0)==1&&result_b==(unsigned)cpu_hd&&result_x==0x5a56,"CPU-selected VM ABI");
 invoke(0xec,0,0,0);unsigned char*r=MC6800GetCpuRam();
 vm_group=r[result_x+2];vm_page=r[result_x+3];
 const unsigned char hd[]={4,5,0x18,0x38,0x3a,0x3c,0x3d,0x83,0x93,0xa3,0xb3,0xc3,0xd3,0xe3,0xf3,0xcc,0xdc,0xec,0xfc,0xdd,0xed,0xfd};
 for(unsigned j=0;j<sizeof hd;j++)hd_opcode[hd[j]]=1;
 progress_at=virtual_cycles+4000000000ULL;native_step_hook=observe_assembly;
 dos_prompt_text="B:\\>";command("b:");
 unsigned sp=SP;unsigned char dp[32];memcpy(dp,MC6800GetCpuRam()+0xe0,32);
 const char*names[]={"BIOS","BIOS_A","XONIX"};
 for(unsigned j=0;j<3;j++){
  char cmd[100];
  snprintf(cmd,sizeof cmd,"b:unias %s-l b:%s.lst -o b:%s.%s b:%s.asm",
           j==2?"-D GAME_MUSIC ":"",j==0?"bios":j==1?"bios_a":"xonix",
           j==0?"bios":j==1?"bios_a":"xonix",j==2?"pgm":"rom",
           j==0?"bios":j==1?"bios_a":"xonix");
  printf("Starting %s on %s/%s\n",names[j],argv[2],argv[3]);fflush(stdout);
  uint64_t started=virtual_cycles;command(cmd);
  require(contains("Lines assembled")&&!contains("unias: Cannot")&&!contains("Error:"),"native assembly completed");
  require(SP==sp&&!memcmp(dp,MC6800GetCpuRam()+0xe0,32),"assembler restores stack and VM direct page");
  printf("Finished %s: %llu reference cycles\n",names[j],(unsigned long long)(virtual_cycles-started));

 }
 char path[1024];snprintf(path,sizeof path,"%s/STATE.IMG",argv[4]);
 FILE*f=fopen(path,"wb");require(f!=NULL,"save native disk");
 require(fwrite(image,1,image_size,f)==image_size,"save native disk bytes");fclose(f);
 require(!resets&&!fdc_port_accesses,"native DOS stable during large assemblies");
 printf("PASS native BIOS, BIOS_A and XONIX assembly on %s/%s\n",argv[2],argv[3]);return 0;
}
