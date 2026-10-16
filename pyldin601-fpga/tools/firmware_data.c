/* Data/PGM packaging for the UniAS build. No instruction encoder or source editor. */
#include <ctype.h>
#include <errno.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void fail(const char *s) { fprintf(stderr,"firmware-data: %s\n",s); exit(1); }
static FILE *open_file(const char *p,const char *mode) {
    FILE *f=fopen(p,mode); if(!f) { perror(p); exit(1); } return f;
}
static unsigned char *read_file(const char *p,size_t *size) {
    FILE *f=open_file(p,"rb");
    if(fseek(f,0,SEEK_END)||ftell(f)<0) fail("input size");
    *size=(size_t)ftell(f); rewind(f);
    unsigned char *d=malloc(*size+1); if(!d) fail("allocation");
    if(fread(d,1,*size,f)!=*size||fclose(f)) fail("input read");
    d[*size]=0; return d;
}
static void write_file(const char *p,const void *data,size_t size) {
    FILE *f=open_file(p,"wb");
    if(fwrite(data,1,size,f)!=size||fclose(f)) fail("output write");
}
static unsigned number(const char *s) {
    char *end; unsigned long n=strtoul(s,&end,0);
    if(!*s||*end||n>0x10000000UL) fail("invalid size"); return (unsigned)n;
}
static unsigned be16(const unsigned char *p) { return (p[0]<<8)|p[1]; }
static void include_bytes(FILE *f,const unsigned char *p,size_t size) {
    for(size_t i=0;i<size;i++) {
        if(i%16==0) fputs("    db ",f);
        fprintf(f,"$%02x%s",p[i],i%16==15||i+1==size?"\n":",");
    }
}

/* Original Uniload LZ stream: 16 LSB-first control bits, an 8-KiB window,
 * short 2..5-byte matches and long 3..255-byte matches. The original decoder
 * refills the control word immediately after bit 16, before token payload.
 * Dynamic programming minimizes token bit cost over the remaining input. */
