// Execute real Small-C bytecode using the native UniDOS and RAMMAN paths.
#define COMPACT_FIXTURE 1
#define DIRECT_SD_FIXTURE 1
#define DOS_PROMPT_CYCLES 4000000000ULL
#define ROMDISK_MAIN unused_romdisk_main
#include "test_romdisk_unidos.c"
#undef ROMDISK_MAIN
static unsigned vm_word(unsigned a){unsigned char*r=MC6800GetCpuRam();return r[a]*256+r[a+1];}
static unsigned vm_group,vm_page,break_pending,vm_steps;
static void observe_vm(void){
 unsigned char*r=MC6800GetCpuRam();
 if(ram_group==vm_group&&page==vm_page&&PC>=0xc000&&PC<0xe000){
  vm_steps++;
  if(!cpu_hd){
   unsigned op=MC6800MemReadByte(PC);
   const unsigned char hd[]={4,5,0x18,0x38,0x3a,0x3c,0x3d,0x83,0x93,0xa3,0xb3,0xc3,0xd3,0xe3,0xf3,0xcc,0xdc,0xec,0xfc,0xdd,0xed,0xfd};
   for(unsigned k=0;k<sizeof hd;k++)require(op!=hd[k],"MC6800 ROM never executes an extended opcode");
  }
  if(break_pending&&vm_word(0xe8)==0x4001){break_pending=0;invoke(4,0,0,0);}
 }
}
static int signed_word(unsigned x){return x<32768?(int)x:(int)x-65536;}
static void arithmetic(void){
 unsigned char*r=MC6800GetCpuRam();
 const unsigned values[]={0,1,3,7,0x7fff,0x8000,0x8001,0xfff9,0xfffd,0xffff};
 unsigned count=0;
 for(unsigned l=0;l<10;l++)for(unsigned q=0;q<10;q++)for(unsigned op=38;op<=84;op+=2){
  unsigned a=values[l],b=values[q],expected=0,n=b&31;int x=signed_word(a),y=signed_word(b);
  if((op==44||op==46)&&!b)continue;
  switch(op){
   case 38:expected=a+b;break;case 40:expected=a-b;break;case 42:expected=a*b;break;
   case 44:expected=x/y;break;case 46:expected=x%y;break;
   case 48:expected=a|b;break;case 50:expected=a^b;break;case 52:expected=a&b;break;
   case 54:expected=n>=16?(x<0?65535:0):(x<0?~((a^65535)>>n):a>>n);break;
   case 56:expected=n>=16?0:a<<n;break;
   case 66:expected=a==b;break;case 68:expected=a!=b;break;
   case 70:expected=x<y;break;case 72:expected=x<=y;break;case 74:expected=x>y;break;case 76:expected=x>=y;break;
   case 78:expected=a<b;break;case 80:expected=a<=b;break;case 82:expected=a>b;break;case 84:expected=a>=b;break;
   default:continue;
  }
  const unsigned char code[]={0,a>>8,a,20,0,b>>8,b,op,12,0x55,0,86,0x3f,0x38};
  memcpy(r+0x4000,code,sizeof code);require(invoke(0xef,1,0,0x4000)==0,"arithmetic bytecode returns");
  if(vm_word(0x5500)!=(expected&65535))fprintf(stderr,"op %u %04x %04x got %04x expected %04x\n",op,a,b,vm_word(0x5500),expected&65535);
  require(vm_word(0x5500)==(expected&65535),"VM agrees with independent 16-bit arithmetic oracle");count++;
 }
 printf("PASS %u independent arithmetic cases\n",count);
}
static void function_calls(void){
 unsigned char*r=MC6800GetCpuRam(),dp[32];memcpy(dp,r+0xe0,32);
 unsigned sp=SP;const unsigned desc=0x3600,args=0x3700;
 const unsigned char add[]={2,0,4,8,20,2,0,4,8,38,32};
 memcpy(r+0x4000,add,sizeof add);
 word_at(desc,0x4000);word_at(desc+2,4);word_at(desc+4,args);
 word_at(args,0xff85);word_at(args+2,23);
 require(invoke(0xef,2,0,desc)==0&&vm_word(desc+6)==0xff9c&&vm_word(desc+8)==0,"native function entry copies arguments in source order");
 const unsigned badptr[]={0,0xfff8,0xbdf7};
 for(unsigned k=0;k<3;k++)require(invoke(0xef,2,0,badptr[k])==3,"reject descriptor outside application RAM");
 word_at(desc+2,1);require(invoke(0xef,2,0,desc)==255&&vm_word(desc+8)==255,"reject odd argument byte count");
 word_at(desc+2,66);require(invoke(0xef,2,0,desc)==255,"reject oversized argument list");
 word_at(desc+2,2);word_at(desc+4,0xffff);require(invoke(0xef,2,0,desc)==255,"reject argument address wrap");
 word_at(desc,0);word_at(desc+2,0);require(invoke(0xef,2,0,desc)==255,"reject invalid function address");
 word_at(desc,0x4000);word_at(desc+2,64);word_at(desc+4,args);r[0x4000]=32;
 require(invoke(0xef,2,0,desc)==0&&vm_word(desc+6)==64,"function entry primary register is argument byte count");
 word_at(desc+2,0);word_at(desc+4,0xffff);
 require(invoke(0xef,2,0,desc)==0&&vm_word(desc+6)==0,"zero-argument call synthesizes no argc/argv");
 const unsigned char exiting[]={0,0,7,20,0,0,2,28,0xc1,0x5c};
 memcpy(r+0x4000,exiting,sizeof exiting);
 require(invoke(0xef,2,0,desc)==7&&vm_word(desc+8)==7,"function exit returns to native caller");
 const unsigned char loop[]={24,0x40,0};memcpy(r+0x4000,loop,sizeof loop);break_pending=1;
 require(invoke(0xef,2,0,desc)==255&&!break_pending&&vm_word(desc+8)==255,"BREAK unwinds arbitrary-function entry");
 r[0x4000]=255;require(invoke(0xef,2,0,desc)==255,"invalid function bytecode unwinds cleanly");
 require(SP==sp&&!memcmp(dp,r+0xe0,32),"function entries restore caller stack and direct page");
 puts("PASS native function ABI: argument order/limits, result, errors, exit, BREAK and context");
}

