// Execute the actual bootstrap menus with raw Set 2 bytes, not native key codes.
#include <stdint.h>
static int hg_read_byte(uint16_t address, unsigned char *out);
static int hg_write_byte(uint16_t address, unsigned char value);
#define HG_FIXTURE 1
#define main firmware_test_main
#include "test_firmware.c"
#undef main

static unsigned char raw[8], key_code=255;
static unsigned raw_head, raw_count, phase, injected, extended, scan;

static void push(unsigned value) { raw[(raw_head+raw_count++)&7]=value; }
static void inject(void) {
    if(committed || raw_count) return;
    if(phase==1) {
        if(extended) push(0xe0);
        push(0xf0); push(scan); phase=2;
    } else if(!phase && setup_position<setup_length) {
        unsigned key=setup_script[setup_position++];
        extended=1;
        switch(key) {
        case 0xf9:scan=0x71;break;
        case 0xc1:scan=0x6b;break;
        case 0xc2:scan=0x74;break;
        case 0xc3:scan=0x72;break;
        case 0xc4:scan=0x75;break;
        case 0xc0:scan=0x5a;extended=0;break;
        case 0x1b:scan=0x76;extended=0;break;
        default:fprintf(stderr,"unsupported menu key %02x\n",key);exit(1);
        }
        if(extended) push(0xe0);
        push(scan);
        // Unmapped make must not steal ownership of the recognized key's break.
        push(0x1c);
        phase=3;
        if(getenv("BOOT_FAST_TAPS")) {
            if(extended) push(0xe0);
            push(0xf0); push(scan); phase=2;
        }
        injected++;
    }
}
static int hg_read_byte(uint16_t address,unsigned char *out) {
    if(address>=0xe6b0 && address<=0xe6b7) {
        *out=255;
        switch(address&7) {
        case 0:*out='R';break;
        case 1:inject();*out=(raw_count!=0)|4;break;
        case 2:if(raw_count){*out=raw[raw_head++&7];raw_count--;}break;
        case 3:*out=raw_count;break;
        case 4:*out=2;break;
        }
        return 1;
    }
    if(address==0xe628) {
        *out=key_code;
        if(!committed) {
            if(key_code!=255 && phase==3) phase=1;
            else if(key_code==255 && phase==2) phase=0;
        }
        return 1;
    }
    if(address==0xe62a || address==0xe62e) { *out=0x37|(caps_off?8:0);return 1; }
    return 0;
}
static int hg_write_byte(uint16_t address,unsigned char value) {
    if(address==0xe628) {key_code=value;return 1;}
    if(address==0xe6b3) {
        if(value&1)raw_head=raw_count=0;
        return 1;
    }
    if(address==0xe62a || address==0xe62e) {caps_off=(value&8)!=0;return 1;}
    return address>=0xe6b0 && address<=0xe6b7;
}
int main(int argc,char **argv) {
    int result=firmware_test_main(argc,argv);
    if(!result && argc>3) {
        unsigned flags=0, partition=0, writes=0;
        if(!strcmp(argv[3],"save8") || !strcmp(argv[3],"save-left")) {
            flags=15; writes=1;
        } else if(!strcmp(argv[3],"save-part4")) {
            flags=3; partition=4; writes=1;
        } else if(!strcmp(argv[3],"save-part-left")) {
            partition=36; writes=1;
        } else if(strcmp(argv[3],"auto") && strcmp(argv[3],"exit")) {
            fprintf(stderr,"unsupported raw menu scenario\n");return 2;
        }
        if((model_a|(cpu_hd<<1)|(boot_speed<<2))!=flags ||
           boot_partition!=partition || sd_writes!=writes) {
            fprintf(stderr,"raw menu result flags=%u partition=%u writes=%u; expected %u/%u/%u\n",
                    model_a|(cpu_hd<<1)|(boot_speed<<2),boot_partition,sd_writes,
                    flags,partition,writes);
            return 1;
        }
    }
    if(!result && injected!=setup_length) {
        fprintf(stderr,"raw boot menu did not consume all keys: %u/%u\n",injected,setup_length);
        return 1;
    }
    if(!result)printf("PASS raw PS/2 bootstrap: %u make/break menu events, unknown-key interleaving\n",injected);
    return result;
}