#define SHELL_MAX_BYTES 16000u
struct shell_input { const unsigned char *data; size_t size,at; unsigned flags,bits; };
static unsigned shell_byte(struct shell_input *s) {
    if(s->at>=s->size) fail("truncated packed shell");
    return s->data[s->at++];
}
static void shell_flags(struct shell_input *s) {
    s->flags=shell_byte(s);s->flags|=shell_byte(s)<<8;s->bits=16;
}
static unsigned shell_bit(struct shell_input *s) {
    unsigned bit=s->flags&1;s->flags>>=1;
    if(!--s->bits) shell_flags(s);
    return bit;
}
static size_t shell_decode(const unsigned char *data,size_t size,
                           unsigned char *out,size_t capacity,size_t *consumed) {
    struct shell_input s={data,size,0,0,0};size_t n=0;shell_flags(&s);
    for(;;) {
        if(shell_bit(&s)) {
            if(n==capacity) fail("unpacked shell overflow");
            out[n++]=(unsigned char)shell_byte(&s);continue;
        }
        unsigned length,distance;
        if(!shell_bit(&s)) {
            length=shell_bit(&s)<<1;length|=shell_bit(&s);length+=2;
            distance=256-shell_byte(&s);
        } else {
            unsigned low=shell_byte(&s),high=shell_byte(&s);
            distance=8192-((high>>3)<<8|low);length=high&7;
            if(length) length+=2;
            else {length=shell_byte(&s);if(!length) break;}
        }
        if(distance>n||length>capacity-n) fail("invalid packed shell reference");
        for(unsigned j=0;j<length;j++,n++) out[n]=out[n-distance];
    }
    *consumed=s.at;return n;
}
struct shell_output { unsigned char *data;size_t size,capacity,group;unsigned bit; };
static void shell_put(struct shell_output *s,unsigned byte) {
    if(s->size==s->capacity) fail("packed shell overflow");
    s->data[s->size++]=(unsigned char)byte;
}
static void shell_group(struct shell_output *s) {
    s->group=s->size;shell_put(s,0);shell_put(s,0);s->bit=0;
}
static void shell_put_bit(struct shell_output *s,unsigned bit) {
    s->data[s->group+s->bit/8]|=(unsigned char)(bit<<(s->bit%8));
    if(++s->bit==16) shell_group(s);
}
struct shell_choice { unsigned length,distance,type; };
struct shell_stats { unsigned literal,short_match,long_match,extended_match; };
static size_t shell_encode(const unsigned char *in,size_t n,
                           unsigned char *out,size_t capacity,struct shell_stats *stats) {
    unsigned *cost=calloc(n+1,sizeof *cost);
    struct shell_choice *choices=calloc(n+1,sizeof *choices);
    if(!cost||!choices) fail("shell encoder allocation");
    for(size_t p=n;p--;) {
        unsigned best=9+cost[p+1];struct shell_choice choice={1,0,0};
        unsigned short_len=0,short_dist=0,long_len=0,long_dist=0;
        unsigned window=p<8192?(unsigned)p:8192;
        unsigned limit=n-p<255?(unsigned)(n-p):255;
        for(unsigned distance=1;distance<=window;distance++) {
            if(limit<2||in[p]!=in[p-distance]||in[p+1]!=in[p+1-distance]) continue;
            unsigned length=2;
            while(length<limit&&in[p+length]==in[p+length-distance]) length++;
            if(distance<=256&&length>short_len) {short_len=length;short_dist=distance;}
            if(length>=3&&length>long_len) {long_len=length;long_dist=distance;}
            if(long_len==limit&&short_len>=(limit<5?limit:5)) break;
        }
        for(unsigned length=2;length<=short_len&&length<=5;length++) {
            unsigned c=12+cost[p+length];
            if(c<best) {best=c;choice=(struct shell_choice){length,short_dist,1};}
        }
        for(unsigned length=3;length<=long_len;length++) {
            unsigned c=(length<=9?18:26)+cost[p+length];
            if(c<best) {best=c;choice=(struct shell_choice){length,long_dist,2};}
        }
        cost[p]=best;choices[p]=choice;
    }
    struct shell_output s={out,0,capacity,0,0};shell_group(&s);
    for(size_t p=0;p<n;) {
        struct shell_choice c=choices[p];
        if(!c.type) {shell_put_bit(&s,1);shell_put(&s,in[p]);stats->literal++;}
        else if(c.type==1) {
            shell_put_bit(&s,0);shell_put_bit(&s,0);
            shell_put_bit(&s,(c.length-2)>>1);shell_put_bit(&s,(c.length-2)&1);
            shell_put(&s,0u-c.distance);stats->short_match++;
        } else {
            shell_put_bit(&s,0);shell_put_bit(&s,1);
            unsigned offset=(0u-c.distance)&8191;
            shell_put(&s,offset);shell_put(&s,(offset>>8)<<3|(c.length<=9?c.length-2:0));
            if(c.length>=10) {shell_put(&s,c.length);stats->extended_match++;}
            else stats->long_match++;
        }
        p+=c.length;
    }
    shell_put_bit(&s,0);shell_put_bit(&s,1);
    shell_put(&s,0);shell_put(&s,0);shell_put(&s,0);
    free(cost);free(choices);return s.size;
}

/* SHA-256 is used only to describe build outputs; it does not alter them. */
static uint32_t rotate(uint32_t x,unsigned n) { return x>>n|x<<(32-n); }
static void sha256(const unsigned char *data,size_t size,char result[65]) {
    static const uint32_t k[64]={
        0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
        0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
        0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
        0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
        0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
        0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
        0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
        0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2};
    uint32_t h[8]={0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19};
    size_t total=(size+9+63)&~(size_t)63;
    unsigned char *p=calloc(total,1); if(!p) fail("hash allocation");
    memcpy(p,data,size); p[size]=0x80;
    uint64_t bits=(uint64_t)size*8;
    for(unsigned i=0;i<8;i++) p[total-1-i]=(unsigned char)(bits>>(8*i));
    for(size_t at=0;at<total;at+=64) {
        uint32_t w[64];
        for(unsigned i=0;i<16;i++) w[i]=(uint32_t)p[at+4*i]<<24|(uint32_t)p[at+4*i+1]<<16|(uint32_t)p[at+4*i+2]<<8|p[at+4*i+3];
        for(unsigned i=16;i<64;i++) w[i]=w[i-16]+(rotate(w[i-15],7)^rotate(w[i-15],18)^w[i-15]>>3)+w[i-7]+(rotate(w[i-2],17)^rotate(w[i-2],19)^w[i-2]>>10);
        uint32_t a=h[0],b=h[1],c=h[2],d=h[3],e=h[4],f=h[5],g=h[6],v=h[7];
        for(unsigned i=0;i<64;i++) {
            uint32_t t=v+(rotate(e,6)^rotate(e,11)^rotate(e,25))+((e&f)^(~e&g))+k[i]+w[i];
            uint32_t u=(rotate(a,2)^rotate(a,13)^rotate(a,22))+((a&b)^(a&c)^(b&c));
            v=g;g=f;f=e;e=d+t;d=c;c=b;b=a;a=t+u;
        }
        h[0]+=a;h[1]+=b;h[2]+=c;h[3]+=d;h[4]+=e;h[5]+=f;h[6]+=g;h[7]+=v;
    }
    free(p); for(unsigned i=0;i<8;i++) sprintf(result+8*i,"%08x",h[i]);
}

