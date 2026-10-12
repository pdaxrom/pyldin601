/* Exercise host encoding against the actual UniAS-assembled MC6800 decoder. */
#define main unused_firmware_data_main
#include "../tools/firmware_data.c"
#undef main
#include "core/mc6800.h"
#include "../build/partitions/shell_labels.h"

static unsigned char rom[8192];
byte *allocateCpuRam(dword size) { return calloc(1,size); }
int SuperIoInit(void) { return 0; }
int SuperIoFinish(void) { return 0; }
void SuperIoReset(void) {}
void SuperIoUpdate(void) {}
int SWIemulator(int swi,byte *a,byte *b,word *x,byte *t,word *pc) {
    (void)swi;(void)a;(void)b;(void)x;(void)t;(void)pc;fail("unexpected shell SWI");return 0;
}
int SuperIoReadByte(word a,byte *out) {
    if(a>=0xc000&&a<0xe000) {*out=rom[a-0xc000];return 1;}return 0;
}
int SuperIoWriteByte(word a,byte d) {
    (void)d;if(a>=0xc000&&a<0xe000) fail("decoder wrote ROM");return 0;
}
#include "core/mc6800.c"

static unsigned checked;
static void run_case(const unsigned char *input,size_t size) {
    unsigned char packed[32768],decoded[16000];struct shell_stats stats={0,0,0,0};
    size_t consumed,length=shell_encode(input,size,packed,sizeof packed,&stats);
    if(shell_decode(packed,length,decoded,sizeof decoded,&consumed)!=size||consumed!=length||memcmp(input,decoded,size))
        fail("host shell codec roundtrip");
    if(length>0xdfff-SH_SHELL_BYTES) fail("test stream exceeds ROM");
    memcpy(rom+SH_SHELL_BYTES-0xc000,packed,length);
    for(unsigned cpu=0;cpu<2;cpu++) for(unsigned masked=0;masked<2;masked++) {
        MC6800SetMachine(cpu?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);MC6800Init();
        unsigned char *ram=MC6800GetCpuRam();memset(ram,0x5a,65536);
        for(unsigned p=0;p<0x1000;p++) ram[p]=(unsigned char)(p*37+checked);
        unsigned char scratch[14];memcpy(scratch,ram+0x80,14);
        ram[0xbe00]=2;ram[0xbe01]=0;PC=SH_SHELL_COPY;SP=0xbdff;X=0x6789;
        c=v=z=n=h=1;i=masked;
        unsigned steps=0;while(PC!=0x200&&steps++<2000000) MC6800Step();
        if(PC!=0x200||SP!=0xbe01||i!=masked||!c||!v||!z||!n||!h) fail("decoder stack/flags return");
        if(memcmp(input,ram+0x1000,size)||memcmp(scratch,ram+0x80,14)) fail("decoder data/scratch mismatch");
        for(unsigned p=0;p<0x1000;p++) if(ram[p]!=(unsigned char)(p*37+checked)) fail("decoder changed low RAM");
        for(unsigned p=(unsigned)(0x1000+size);p<0xbd00;p++) if(ram[p]!=0x5a) fail("decoder output overrun");
        MC6800Finish();free(ram);
    }
    checked++;
}
int main(void) {
    size_t size;unsigned char *data=read_file("build/partitions/SHELL.ROM",&size);
    if(size!=sizeof rom) fail("shell ROM size");memcpy(rom,data,size);free(data);
    unsigned char sample[16000];uint32_t random=0x6303601;
    for(unsigned size=0;size<=96;size++) {
        for(unsigned p=0;p<size;p++) {random=random*1664525u+1013904223u;sample[p]=(unsigned char)(random>>24);}
        run_case(sample,size);
    }
    for(unsigned size=2;size<=512;size+=17) {memset(sample,'A',size);run_case(sample,size);}
    for(unsigned p=0;p<256;p++) {random=random*1664525u+1013904223u;sample[p]=(unsigned char)(random>>24);}
    memset(sample+256,0,8192-256);memcpy(sample+8192,sample,256);run_case(sample,8448);
    memset(sample,0,sizeof sample);run_case(sample,sizeof sample);
    data=read_file("build/partitions/SHELL.CMD",&size);run_case(data,size);free(data);
    printf("PASS %u packed streams on MC6800/HD6303, IRQ mask 0/1: literal/flag boundaries, overlap, 8-KiB distance, 255-byte matches, all flags/low RAM/stack restored\n",checked);
    return 0;
}
