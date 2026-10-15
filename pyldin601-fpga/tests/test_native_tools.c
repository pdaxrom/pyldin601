#ifdef NATIVE_TOOLS_HG
#include <stdint.h>
#include "../host/hg/hg.h"
static unsigned native_hg_drive;
static int hg_read_byte(uint16_t a,unsigned char*out);
static int hg_write_byte(uint16_t a,unsigned char d);
#define HG_FIXTURE 1
#endif
// Assemble real firmware using UNIAS.CMD, the banked VM and native UniDOS.
#define COMPACT_FIXTURE 1
#define DIRECT_SD_FIXTURE 1
#define DOS_PROMPT_CYCLES 200000000000ULL
#define ROMDISK_MAIN unused_romdisk_main
#include "test_romdisk_unidos.c"
#undef ROMDISK_MAIN
#ifdef NATIVE_TOOLS_HG
#include "hg_transport.h"
static HgVolume tools_volume;
static int tools_host_write(unsigned block,const uint8_t*data,unsigned length){return hg_volume_write(&tools_volume,block,data,length);}
static int hg_read_byte(uint16_t a,unsigned char*out){return hg_transport_read(a,out);}
static int hg_write_byte(uint16_t a,unsigned char d){return hg_transport_write(a,d);}
#endif

static unsigned vm_group,vm_page;
static unsigned stack_min;
static uint64_t progress_at;
static unsigned char hd_opcode[256];
static unsigned vm_return_pc,vm_return_status;
static void observe_assembly(void){
 if(vm_return_pc && PC==vm_return_pc){vm_return_status=A;vm_return_pc=0;}
 if(PC<0xbe00&&MC6800MemReadByte(PC)==0x3f&&MC6800MemReadByte(PC+1)==0xef&&A==1)
  vm_return_pc=PC+2;
 if(ram_group==vm_group&&page==vm_page&&PC>=0xc000&&PC<0xe000&&SP<stack_min)stack_min=SP;
 if(!cpu_hd&&ram_group==vm_group&&page==vm_page&&PC>=0xc000&&PC<0xe000)
  require(!hd_opcode[MC6800MemReadByte(PC)],"MC6800 VM uses only classic CPU instructions");
 if(virtual_cycles>=progress_at){
  printf("Progress: %llu reference cycles\n",(unsigned long long)virtual_cycles);fflush(stdout);
  progress_at=virtual_cycles+4000000000ULL;
 }
}


