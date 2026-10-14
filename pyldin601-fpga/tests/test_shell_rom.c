/* Native BIOS registered INT01 boot entry and the shell supplied by page F. */
#define NATIVE_STABILITY_MAIN unused_stability_main
#include "test_native_stability.c"
#undef NATIVE_STABILITY_MAIN
#include "../build/partitions/shell_labels.h"
static unsigned entered,returned;
static unsigned char saved_scratch[14],*shell_reference;
static word entry_sp;
static unsigned entry_i;
static size_t shell_size;
static int screen_contains(const char *text) {
    unsigned start=crtc[12]*256+crtc[13],stride=crtc[1];
    unsigned step=model_a&&(MC6800GetCpuRam()[0xe629]&2)?2:1;
    unsigned char *ram=MC6800GetCpuRam();
    for(unsigned y=0;y<25;y++)for(unsigned x=0;x<stride/step;x++) {
        unsigned k;for(k=0;text[k];k++)
            if(ram[(start+y*stride+(x+k)*step+(step==2))&65535]!=(unsigned char)text[k])break;
        if(!text[k])return 1;
    }
    return 0;
}
static void decimal_return(unsigned address) {
    uint64_t deadline=virtual_cycles+1000000;
    while(PC!=address&&virtual_cycles<deadline)until(virtual_cycles+1);
    if(PC!=address||SP!=0x7000) {
        dump();fprintf(stderr,"decimal output did not return with its stack intact\n");exit(1);
    }
}
static void bios_char(unsigned value) {
    unsigned char *ram=MC6800GetCpuRam();
    ram[0x8100]=0x3f;ram[0x8101]=0x22;ram[0x8102]=1;
    PC=0x8100;A=value;decimal_return(0x8102);
}
static void check_decimal(void) {
    unsigned entry[2]={0,0};char line[256];
    FILE *listing=fopen("build/partitions/SHELL.CMD.LST","r");
    if(!listing)exit(1);
    while(fgets(line,sizeof line,listing)) {
        sscanf(line,"PR_DEC =$%x",entry);
        sscanf(line,"PR_DEC_24 =$%x",entry+1);
    }
    fclose(listing);
    if(!entry[0]||!entry[1])exit(1);
    /* Exercise the real resident routines and BIOS/STDOUT, including unsigned
       boundaries. The oracle is host decimal formatting and actual video RAM. */
    static const uint32_t values[]={0,1,9,10,65535,16777215,99999999,
        100000000,132890624,999999999,1000000000,2147483647,2147483648u,4294967295u};
    unsigned char *ram=MC6800GetCpuRam();SP=0x7000;i=1;page=0;
    for(unsigned output=0;output<2;output++)for(unsigned k=0;k<sizeof values/sizeof *values;k++) {
        unsigned start=crtc[12]*256+crtc[13],stride=crtc[1];
        unsigned step=model_a&&(ram[0xe629]&2)?2:1;
        for(unsigned y=0;y<25;y++)for(unsigned x=0;x<stride/step;x++)
            ram[(start+y*stride+x*step+(step==2))&65535]=' ';
        bios_char(13);bios_char(10);bios_char('|');
        for(unsigned b=0;b<4;b++)ram[0x8000+b]=values[k]>>(8*b);
        ram[0x8100]=0xbd;ram[0x8101]=entry[output]>>8;ram[0x8102]=entry[output];ram[0x8103]=1;
        PC=0x8100;X=0x8000;decimal_return(0x8103);bios_char('|');
        char expected[32];snprintf(expected,sizeof expected,"|%8u|",values[k]);
        if(!screen_contains(expected)) {
            dump();fprintf(stderr,"decimal %u via %s: expected '%s'\n",values[k],output?"BIOS":"STDOUT",expected);exit(1);
        }
    }
}
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
    /* Exercise ROM fallback without executing the native disk boot sector. */
    unsigned start=le32(image+462+8);image[(start+1)*512-2]=0x55;image[(start+1)*512-1]=0xaa;
    committed=1;native_step_hook=observe_shell;
    MC6800Init();MC6800Reset();until(60000000);key(0x1c);key(0x1c);wait_prompt();
    if(!entered||!returned||!irq_count) {fprintf(stderr,"compressed shell was not invoked\n");return 1;}
    key(0x20);key(0x17);key(0x13);key(0x1c);wait_prompt();
    entered=returned=0;MC6800Reset();until(virtual_cycles+2000000);key(0x1c);key(0x1c);wait_prompt();
    if(!entered||!returned) {fprintf(stderr,"warm Reset did not restore compressed shell\n");return 1;}
    check_decimal();
    printf("PASS %s/%s native INT01, shell startup, DIR and warm Reset; complete shell/scratch/SP/IRQ mask restored, unsigned 32-bit decimal via BIOS/STDOUT with eight-column minimum width, %u timer IRQs\n",argv[1],argv[2],irq_count);
    free(shell_reference);return 0;
}
