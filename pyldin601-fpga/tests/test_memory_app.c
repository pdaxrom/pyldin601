// Run the actual relocatable RAMPAGE through the native UniDOS command loader.
// Full memory verification plus deliberate corruption and ESC cleanup paths.
#define COMPACT_FIXTURE 1
#define DIRECT_SD_FIXTURE 1
#define ROMDISK_MAIN unused_romdisk_main
#include "test_romdisk_unidos.c"
#include "../build/memory-test/rampage_labels.h"
#undef ROMDISK_MAIN

static unsigned original_irq, app_base, injection, injected, saved_group, saved_page, restored;
static void app_step(void){
    unsigned char *r=MC6800GetCpuRam();
    unsigned vector=(r[0xee0a]<<8)|r[0xee0b];
    if(!app_base&&vector!=original_irq){
        app_base=vector-RP_IRQ_PROBE;
        require(app_base>=0x100&&app_base<0xbc00,"PGM loaded into conventional RAM");
        saved_group=r[app_base+RP_SAVED_GROUP];saved_page=r[app_base+RP_SAVED_PAGE];
    }
    if(app_base&&!injected){
        if(injection==1&&r[app_base+RP_PHASE]==1){
            physical[0x22000+37*8192+0x123]^=1;injected=1;
        }else if(injection==2&&r[app_base+RP_BANK]>=2){
            KBDKeyDown(1);injected=1;
        }
    }
    if(app_base&&PC==app_base+RP_RETURN_TO_DOS){
        require(page==saved_page&&ram_group==saved_group,"RAMPAGE restores both paging registers before INT38");
        restored++;
    }
}

int main(int argc,char **argv){
    if(argc!=5)return 2;
    model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");
    injection=atoi(argv[4]);
    MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
    size_t length;
    unsigned char *rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&length);
    require(length==ROM_BYTES+512,"current paged-ROM length");
    memcpy(config,rom,HEADER_BYTES);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
    image=load(argv[1],&image_size);committed=1;
    MC6800Init();MC6800Reset();until(60000000);key(0x1c);key(0x1c);prompt_wait();
    unsigned char *r=MC6800GetCpuRam();unsigned prompt_sp=SP;
    original_irq=(r[0xee0a]<<8)|r[0xee0b];
    unsigned before_irq=irq_count;
    unsigned char preserved[0x12000];memcpy(preserved,physical+0x10000,sizeof preserved);
    native_step_hook=app_step;watch_resets=1;
    const unsigned scans[]={0x30,0x27,0x13,0x1e,0x32,0x19,0x1e,0x22,0x12};
    for(unsigned k=0;k<sizeof scans/sizeof scans[0];k++){
        if(k==1)KBDModKeyDown(2);key(scans[k]);if(k==1)KBDModKeyUp(2);
    }
    key(0x1c);
    uint64_t deadline=virtual_cycles+200000000;
    do{
        until(virtual_cycles+10000);
        if(PC>=0xf380&&PC<=0xf3a8&&SP==prompt_sp)break;
    }while(virtual_cycles<deadline);
    if(virtual_cycles>=deadline)fprintf(stderr,"app=%04x phase=%u bank=%u vector=%04x timer=%04x F0/F1=%02x/%02x kbd=%02x%02x/%02x%02x\n",app_base,r[app_base+RP_PHASE],r[app_base+RP_BANK],(r[0xee0a]<<8)|r[0xee0b],original_irq,page,ram_group,r[0xed0c],r[0xed0d],r[0xed0e],r[0xed0f]);
    require(virtual_cycles<deadline,"RAMPAGE returns to original DOS prompt stack");
    require(app_base&&irq_count>before_irq,"real PGM and 50-Hz IRQs executed");
    require(((r[0xee0a]<<8)|r[0xee0b])==original_irq,"RAMPAGE restores the native timer handler");
    require(restored==1&&ram_group==saved_group,"PGM cleanup executed exactly once and DOS retains RAM group");
    require(!memcmp(preserved,physical+0x10000,sizeof preserved),"monitor/ROM/font untouched");
    require(!resets&&!fdc_port_accesses,"no reset or removed FDC access");
    if(injection==1){
        require(injected&&contains("FAIL phase=01 bank=25")&&contains("address=C123")
                &&contains("expected=C7 got=C6"),
                "RAMPAGE diagnoses injected byte corruption with bank/address");
        require(!contains("PASS: 888 KiB"),"corrupted memory is never reported PASS");
    }else if(injection==2){
        require(injected&&contains("RAMPAGE: aborted."),"ESC abort restores timer and DOS");
        KBDKeyUpCode(1);
    }else{
        require(contains("PASS: 888 KiB, SWI/IRQ."),"RAMPAGE reports the complete pass");
        for(unsigned bank=0;bank<111;bank++)for(unsigned off=0;off<8192;off++){
            unsigned expected=(~(((0xc000+off)>>8)^bank^(off&255)))&255;
            require(physical[0x22000+bank*8192+off]==expected,"all 909312 bytes tested and inverted");
        }
    }
    command("dir a:");command("dir b:");command("dir c:");
    printf("PASS RAMPAGE %s/%s scenario %u: real loader, memory result, IRQ/page/stack cleanup, A/B/C DIR\n",
           argv[2],argv[3],injection);
    return 0;
}
