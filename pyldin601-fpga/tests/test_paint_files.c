// Native APIs use owned application scratch, avoiding the low stack in 601A
// graphics mode. No test buffer assumes a large unused ordinary RAM region.
static unsigned test_file_io,test_file_data;
#define TEST_FILE_IO_BASE test_file_io
#define TEST_FILE_DATA_BASE test_file_data
#define DOS_API_CYCLES 200000000
#define PAINT_UI_MAIN unused_paint_ui_main
#define PAINT_UI_HEADER "../build/paint/PAINTF.h"
#include "test_paint_ui.c"
static unsigned cancel_save,cancel_seen,cancel_open,open_cancel_seen,fail_publish,publish_failed;
static void files_observe(void){
 ui_observe();
 if(base&&cancel_save&&PC==base+PUI_FILE_FETCH){cancel_save=0;cancel_seen++;KBDKeyDown(1);}
 if(base&&cancel_open&&PC==base+PUI_FILE_STORE){cancel_open=0;open_cancel_seen++;KBDKeyDown(1);}
 if(base&&fail_publish&&PC>=base&&PC<base+PUI_BSS_START&&r[PC]==0x3f&&r[PC+1]==0x56){
  const char*s=(char*)r+ramword(X),*d=(char*)r+ramword(X+2);
  if(strstr(s,".TMP")&&strstr(d,"ROLL.PCX")){fail_publish=0;publish_failed++;A=14;PC+=2;}
 }
}
static void replace_input(const char*s){
 key(0x47);for(unsigned k=0;k<80&&r[base+PUI_EDIT_LENGTH];k++)key(0x53);
 require(!r[base+PUI_EDIT_LENGTH],"modal line editor accepts Home/Delete in its input field");text(s);
}
static void open_image(const char*s,unsigned error){
 fprintf(stderr,"Open %s\n",s);
 unsigned modified=r[base+PUI_P_MODIFIED];key(0x3d);if(modified){wait_context(3);key(0x15);}wait_context(2);replace_input(s);key(0x1c);
 if(error){wait_context(4);key(1);}wait_context(0);
}
static void save_image(const char*s,unsigned exists,unsigned error){
 fprintf(stderr,"Save %s exists%u error%u\n",s,exists,error);
 key(0x3c);wait_context(2);replace_input(s);key(0x1c);if(exists){wait_context(3);key(0x15);}
 if(error){wait_context(4);key(1);}wait_context(0);
}
static unsigned char*read_file(const char*path,unsigned*bytes){
 unsigned io=test_file_io,data=test_file_data;strcpy((char*)r+io+64,path);word_at(io,io+64);word_at(io+2,0);require(!invoke(0x4a,1,0,io),"native verification opens published image");unsigned handle=result_b;
 require(!invoke(0x51,handle,0,io+4),"published image size");unsigned n=(uint32_t)r[io+4]<<24|r[io+5]<<16|r[io+6]<<8|r[io+7];require(n<300000,"bounded published image");unsigned char*p=malloc(n?n:1);require(p!=NULL,"published image oracle");
 for(unsigned at=0;at<n;){unsigned count=n-at>512?512:n-at;word_at(io,data);word_at(io+2,count);require(!invoke(0x4c,handle,0,io)&&result_x==count,"native verification reads complete published image");memcpy(p+at,r+data,count);at+=count;}
 require(!invoke(0x4e,handle,0,0),"verification closes published image");*bytes=n;return p;
}
static void artifact(const char*path,const char*name){unsigned n;unsigned char*p=read_file(path,&n);FILE*f=fopen(name,"wb");require(f&&fwrite(p,1,n,f)==n,"native image validation artifact");fclose(f);free(p);}
static void current_matches(const char*path,unsigned kind){size_t n;unsigned char*p=load(path,&n);require(r[base+PUI_P_KIND]==kind&&!r[base+PUI_P_MODIFIED]&&!memcmp(p,physical+r[base+PUI_P_DOC_PAGE]*65536,n),"Open commits the exact staged canonical image");free(p);}
static void expect_same(const unsigned char*doc,unsigned length,unsigned kind,unsigned page,unsigned modified,const unsigned char*palette){
 require(r[base+PUI_P_KIND]==kind&&r[base+PUI_P_DOC_PAGE]==page&&r[base+PUI_P_MODIFIED]==modified&&!memcmp(doc,physical+page*65536,length)&&!memcmp(palette,r+base+PUI_P_PALETTE,768),"failed Open retains document, format, serial and palette");
}
static void attributes(const char*path,unsigned value){unsigned p=test_file_io+64;strcpy((char*)r+p,path);require(!invoke(0x54,1,value,p),"set verification file attributes");}
static void fill_disk(void){
 unsigned io=test_file_io,data=test_file_data;strcpy((char*)r+io+64,"b:filler.bin");word_at(io,io+64);word_at(io+2,0);require(!invoke(0x4b,0,0,io),"create disk-exhaustion fixture");unsigned handle=result_b,full=0;
 for(unsigned k=0;k<512;k++)r[data+k]=k;
 for(unsigned n=0;n<4096;n++){
  word_at(io,data);word_at(io+2,512);unsigned status=invoke(0x4d,handle,0,io);
  if(status==17||(!status&&result_x<512)){full=1;break;}
  require(!status&&result_x==512,"fill fixture writes whole sectors until the volume is full");
 }
 require(full,"private volume reaches real FAT disk-full condition");unsigned status=invoke(0x4e,handle,0,0);require(!status||status==17,"close exhausted fixture");
}
int main(int argc,char**argv){
 if(argc!=6)return 2;model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");unsigned native=atoi(argv[4]);MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load(argv[1],&image_size);committed=1;dma_mmio_read=paint_dma_read;dma_mmio_write=paint_dma_write;MC6800Init();MC6800Reset();r=MC6800GetCpuRam();until(60000000);key(0x1c);key(0x1c);prompt_wait();
 command("md b:nest");command("md b:nest\\sub");
 unsigned sp0=SP,heap0=ramword(0xee1e),banks=free_banks(),mode0=r[0xed12];unsigned char old_palette[8192];for(unsigned k=0;k<8192;k++)old_palette[k]=pal[k]=(k*7+(k>>3))&63;
 invoke(0x2e,0xe5,0,0);unsigned ramvec=result_x,rampage=result_b;unsigned char foreign[114];unsigned foreign_n=0;
 if(!strcmp(argv[5],"missing"))invoke(0x2f,0xe5,0,0);
 if(!strcmp(argv[5],"busy")){require(!invoke(0xe5,1,banks,0x9000),"reserve every RAMMAN bank for another application");foreign_n=banks+3;memcpy(foreign,r+0x9000,foreign_n);for(unsigned k=3;k<foreign_n;k++)memset(physical+0x22000+foreign[k]*8192,k^0xa6,8192);}
 native_step_hook=files_observe;watch_resets=1;text(native==2?"b:pfgraf2":native?"b:pfgraph":!strcmp(argv[5],"arg")?"b:paint b:pcx3.pcx":"b:paint");key(0x1c);wait_context(0);
 require(r[base+PUI_BACKEND_BANKED]==(!strcmp(argv[5],"missing")||!strcmp(argv[5],"busy")?0:1),"production backend chooses RAMMAN/ordinary memory at runtime");
 test_file_io=base+PUI_P_ROW;test_file_data=base+PUI_P_ENCODED;
 char name[180],stem[160];snprintf(stem,sizeof stem,"build/paint/files-%s-%s-%s-%s",argv[2],argv[3],argv[4],argv[5]);
 open_image("b:pcx3.pcx",0);current_matches("build/paint/PCX3.raw",3);
 save_image("b:save.pcx",0,0);snprintf(name,sizeof name,"%s.pcx",stem);artifact("b:save.pcx",name);
 // Failed decode must not destroy a previously opened image or its palette.
 unsigned page=r[base+PUI_P_DOC_PAGE];unsigned char*original=malloc(64000);memcpy(original,physical+page*65536,64000);unsigned char palette[768];memcpy(palette,r+base+PUI_P_PALETTE,768);
 open_image("b:pcxbad.pcx",1);expect_same(original,64000,3,page,0,palette);
 open_image("b:iffbad.iff",1);expect_same(original,64000,3,page,0,palette);
 cancel_open=1;open_image("b:iff1.iff",0);KBDKeyUpCode(1);require(open_cancel_seen==1,"Open receives Escape while staging canonical rows");expect_same(original,64000,3,page,0,palette);
 runtime_r1=4;open_image("b:pcx3.pcx",1);runtime_r1=0;expect_same(original,64000,3,page,0,palette);free(original);
 if(!strcmp(argv[5],"bad")){
  original=malloc(64000);memcpy(original,physical+page*65536,64000);open_image("b:iff1.iff",1);expect_same(original,64000,3,page,0,palette);
  key(0x40);wait_context(5);key(6);wait_context(4);key(1);wait_context(0);expect_same(original,64000,3,page,0,palette);
  require(!r[base+PUI_MODULE_VALID+2]&&ramword(base+PUI_BACKEND_BASE),"invalid cold module retains a working cached previous backend");free(original);goto finish;
 }
 const char*roll="b:nest\\sub\\roll.pcx";
 save_image(roll,0,0);unsigned before_n;unsigned char*before=read_file(roll,&before_n);
 attributes(roll,33);save_image(roll,0,1);attributes(roll,32);
 unsigned protected_n;unsigned char*protected_data=read_file(roll,&protected_n);require(protected_n==before_n&&!memcmp(protected_data,before,before_n),"read-only target is retained byte for byte");free(protected_data);
 // Cancel after the first canonical row was fetched, before publication.
 cancel_save=1;save_image(roll,1,0);KBDKeyUpCode(1);require(cancel_seen==1,"Save observes Escape while streaming");unsigned after_n;unsigned char*after=read_file(roll,&after_n);require(after_n==before_n&&!memcmp(after,before,before_n),"cancelled Save retains the existing target byte for byte");free(after);
 fail_publish=1;save_image(roll,1,1);require(publish_failed==1,"publication rename failure was injected once");after=read_file(roll,&after_n);require(after_n==before_n&&!memcmp(after,before,before_n),"failed publish restores the original backup");free(after);free(before);
 if(!strcmp(argv[5],"full")){
  before=read_file(roll,&before_n);fill_disk();save_image(roll,1,1);after=read_file(roll,&after_n);require(after_n==before_n&&!memcmp(after,before,before_n),"disk-full Save retains existing target");free(after);free(before);
  strcpy((char*)r+test_file_io+64,"b:filler.bin");require(!invoke(0x4f,0,0,test_file_io+64),"remove only the owned exhaustion fixture");
 }
 open_image("b:iff1.iff",0);current_matches("build/paint/IFF1.raw",4);
 save_image("b:ham.iff",0,0);snprintf(name,sizeof name,"%s.iff",stem);artifact("b:ham.iff",name);
 open_image("b:ham.iff",0);unsigned char*p=physical+r[base+PUI_P_DOC_PAGE]*65536;snprintf(name,sizeof name,"%s-ham-loaded.raw",stem);FILE*f=fopen(name,"wb");require(f&&fwrite(p,1,192000,f)==192000,"reopened HAM canonical artifact");fclose(f);
 // Once warmed, all three modules must work without another disk read.
 format(model_a?1:0);format(3);format(4);require(r[base+PUI_MODULE_VALID]&&r[base+PUI_MODULE_VALID+1]&&r[base+PUI_MODULE_VALID+2],"three immutable native backend caches are valid");
 unsigned reads=sd_reads;runtime_r1=4;format(model_a?1:0);format(3);format(4);runtime_r1=0;require(sd_reads==reads,"warm module switching and rollback need no disk I/O");
finish:
 key(0x44);prompt_wait();
 if(foreign_n){for(unsigned k=3;k<foreign_n;k++)for(unsigned x=0;x<8192;x+=127)require(physical[0x22000+foreign[k]*8192+x]==(unsigned char)(k^0xa6),"Paint ordinary fallback preserves all foreign banks");memcpy(r+0x9000,foreign,foreign_n);require(!invoke(0xe5,2,0,0x9000),"release foreign RAMMAN ownership");}
 if(!strcmp(argv[5],"missing"))invoke(0x2f,0xe5,rampage,ramvec);
 require(return_seen==1&&!resets&&SP==sp0&&ramword(0xee1e)==heap0&&free_banks()==banks&&r[0xed12]==mode0&&!memcmp(pal,old_palette,8192),"production Paint restores native stack, video, palette, files and leases");
 printf("PASS production Paint files %s/%s start%s %s: staged PCX/IFF Open, exact palette/rows, closed temp Save, Cancel, rename rollback, corrupt input, offline module cache, native resources\n",argv[2],argv[3],argv[4],argv[5]);return 0;
}