int main(int argc,char**argv){
 if(argc!=5)return 2;
 model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);
 require(n==ROM_BYTES+512,"ROM size");memcpy(config,rom,HEADER_BYTES);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load(argv[1],&image_size);committed=1;MC6800Init();MC6800Reset();until(60000000);key(0x1c);key(0x1c);prompt_wait();watch_resets=1;
 unsigned char lease[21];unsigned reserved=!strcmp(argv[4],"offset")?17:0;
 if(!cpu_hd){command("b:ramload b:zvm6303.rom");require(contains("error $03"),"HD6303 image rejects a classic CPU before any extended instruction");}
 if(reserved){unsigned owner=vm_word(0xec00);word_at(0xec00,0xffff);require(invoke(0xe5,1,reserved,0x3500)==0,"reserve unrelated banks");memcpy(lease,MC6800GetCpuRam()+0x3500,sizeof lease);word_at(0xec00,owner);}
 command("b:ramload /cvm");require(contains("Loaded ZCODEVM"),"CPU-selected VM loaded");
 require(invoke(0xef,0,0,0)==1&&result_x==0x5a56&&result_b==(unsigned)cpu_hd,"VM ABI and selected CPU");
 unsigned char*r=MC6800GetCpuRam();unsigned sp=SP,resident=vm_word(0xee1a);
 invoke(0xec,0,0,0);vm_group=r[result_x+2];vm_page=r[result_x+3];native_step_hook=observe_vm;
 unsigned vm_bank=r[result_x+7];unsigned char rom_snapshot[8192];memcpy(rom_snapshot,physical+0x22000+vm_bank*8192,8192);
 unsigned char dp[32];memcpy(dp,r+0xe0,32);
 command("b:hello");require(contains("CVM HELLO PASS"),"C program printed through banked VM");
 require(SP==sp&&!memcmp(dp,r+0xe0,32),"VM restores stack and application direct page");
 command("b:hello");require(SP==sp&&vm_word(0xee1a)==resident,"second execution reuses VM and resident allocation");
 command("b:cvmtest");require(contains("CVM TEST PASS")&&!contains("CVM TEST FAIL"),"shared Small-C arithmetic, recursion, strings and file regression");
 command("b:native");require(contains("CVM SYSTEM PASS")&&contains("error $55"),"system PGM returns and cannot unload its active VM");
 arithmetic();
 function_calls();
 // Parent bytecode calls a classic native inline routine which invokes a
 // second VM. Both interpreters must retain separate stacks/direct pages.
 const unsigned char parent[]={28,0x40,0x10,12,0x55,2,86,0x3f,0x38};
 const unsigned char inline_call[]={86,0x86,1,0xce,0x54,0,0x3f,0xef,0x86,0x12,0xc6,0x34,0x7e,0xc1,0x24};
 const unsigned char child[]={0,0x56,0x78,12,0x55,4,86,0x3f,0x38};
 memcpy(r+0x4000,parent,sizeof parent);memcpy(r+0x4010,inline_call,sizeof inline_call);memcpy(r+0x5400,child,sizeof child);
 require(invoke(0xef,1,0,0x4000)==0&&vm_word(0x5502)==0x1234&&vm_word(0x5504)==0x5678,"nested VM call restores its parent context");
 const unsigned char loop[]={24,0x40,0};memcpy(r+0x4000,loop,sizeof loop);break_pending=1;
 require(invoke(0xef,1,0,0x4000)==255&&!break_pending,"BREAK leaves VM through its balanced gateway");
 r[0x4000]=255;require(invoke(0xef,1,0,0x4000)==255,"invalid bytecode returns cleanly");
 const unsigned char zero[]={0,0,1,20,0,0,0,44};memcpy(r+0x4000,zero,sizeof zero);
 require(invoke(0xef,1,0,0x4000)==255,"division by zero returns cleanly");
 uint64_t started=virtual_cycles;command("b:unicc -o b:board.asm b:hello.c");
 printf("C VM reference cycles %s UNICC: %llu\n",argv[3],(unsigned long long)(virtual_cycles-started));
 started=virtual_cycles;command("b:unias -o b:board.cmd b:board.asm");
 printf("C VM reference cycles %s UNIAS: %llu\n",argv[3],(unsigned long long)(virtual_cycles-started));
 command("b:board");require(contains("CVM HELLO PASS"),"native compiler and assembler produce an executable C program");
 size_t expected_size;unsigned char*expected=load("build/cvm/HELLO.CMD",&expected_size);
 file_check("B:BOARD.CMD",expected,expected_size);free(expected);
 require(SP==sp&&!memcmp(dp,r+0xe0,32),"all nested/error/tool runs restore stack and direct page");
 command("b:ramload /cvm");require(contains("already loaded"),"automatic load is idempotent");
 require(!memcmp(rom_snapshot,physical+0x22000+vm_bank*8192,8192),"executed VM bank remains byte-identical to its ROM image");
 command("b:ramload /u zcodevm");require(contains("Unloaded ZCODEVM"),"completed VM can be unloaded");
 invoke(0x2e,0xef,0,0);require(result_x==0,"VM vector detached");
 if(reserved){unsigned owner=vm_word(0xec00);memcpy(r+0x3500,lease,sizeof lease);word_at(0xec00,0xffff);require(invoke(0xe5,2,0,0x3500)==0,"unrelated bank lease remains valid");word_at(0xec00,owner);}
 require(!resets&&!fdc_port_accesses,"native DOS survives VM");
 printf("PASS C VM %s/%s %s: CPU selection, arithmetic, files, recursion, nested calls, BREAK, native toolchain, context and unload (%u VM instructions)\n",argv[2],argv[3],argv[4],vm_steps);
 return 0;
}