static void shell_pack(const char *input,const char *packed,const char *include,const char *metadata) {
    size_t size;unsigned char *data=read_file(input,&size);
    if(!size||size>SHELL_MAX_BYTES) fail("shell input extent");
    size_t capacity=2*size+32;
    unsigned char *encoded=malloc(capacity),*decoded=malloc(size);
    if(!encoded||!decoded) fail("shell buffer allocation");
    struct shell_stats stats={0,0,0,0};
    size_t length=shell_encode(data,size,encoded,capacity,&stats),consumed;
    if(length>=8192) fail("packed shell cannot fit a ROM page");
    if(shell_decode(encoded,length,decoded,size,&consumed)!=size||consumed!=length||memcmp(data,decoded,size))
        fail("packed shell verification");
    char source_hash[65],packed_hash[65];sha256(data,size,source_hash);sha256(encoded,length,packed_hash);
    write_file(packed,encoded,length);
    FILE *f=open_file(include,"w");
    fputs("; Generated data from UniAS SHELL.CMD by firmware-data; source: firmware/bios/UNIDOS.ASM.\n",f);
    fprintf(f,"SH_UNPACKED_BYTES equ %zu\nSH_PACKED_BYTES equ %zu\n",size,length);
    include_bytes(f,encoded,length);if(fclose(f)) fail("packed shell include write");
    f=open_file(metadata,"w");
    fprintf(f,"{\"codec\":\"uniload-lz16\",\"unpacked_bytes\":%zu,\"packed_bytes\":%zu,\"source_sha256\":\"%s\",\"packed_sha256\":\"%s\",\"roundtrip_verified\":true,\"tokens\":{\"literal\":%u,\"short\":%u,\"long\":%u,\"extended\":%u}}\n",
        size,length,source_hash,packed_hash,stats.literal,stats.short_match,stats.long_match,stats.extended_match);
    if(fclose(f)) fail("packed shell metadata write");
    free(data);free(encoded);free(decoded);
}

struct symbol { char name[128]; unsigned value; };
static struct symbol symbols[8192];
static unsigned symbol_count;
static void read_symbols(const char *path) {
    FILE *f=open_file(path,"r"); char line[1024],name[128],extra; unsigned value;
    symbol_count=0;
    while(fgets(line,sizeof line,f)) {
        if(sscanf(line,"%127s =$%x %c",name,&value,&extra)!=2) continue;
        if(symbol_count==8192) fail("symbol capacity");
        strcpy(symbols[symbol_count].name,name); symbols[symbol_count++].value=value;
    }
    fclose(f); if(!symbol_count) fail("empty UniAS symbol table");
}
static unsigned symbol_value(const char *name) {
    for(unsigned i=0;i<symbol_count;i++) if(!strcmp(symbols[i].name,name)) return symbols[i].value;
    fprintf(stderr,"missing UniAS symbol: %s\n",name); exit(1);
}
static void labels(const char *listing,const char *output,const char *prefix) {
    read_symbols(listing); FILE *f=open_file(output,"w");
    if(prefix) {
        for(unsigned i=0;i<symbol_count;i++) fprintf(f,"#define %s_%s 0x%04X\n",prefix,symbols[i].name,symbols[i].value);
    } else {
        /* Keep the existing boot/debug JSON interface. UniAS names are case-insensitive. */
        for(unsigned i=0;i<symbol_count;i++) {
            if(!strncmp(symbols[i].name,"B_",2)) memmove(symbols[i].name,symbols[i].name+2,strlen(symbols[i].name+2)+1);
            for(char *s=symbols[i].name;*s;s++) *s=(char)tolower((unsigned char)*s);
        }
        fputs("{\n",f); unsigned written=0;
        for(unsigned i=0;i<symbol_count;i++) {
            unsigned j; for(j=i+1;j<symbol_count;j++) if(!strcmp(symbols[i].name,symbols[j].name)) break;
            if(j<symbol_count) continue;
            fprintf(f,"%s  \"%s\": %u",written++?",\n":"",symbols[i].name,symbols[i].value);
        }
        fputs("\n}\n",f);
    }
    if(fclose(f)) fail("labels write");
}
static void pgm_info(const char *input,const char *metadata) {
    size_t size; unsigned char *data=read_file(input,&size);
    if(size<16||be16(data)!=0xa55a) fail("PGM header");
    unsigned count=be16(data+2),offset=be16(data+4),length=be16(data+6),entry=be16(data+8),bss=be16(data+10);
    if(offset!=16+2*count||size!=offset+length||entry>=length) fail("PGM layout");
    for(unsigned i=0;i<count;i++) if(be16(data+16+2*i)+1>=length) fail("PGM relocation outside code");
    char digest[65]; sha256(data,size,digest); free(data);
    FILE *f=open_file(metadata,"w");
    fprintf(f,"{\"bytes\":%zu,\"code\":%u,\"bss\":%u,\"ram_bytes\":%u,\"relocations\":%u,\"sha256\":\"%s\"}\n",size,length,bss,length+bss,count,digest);
    if(fclose(f)) fail("PGM metadata write");
}
/* These containers keep two complete UniAS PGM streams. They neither link
 * instructions nor rewrite headers/BSS: the native prefix streams the child. */
