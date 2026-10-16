// Execute actual relocatable row modules in ordinary RAM and a leased bank.
#define COMPACT_FIXTURE 1
#define DIRECT_SD_FIXTURE 1
#define ROMDISK_MAIN backend_unused_main
#include "test_romdisk_unidos.c"
#undef ROMDISK_MAIN
static unsigned modules,rows;static uint64_t row_cycles;
static unsigned rng=0x6016303;
static unsigned oracle_seed[3];
static unsigned random_byte(void){rng=rng*1664525+1013904223;return rng>>24;}
static unsigned dist(unsigned a,unsigned b){return a>b?a-b:b-a;}
static void ham_apply(unsigned code,unsigned *r,unsigned *g,unsigned *b){
 if(code<64){*r=(code>>4)*21;*g=((code>>2)&3)*21;*b=(code&3)*21;}
 else if(code<128)*b=code&63;else if(code<192)*r=code&63;else *g=code&63;
}
static void expected_row(unsigned kind,unsigned width,const unsigned char *src,unsigned char *dst,unsigned *count,unsigned rgb){
 *count=0;
 if(rgb){for(unsigned k=0;k<width;k++)dst[(*count)++]=src[k]&(kind==0?1:kind==2?3:255);return;}
 if(kind<3){unsigned bits=kind==2?2:1,unit=8/bits;
  for(unsigned k=0;k<width;k+=unit){unsigned v=0;for(unsigned x=0;x<unit;x++)v=(v<<bits)|(src[k+x]&((1u<<bits)-1));dst[(*count)++]=v;}return;
 }
 unsigned r=oracle_seed[0],g=oracle_seed[1],b=oracle_seed[2];
 for(unsigned x=0;x<width;x++){
  unsigned rr=src[x*3]&63,gg=src[x*3+1]&63,bb=src[x*3+2]&63,best=0,error=1000;
  // Independent exhaustive cube search, followed by the three HAM commands.
  for(unsigned code=0;code<67;code++){
   unsigned command=code<64?code:code==64?64+bb:code==65?128+rr:192+gg;
   unsigned cr=r,cg=g,cb=b;ham_apply(command,&cr,&cg,&cb);
   unsigned e=dist(cr,rr)+dist(cg,gg)+dist(cb,bb);
   if(e<error){error=e;best=command;}
  }
  dst[(*count)++]=best;ham_apply(best,&r,&g,&b);
 }
}
static unsigned call_module(unsigned target){
 unsigned char*r=MC6800GetCpuRam();
 unsigned pc0=PC,sp0=SP,a0=A,b0=B,x0=X,h0=h,i0=i,n0=n,z0=z,v0=v,c0=c,page0=page,group0=ram_group;
 r[0x210]=0xce;r[0x211]=target>>8;r[0x212]=target;r[0x213]=0xad;r[0x214]=0;r[0x215]=1;
 PC=0x210;A=0x10;B=0;
 uint64_t before=virtual_cycles,end=before+20000000;
 do{until(virtual_cycles+1);require(virtual_cycles<end,"row backend returns in bounded time");}while(PC!=0x215);
 unsigned result=A;row_cycles+=virtual_cycles-before;
 require(SP==sp0&&page==page0&&ram_group==group0,"row backend and native IRQ preserve stack and bank selectors");
 PC=pc0;SP=sp0;A=a0;B=b0;X=x0;h=h0;i=i0;n=n0;z=z0;v=v0;c=c0;
 return result;
}
static void test_module(const char*name,unsigned banked,unsigned bank){
 char path[160];snprintf(path,sizeof path,"build/paint/%s.PGM",name);
 size_t bytes;unsigned char*pgm=load(path,&bytes);
 unsigned reloc=pgm[2]*256+pgm[3],off=pgm[4]*256+pgm[5],code=pgm[6]*256+pgm[7],entry=pgm[8]*256+pgm[9],bss=pgm[10]*256+pgm[11];
 require(bytes==off+code&&off==16+reloc*2&&code+bss<=8192,"backend uses a standard bounded native PGM");
 require(!memcmp(pgm+off+2,"PNB1",4)&&pgm[off+7]==1,"backend descriptor ABI");
 unsigned base=banked?0xc000:0x4000;
 unsigned char*memory=banked?physical+0x22000+bank*8192:MC6800GetCpuRam()+base;
 memcpy(memory,pgm+off,code);memset(memory+code,0,bss);
 for(unsigned k=0;k<reloc;k++){unsigned at=pgm[16+k*2]*256+pgm[17+k*2];require(at+1<code,"backend relocation lies in code");memory[at]+=base>>8;}
 unsigned char*loaded=malloc(code);require(loaded!=NULL,"backend code oracle");memcpy(loaded,memory,code);
 unsigned page0=page,group0=ram_group;
 if(banked){page=bank%6+1;ram_group=bank/6;}
 unsigned rgb=!strcmp(name,"PNTRGB"),ham=!strcmp(name,"PNTHAM");
 unsigned kinds[3]={0,1,2},nk=3;if(rgb){kinds[0]=0;kinds[1]=2;kinds[2]=3;}if(ham){kinds[0]=4;nk=1;}
 unsigned char source[960],want[640];
 unsigned char*r=MC6800GetCpuRam();
 for(unsigned t=0;t<nk;t++)for(unsigned pattern=0;pattern<5;pattern++){
  unsigned kind=kinds[t],width=kind==1?640:320,length=width*(kind==4?3:1),count;
  for(unsigned k=0;k<length;k++)source[k]=pattern==0?0:pattern==1?255:pattern==2?k:pattern==3?(k%3==0?63:0):random_byte();
  expected_row(kind,width,source,want,&count,rgb);
  memcpy(r+0x1200,source,length);memset(r+0x17f0,0xa5,672);
  memset(r+0x1000,0,16);word_at(0x1000,0x504e);r[0x1002]=1;r[0x1004]=kind;word_at(0x1006,width);word_at(0x1008,0x1200);word_at(0x100a,0x1800);
  if(pattern==4&&!rgb){
   // An ordinary callback deliberately clobbers A/B/X while the module is
   // executing either in ordinary memory or the leased C000 page.
   const unsigned char callback[]={0x7c,0x11,0x00,0xce,0xff,0xff,0x4f,0x5f,0x39};
   memcpy(r+0x220,callback,sizeof callback);r[0x1100]=0;word_at(0x100e,0x220);
  }
  require(call_module(base+entry)==0,"backend accepts its row format");
  if(pattern==4&&!rgb)require(r[0x1100]>0,"long row conversion services its ordinary idle callback");
  require(r[0x100c]*256+r[0x100d]==count&&!memcmp(r+0x1800,want,count),"native row matches independent packed/HAM oracle");
  require(!memcmp(r+0x1200,source,length),"backend retains canonical source pixels");
  for(unsigned k=0;k<16;k++)require(r[0x17f0+k]==0xa5&&r[0x1800+count+k]==0xa5,"row output remains within its buffer");
  require(!memcmp(loaded,memory,code),"backend code remains unchanged in ordinary/banked RAM");rows++;
 }
 if(ham)for(unsigned s=0;s<2;s++)for(unsigned k=0;k<5;k++){
  unsigned width=(unsigned[]){1,2,7,16,319}[k],count;
  for(unsigned j=0;j<3;j++)oracle_seed[j]=s?(j==0?63:j==1?12:47):0;
  for(unsigned j=0;j<width*3;j++)source[j]=random_byte()&63;
  expected_row(4,width,source,want,&count,0);
  memcpy(r+0x1200,source,width*3);memset(r+0x17f0,0xa5,672);memset(r+0x1000,0,16);
  word_at(0x1000,0x504e);r[0x1002]=1;r[0x1003]=1;r[0x1004]=4;word_at(0x1006,width);word_at(0x1008,0x1200);word_at(0x100a,0x1800);word_at(0x100c,s?0x1100:0);
  for(unsigned j=0;j<3;j++)r[0x1100+j]=oracle_seed[j];
  require(!call_module(base+entry)&&r[0x100c]*256+r[0x100d]==width&&!memcmp(r+0x1800,want,width),"seeded partial HAM span matches independent exhaustive oracle");
  require(!memcmp(r+0x1200,source,width*3)&&!memcmp(loaded,memory,code),"partial HAM retains source and code");
  for(unsigned j=0;j<16;j++)require(r[0x17f0+j]==0xa5&&r[0x1800+width+j]==0xa5,"partial HAM respects its exact output extent");rows++;
 }
 memset(oracle_seed,0,sizeof oracle_seed);
 for(unsigned t=0;t<4;t++){
  memset(r+0x1800,0xa5,640);
  if(t==0)word_at(0x1000,0);if(t==1){word_at(0x1000,0x504e);r[0x1002]=2;}
  if(t==2){r[0x1002]=1;r[0x1003]=ham?2:1;}if(t==3){r[0x1003]=0;word_at(0x1006,319);}
  require(call_module(base+entry)==1,"backend rejects invalid ABI/operation/width");
  for(unsigned k=0;k<640;k++)require(r[0x1800+k]==0xa5,"invalid row changes no output pixels");
 }
 page=page0;ram_group=group0;free(loaded);free(pgm);modules++;
}
#ifndef PAINT_BACKEND_MAIN
#define PAINT_BACKEND_MAIN main
#endif
int PAINT_BACKEND_MAIN(int argc,char**argv){
 if(argc!=3)return 2;model_a=!strcmp(argv[1],"601a");cpu_hd=!strcmp(argv[2],"hd6303");
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load("build/test-sd.img",&image_size);committed=1;MC6800Init();MC6800Reset();until(60000000);key(0x1c);key(0x1c);prompt_wait();
 require(!invoke(0xe5,1,1,0x9000),"lease a backend bank through RAMMAN");unsigned char lease[4];memcpy(lease,MC6800GetCpuRam()+0x9000,4);unsigned bank=lease[3];
 for(unsigned banked=0;banked<2;banked++)for(unsigned k=0;k<3;k++)test_module((const char*[]){"PNTNAT","PNTRGB","PNTHAM"}[k],banked,bank);
 memcpy(MC6800GetCpuRam()+0x9000,lease,4);require(!invoke(0xe5,2,0,0x9000),"release the backend bank");
 printf("PASS Paint backends %s/%s: %u native PGMs, %u rows, ordinary/leased RAM, packed formats/HAM oracle, IRQ/selectors, validation, unchanged code (%llu cycles)\n",argv[1],argv[2],modules,rows,(unsigned long long)row_cycles);return 0;
}
