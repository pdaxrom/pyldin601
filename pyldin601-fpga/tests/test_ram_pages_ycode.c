// Execute the shipped Y ROMs, the original UPC/UPL, and a program compiled
// by UPC. Check bank switching and the stack-based ExitYcode on both BIOSes.
#ifndef LEGACY_FIXTURE
#define COMPACT_FIXTURE 1
#endif
#define DIRECT_SD_FIXTURE 1
#define ROMDISK_MAIN unused_romdisk_main
#include "test_romdisk_unidos.c"
#undef ROMDISK_MAIN

static unsigned prompt_sp, switch1, switch2, count1, count2;
static unsigned inject_group, injected, before_irq;

static void y_step(void){
    if(PC==switch1||PC==switch2){
        if(inject_group&&!injected){
            // Model a Y program's inline machine routine changing E6F1.
            // Subsequent Y bank switches and nested BIOS/DOS calls must
            // preserve that context until ExitYcode returns to its caller.
            ram_group=13;injected=1;
        }
        if(PC==switch1){require(A==9,"Y main loop selects ROM page 9");count1++;}
        else{require(B==13,"Y standard/long instruction selects ROM page D");count2++;}
        if(injected)require(ram_group==13,"direct Y ROM switch retains E6F1");
    }
}

static void y_command(const char *text){
    const char *letters="abcdefghijklmnopqrstuvwxyz";
    const unsigned scans[]={0x1e,0x30,0x2e,0x20,0x12,0x21,0x22,0x23,0x17,0x24,0x25,0x26,0x32,0x31,0x18,0x19,0x10,0x13,0x1f,0x14,0x16,0x2f,0x11,0x2d,0x15,0x2c};
    for(;*text;text++){
        const char *p=strchr(letters,*text);
        unsigned scan=p?scans[p-letters]:*text=='.'?0x34:*text==' '?0x39:*text==':'?0x27:0;
        require(scan!=0,"Y test command key");
        if(*text==':')KBDModKeyDown(2);
        key(scan);
        if(*text==':')KBDModKeyUp(2);
    }
    key(0x1c);
    uint64_t deadline=virtual_cycles+100000000;
    // The compiler takes longer than the ordinary DIR budget. Match the
    // original prompt's SP too: the disk-error question uses the same
    // keyboard routine and leaves an earlier prompt visible on the screen.
    do{
        until(virtual_cycles+10000);
        if(PC>=0xf380&&PC<=0xf3a8&&SP==prompt_sp)return;
    }while(virtual_cycles<deadline);
    require(0,"Y command returns to the original DOS input stack");
}

static unsigned call(unsigned op,unsigned a,unsigned b,unsigned x){
    unsigned char *r=MC6800GetCpuRam();
    unsigned sp0=SP,page0=page,group0=ram_group;
    r[0x210]=0x3f;r[0x211]=op;r[0x212]=1;
    PC=0x210;A=a;B=b;X=x;
    uint64_t deadline=virtual_cycles+15000000;
    do{until(virtual_cycles+1);require(virtual_cycles<deadline,"Y test SWI returns");}while(PC!=0x212);
    require(SP==sp0&&page==page0&&ram_group==group0,"Y/DOS returns preserve SP, E6F0 and E6F1");
    return A;
}

static unsigned open_program(void){
    unsigned char *r=MC6800GetCpuRam();
    strcpy((char*)r+0x3100,"B:YPAGES.PGM");word_at(0x3000,0x3100);word_at(0x3002,0);
    require(call(0x4a,1,0,0x3000)==0,"open compiled Y program");
    return B;
}

int main(int argc,char **argv){
    if(argc!=5)return 2;
    model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");
    MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
    size_t rom_size;
#ifdef LEGACY_FIXTURE
    unsigned char *rom=load("build/legacy-rom.reference",&rom_size);
#else
    unsigned char *rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&rom_size);
#endif
    require(rom_size==ROM_BYTES+512,"native ROM bundle length");
    memcpy(config,rom,HEADER_BYTES);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
    image=load(argv[1],&image_size);
#ifdef LEGACY_FIXTURE
    if(model_a){
        rom=load("build/partitions/BIOS_A-BASE.ROM",&rom_size);
        require(rom_size==4096,"original BIOS_A length");
        memcpy(physical+ROM_BIOS,rom,rom_size);free(rom);
    }
    memcpy(config+64,image+462,32);
    for(unsigned k=0;k<2;k++){
        unsigned off=446+16*(k+1),base=32+16*k;memcpy(config+base,image+off+8,8);
        const unsigned char *bpb=image+le32(config+base)*512;
        config[base+8]=le16(bpb+24);config[base+10]=le16(bpb+26);
        config[base+12]=le16(bpb+19)/(le16(bpb+24)*le16(bpb+26));
    }
