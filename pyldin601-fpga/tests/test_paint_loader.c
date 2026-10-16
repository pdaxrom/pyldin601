// Actual UniDOS loads the linked probe; the production loader reads PGMs.
#define PAINT_BACKEND_MAIN unused_backend_main
#include "test_paint_backends.c"
#include "../build/paint/PNTTEST.h"
static unsigned probe_base,expected_kind,expected_error,expected_banked,expected_rgb;
static unsigned loaded_seen,encoded_seen,closed_seen,loaded_code,loaded_bank;
static unsigned char *code_oracle;
static unsigned char*module_memory(void){
 unsigned char*r=MC6800GetCpuRam();unsigned base=r[probe_base+PLT_BACKEND_BASE]*256+r[probe_base+PLT_BACKEND_BASE+1];
 return loaded_bank?physical+0x22000+r[probe_base+PLT_BACKEND_LEASE+3]*8192:r+base;
}
static void loader_observe(void){
 unsigned char*r=MC6800GetCpuRam();
 if(!probe_base&&PC>=0x100&&PC<0xb000&&r[PC]==0x20&&!memcmp(r+PC+2,"PLT1",4))probe_base=PC;
 if(!probe_base)return;
 if(!loaded_seen&&PC==probe_base+PLT_PROBE_LOADED){
  loaded_seen++;loaded_bank=r[probe_base+PLT_BACKEND_BANKED]!=0;
  require(!expected_error&&loaded_bank==expected_banked,"loader chooses leased/ordinary RAM at runtime");
  memcpy(code_oracle,module_memory(),loaded_code);
 }
 if(!encoded_seen&&PC==probe_base+PLT_PROBE_ENCODED){
  encoded_seen++;unsigned width=expected_kind==1?640:320,count;
  unsigned char want[640];expected_row(expected_kind,width,r+probe_base+PLT_PIXELS,want,&count,expected_rgb);
  require(!r[probe_base+PLT_PROBE_ERROR]&&!memcmp(r+probe_base+PLT_OUTPUT,want,count),"dynamically loaded backend encodes its actual native row");
  require(r[probe_base+PLT_PARAMS+12]*256+r[probe_base+PLT_PARAMS+13]==count,"loaded module reports its output size");
  require(!memcmp(code_oracle,module_memory(),loaded_code),"loaded module retains its relocated code");
 }
 if(!closed_seen&&PC==probe_base+PLT_PROBE_CLOSED){
  closed_seen++;require(r[probe_base+PLT_PROBE_ERROR]==expected_error,"backend load/execute returns the expected error");
  require(!r[probe_base+PLT_BACKEND_BASE]&&!r[probe_base+PLT_BACKEND_BASE+1]&&!r[probe_base+PLT_BACKEND_BANKED],"backend close clears ownership after success or failure");
 }
}
int main(int argc,char**argv){
 if(argc!=5)return 2;model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load(argv[1],&image_size);committed=1;MC6800Init();MC6800Reset();until(60000000);key(0x1c);key(0x1c);prompt_wait();
 unsigned sp0=SP,top0=MC6800GetCpuRam()[0xee1e]*256+MC6800GetCpuRam()[0xee1f];
 invoke(0x2e,0xe5,0,0);unsigned vec=result_x,vecpage=result_b;
 require(invoke(0xe5,0,0,0)==1,"fixture RAMMAN ABI");unsigned free0=result_b;
 unsigned char foreign[114];unsigned reserved=0;
 if(!strcmp(argv[4],"missing"))invoke(0x2f,0xe5,0,0);
 if(!strcmp(argv[4],"busy")){
  require(!invoke(0xe5,1,free0,0x9000),"reserve foreign backend banks");reserved=free0+3;memcpy(foreign,MC6800GetCpuRam()+0x9000,reserved);
  for(unsigned k=3;k<reserved;k++)memset(physical+0x22000+foreign[k]*8192,k^0x5a,8192);
 }
 const char*names[]={"PNTNAT","PNTNAT","PNTNAT","PNTRGB","PNTRGB","PNTHAM","BADHEAD","BADMAG","BADREL","NOTHERE","PNTRGB"};
 unsigned kinds[]={0,1,2,2,3,4,4,4,4,4,4};
 code_oracle=malloc(8192);require(code_oracle!=NULL,"module code oracle");
 for(unsigned k=0;k<sizeof kinds/sizeof kinds[0];k++){
  probe_base=loaded_seen=encoded_seen=closed_seen=0;expected_kind=kinds[k];expected_error=k<6?0:k==9?11:65;expected_rgb=!strcmp(names[k],"PNTRGB");expected_banked=!strcmp(argv[4],"banked");
  if(k<6){char path[100];snprintf(path,sizeof path,"build/paint/%s.PGM",names[k]);size_t len;unsigned char*p=load(path,&len);loaded_code=p[6]*256+p[7];free(p);}
  native_step_hook=loader_observe;
  char line[100];snprintf(line,sizeof line,"b:pnttest b:%s.pgm %u",names[k],expected_kind);command(line);
  require(closed_seen==1&&loaded_seen==(expected_error==0)&&encoded_seen==(expected_error==0),"probe reaches exactly the expected loader/encoder/cleanup stages");
  require(SP==sp0&&MC6800GetCpuRam()[0xee1e]*256+MC6800GetCpuRam()[0xee1f]==top0,"module/probe exit restores the native stack and ordinary heap");
  native_step_hook=NULL;
 }
 if(reserved){
  for(unsigned k=3;k<reserved;k++)for(unsigned j=0;j<8192;j+=127)require(physical[0x22000+foreign[k]*8192+j]==(unsigned char)(k^0x5a),"ordinary fallback leaves foreign RAMMAN banks intact");
  memcpy(MC6800GetCpuRam()+0x9000,foreign,reserved);require(!invoke(0xe5,2,0,0x9000),"release foreign lease");
 }
 if(!strcmp(argv[4],"missing"))invoke(0x2f,0xe5,vecpage,vec);
 require(invoke(0xe5,0,0,0)==1&&result_b==free0,"dynamic module load/close leaks no RAMMAN banks");
 free(code_oracle);printf("PASS Paint loader %s/%s %s: six rows, invalid headers/descriptors/relocations, missing/wrong module, native files, runtime fallback, selectors/IRQ, heap/lease cleanup\n",argv[2],argv[3],argv[4]);return 0;
}
