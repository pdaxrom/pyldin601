/* JPEG/PNG -> standard IFF ILBM HAM8 for the Pyldin RGB222 base palette.
 * libjpeg/libpng decode images; each row is optimised with a 32-state beam.
 * The preview decodes exactly the commands consumed by our FPGA.
 */
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <unistd.h>
#include <sys/stat.h>
#include <jpeglib.h>
#include <png.h>

enum { W=320, H=200, BEAM=32, MAX_SIDE=16384 };
typedef struct { unsigned w,h; uint8_t *rgb; } Image;
typedef struct { uint8_t r,g,b,code,parent; double cost; } State;
static void die(const char *s) { fprintf(stderr,"ham8conv: %s\n",s); exit(1); }
static void *allocate(size_t n) { void *p=malloc(n); if(!p)die("out of memory"); return p; }
static void dimensions(unsigned w,unsigned h) {
    if(!w||!h||w>MAX_SIDE||h>MAX_SIDE||(uint64_t)w*h>64000000)die("image exceeds 64 million pixels or 16384 pixels per side");
}
static unsigned word(const uint8_t *p,int le) { return le?p[0]+256u*p[1]:256u*p[0]+p[1]; }
static unsigned exif_orientation(jpeg_saved_marker_ptr m) {
    for(;m;m=m->next) {
        const uint8_t *p=m->data; size_t n=m->data_length;
        if(n<14||memcmp(p,"Exif\0\0",6))continue;
        p+=6; n-=6; int le=p[0]=='I'&&p[1]=='I';
        if(!le&&!(p[0]=='M'&&p[1]=='M'))continue;
        if(word(p+2,le)!=42)continue;
        uint32_t off=le?((uint32_t)p[7]<<24|(uint32_t)p[6]<<16|word(p+4,1)):((uint32_t)word(p+4,0)<<16|word(p+6,0));
        if(off>n-2)continue;
        unsigned count=word(p+off,le); off+=2;
        if(count>(n-off)/12)continue;
        for(unsigned i=0;i<count;i++) {
            const uint8_t *e=p+off+i*12;
            if(word(e,le)==0x112&&word(e+2,le)==3&&
               (le?word(e+4,le)==1&&!word(e+6,le):!word(e+4,le)&&word(e+6,le)==1)) {
                unsigned v=word(e+8,le); if(v>=1&&v<=8)return v;
            }
        }
    }
    return 1;
}
static Image orient(Image in,unsigned o) {
    if(o==1)return in;
    Image out={o>4?in.h:in.w,o>4?in.w:in.h,NULL}; out.rgb=allocate((size_t)out.w*out.h*3);
    for(unsigned y=0;y<in.h;y++)for(unsigned x=0;x<in.w;x++) {
        unsigned a=x,b=y;
        switch(o) {
        case 2:a=in.w-1-x;break; case 3:a=in.w-1-x;b=in.h-1-y;break;
        case 4:b=in.h-1-y;break; case 5:a=y;b=x;break;
        case 6:a=in.h-1-y;b=x;break; case 7:a=in.h-1-y;b=in.w-1-x;break;
        case 8:a=y;b=in.w-1-x;break;
        }
        memcpy(out.rgb+((size_t)b*out.w+a)*3,in.rgb+((size_t)y*in.w+x)*3,3);
    }
    free(in.rgb);return out;
}
static Image read_jpeg(const char *path) {
    FILE *f=fopen(path,"rb");if(!f)die("cannot open JPEG");
    struct jpeg_decompress_struct d;struct jpeg_error_mgr error;
    d.err=jpeg_std_error(&error);jpeg_create_decompress(&d);jpeg_stdio_src(&d,f);
    jpeg_save_markers(&d,JPEG_APP0+1,65535);jpeg_read_header(&d,TRUE);
    dimensions(d.image_width,d.image_height);
    unsigned orientation=exif_orientation(d.marker_list);
    int cmyk=d.jpeg_color_space==JCS_CMYK||d.jpeg_color_space==JCS_YCCK;
    d.out_color_space=cmyk?JCS_CMYK:JCS_RGB;jpeg_start_decompress(&d);
    Image im={d.output_width,d.output_height,NULL};im.rgb=allocate((size_t)im.w*im.h*3);
    uint8_t *row=allocate((size_t)im.w*d.output_components);
    while(d.output_scanline<d.output_height) {
        unsigned y=d.output_scanline;JSAMPROW p=row;jpeg_read_scanlines(&d,&p,1);
        if(!cmyk)memcpy(im.rgb+(size_t)y*im.w*3,row,(size_t)im.w*3);
        else for(unsigned x=0;x<im.w;x++)for(unsigned c=0;c<3;c++) {
            unsigned a=row[x*4+c],k=row[x*4+3];
            im.rgb[((size_t)y*im.w+x)*3+c]=(uint8_t)(d.saw_Adobe_marker?(a*k+127)/255:((255-a)*(255-k)+127)/255);
        }
    }
    free(row);jpeg_finish_decompress(&d);jpeg_destroy_decompress(&d);fclose(f);
    return orient(im,orientation);
}
static Image read_png(const char *path) {
    png_image p;memset(&p,0,sizeof(p));p.version=PNG_IMAGE_VERSION;
    if(!png_image_begin_read_from_file(&p,path))die(p.message);
    dimensions(p.width,p.height);p.format=PNG_FORMAT_RGBA;
    uint8_t *rgba=allocate(PNG_IMAGE_SIZE(p));
    if(!png_image_finish_read(&p,NULL,rgba,0,NULL))die(p.message);
    Image im={p.width,p.height,allocate((size_t)p.width*p.height*3)};
    for(size_t i=0;i<(size_t)im.w*im.h;i++)for(unsigned c=0;c<3;c++)im.rgb[3*i+c]=(uint8_t)((rgba[4*i+c]*rgba[4*i+3]+127)/255);
    free(rgba);png_image_free(&p);return im;
}
static Image read_image(const char *path) {
    FILE *f=fopen(path,"rb");uint8_t magic[8];if(!f)die("cannot open input");
    size_t n=fread(magic,1,8,f);fclose(f);
    if(n>=2&&magic[0]==255&&magic[1]==216)return read_jpeg(path);
    if(n==8&&!png_sig_cmp(magic,0,8))return read_png(path);
    die("input must be JPEG or PNG");return (Image){0,0,NULL};
}
/* Area filtering for reductions; bilinear interpolation for enlargements.
 * Keep the input aspect in logical pixels unless --stretch is explicit.
 */
