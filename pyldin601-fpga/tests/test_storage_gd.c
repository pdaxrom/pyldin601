// Original GD.CMD loaded by native UniDOS after installing the resident HG.
// Compare both the splash and editor bitmap with the unmodified ROM baseline.
#define HG_UNIDOS_MAIN unused_hg_main
#include "test_hg_unidos.c"
static unsigned entered,graphics_allocation;
static void gd_step(void) {
    unsigned char *ram=MC6800GetCpuRam();
    if(PC==0x100)entered++;
    if(entered&&PC==0x12a){
        if(!X){fprintf(stderr,"GD could not allocate its native graphics screen\n");exit(1);}
        graphics_allocation=X;
    }
}
static void snapshot(FILE *golden,int baseline,const char *stage) {
    unsigned char *ram=MC6800GetCpuRam();
    unsigned start=((crtc[12]*256+crtc[13])*8)&65535;
    unsigned width=model_a?80:40,length=width*200;
    if(!entered||!graphics_allocation||resets||crtc[1]!=width||crtc[6]!=25||ram[0xe629]!=0x39){
        dump();fprintf(stderr,"GD %s failed to establish its native graphic screen\n",stage);exit(1);
    }
    unsigned different=0,lit=0;
    for(unsigned n=0;n<length;n++) {
        unsigned value=ram[(start+n)&65535];lit+=value!=0;
        if(baseline) {if(fputc(value,golden)==EOF)exit(1);}
        else {int expected=fgetc(golden);if(expected==EOF)exit(1);different+=value!=expected;}
    }
    if(lit<100||different){fprintf(stderr,"GD %s bitmap: %u lit bytes, %u differences from original\n",stage,lit,different);exit(1);}
}
int main(int argc,char **argv) {
    if(argc!=5)return 2;
    model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");hg_v2=1;
    MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
    size_t size;
#ifdef LEGACY_FIXTURE
    const int baseline=1;
    unsigned char *rom=load("build/legacy-rom.reference",&size);
#else
    const int baseline=0;
    unsigned char *rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&size);
#endif
    if(size!=ROM_BYTES+512)return 1;
    memcpy(config,rom,HEADER_BYTES);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
#ifdef LEGACY_FIXTURE
    if(model_a){rom=load("build/partitions/BIOS_A-BASE.ROM",&size);if(size!=4096)return 1;memcpy(physical+ROM_BIOS,rom,size);free(rom);}
#endif
    image=load(argv[1],&image_size);host_image=load("build/storage-gd-host.img",&host_size);
#ifdef LEGACY_FIXTURE
    memcpy(config+64,image+462,32);
    for(unsigned n=0;n<2;n++){
        unsigned off=446+16*(n+1),base=32+16*n;memcpy(config+base,image+off+8,8);
        const unsigned char *bpb=image+le32(config+base)*512;
        config[base+8]=le16(bpb+24);config[base+10]=le16(bpb+26);
        config[base+12]=le16(bpb+19)/(le16(bpb+24)*le16(bpb+26));
    }
#endif
    committed=1;MC6800Init();MC6800Reset();i=1;
    until(60000000);key(0x1c);key(0x1c);until(virtual_cycles+1000000);
    if(!contains("A:\\>"))return 1;watch_resets=1;
    unsigned char *ram=MC6800GetCpuRam();
    while(hg_drive<8&&(ram[0xeb03+hg_drive*2]||ram[0xeb04+hg_drive*2]))hg_drive++;
    command("b:hg");
    if(!contains("host date/time synchronized"))return 1;
    native_step_hook=gd_step;
    // GD is a fixed-address CMD, executed through the real command loader.
    const unsigned scans[]={baseline?0x30:0x2e,0x27,0x22,0x20,0x34,0x2e,0x32,0x20};
    for(unsigned n=0;n<8;n++){if(n==1)KBDModKeyDown(2);key(scans[n]);if(n==1)KBDModKeyUp(2);}
    key(0x1c);until(virtual_cycles+50000000);
    FILE *golden=fopen(argv[4],baseline?"wb":"rb");if(!golden)return 1;
    snapshot(golden,baseline,"splash");
    key(0x1c);until(virtual_cycles+50000000);
    snapshot(golden,baseline,"editor");
    if(!baseline&&fgetc(golden)!=EOF)return 1;
    if(fclose(golden))return 1;
    printf("PASS GD %s/%s after HG: splash and editor %s, nonzero screen allocation, zero resets\n",argv[2],argv[3],baseline?"baseline recorded":"byte-identical to original ROM");
    return 0;
}