static void app_path(char *path,size_t size,const char *dir,const char *name) {
    if(snprintf(path,size,"%s/%s",dir,name)<0||strlen(dir)+strlen(name)+2>size)
        fail("application path too long");
}
static unsigned char *app_read(const char *dir,const char *name,size_t *size) {
    char path[1024];app_path(path,sizeof path,dir,name);return read_file(path,size);
}
static void pgm_check(const unsigned char *p,size_t size) {
    if(size<16||be16(p)!=0xa55a||be16(p+4)!=16+2*be16(p+2)
       ||size!=be16(p+4)+be16(p+6)||be16(p+8)>=be16(p+6)
       ||be16(p+6)+be16(p+10)>=0xbe00) fail("invalid application PGM");
    for(unsigned i=0;i<be16(p+2);i++)
        if(be16(p+16+2*i)+1>=be16(p+6)) fail("application relocation outside code");
}
static void pgm_bundle_info(const char *kind,const char *dir) {
    int editor=!strcmp(kind,"nc"),ramloader=!strcmp(kind,"ramloader"),paint=!strcmp(kind,"paint");
    if(!editor&&!ramloader&&!paint) fail("unknown PGM container");
    const char *prefix_name=paint?"PNTBOOT.PGM":editor?"NCELOAD.PGM":"RAMPREF.PGM";
    const char *core_name=paint?"PNTCORE.PGM":editor?"NCECORE.PGM":"RAMCORE.PGM";
    const char *output_name=paint?"PAINT.PGM":editor?"NCEDIT.PGM":"RAMLOAD.PGM";
    size_t prefix_size,core_size;
    unsigned char *prefix=app_read(dir,prefix_name,&prefix_size);
    unsigned char *core=app_read(dir,core_name,&core_size);
    pgm_check(prefix,prefix_size);pgm_check(core,core_size);
    if(editor&&be16(prefix+6)+be16(prefix+10)<768)
        fail("NCEDIT needs 768 bytes of reusable loader memory");
    if(paint&&be16(prefix+6)+be16(prefix+10)<512)
        fail("Paint needs 512 bytes of reusable loader memory");
    if(ramloader&&be16(core+8)!=0) fail("RAMCORE entry must be zero");
    unsigned code=be16(((editor||paint)?core:prefix)+6),bss=be16(((editor||paint)?core:prefix)+10);
    unsigned relocations=be16(((editor||paint)?core:prefix)+2);
    size_t size=prefix_size+core_size;
    size_t actual_size;unsigned char *combined=app_read(dir,output_name,&actual_size);
    if(actual_size!=size||memcmp(combined,prefix,prefix_size)||memcmp(combined+prefix_size,core,core_size))
        fail("UniLD PGM container differs from its inputs");
    char digest[65],path[1024];sha256(combined,size,digest);
    app_path(path,sizeof path,dir,paint?"PAINT.json":editor?"NCEDIT.json":"RAMLOAD.json");
    FILE *f=open_file(path,"w");
    fprintf(f,"{\"bytes\":%zu,\"code\":%u,\"bss\":%u,\"ram_bytes\":%u,\"relocations\":%u,\"sha256\":\"%s\",\"streamed_relocations\":true",
            size,code,bss,code+bss,relocations,digest);
    unsigned core_ram=be16(core+6)+be16(core+10),prefix_ram=be16(prefix+6)+be16(prefix+10);
    if(editor) fprintf(f,",\"loader_ram_bytes\":%u,\"loader_reused_bytes\":768,\"base_ram_bytes\":%u,\"viewport_tail_40_text\":200,\"viewport_tail_40_graphics\":160,\"viewport_tail_80_text\":1200,\"viewport_tail_80_graphics\":1120,\"optional_cache_bytes\":512,\"total_ram_bytes\":%u",prefix_ram,core_ram+prefix_ram,core_ram+prefix_ram+1200+512);
    else if(paint) {
        unsigned maximum=0;const char *names[]={"PNTNAT.PGM","PNTRGB.PGM","PNTHAM.PGM"};
        for(unsigned k=0;k<3;k++) {
            size_t n;unsigned char *p=app_read(dir,names[k],&n);pgm_check(p,n);
            unsigned ram=be16(p+6)+be16(p+10);if(ram>8192) fail("Paint backend exceeds one RAMMAN page");
            if(ram>maximum) maximum=ram;free(p);
        }
        fprintf(f,",\"loader_ram_bytes\":%u,\"loader_reused_bytes\":512,\"base_ram_bytes\":%u,\"ordinary_backend_peak_bytes\":%u,\"total_ram_bytes\":%u,\"text_screen_bytes_601\":8000,\"text_screen_bytes_601a\":16000,\"native_screen_alignment_bytes\":7,\"native_screen_reused\":true",prefix_ram,core_ram+prefix_ram,maximum,core_ram+prefix_ram+maximum+255);
    } else {
        app_path(path,sizeof path,dir,"RAMLOAD.LST");read_symbols(path);
        fprintf(f,",\"resident_payload_bytes\":%u,\"working_ram_bytes\":%u,\"module_slots\":4,\"exports_per_module\":8",
                symbol_value("BSS_END")-symbol_value("RESIDENT_START"),core_ram+prefix_ram);
    }
    fputs("}\n",f);if(fclose(f)) fail("application metadata write");
    if(ramloader) {
        app_path(path,sizeof path,dir,"roms.json");f=open_file(path,"w");fputs("{",f);
        const char *names[]={"CRC16.ROM","CRCALT.ROM"};
        for(unsigned k=0;k<2;k++) {
            size_t n;unsigned char *rom=app_read(dir,names[k],&n);unsigned sum=0;
            for(size_t i=0;i<n;i++) sum+=rom[i];
            if(n!=8192||sum%256) fail("ramloader ROM checksum");
            sha256(rom,n,digest);free(rom);
            fprintf(f,"%s\"%s\":{\"bytes\":%zu,\"sha256\":\"%s\"}",k?",":"",names[k],n,digest);
        }
        fputs("}\n",f);if(fclose(f)) fail("ramloader ROM metadata write");
    }
    free(prefix);free(core);free(combined);
}
/* Debug/test symbols follow the actual UniLD map. No executable is generated
 * here; module-local listings supply private labels absent from OBJ exports. */