static void resize(Image im,uint8_t *out,int stretch) {
    unsigned w=W,h=H;
    if(!stretch) {
        double scale=fmin((double)W/im.w,(double)H/im.h);
        w=(unsigned)floor(im.w*scale+.5);h=(unsigned)floor(im.h*scale+.5);
        if(!w)w=1;
        if(!h)h=1;
    }
    memset(out,0,W*H*3);unsigned left=(W-w)/2,top=(H-h)/2;
    double sx=(double)im.w/w,sy=(double)im.h/h;
    for(unsigned y=0;y<h;y++)for(unsigned x=0;x<w;x++) {
        double sum[3]={0},weight=0;
        if(sx>=1&&sy>=1) {
            double a=x*sx,b=(x+1)*sx,c=y*sy,d=(y+1)*sy;
            for(unsigned iy=(unsigned)c;iy<(unsigned)ceil(d)&&iy<im.h;iy++)
                for(unsigned ix=(unsigned)a;ix<(unsigned)ceil(b)&&ix<im.w;ix++) {
                    double k=(fmin(ix+1,b)-fmax(ix,a))*(fmin(iy+1,d)-fmax(iy,c));weight+=k;
                    for(unsigned ch=0;ch<3;ch++)sum[ch]+=k*im.rgb[((size_t)iy*im.w+ix)*3+ch];
                }
        } else {
            double a=fmax(0,fmin(im.w-1,(x+.5)*sx-.5)),b=fmax(0,fmin(im.h-1,(y+.5)*sy-.5));
            unsigned ix=(unsigned)a,iy=(unsigned)b;double fx=a-ix,fy=b-iy;
            for(unsigned j=0;j<2;j++)for(unsigned i=0;i<2;i++) {
                unsigned xx=ix+i<im.w?ix+i:im.w-1,yy=iy+j<im.h?iy+j:im.h-1;
                double k=(i?fx:1-fx)*(j?fy:1-fy);weight+=k;
                for(unsigned ch=0;ch<3;ch++)sum[ch]+=k*im.rgb[((size_t)yy*im.w+xx)*3+ch];
            }
        }
        for(unsigned ch=0;ch<3;ch++)out[((y+top)*W+x+left)*3+ch]=(uint8_t)floor(sum[ch]/weight+.5);
    }
    printf("Input %ux%u -> %ux%u centred in 320x200%s\n",im.w,im.h,w,h,stretch?" (stretch)":"");
}
static unsigned expand(unsigned v){return (v<<2)|(v>>4);}
static State apply(State s,unsigned code) {
    unsigned v=code&63;
    switch(code>>6) {
    case 0:s.r=(v>>4)*21;s.g=((v>>2)&3)*21;s.b=(v&3)*21;break;
    case 1:s.b=v;break;case 2:s.r=v;break;case 3:s.g=v;break;
    }
    s.code=(uint8_t)code;return s;
}
static double error(State s,const uint8_t *p) {
    double r=(double)expand(s.r)-p[0],g=(double)expand(s.g)-p[1],b=(double)expand(s.b)-p[2];
    return .299*r*r+.587*g*g+.114*b*b;
}
static unsigned level(unsigned c){return (c*63+127)/255;}
static int compare(const void *a,const void *b) {
    const State *x=a,*y=b;if(x->cost<y->cost)return -1;if(x->cost>y->cost)return 1;
    if(x->r!=y->r)return (int)x->r-y->r;
    if(x->g!=y->g)return (int)x->g-y->g;
    if(x->b!=y->b)return (int)x->b-y->b;
    if(x->code!=y->code)return (int)x->code-y->code;
    return (int)x->parent-y->parent;
}
static void encode(const uint8_t *rgb,uint8_t *codes) {
    uint8_t history[W][BEAM][2],greedy[W];State beam[BEAM],next[BEAM],candidates[64+BEAM*3];
    for(unsigned y=0;y<H;y++) {
        unsigned size=1;beam[0]=(State){0};State gs={0};double gc=0;
        for(unsigned x=0;x<W;x++) {
            const uint8_t *p=rgb+(y*W+x)*3;unsigned n=0;
            for(unsigned c=0;c<64;c++){State s=apply(beam[0],c);s.parent=0;s.cost=beam[0].cost+error(s,p);candidates[n++]=s;}
            unsigned mods[]={64+level(p[2]),128+level(p[0]),192+level(p[1])};
            for(unsigned b=0;b<size;b++)for(unsigned c=0;c<3;c++) {
                State s=apply(beam[b],mods[c]);s.parent=(uint8_t)b;s.cost=beam[b].cost+error(s,p);candidates[n++]=s;
            }
            qsort(candidates,n,sizeof(State),compare);unsigned used=0;
            for(unsigned i=0;i<n&&used<BEAM;i++) {
                State s=candidates[i];unsigned k;
                for(k=0;k<used;k++)if(s.r==next[k].r&&s.g==next[k].g&&s.b==next[k].b)break;
                if(k<used)continue;
                next[used]=s;history[x][used][0]=s.parent;history[x][used][1]=s.code;used++;
            }
            memcpy(beam,next,used*sizeof(State));size=used;
            State best=apply(gs,0);double best_error=error(best,p);
            for(unsigned i=1;i<67;i++) {
                unsigned c=i<64?i:mods[i-64];State s=apply(gs,c);double e=error(s,p);
                if(e<best_error){best=s;best_error=e;}
            }
            gs=best;gc+=best_error;greedy[x]=best.code;
        }
        if(beam[0].cost>gc){memcpy(codes+y*W,greedy,W);continue;}
        unsigned s=0;for(unsigned x=W;x-->0;){codes[y*W+x]=history[x][s][1];s=history[x][s][0];}
    }
}
static double preview(const uint8_t *codes,const uint8_t *target,uint8_t *rgb) {
    double total=0;
    for(unsigned y=0;y<H;y++){State s={0};for(unsigned x=0;x<W;x++) {
        unsigned p=(y*W+x)*3;s=apply(s,codes[y*W+x]);unsigned v[]={expand(s.r),expand(s.g),expand(s.b)};
        for(unsigned c=0;c<3;c++){rgb[p+c]=(uint8_t)v[c];double d=(double)v[c]-target[p+c];total+=d*d;}
    }}return total/(W*H*3);
}
static void be16(uint8_t *p,unsigned v){p[0]=(uint8_t)(v>>8);p[1]=(uint8_t)v;}
static void be32(uint8_t *p,uint32_t v){be16(p,v>>16);be16(p+2,v);}
static void output(FILE *f,const void *p,size_t n){if(fwrite(p,1,n,f)!=n)die("output write failed");}
static void chunk(FILE *f,const char *id,const uint8_t *p,size_t n) {
    uint8_t head[8];memcpy(head,id,4);be32(head+4,(uint32_t)n);output(f,head,8);output(f,p,n);
    if(n&1){uint8_t zero=0;output(f,&zero,1);}
}
static size_t pack(const uint8_t *in,unsigned n,uint8_t *out) {
    unsigned i=0;size_t used=0;
    while(i<n) {
        unsigned run=1;while(i+run<n&&run<128&&in[i+run]==in[i])run++;
        if(run>=3){out[used++]=(uint8_t)(257-run);out[used++]=in[i];i+=run;continue;}
        unsigned start=i;i+=run;
        while(i<n&&i-start<128) {
            run=1;while(i+run<n&&run<128&&in[i+run]==in[i])run++;
            if(run>=3)break;
            unsigned take=run;if(take>128-(i-start))take=128-(i-start);i+=take;
        }
        unsigned count=i-start;out[used++]=(uint8_t)(count-1);memcpy(out+used,in+start,count);used+=count;
    }
    return used;
}
static void not_same(const char *a,const char *b) {
    struct stat x,y;if(!stat(a,&x)&&!stat(b,&y)&&x.st_dev==y.st_dev&&x.st_ino==y.st_ino)die("input, IFF and preview must be different files");
    if(!strcmp(a,b))die("input, IFF and preview must be different files");
}
static size_t write_iff(const char *path,const uint8_t *codes,int compressed) {
    uint8_t *body=allocate(H*8*42),plane[40],header[20]={0},cmap[192],mode[4];size_t length=0;
    for(unsigned y=0;y<H;y++)for(unsigned bit=0;bit<8;bit++) {
        memset(plane,0,40);
        for(unsigned x=0;x<W;x++)if(codes[y*W+x]&(1u<<bit))plane[x/8]|=(uint8_t)(128u>>(x&7));
        if(compressed)length+=pack(plane,40,body+length);else{memcpy(body+length,plane,40);length+=40;}
    }
    be16(header,W);be16(header+2,H);header[8]=8;header[10]=(uint8_t)compressed;header[14]=header[15]=1;
    be16(header+16,W);be16(header+18,H);be32(mode,0x800);
    for(unsigned i=0;i<64;i++){cmap[3*i]=(uint8_t)((i>>4)*85);cmap[3*i+1]=(uint8_t)(((i>>2)&3)*85);cmap[3*i+2]=(uint8_t)((i&3)*85);}
    size_t size=12+28+12+200+8+length+(length&1);uint8_t form[12];memcpy(form,"FORM",4);be32(form+4,(uint32_t)(size-8));memcpy(form+8,"ILBM",4);
    char *temporary=allocate(strlen(path)+16);sprintf(temporary,"%s.tmp.XXXXXX",path);
    int fd=mkstemp(temporary);if(fd<0)die("cannot create output");FILE *f=fdopen(fd,"wb");if(!f)die("cannot open output stream");
    output(f,form,12);chunk(f,"BMHD",header,20);chunk(f,"CAMG",mode,4);chunk(f,"CMAP",cmap,192);chunk(f,"BODY",body,length);
    if(fflush(f)||fsync(fd)||fclose(f))die("cannot flush output");
    if(rename(temporary,path))die("cannot install output");
    free(temporary);free(body);return size;
}
int main(int argc,char **argv) {
    const char *input=NULL,*out=NULL,*png=NULL;int stretch=0,compressed=1;
    for(int i=1;i<argc;i++) {
        if(!strcmp(argv[i],"--stretch"))stretch=1;
        else if(!strcmp(argv[i],"--uncompressed"))compressed=0;
        else if(!strcmp(argv[i],"--preview")&&i+1<argc)png=argv[++i];
        else if(argv[i][0]=='-')die("usage: ham8conv [--stretch] [--uncompressed] [--preview preview.png] input.jpg output.iff");
        else if(!input)input=argv[i];else if(!out)out=argv[i];else die("too many filenames");
    }
    if(!input||!out)die("usage: ham8conv [--stretch] [--uncompressed] [--preview preview.png] input.jpg output.iff");
    not_same(input,out);if(png){not_same(input,png);not_same(out,png);}
    Image im=read_image(input);uint8_t *rgb=allocate(W*H*3),*codes=allocate(W*H),*decoded=allocate(W*H*3);
    resize(im,rgb,stretch);free(im.rgb);encode(rgb,codes);double mse=preview(codes,rgb,decoded);
    size_t size=write_iff(out,codes,compressed);
    if(png){png_image p;memset(&p,0,sizeof(p));p.version=PNG_IMAGE_VERSION;p.width=W;p.height=H;p.format=PNG_FORMAT_RGB;
        if(!png_image_write_to_file(&p,png,0,decoded,0,NULL))die(p.message);
        png_image_free(&p);}
    printf("HAM8 ILBM: %s, %zu bytes, %s; decoded RGB PSNR %.2f dB\n",out,size,compressed?"ByteRun1":"uncompressed",mse?10*log10(255.0*255/mse):INFINITY);
    free(rgb);free(codes);free(decoded);return 0;
}