#endif
    committed=1;MC6800Init();MC6800Reset();until(60000000);
    key(0x1c);key(0x1c);prompt_wait();prompt_sp=SP;watch_resets=1;
    unsigned char *r=MC6800GetCpuRam();
    require(r[0xbe02]==9&&r[0xbe03]==13,"native interpreter initialized both ROM banks");
    for(unsigned p=0xbed2;p<0xbefe - 2;p++){
        if(r[p+1]!=0xe6||r[p+2]!=0xf0)continue;
        if(r[p]==0xb7){require(!switch1,"unique Y bank 1 switch");switch1=p;}
        if(r[p]==0xf7){require(!switch2,"unique Y bank 2 switch");switch2=p;}
    }
    require(switch1&&switch2,"Y RAM trampoline uses E6F0");
    native_step_hook=y_step;
#ifndef LEGACY_FIXTURE
    y_command("c:");y_command("c:upc c:ypages.pas");
    require(contains("Successful compilation."),"original UPC compiles the Y regression");
    y_command("c:upl c:ypages");
    require(contains("YPAGES")&&contains("segment."),"original UPL reads the compiled Y module");
    y_command("c:ypages");
    require(contains("Y PAGE PASS 220"),"real UniDOS command loader executes compiled Y code");
    y_command("copy c:ypages.pgm b:ypages.pgm");
    require(!contains("File creation failure."),"compiled program copied for original-ROM comparison");
    memset(physical+0x22000,0xa7,111*8192);
#endif
    before_irq=irq_count;
#ifdef LEGACY_FIXTURE
    // The original board has no E6F1 or paged RAM. One root invocation is
    // the oracle for ExitYcode's native register/frame convention.
    const unsigned groups[]={0},slots[]={7};
#else
    const unsigned groups[]={0,1,9,18},slots[]={1,2,3,4,5,6};
#endif
    unsigned runs=0;
    for(unsigned k=0;k<sizeof groups/sizeof groups[0];k++)for(unsigned s=0;s<sizeof slots/sizeof slots[0];s++){
        PC=0x212;SP=0x7000;r[0]=0;page=0xa0|slots[s];ram_group=groups[k];
        // The original emulator fixture reads the CSR from its RAM mirror.
        r[0xe6f0]=page;
        unsigned handle=open_program();
        h=1;i=1;n=0;z=1;v=0;c=1;
        injected=0;
#ifndef LEGACY_FIXTURE
        inject_group=1;
#endif
        require(call(0xa0,handle,255,0x8123)==handle,"Y exit restores caller A");
        inject_group=0;
        if(B||X!=0x8123||h!=1||i!=1||n||z!=1||v||c!=1)fprintf(stderr,"Y return A=%02x B=%02x X=%04x HINZVC=%u%u%u%u%u%u\n",A,B,X,h,i,n,z,v,c);
        require(B==0&&X==0x8123&&h==1&&i==1&&n==0&&z==1&&v==0&&c==1,"Y exit code and caller X/CCR");
        require(contains("Y PAGE PASS 220"),"Y program completes");
#ifndef LEGACY_FIXTURE
        require(injected,"Y program executes with a changed inner RAM group");
#endif
        // ExitYcode abandons nested interpreter SWIs by restoring the saved
        // SP. The original interpreter also returns inDOS=1 on this root
        // call; verify the same behavior on the unchanged BIOS baseline.
        require(r[0]==1,"Y exit retains original inDOS convention");
        // The interpreter owns and closes its input handle; do not close it
        // again. Read output through native DOS to check its file I/O too.
#ifndef LEGACY_FIXTURE
        static const unsigned char expected[]="Y PAGE SUM 220\r\n";
        file_check("B:YRESULT.TXT",expected,sizeof expected-1);
#endif
        require(ram_group==groups[k],"output read retains caller RAM group");
        runs++;
    }
#ifndef LEGACY_FIXTURE
    for(unsigned p=0x22000;p<0x100000;p++)require(physical[p]==0xa7,"Y ROM switches do not write paged RAM");
#endif
    require(count1>0&&count2>0&&irq_count>before_irq,"both direct Y switches and IRQs exercised");
    require(!resets&&!fdc_port_accesses,"Y execution caused no reset or removed FDC access");
    FILE *f=fopen(argv[4],"wb");
    require(f&&fwrite(image,1,image_size,f)==image_size&&fclose(f)==0,"save disposable Y test image");
    printf("PASS Y interpreter %s/%s %s: %u/%u direct bank switches, %u runs, file I/O, caller %s, IRQs\n",
           argv[2],argv[3],
#ifdef LEGACY_FIXTURE
           "original BIOS baseline",
#else
           "paged BIOS and native UPC/UPL",
#endif
           count1,count2,runs,
#ifdef LEGACY_FIXTURE
           "SP/E6F0/X/CCR"
#else
           "SP/E6F0/E6F1/X/CCR"
#endif
           );
    return 0;
}