static void public_labels(const char *map,const char *output,const char *prefix) {
    FILE *in=open_file(map,"r"),*out=open_file(output,"w");
    char line[1024],name[128];unsigned value,count=0;
    while(fgets(line,sizeof line,in)) {
        if(sscanf(line,"S %127s %u",name,&value)!=2) continue;
        if(value>65535) fail("public map symbol extent");
        fprintf(out,"#define %s_%s 0x%04X\n",prefix,name,value);count++;
    }
    if(!count) fail("empty public symbol map");
    if(fclose(in)||fclose(out)) fail("public labels write");
}
static void linked_labels(const char *map,const char *output,const char *prefix) {
    struct module { char name[16];unsigned code,length,bss,extent; };
    static struct module modules[256];static struct symbol merged[8192];
    unsigned module_count=0,merged_count=0,absolute_count=0;
    char absolutes[128][128],dir[1024],path[1024],line[1024],name[128],op[32];
    if(strlen(map)>=sizeof dir) fail("map path too long");
    strcpy(dir,map);char *slash=strrchr(dir,'/');if(slash)*slash=0;else strcpy(dir,".");
    FILE *f=open_file(map,"r");
    while(fgets(line,sizeof line,f)) {
        struct module *m=&modules[module_count];
        if(sscanf(line,"M %15s %u %u %u %u",m->name,&m->code,&m->length,&m->bss,&m->extent)!=5) continue;
        if(++module_count==256) fail("map module capacity");
    }
    fclose(f);if(!module_count) fail("empty UniLD map");
    const char *headers[]={"NCABI.INC","NCBOX.INC"};
    for(unsigned k=0;k<2;k++) {
        app_path(path,sizeof path,dir,headers[k]);f=open_file(path,"r");
        while(fgets(line,sizeof line,f)) {
            if(sscanf(line,"%127s %31s",name,op)!=2||strcmp(op,"equ")) continue;
            for(char *p=name;*p;p++) *p=(char)toupper((unsigned char)*p);
            if(absolute_count==128) fail("absolute symbol capacity");
            strcpy(absolutes[absolute_count++],name);
        }
        fclose(f);
    }
    for(unsigned k=0;k<module_count;k++) {
        char externs[255][128],file[32];unsigned extern_count=0;
        snprintf(file,sizeof file,"%s.ASM",modules[k].name);app_path(path,sizeof path,dir,file);f=open_file(path,"r");
        while(fgets(line,sizeof line,f)) {
            if(sscanf(line,"%31s %127s",op,name)!=2) continue;
            for(char *p=name;*p;p++) *p=(char)toupper((unsigned char)*p);
            if(!strcmp(op,".define")) {
                if(absolute_count==128) fail("absolute symbol capacity");
                strcpy(absolutes[absolute_count++],name);continue;
            }
            if(strcmp(op,"extern")) continue;
            if(extern_count==255) fail("external symbol capacity");
            strcpy(externs[extern_count++],name);
        }
        fclose(f);
        snprintf(file,sizeof file,"%s.LST",modules[k].name);app_path(path,sizeof path,dir,file);read_symbols(path);
        for(unsigned i=0;i<symbol_count;i++) {
            int external=0,absolute=0;
            for(unsigned j=0;j<extern_count;j++) if(!strcmp(symbols[i].name,externs[j])) external=1;
            if(external) continue;
            for(unsigned j=0;j<absolute_count;j++) if(!strcmp(symbols[i].name,absolutes[j])) absolute=1;
            unsigned value=symbols[i].value;
            if(!absolute) value=value>=modules[k].length?modules[k].bss+value-modules[k].length:modules[k].code+value;
            unsigned j;for(j=0;j<merged_count;j++) if(!strcmp(merged[j].name,symbols[i].name)) break;
            if(j<merged_count) {
                if(merged[j].value!=value) {
                    fprintf(stderr,"%s in %s: %04X != %04X\n",symbols[i].name,modules[k].name,merged[j].value,value);
                    fail("conflicting linked debug symbols");
                }
                continue;
            }
            if(merged_count==8192) fail("linked symbol capacity");
            strcpy(merged[merged_count].name,symbols[i].name);merged[merged_count++].value=value;
        }
    }
    f=open_file(output,"w");
    for(unsigned i=0;i<merged_count;i++) fprintf(f,"#define %s_%s 0x%04X\n",prefix,merged[i].name,merged[i].value);
    if(fclose(f)) fail("linked labels write");
}
static void rom_index(const char *dir,const char *output) {
    const char *names[]={"UNIBIOS.ROM","SD.ROM","SHELL.ROM","PARTS.ROM","RAMMAN.ROM","BIOS.ROM","BIOS_A.ROM","KERNEL.ROM"};
    FILE *f=open_file(output,"w"); fputs("{\"roms\":{",f); char path[512];
    for(unsigned i=0;i<8;i++) {
        snprintf(path,sizeof path,"%s/%s",dir,names[i]); size_t n;unsigned char *d=read_file(path,&n);
        if(n!=((i<5||i==7)?8192u:4096u)) fail("ROM size");
        unsigned sum=0; for(size_t j=0;j<n;j++) sum+=d[j]; free(d);
        if(sum%256) fail("UniAS ROM CHECKSUM");
        fprintf(f,"%s\"%s\":%zu",i?",":"",names[i],n);
    }
    snprintf(path,sizeof path,"%s/SHELL.CMD",dir); size_t n; unsigned char *d=read_file(path,&n); free(d);
    snprintf(path,sizeof path,"%s/SHELL.ROM.LST",dir);read_symbols(path);
    unsigned packed=symbol_value("SH_PACKED_BYTES"),shell_used=symbol_value("SHELL_END")-0xc000+1;
    if(symbol_value("SH_UNPACKED_BYTES")!=n||shell_used>8192) fail("packed shell layout");
    fprintf(f,"},\"shell_bytes\":%zu,\"unishell\":{\"codec\":\"uniload-lz16\",\"unpacked_bytes\":%zu,\"packed_bytes\":%u,\"rom_f_used_bytes\":%u,\"rom_f_free_bytes\":%u}",n,n,packed,shell_used,8192-shell_used);
    snprintf(path,sizeof path,"%s/RAMMAN.ROM.LST",dir); read_symbols(path);
    unsigned used=symbol_value("RAM_IMAGE_END")-0xc000+1;
    if(used>8192) fail("ROM E overflow");
    fprintf(f,",\"gamebios\":{\"abi\":%u,\"context_bytes\":%u,\"resident_bytes\":0,\"rom_e_used_bytes\":%u,\"rom_e_free_bytes\":%u}}\n",symbol_value("GB_ABI"),symbol_value("GB_CONTEXT_BYTES"),used,8192-used);
    if(fclose(f)) fail("ROM manifest write");
}
static void app_index(int argc,char **argv) {
    FILE *f=open_file(argv[2],"w"); fputs("{\n",f);
    for(int i=3;i<argc;i++) {
        char name[128]; const char *base=strrchr(argv[i],'/'); base=base?base+1:argv[i];
        size_t len=strcspn(base,"."); if(len>=sizeof name) fail("app name"); memcpy(name,base,len);name[len]=0;
        size_t n;unsigned char *d=read_file(argv[i],&n);
        fprintf(f,"%s\"%s\":%s",i>3?",\n":"",name,d);free(d);
    }
    fputs("}\n",f);if(fclose(f)) fail("app manifest write");
}
static void ps2(const char *input,const char *output,const char *include) {
    unsigned char table[256]; memset(table,255,sizeof table); unsigned char seen[256]={0};
    FILE *f=open_file(input,"r");char line[256];unsigned a,b;int header=0;
    while(fgets(line,sizeof line,f)) {
        char *s=line; while(isspace((unsigned char)*s))s++; if(!*s||*s=='#')continue;
        if(!header) { if(strncmp(s,"set2,set1,key",12))fail("keyboard CSV header"); header=1;continue; }
        char key[200]; if(sscanf(s,"%x,%x,%199[^\r\n]",&a,&b,key)!=3||a>255||(b>127&&b!=255)||seen[a]++)fail("keyboard CSV row");
        table[a]=(unsigned char)b;
    }
    fclose(f);FILE *out=open_file(output,"w");for(unsigned i=0;i<256;i++)fprintf(out,"%02x\n",table[i]);if(fclose(out))fail("keyboard table write");
    if(include){out=open_file(include,"w");include_bytes(out,table,256);if(fclose(out))fail("keyboard include write");}
}
static void pal(const char *output,const char *rgb_output) {
    const double pi=3.1415926535897932384626433832795;
    for(unsigned bank=0;bank<2;bank++) {
        FILE *f=open_file(bank?rgb_output:output,"w");
        for(unsigned burst=0;burst<(bank?1u:2u);burst++)for(unsigned c=0;c<(bank?256u:16u);c++) {
            double r,g,b; unsigned intensity=c>>3&1;
            if(bank){r=(double)(c>>5)/7;g=(double)(c>>2&7)/7;b=(double)(c&3)/3;}
            else {r=(double)(2*(c>>2&1)+intensity)/3;g=(double)(2*(c>>1&1)+intensity)/3;b=(double)(2*(c&1)+intensity)/3;}
            double y=.299*r+.587*g+.114*b,u=.493*(b-y),v=.877*(r-y);
            if(burst){y=0;u=-(.3/.7)/(2*sqrt(2));v=-u;}
            for(unsigned phase=0;phase<32;phase++) {
                double angle=(phase+.5)*2*pi/32;
                long sample=lrint(15+34*(y+u*sin(angle)+v*cos(angle)));
                if(sample<=0||sample>=64)fail("PAL sample range"); fprintf(f,"%02lx\n",sample);
            }
        }
        if(fclose(f))fail("PAL table write");
    }
}
static void ay(const char *output,const char *init_output) {
    unsigned words[1024]={0},pos=512;
    const unsigned volumes[]={0,1,2,3,4,6,8,12,16,23,32,45,64,80,101,127};
    memcpy(words+32,volumes,sizeof volumes);
#define EMIT(op,addr) words[pos++]=((op)<<5)|(addr)
    for(unsigned c=0;c<3;c++){EMIT(0,2*c);EMIT(1,2*c+1);EMIT(2,16+2*c);EMIT(3,17+2*c);EMIT(4,16+2*c);EMIT(5,17+2*c);EMIT(6,c);}
    EMIT(0,6);EMIT(2,22);EMIT(3,23);EMIT(4,22);EMIT(5,23);EMIT(7,0);
    EMIT(14,11);EMIT(15,12);EMIT(2,24);EMIT(3,25);EMIT(8,13);EMIT(4,24);EMIT(5,25);EMIT(9,7);EMIT(11,0);
    for(unsigned c=0;c<3;c++){EMIT(10,8+c);EMIT(12,0);}EMIT(13,0);
#undef EMIT
    if(pos!=555)fail("AY scheduler size");
    FILE *f=open_file(output,"w");for(unsigned i=0;i<1024;i++)fprintf(f,"%03x\n",words[i]);if(fclose(f))fail("AY table write");
    f=open_file(init_output,"w");fputs("// Generated by firmware-data; AY EBR startup contents.\n",f);
    for(unsigned bank=0;bank<32;bank++) {
        fprintf(f,"%s.INITVAL_%02X(\"0x",bank?",\n":"",bank);
        for(int pair=15;pair>=0;pair--){unsigned at=bank*32+(unsigned)pair*2;fprintf(f,"%05X",words[at]|words[at+1]<<9);}
        fputs("\")",f);
    }
    fputs("\n",f);if(fclose(f))fail("AY INIT write");
}
int main(int argc,char **argv) {
    if(argc<2)fail("command required");
    if(!strcmp(argv[1],"labels")&&(argc==4||argc==5)){labels(argv[2],argv[3],argc==5?argv[4]:NULL);return 0;}
    if(!strcmp(argv[1],"linked-labels")&&argc==5){linked_labels(argv[2],argv[3],argv[4]);return 0;}
    if(!strcmp(argv[1],"public-labels")&&argc==5){public_labels(argv[2],argv[3],argv[4]);return 0;}
    if(!strcmp(argv[1],"pgm-info")&&argc==4){pgm_info(argv[2],argv[3]);return 0;}
    if(!strcmp(argv[1],"pgm-bundle-info")&&argc==4){pgm_bundle_info(argv[2],argv[3]);return 0;}
    if(!strcmp(argv[1],"rom-index")&&argc==4){rom_index(argv[2],argv[3]);return 0;}
    if(!strcmp(argv[1],"index")&&argc>=4){app_index(argc,argv);return 0;}
    if(!strcmp(argv[1],"ps2")&&(argc==4||argc==5)){ps2(argv[2],argv[3],argc==5?argv[4]:NULL);return 0;}
    if(!strcmp(argv[1],"pal")&&argc==4){pal(argv[2],argv[3]);return 0;}
    if(!strcmp(argv[1],"ay")&&argc==4){ay(argv[2],argv[3]);return 0;}
    if(!strcmp(argv[1],"shell")&&argc==6) {shell_pack(argv[2],argv[3],argv[4],argv[5]);return 0;}
    if(!strcmp(argv[1],"shell-unpack")&&argc==4) {
        size_t n,consumed;unsigned char *d=read_file(argv[2],&n),out[SHELL_MAX_BYTES];
        size_t length=shell_decode(d,n,out,sizeof out,&consumed);
        if(consumed!=n) fail("trailing packed shell bytes");
        write_file(argv[3],out,length);free(d);return 0;
    }
    if(argc<4)fail("invalid arguments");
    size_t size;unsigned char *d=read_file(argv[2],&size);
    if(!strcmp(argv[1],"inc")&&(argc==4||argc==6)) {
        unsigned start=argc==6?number(argv[4]):0,count=argc==6?number(argv[5]):(unsigned)size;
        if(start>size||count>size-start)fail("include extent");FILE *f=open_file(argv[3],"w");include_bytes(f,d+start,count);if(fclose(f))fail("include write");
    } else if(!strcmp(argv[1],"font-boot")&&argc==4) {
        if(size!=2048)fail("font bitmap extent");FILE *f=open_file(argv[3],"w");
        /* FPGA EBR interleaves glyph c and c+128; UniBIOS stores contiguous glyphs. */
        for(unsigned c=0;c<128;c++)for(unsigned bank=0;bank<2;bank++)for(unsigned row=0;row<8;row++)fprintf(f,"%02x\n",d[(c+bank*128)*8+row]);
        if(fclose(f))fail("bootstrap font write");
    } else if(!strcmp(argv[1],"mem")&&(argc==4||argc==5)) {
        unsigned total=argc==5?number(argv[4]):(unsigned)size;if(total<size)fail("memory output extent");FILE *f=open_file(argv[3],"w");
        for(unsigned i=0;i<total;i++)fprintf(f,"%02x\n",i<size?d[i]:255);if(fclose(f))fail("memory write");
    } else fail("unknown command");
    free(d);return 0;
}