int main(int argc,char**argv){
#ifdef NATIVE_TOOLS_HG
 if(argc!=7&&argc!=8)return 2;
 int root_sources=argc==8&&!strcmp(argv[7],"/");
 require(!hg_volume_open(&tools_volume,argv[6],!getenv("NATIVE_TOOLS_IMAGE"),HG_MAX_SECTORS,false),"open HG host volume");
 host_image=tools_volume.image;host_size=tools_volume.size;host_write=tools_host_write;hg_v2=1;
#else
 if(argc!=6)return 2;
#endif
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
#ifdef NATIVE_TOOLS_HG
 printf("Memory before HG: SP=%04x heap=%04x\n",SP,MC6800GetCpuRam()[0xee1a]*256+MC6800GetCpuRam()[0xee1b]);
 native_hg_drive=0;
 while(native_hg_drive<8&&(MC6800GetCpuRam()[0xeb03+native_hg_drive*2]||MC6800GetCpuRam()[0xeb04+native_hg_drive*2]))native_hg_drive++;
 command("b:hg");require(contains("HG 2.0 remote disk"),"resident HG installed");
 printf("Memory after HG: SP=%04x heap=%04x\n",SP,MC6800GetCpuRam()[0xee1a]*256+MC6800GetCpuRam()[0xee1b]);
 char prompt[16],change[3]={(char)('a'+native_hg_drive),':',0};
 dos_prompt_text=">";command(change);if(!root_sources)command("cd cvm");
 snprintf(prompt,sizeof prompt,"%c:\\%s>",'A'+native_hg_drive,root_sources?"":"CVM");dos_prompt_text=prompt;
#endif
 command("handles 16");require(MC6800GetCpuRam()[0xeb15]>=16,"expanded native DOS handle table");
#ifdef NATIVE_TOOLS_HG
 command(root_sources?"cvm\\ramload /cvm":"ramload /cvm");
#else
 command("b:ramload /cvm");
#endif
 require(contains("Loaded ZCODEVM"),"load selected VM");
 require(invoke(0xef,0,0,0)==1&&result_b==(unsigned)cpu_hd&&result_x==0x5a56,"CPU-selected VM ABI");
 invoke(0xec,0,0,0);unsigned char*r=MC6800GetCpuRam();
 vm_group=r[result_x+2];vm_page=r[result_x+3];
 const unsigned char hd[]={4,5,0x18,0x38,0x3a,0x3c,0x3d,0x83,0x93,0xa3,0xb3,0xc3,0xd3,0xe3,0xf3,0xcc,0xdc,0xec,0xfc,0xdd,0xed,0xfd};
 for(unsigned j=0;j<sizeof hd;j++)hd_opcode[hd[j]]=1;
 progress_at=virtual_cycles+4000000000ULL;native_step_hook=observe_assembly;
#ifndef NATIVE_TOOLS_HG
 dos_prompt_text="B:\\>";command("b:");
#endif
 printf("Memory before tools: SP=%04x heap=%04x\n",SP,r[0xee1a]*256+r[0xee1b]);
 unsigned sp=SP;unsigned char dp[32];memcpy(dp,MC6800GetCpuRam()+0xe0,32);
 FILE *commands=fopen(argv[5],"r");require(commands!=NULL,"open commands");
 char line[160];
 while(fgets(line,sizeof line,commands)){
  line[strcspn(line,"\r\n")]=0;if(!line[0])continue;
  char *expected=strchr(line,'\t');if(expected)*expected++=0;
  int expect_failure=line[0]=='!';
  if(expect_failure)memmove(line,line+1,strlen(line));
  vm_return_status=256;vm_return_pc=0;
  printf("Command: %s\n",line);fflush(stdout);
  memcpy(dp,MC6800GetCpuRam()+0xe0,32);
  stack_min=SP;
  uint64_t started=virtual_cycles;command(line);dump();
  if(expect_failure)require(vm_return_status==1,"native compiler returns failure through VM");
  else require(!contains("Error:")&&!contains("Insufficient memory")&&!contains("Too many simultaneous")&&!contains("unias: Cannot"),"native command completed");
  if(expected)require(contains(expected),"expected command output");
  if(!expect_failure&&!strncmp(line,"unicc ",6))require(contains("There were 0 errors"),"native compilation has no errors");
  require(SP==sp,"tool restores DOS stack");
  if(strncmp(line,"ulink ",6))require(!memcmp(dp,MC6800GetCpuRam()+0xe0,32),"VM tool restores direct page");
#ifdef NATIVE_TOOLS_HG
  require(!hg_volume_sync(&tools_volume),"sync native HG output to host directory");
  host_image=tools_volume.image;
  unsigned bank=vm_group*6+(vm_page&15)-1;
  const unsigned char *work=physical+0x22000+bank*8192+0xc00;
  require(work[0]==0x56&&work[1]==0x57&&work[2]==0&&work[3]==1,"symbol arena preserves VM descriptor");
  unsigned used=0;for(unsigned k=0x10;k<0x1300;k++)if(work[k]!=255)used++;
  printf("VM workspace changed bytes: %u\n",used);
#endif
  printf("Finished command: %llu reference cycles\n",(unsigned long long)(virtual_cycles-started));
  printf("Lowest stack address: %04x\n",stack_min);
 }
 fclose(commands);require(!resets&&!fdc_port_accesses,"native DOS stable");
 char path[1024];snprintf(path,sizeof path,"%s/STATE.IMG",argv[4]);
 FILE*f=fopen(path,"wb");require(f!=NULL,"save native disk");
 require(fwrite(image,1,image_size,f)==image_size,"save native disk bytes");fclose(f);
#ifdef NATIVE_TOOLS_HG
 snprintf(path,sizeof path,"%s/HOST.IMG",argv[4]);f=fopen(path,"wb");require(f!=NULL,"save host disk");
 require(fwrite(host_image,1,host_size,f)==host_size,"save HG disk bytes");fclose(f);
 require(hg_reads&&hg_writes,"native HG reads and writes exercised");
 hg_volume_close(&tools_volume);
#endif
 puts("PASS native object tools and legacy ULINK");return 0;
}
