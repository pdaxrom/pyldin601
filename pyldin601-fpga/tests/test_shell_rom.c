/* Native BIOS banked INT E3, with the entire shell supplied by page F. */
#define NATIVE_STABILITY_MAIN unused_stability_main
#include "test_native_stability.c"
#undef NATIVE_STABILITY_MAIN
#include "../build/partitions/shell_labels.h"
static unsigned entered,returned;
static unsigned char saved_scratch[14],*shell_reference;
static word entry_sp;
static unsigned entry_i;
static size_t shell_size;
static void observe_shell(void) {
    unsigned char *ram=MC6800GetCpuRam();
    if(page==15&&PC==SH_SHELL_COPY) {
        if(entered) return;
        memcpy(saved_scratch,ram+0x80,14);entry_sp=SP;entry_i=i;entered=1;
    }
    if(page==15&&PC==SH_SHELL_RETURN) {
        if(memcmp(saved_scratch,ram+0x80,14)||SP!=entry_sp||i!=entry_i||memcmp(shell_reference,ram+0x1000,shell_size)) {
            fprintf(stderr,"shell did not restore complete data/scratch/stack/IRQ mask\n");exit(1);
        }
        /* A pending IRQ can revisit the RTS after servicing the timer. */
        returned=1;
    }
}
int main(int argc,char **argv) {
    if(argc!=3) return 2;
    model_a=!strcmp(argv[1],"601a");cpu_hd=!strcmp(argv[2],"hd6303");
    MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
    size_t n;unsigned char *rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);
    if(n!=ROM_BYTES+512) return 1;
    memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
    shell_reference=load("build/partitions/SHELL.CMD",&shell_size);
    image=load("images/sd.img",&image_size);memcpy(config+64,image+462,32);
    committed=1;native_step_hook=observe_shell;
    MC6800Init();MC6800Reset();until(60000000);key(0x1c);key(0x1c);wait_prompt();
    if(!entered||!returned||!irq_count) {fprintf(stderr,"compressed shell was not invoked\n");return 1;}
    key(0x20);key(0x17);key(0x13);key(0x1c);wait_prompt();
    entered=returned=0;MC6800Reset();until(virtual_cycles+2000000);key(0x1c);key(0x1c);wait_prompt();
    if(!entered||!returned) {fprintf(stderr,"warm Reset did not restore compressed shell\n");return 1;}
    printf("PASS %s/%s native INT E3, single-page shell startup, DIR and warm Reset; complete shell/scratch/SP/IRQ mask restored, %u timer IRQs\n",argv[1],argv[2],irq_count);
    free(shell_reference);return 0;
}
