// Exercise packaged C bytecode from NC, with the CPU-selected VM resident.
#define NC_MAIN release_nc_panels
#ifndef RELEASE_NC_SOURCE
#define RELEASE_NC_SOURCE "test_nc.c"
#endif
#include RELEASE_NC_SOURCE

static unsigned release_vm_return, release_vm_status;
static void release_observe(void) {
 observe();
 if(release_vm_return&&PC==release_vm_return){release_vm_status=A;release_vm_return=0;}
 if(PC<0xbe00&&MC6800MemReadByte(PC)==0x3f&&MC6800MemReadByte(PC+1)==0xef&&A==1)
  release_vm_return=PC+2;
}
int main(int argc,char**argv) {
 if(argc!=6)return 2;
 int result=release_nc_panels(argc,argv);if(result)return result;
 native_step_hook=NULL;
 invoke(0x12,0,model_a?0x71:0,0);
 command("handles 16");
 command("c:\\cvm\\ramload /cvm");
 require(contains("Loaded ZCODEVM"),"packaged loader installs the VM from C:\\CVM");
 require(invoke(0xef,0,0,0)==1&&result_b==(unsigned)cpu_hd&&result_x==0x5a56,"packaged VM matches the CPU");
 command("c:\\cvm\\hello");require(contains("CVM HELLO PASS"),"packaged C bytecode runs from the original disk shell");
 unsigned sp0=SP,heap0=ram_word(0xee1e),resident0=ram_word(0xee1a);
 require(invoke(0xe5,0,0,0)==1,"RAMMAN remains accessible after VM installation");unsigned banks0=result_b;
 nc_base=core_base=core_entries=wait_entries=core_load_armed=0;
 native_step_hook=release_observe;type("b:nc");key(0x1c);panels(0);
 const char*commands[]={"c:\\cvm\\hello","c:\\cvm\\cvmtest"};
 for(unsigned k=0;k<2;k++){
  unsigned after=wait_entries,entries=core_entries;
  release_vm_status=256;release_vm_return=0;
  type(commands[k]);key(0x1c);loaded(entries+1);panels(after);
  require(release_vm_status==0&&!release_vm_return,"C bytecode completes successfully and NC reloads its panels");
 }
 key(0x44);prompt_wait();
 require(SP==sp0&&ram_word(0xee1e)==heap0&&ram_word(0xee1a)==resident0,"NC restores the resident VM owner's heap and stack");
 require(invoke(0xe5,0,0,0)==1&&result_b==banks0,"only the deliberate resident VM bank remains allocated");
 puts("PASS release integration: original shell -> resident VM -> NC -> HELLO/CVMTEST -> NC -> shell; stack/heap/banks preserved");
 return 0;
}
