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
static void put16(unsigned char *p,unsigned n) { p[0]=(unsigned char)(n>>8); p[1]=(unsigned char)n; }
static void include_bytes(FILE *f,const unsigned char *p,size_t size) {
    for(size_t i=0;i<size;i++) {
        if(i%16==0) fputs("    db ",f);
        fprintf(f,"$%02x%s",p[i],i%16==15||i+1==size?"\n":",");
    }
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
static void pgm(const char *input,const char *output,const char *listing,const char *metadata,const char *trim) {
    size_t size; unsigned char *data=read_file(input,&size);
    if(size<16||be16(data)!=0xa55a) fail("PGM header");
    unsigned count=be16(data+2),offset=be16(data+4),length=be16(data+6),entry=be16(data+8),bss=be16(data+10);
    if(offset!=16+2*count||size!=offset+length||entry>=length) fail("PGM layout");
    unsigned scratch=0;
    if(!strcmp(trim,"auto")) { read_symbols(listing); scratch=symbol_value("BSS_END")-symbol_value("BSS_START"); }
    else scratch=number(trim);
    if(scratch) {
        if(bss||scratch>=length) fail("PGM BSS extent");
        for(size_t i=size-scratch;i<size;i++) if(data[i]) fail("initialized PGM BSS");
        length-=scratch; size-=scratch; bss=scratch; put16(data+6,length); put16(data+10,bss);
    }
    for(unsigned i=0;i<count;i++) if(be16(data+16+2*i)+1>=length) fail("PGM relocation outside code");
    write_file(output,data,size);
    char digest[65]; sha256(data,size,digest); free(data);
    FILE *f=open_file(metadata,"w");
    fprintf(f,"{\"bytes\":%zu,\"code\":%u,\"bss\":%u,\"ram_bytes\":%u,\"relocations\":%u,\"sha256\":\"%s\"}\n",size,length,bss,length+bss,count,digest);
    if(fclose(f)) fail("PGM metadata write");
}
static void rom_index(const char *dir,const char *output) {
    const char *names[]={"UNIBIOS.ROM","SD.ROM","SHELL.ROM","PARTS.ROM","RAMMAN.ROM","BIOS.ROM","BIOS_A.ROM"};
    FILE *f=open_file(output,"w"); fputs("{\"roms\":{",f); char path[512];
    for(unsigned i=0;i<7;i++) {
        snprintf(path,sizeof path,"%s/%s",dir,names[i]); size_t n;unsigned char *d=read_file(path,&n);
        if(n!=(i<5?8192u:4096u)) fail("ROM size");
        unsigned sum=0; for(size_t j=0;j<n;j++) sum+=d[j]; free(d);
        if(sum%256) fail("UniAS ROM CHECKSUM");
        fprintf(f,"%s\"%s\":%zu",i?",":"",names[i],n);
    }
    snprintf(path,sizeof path,"%s/SHELL.CMD",dir); size_t n; unsigned char *d=read_file(path,&n); free(d);
    snprintf(path,sizeof path,"%s/RAMMAN.ROM.LST",dir); read_symbols(path);
    unsigned used=symbol_value("RAM_IMAGE_END")-0xc000+1;
    if(used>8192) fail("ROM E overflow");
    fprintf(f,"},\"shell_bytes\":%zu,\"gamebios\":{\"abi\":%u,\"context_bytes\":%u,\"resident_bytes\":0,\"rom_e_used_bytes\":%u,\"rom_e_free_bytes\":%u}}\n",n,symbol_value("GB_ABI"),symbol_value("GB_CONTEXT_BYTES"),used,8192-used);
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
    if(!strcmp(argv[1],"pgm")&&argc==7){pgm(argv[2],argv[3],argv[4],argv[5],argv[6]);return 0;}
    if(!strcmp(argv[1],"rom-index")&&argc==4){rom_index(argv[2],argv[3]);return 0;}
    if(!strcmp(argv[1],"index")&&argc>=4){app_index(argc,argv);return 0;}
    if(!strcmp(argv[1],"ps2")&&(argc==4||argc==5)){ps2(argv[2],argv[3],argc==5?argv[4]:NULL);return 0;}
    if(!strcmp(argv[1],"pal")&&argc==4){pal(argv[2],argv[3]);return 0;}
    if(!strcmp(argv[1],"ay")&&argc==4){ay(argv[2],argv[3]);return 0;}
    if(!strcmp(argv[1],"shell")&&argc==5) {
        size_t size;unsigned char *d=read_file(argv[2],&size);if(size<8000||size>16000)fail("shell split extent");
        FILE *f=open_file(argv[3],"w");include_bytes(f,d,8000);if(fclose(f))fail("shell head write");
        f=open_file(argv[4],"w");fprintf(f,"SHELL_SPLIT equ 8000\nSHELL_LENGTH equ %zu\nshell_tail\n",size);include_bytes(f,d+8000,size-8000);if(fclose(f))fail("shell tail write");free(d);return 0;
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
