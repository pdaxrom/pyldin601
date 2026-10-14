// Actual native BIOS/UniDOS and assembled relocatable NC, private SD only.
#define COMPACT_FIXTURE 1
#define DIRECT_SD_FIXTURE 1
#define ROMDISK_MAIN unused_romdisk_main
#include "test_romdisk_unidos.c"
#undef ROMDISK_MAIN
#include "../build/nc/NC.h"
#include "../build/nc/NCMAIN.h"
#include "../build/nc/NCPROBE.h"
static unsigned cancel_pending,cancel_injected,core_load_armed,probe_armed;
static unsigned nc_base,core_base,core_entries,wait_entries,supervisor_sp,core_sp,probe_base,probe_ok;
static unsigned measure_key,measured_reads,measured_scans,measured_transfers,measured_glyphs;
static unsigned input_boundary,modal_video,progress_checks,progress_captured;
static void snapshot(unsigned video,const char*backend);
static uint64_t key_started,key_cycles;
static unsigned char nc_sig[24],core_sig[24],nc_mask[24],core_mask[24],probe_sig[24],probe_mask[24];
static unsigned ram_word(unsigned a){unsigned char*r=MC6800GetCpuRam();return r[a]*256+r[a+1];}
static unsigned char*catalog(void){
 unsigned char*r=MC6800GetCpuRam();unsigned ptr=ram_word(core_base+NCMAIN_CACHEPTR);
 if(r[core_base+NCMAIN_CACHE_LEASE_OPEN])return physical+0x22000+r[core_base+NCMAIN_CACHE_LEASE+3]*8192+(ptr&8191);
 return r+ptr;
}
static void signature(const char*path,unsigned char*sig,unsigned char*mask){
 size_t n;unsigned char*p=load(path,&n);unsigned count=p[2]*256+p[3],off=p[4]*256+p[5];
 memcpy(sig,p+off,24);memset(mask,255,24);
 for(unsigned k=0;k<count;k++){unsigned pos=p[16+2*k]*256+p[17+2*k];if(pos<24)mask[pos]=0;}
 free(p);
}
static int matches(unsigned pc,const unsigned char*sig,const unsigned char*mask){
 unsigned char*r=MC6800GetCpuRam();for(unsigned k=0;k<24;k++)if((r[(pc+k)&65535]&mask[k])!=(sig[k]&mask[k]))return 0;return 1;
}
static void observe(void){
 if(core_base){
  const unsigned waits[]={NCMAIN_DIALOG_KEY,NCMAIN_MENU_KEY,NCMAIN_SETTINGS_KEY,NCMAIN_CONFIRM_KEY,NCMAIN_MESSAGE_KEY};
  for(unsigned k=0;k<sizeof waits/sizeof waits[0];k++)if(PC==core_base+waits[k])input_boundary=waits[k];
  if(PC==core_base+NCMAIN_COPY_BLOCK&&MC6800GetCpuRam()[core_base+NCMAIN_PROGRESS_MODE]){
   unsigned char*r=MC6800GetCpuRam();unsigned d=core_base+NCMAIN_PROGRESS_DONE,t=core_base+NCMAIN_PROGRESS_TOTAL;
   uint32_t done=(uint32_t)r[d]<<24|r[d+1]<<16|r[d+2]<<8|r[d+3],total=(uint32_t)r[t]<<24|r[t+1]<<16|r[t+2]<<8|r[t+3];
   require(done<=total,"progress counts only successfully written bytes");progress_checks++;
   require(r[core_base+NCMAIN_PROGRESS_CELLS]<=r[core_base+NCMAIN_PROGRESS_WIDTH],"progress bar remains within its frame");
   if(!progress_captured&&done>=total/3&&done<total&&total>65536){snapshot(modal_video,"progress");progress_captured=1;}
  }
 }
 if(measure_key&&core_base){
  if(PC==core_base+NCMAIN_WAIT_KEY+2&&!key_started)key_started=virtual_cycles;
  if(key_started&&!key_cycles){
   if(PC==core_base+NCMAIN_READ_DIRECTORY)measured_scans++;
   if(PC==core_base+NCMAIN_CACHE_MAP)measured_transfers++;
   if(PC==core_base+NCMAIN_PUT)measured_glyphs++;
   if(PC==core_base+NCMAIN_WAIT_KEY)key_cycles=virtual_cycles-key_started;
  }
 }
 if(cancel_pending&&core_base&&PC==core_base+NCMAIN_COPY_READ){KBDKeyDown(1);cancel_pending=0;cancel_injected++;}


 if(PC>=0x100&&PC<0xbc00&&MC6800GetCpuRam()[PC]==probe_sig[0]&&matches(PC,probe_sig,probe_mask)){probe_base=PC;probe_armed=1;}
 if(probe_armed&&probe_base&&PC==probe_base+PROBE_ALLOCATED){
  probe_armed=0;
  require(MC6800GetCpuRam()[core_base+NCMAIN_IO_BUFFER]==0xa5,"external child overwrites the released NCMAIN allocation");probe_ok++;
 }
 if(PC>=0x100&&PC<0xbc00&&MC6800GetCpuRam()[PC]==nc_sig[0]){
  if(!nc_base&&matches(PC,nc_sig,nc_mask))nc_base=PC;
  if(core_load_armed&&matches(PC,core_sig,core_mask)){core_base=PC;core_entries++;core_load_armed=0;}
 }
 // An IRQ can interrupt before the first instruction and present the same
 // entry PC again after RTI. Count one entry per supervisor reload request.
 if(nc_base&&PC==nc_base+NC_RELOAD){supervisor_sp=SP;core_load_armed=1;}
 if(core_base&&PC==core_base+NCMAIN_WAIT_KEY){wait_entries++;core_sp=SP;}
}
static void panels(unsigned after){
 uint64_t end=virtual_cycles+200000000;
 do{until(virtual_cycles+1009);if(wait_entries>after&&PC==(model_a?0xf397:0xf39d))return;}while(virtual_cycles<end);
 fprintf(stderr,"NC=%04x core=%04x loads=%u waits=%u owner=%04x req=%u last=%02x\n",nc_base,core_base,core_entries,wait_entries,core_base?ram_word(core_base+NCMAIN_OWNER):0,nc_base?MC6800GetCpuRam()[nc_base+NC_STATE+NC_S_REQUEST]:0,core_base?MC6800GetCpuRam()[core_base+NCMAIN_LAST_KEY]:0);
 require(0,"NC reaches panel keyboard loop");
}
static void type(const char*text){
 const char*letters="abcdefghijklmnopqrstuvwxyz";
 static const unsigned scans[]={0x1e,0x30,0x2e,0x20,0x12,0x21,0x22,0x23,0x17,0x24,0x25,0x26,0x32,0x31,0x18,0x19,0x10,0x13,0x1f,0x14,0x16,0x2f,0x11,0x2d,0x15,0x2c};
 for(;*text;text++){const char*p=strchr(letters,*text);unsigned s=p?scans[p-letters]:*text==':'?0x27:*text=='.'?0x34:*text=='\\'?0x2b:*text==' '?0x39:*text>='1'&&*text<='9'?*text-'1'+2:*text=='0'?11:0;require(s,"input scan supported");if(*text==':')KBDModKeyDown(2);key(s);if(*text==':')KBDModKeyUp(2);}
}
static void loaded(unsigned count){uint64_t end=virtual_cycles+200000000;do{until(virtual_cycles+1009);if(core_entries>=count)return;}while(virtual_cycles<end);require(0,"NCMAIN executable reloaded");}
static void graphic_glyph(unsigned col,unsigned row,unsigned code,unsigned foreground){
 unsigned char*r=MC6800GetCpuRam();unsigned mode=r[core_base+NCMAIN_MODE],bits=mode==2?2:1,unit=8/bits,base=ram_word(core_base+NCMAIN_SCREEN_BASE);
 for(unsigned y=0;y<8;y++)for(unsigned x=0;x<8;x++){
  unsigned pixel_x=col*8+x,pixel_y=row*8+y;
  unsigned at=base+(pixel_y/8)*(model_a?640:320)+(pixel_x/unit)*8+pixel_y%8;
  unsigned sample=(r[at]>>(8-bits*(pixel_x%unit+1)))&((1u<<bits)-1);
  unsigned bit=(physical[0x11800+code*8+y]>>(7-x))&1;
  require(sample==(bit?(bits==2?foreground:1):0),"native graphic glyph is complete at its actual panel position");
 }
}
static void snapshot(unsigned video,const char*backend){
 unsigned char*r=MC6800GetCpuRam();char name[180];
 snprintf(name,sizeof name,"build/nc/screen-%s-%u-%s.bin",model_a?"601a":"601",video,backend);
 FILE*f=fopen(name,"wb");require(f&&fwrite(r,1,65536,f)==65536&&!fclose(f),"save NC framebuffer snapshot");
 snprintf(name,sizeof name,"build/nc/screen-%s-%u-%s.txt",model_a?"601a":"601",video,backend);
 f=fopen(name,"w");require(f!=NULL,"framebuffer metadata");fprintf(f,"%u %u %u %u\n",model_a,video,ram_word(core_base+NCMAIN_SCREEN_BASE),crtc[1]);fclose(f);
 f=fopen("build/nc/font.bin","wb");require(f&&fwrite(physical+0x11800,1,2048,f)==2048&&!fclose(f),"save actual native font");
}
static void panel_key(unsigned scan){unsigned after=wait_entries;key(scan);panels(after);}
static void modal_wait(unsigned boundary){
 uint64_t end=virtual_cycles+200000000;
 do{until(virtual_cycles+1009);if(input_boundary==boundary&&PC==(model_a?0xf397:0xf39d))return;}while(virtual_cycles<end);
 require(0,"modal window reaches its keyboard loop");
}
static void open_settings(void){
 key(0x43);modal_wait(NCMAIN_MENU_KEY);
 while(MC6800GetCpuRam()[core_base+NCMAIN_MENU_GROUP]!=3){key(0x4d);modal_wait(NCMAIN_MENU_KEY);}
 key(0x1c);modal_wait(NCMAIN_SETTINGS_KEY);
}
static void modal_key(unsigned scan,unsigned boundary){input_boundary=0;key(scan);modal_wait(boundary);}
static void check_menu_restore(void){
 unsigned char*r=MC6800GetCpuRam(),expected[16000];
 unsigned base=ram_word(core_base+NCMAIN_SCREEN_BASE),mode=r[core_base+NCMAIN_MODE];
 unsigned length=(mode&3)?25*(model_a?640:320):26*crtc[1];
 memcpy(expected,r+base,length);
 modal_key(0x4d,NCMAIN_MENU_KEY);modal_key(0x4b,NCMAIN_MENU_KEY);
 require(!memcmp(expected,r+base,length),"changing top menus restores their underlay without disturbing the panels");
 modal_key(0x50,NCMAIN_MENU_KEY);
 require(r[core_base+NCMAIN_MENU_INDEX]==1,"Down selects the next menu item");
 modal_key(0x48,NCMAIN_MENU_KEY);
 require(r[core_base+NCMAIN_MENU_INDEX]==0,"Up selects the previous menu item");
}
static void drive_b(void){unsigned after=wait_entries;KBDModKeyDown(1);key(0x20);KBDModKeyUp(1);type("b");key(0x1c);panels(after);}
static void check_incremental_screen(void){
 unsigned char*r=MC6800GetCpuRam(),expected[16000];
 unsigned base=ram_word(core_base+NCMAIN_SCREEN_BASE),mode=r[core_base+NCMAIN_MODE];
 unsigned length=(mode&3)?25*(model_a?640:320):26*crtc[1];
 memcpy(expected,r+base,length);
 // A complete render is the oracle for incremental highlights and scrolling.
 // Call it at the stable keyboard boundary without changing the CPU context.
 unsigned pc0=PC,sp0=SP,a0=A,b0=B,x0=X,h0=h,i0=i,n0=n,z0=z,v0=v,c0=c,page0=page;
 unsigned target=core_base+NCMAIN_RENDER;
 r[0x210]=0xbd;r[0x211]=target>>8;r[0x212]=target;r[0x213]=1;PC=0x210;
 uint64_t end=virtual_cycles+200000000;
 do{until(virtual_cycles+1);require(virtual_cycles<end,"full render oracle returns");}while(PC!=0x213);
 require(SP==sp0&&page==page0,"full render preserves caller stack and ROM mapping");
 PC=pc0;A=a0;B=b0;X=x0;h=h0;i=i0;n=n0;z=z0;v=v0;c=c0;
 if(memcmp(expected,r+base,length)){
  for(unsigned k=0;k<length;k++)if(expected[k]!=r[base+k]){fprintf(stderr,"incremental mismatch offset=%04x got=%02x full=%02x mode=%u cursor=%u/%u top=%u/%u\n",k,expected[k],r[base+k],mode,r[core_base+NCMAIN_CURSORS],r[core_base+NCMAIN_CURSORS+1],r[core_base+NCMAIN_TOPS],r[core_base+NCMAIN_TOPS+1]);break;}
  require(0,"incremental video matches the complete renderer byte-for-byte");
 }
}
static void profile_key(unsigned scan,const char*name){
 measure_key=1;key_started=key_cycles=0;measured_scans=measured_transfers=measured_glyphs=0;measured_reads=sd_reads;
 panel_key(scan);measure_key=0;
 require(key_cycles!=0,"measure actual key dispatch through return to input");
 printf("NC PERF %s: %llu cycles, %u disk reads, %u directory scans, %u bank maps, %u glyphs\n",name,(unsigned long long)key_cycles,sd_reads-measured_reads,measured_scans,measured_transfers,measured_glyphs);fflush(stdout);
 if(scan!=0x0f)require(!measured_scans&&!measured_transfers&&sd_reads==measured_reads,"ordinary navigation performs no directory I/O or RAMMAN catalogue copies");
 if(scan==0x50||scan==0x48||scan==0x52){
  unsigned mode=MC6800GetCpuRam()[core_base+NCMAIN_MODE];
  require(key_cycles<((mode&3)?400000:300000),"navigation remains below the 1 MHz viewport-scroll cycle budget");
  if(!strcmp(name,"Down")||!strcmp(name,"Up")||scan==0x52)require(key_cycles<((mode&3)?150000:30000),"non-scrolling cursor and marking remain responsive at 1 MHz");
 }
 check_incremental_screen();
}
static void select_name(const char*name){
 unsigned char*r=MC6800GetCpuRam();panel_key(0x47);
 unsigned p=r[core_base+NCMAIN_ACTIVE],count=r[core_base+NCMAIN_COUNTS+p],idx;
 for(idx=0;idx<count;idx++)if(!memcmp(catalog()+idx*NCMAIN_ENTRY_SIZE,name,8))break;
 require(idx<count,"test file appears in NC panel");
 for(unsigned k=0;k<idx;k++)panel_key(0x50);
 require(r[core_base+NCMAIN_CURSORS+p]==idx,"arrow navigation selects the requested file");
}
static void dialog_clear(void){for(unsigned k=0;k<79;k++)key(0x0e);}
static void operation(unsigned scan,const char*destination){unsigned after=wait_entries;key(scan);dialog_clear();type(destination);key(0x1c);panels(after);}
static int name_order(const void*a,const void*b){return memcmp(a,b,11);}
static void viewport_names(unsigned char names[17][11]){
 unsigned char*r=MC6800GetCpuRam();unsigned top=r[core_base+NCMAIN_PTOP],count=r[core_base+NCMAIN_PCOUNT];
 memset(names,0,17*11);
 for(unsigned k=0;k<r[core_base+NCMAIN_UI_ROWS]&&top+k<count;k++)memcpy(names[k],catalog()+(top+k)*NCMAIN_ENTRY_SIZE,11);
}
static void continuous_arrow(unsigned scan,const char*expected){
 unsigned char*r=MC6800GetCpuRam(),before[17][11],after[17][11];
 unsigned rows=r[core_base+NCMAIN_UI_ROWS],row=r[core_base+NCMAIN_PCUR]-r[core_base+NCMAIN_PTOP];
 viewport_names(before);panel_key(scan);viewport_names(after);
 unsigned newrow=r[core_base+NCMAIN_PCUR]-r[core_base+NCMAIN_PTOP];
 require(!memcmp(catalog()+r[core_base+NCMAIN_PCUR]*NCMAIN_ENTRY_SIZE,expected,11),"every arrow selects the adjacent file across cache boundaries, without repeating parent");
 if(scan==0x50&&row==rows-1){
  require(newrow==rows-1&&!memcmp(before+1,after,(rows-1)*11),"Down scrolls the viewport by exactly one row at a cache boundary");
 }else if(scan==0x48&&row==0){
  require(newrow==0&&!memcmp(before,after+1,(rows-1)*11),"Up scrolls the viewport by exactly one row at a cache boundary");
 }else require(newrow==(scan==0x50?row+1:row-1)&&!memcmp(before,after,rows*11),"ordinary arrows keep the viewport and move only one row");
}
static void check_large_directory(unsigned video){
 char names[361][12];unsigned count=0;
 const char*fixed[]={"AONE    TXT","BTWO    TXT","CTHREE  TXT","DFOUR   TXT","EFIVE   TXT","ZLAST   TXT","NC      PGM","NCMAIN  PGM","NCPROBE PGM","NCGRAF2 PGM","NCGRAF3 PGM"};
 for(unsigned k=0;k<350;k++)snprintf(names[count++],12,"F%03u    TXT",k);
 for(unsigned k=0;k<sizeof fixed/sizeof fixed[0];k++)strcpy(names[count++],fixed[k]);
 qsort(names,count,sizeof names[0],name_order);
 panel_key(0x47);
 for(unsigned k=0;k<count;k++)continuous_arrow(0x50,names[k]);
 check_incremental_screen();snapshot(video,"scroll-last");
 for(unsigned k=count-1;k>0;k--)continuous_arrow(0x48,names[k-1]);
 continuous_arrow(0x48,"..         ");check_incremental_screen();
 panel_key(0x51);
 unsigned char*r=MC6800GetCpuRam();unsigned rows=r[core_base+NCMAIN_UI_ROWS];
 require(!memcmp(catalog()+r[core_base+NCMAIN_PCUR]*NCMAIN_ENTRY_SIZE,names[rows-1],11),"PgDn advances by one viewport");
 panel_key(0x49);
 require(!memcmp(catalog()+r[core_base+NCMAIN_PCUR]*NCMAIN_ENTRY_SIZE,"..",2),"PgUp returns to the real directory start");
 for(unsigned k=0;k<200;k++)panel_key(0x50);
 require(r[core_base+NCMAIN_HAS_PREVIOUS],"test reaches a continuation of the directory");
 panel_key(0x47);
 require(r[core_base+NCMAIN_PCUR]==1&&r[core_base+NCMAIN_PTOP]==1,"Home selects the first visible file in a continuation, without exposing synthetic parent");
 check_incremental_screen();
}
static void expect_info(unsigned col,unsigned row,const char*expected){
 unsigned char*r=MC6800GetCpuRam();
 for(;*expected;expected++,col++){
  if(r[core_base+NCMAIN_MODE]&3)graphic_glyph(col,row,(unsigned char)*expected,3);
  else{unsigned step=model_a&&!r[core_base+NCMAIN_MODE]?2:1,base=ram_word(core_base+NCMAIN_SCREEN_BASE);
   require(r[base+row*crtc[1]+col*step+(step==2)]==(unsigned char)*expected,"selected-file information has exact attributes, timestamp and unsigned 32-bit size");
  }
 }
}
static void check_file_information(unsigned video){
 unsigned char*r=MC6800GetCpuRam(),saved[NCMAIN_ENTRY_SIZE];
 unsigned idx=r[core_base+NCMAIN_PCUR];unsigned char*entry=catalog()+idx*NCMAIN_ENTRY_SIZE;
 memcpy(saved,entry,sizeof saved);entry[NCMAIN_E_ATTR]=0x27;
 entry[NCMAIN_E_DATE]=0x4e;entry[NCMAIN_E_DATE+1]=0x5d;entry[NCMAIN_E_TIME]=0x20;entry[NCMAIN_E_TIME+1]=0x6b;
 memset(entry+NCMAIN_E_SIZE,255,4);panel_key(0x50);panel_key(0x48);
 unsigned width=r[core_base+NCMAIN_PANEL_WIDTH],info=r[core_base+NCMAIN_UI_INFO];
 expect_info(1,info,"HELLO.TXT");expect_info(width-5,info,"RHSA");
 if(width==20){expect_info(1,info+1,"14.10 13:25");expect_info(14,info+1,"4095M");}
 else{expect_info(1,info+1,"14.10.2026 13:25");expect_info(width-11,info+1,"4294967295");}
 snapshot(video,"info");memcpy(entry,saved,sizeof saved);panel_key(0x50);panel_key(0x48);
}

int main(int argc,char**argv){
 if(argc!=5&&argc!=6)return 2;
 const char*backend=argc==6?argv[5]:"bank";
 model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");unsigned video=atoi(argv[4]);modal_video=video;
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);
 memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load(argv[1],&image_size);committed=1;
 MC6800Init();MC6800Reset();until(60000000);key(0x1c);key(0x1c);prompt_wait();
 if(strncmp(backend,"many",4)&&strcmp(backend,"no-main")&&strcmp(backend,"ready")){command("md b:tree");command("md b:tree\\sub");command("copy b:hello.txt b:tree\\sub\\leaf.txt");}
 unsigned original_sp=SP,original_himem=ram_word(0xee1e),original_resident=ram_word(0xee1a);
 invoke(0x2e,0xe5,0,0);unsigned ram_vector=result_x,ram_vector_page=result_b;
 require(ram_vector!=0,"RAMMAN fixture available before optional-backend tests");
 require(invoke(0xe5,0,0,0)==1,"RAMMAN ABI");unsigned banks_before=result_b;
 unsigned char held_lease[114];unsigned held_length=0;
 if(!strcmp(backend,"missing")||!strcmp(backend,"many"))invoke(0x2f,0xe5,0,0);
 if(!strcmp(backend,"full")||!strcmp(backend,"offset")){
  unsigned held_count=!strcmp(backend,"offset")?7:banks_before;
  require(invoke(0xe5,1,held_count,0x9000)==0,"occupy RAMMAN banks with another owner");
  held_length=3+held_count;memcpy(held_lease,MC6800GetCpuRam()+0x9000,held_length);
 }
 if(model_a&&(video==0||video==4))invoke(0x12,video,video==0?0x71:0,0);
 signature("build/nc/NC.PGM",nc_sig,nc_mask);signature("build/nc/NCMAIN.PGM",core_sig,core_mask);signature("build/nc/NCPROBE.PGM",probe_sig,probe_mask);
 native_step_hook=observe;watch_resets=1;
 if(!strcmp(backend,"no-main")){
  type("b:nc");key(0x1c);
  uint64_t deadline=virtual_cycles+20000000;
  do{until(virtual_cycles+1009);if(nc_base&&contains("NC:")&&PC==(model_a?0xf397:0xf39d))break;}while(virtual_cycles<deadline);
  require(virtual_cycles<deadline&&!core_entries,"missing NCMAIN reports its error and keeps no panel allocation");
  key(1);prompt_wait();require(SP==original_sp&&ram_word(0xee1e)==original_himem,"missing panel loader exits cleanly to DOS");
  puts("PASS NC missing NCMAIN: readable load error, key acknowledgement and complete cleanup");return 0;
 }
 type((video&3)?(video==2?"b:ncgraf2":"b:ncgraf3"):"b:nc");key(0x1c);panels(0);
 require(nc_base&&core_base&&core_entries==1,"separate supervisor and panel PGM loaded");
 require((video&3)||(contains("Left")&&contains("Command")&&contains("Options")),"functional top menu drawn");
 require((video&3)||(!contains("Tab panel")&&contains("Name")&&contains("free")),"MC layout has headings and per-panel information without a hint row");
 unsigned char*r=MC6800GetCpuRam();
 require(r[core_base+NCMAIN_CACHE_LEASE_OPEN]==(!strcmp(backend,"bank")||!strcmp(backend,"many-bank")||!strcmp(backend,"offset")||!strcmp(backend,"disk")||!strcmp(backend,"ready")),"RAMMAN optional: absent vector and allocation failure use ordinary RAM");
 if(!strcmp(backend,"offset"))require(r[core_base+NCMAIN_CACHE_GROUP]>0,"leased catalogue works outside the first six-bank group");
 require(ram_word(core_base+NCMAIN_OWNER)==nc_base+NC_STATE,"panel receives parent-owned ABI state");
 require(ram_word(0xee1a)==original_resident,"NC does not permanently mark memory resident");
 fprintf(stderr,"NC layout: cols=%u CRTC stride=%u base=%04x display=%04x mode=%u\n",r[core_base+NCMAIN_COLUMNS],crtc[1],ram_word(core_base+NCMAIN_SCREEN_BASE),crtc[12]*256+crtc[13],r[core_base+NCMAIN_MODE]);
 if(model_a&&video==0){
  unsigned base=ram_word(core_base+NCMAIN_SCREEN_BASE);
  require(r[base]==0x03&&r[base+4*80+2]==0x71,"NC cyan headings and blue panel colour attributes");
 }
 if(!strcmp(backend,"ready")){
  drive_b();snapshot(video,backend);
  unsigned after=wait_entries;key(0x3b);key(1);panels(after);
  key(0x44);prompt_wait();
  require(SP==original_sp&&ram_word(0xee1e)==original_himem,"packaged SD image launches and quits without memory leaks");
  require(invoke(0xe5,0,0,0)==1&&result_b==banks_before,"packaged SD image releases its cache bank");
  printf("PASS NC ready SD image %s/%s: original disk shell, B:NC, panels, F1, F10 cleanup\n",argv[2],argv[3]);return 0;
 }
 unsigned after=wait_entries;
 type("ab");panel_key(0x0e);
 require(!strcmp((char*)r+core_base+NCMAIN_COMMAND_LINE,"a"),"native Backspace edits the command line");
 after=wait_entries;KBDModKeyDown(1);key(0x2e);KBDModKeyUp(1);panels(after);
 require(!r[core_base+NCMAIN_COMMAND_LENGTH]&&core_entries==1,"Ctrl+C clears command input without abandoning memory");
 after=wait_entries;
 type("b:ncprobe");key(0x1c);loaded(2);panels(after);
 require(probe_ok==1&&core_entries==2,"real external PGM runs with panel memory released, then NC reloads");
 require(r[0xed12]==video,"NC restores its initial video mode after the external PGM");
 drive_b();
 profile_key(0x50,"Down");profile_key(0x48,"Up");
 profile_key(0x50,"Down");profile_key(0x52,"Insert mark");profile_key(0x48,"Up");profile_key(0x52,"Insert unmark");profile_key(0x47,"Home");
 profile_key(0x0f,"Tab");
 profile_key(0x4f,"End");profile_key(0x47,"Home");
 unsigned right_count=r[core_base+NCMAIN_COUNTS+1];
 for(unsigned k=0;k<r[core_base+NCMAIN_UI_ROWS]-1&&k+1<right_count;k++)panel_key(0x50);
 if(right_count>r[core_base+NCMAIN_UI_ROWS]){profile_key(0x50,"Scroll down");profile_key(0x47,"Scroll up");}
 profile_key(0x0f,"Tab back");

 if(!strncmp(backend,"many",4)){
  check_large_directory(video);
  key(0x44);prompt_wait();
  require(SP==original_sp&&ram_word(0xee1e)==original_himem,"large directory exits without memory leaks");
  if(!strcmp(backend,"many-bank"))require(invoke(0xe5,0,0,0)==1&&result_b==banks_before,"large bank catalogue releases its lease");
  printf("PASS NC large directory %s/%s video %u %s: 361 files, adjacent arrows, one-row scrolling across cache boundaries, PgDn/PgUp\n",argv[2],argv[3],video,backend);return 0;
 }

 {unsigned width=r[core_base+NCMAIN_PANEL_WIDTH];
  const unsigned frame[][3]={{0,1,0xda},{width-1,1,0xcf},{0,4,0xd3},{1,r[core_base+NCMAIN_UI_END],0xc4},{0,r[core_base+NCMAIN_UI_BOTTOM],0xc0},{width-1,r[core_base+NCMAIN_UI_BOTTOM],0xd9}};
  if(video&3){
   graphic_glyph(width+2,4,'G',3);
   for(unsigned k=0;k<6;k++)graphic_glyph(frame[k][0],frame[k][1],frame[k][2],1);
  }else{
   unsigned step=model_a&&video==0?2:1,base=ram_word(core_base+NCMAIN_SCREEN_BASE);
   for(unsigned k=0;k<6;k++)require(r[base+frame[k][1]*crtc[1]+frame[k][0]*step+(step==2)]==frame[k][2],"native Pyldin box-drawing glyphs used for every frame edge");
  }
 }
 snapshot(video,backend);
 // Change the DOS CWD behind the panels, then launch by Enter. Resources
 // opened with relative paths must still resolve in the selected directory.
 require(invoke(0x44,0,0,0)==0,"set a different DOS working drive behind the panels");
 select_name("NCPROBE ");
 after=wait_entries;key(0x1c);loaded(3);panels(after);
 require(probe_ok==2&&core_entries==3,"Enter executes the selected PGM and reloads panels");
 require(invoke(0x45,0,0,0)==1,"selected program inherits the active panel drive");
 select_name("HELLO   ");
 after=wait_entries;key(0x3d);until(virtual_cycles+2000000);
 require((video&3)||contains("F3 View"),"F3 text viewer opens the selected file");
 key(0x51);key(0x49);key(1);panels(after);
 check_file_information(video);
 select_name("LARGE   ");operation(0x3f,"copy.bin");
 unsigned char large[76800];for(unsigned k=0;k<sizeof large;k++)large[k]=k;
 file_check("b:COPY.BIN",large,sizeof large);
 require(progress_checks>0&&progress_captured,"real 32-bit copy progress is displayed, including beyond 64 KiB");
 select_name("TREE    ");operation(0x3f,"b:treecopy");
 const unsigned char hello[]="Pyldin Commander text viewer\r\n";
 unsigned char hello_all[(sizeof hello-1)+26*100];
 size_t hello_len=sizeof hello-1;memcpy(hello_all,hello,hello_len);
 for(unsigned k=0;k<100;k++){memcpy(hello_all+hello_len,"Line of text for paging.\r\n",26);hello_len+=26;}
 file_check("b:TREECOPY\\SUB\\LEAF.TXT",hello_all,hello_len);
 select_name("TREECOPY");after=wait_entries;key(0x42);type("y");panels(after);
 select_name("HELLO   ");after=wait_entries;key(0x3f);dialog_clear();type("b:copy.bin");key(0x1c);until(virtual_cycles+2000000);type("y");panels(after);
 file_check("b:COPY.BIN",hello_all,hello_len);
 select_name("LARGE   ");after=wait_entries;key(0x3f);dialog_clear();type("b:copy.bin");key(0x1c);until(virtual_cycles+2000000);
 cancel_pending=1;type("y");panels(after);KBDKeyUpCode(1);
 require(cancel_injected==1,"ESC interrupts a real copy after opening its temporary file");
 file_check("b:COPY.BIN",hello_all,hello_len);
 after=wait_entries;key(0x41);type("group");key(0x1c);panels(after);
 select_name("HELLO   ");panel_key(0x52);
 select_name("COPY    ");panel_key(0x52);
 panel_key(0x0f);panel_key(0x0f);
 operation(0x3f,"b:group");
 file_check("b:GROUP\\HELLO.TXT",hello_all,hello_len);
 file_check("b:GROUP\\COPY.BIN",hello_all,hello_len);
 select_name("GROUP   ");after=wait_entries;key(0x42);type("y");panels(after);
 after=wait_entries;open_settings();snapshot(video,"settings");type("s");key(0x1c);panels(after);panel_key(0x4f);
 require(!memcmp(catalog()+r[core_base+NCMAIN_CURSORS]*NCMAIN_ENTRY_SIZE,"LARGE   ",8),"F9 sorts complete 32-bit sizes");
 after=wait_entries;open_settings();type("n");key(0x1c);panels(after);
 unsigned state=nc_base+NC_STATE,old_sort=r[state+NC_S_SORT],old_hidden=r[state+NC_S_HIDDEN];
 after=wait_entries;open_settings();type("dh");key(1);panels(after);
 require(r[state+NC_S_SORT]==old_sort&&r[state+NC_S_HIDDEN]==old_hidden,"Esc discards all staged settings");
 after=wait_entries;open_settings();type("h");modal_key(0x0f,NCMAIN_SETTINGS_KEY);modal_key(0x0f,NCMAIN_SETTINGS_KEY);key(0x1c);panels(after);
 require(r[state+NC_S_HIDDEN]==old_hidden,"Cancel button discards the hidden-file setting");
 after=wait_entries;open_settings();type("h");modal_key(0x0f,NCMAIN_SETTINGS_KEY);key(0x1c);panels(after);
 require(r[state+NC_S_HIDDEN]==(old_hidden^1),"Apply button commits the hidden-file setting");
 after=wait_entries;open_settings();type("h");key(0x1c);panels(after);
 after=wait_entries;key(0x3b);key(1);panels(after);
 after=wait_entries;key(0x3c);modal_wait(NCMAIN_MENU_KEY);snapshot(video,"menu");check_menu_restore();type("3");panels(after);
 select_name("EMPTY   ");operation(0x40,"b:renamed.txt");
 file_check("b:RENAMED.TXT",(const unsigned char*)"",0);
 after=wait_entries;key(0x41);modal_wait(NCMAIN_DIALOG_KEY);
 for(unsigned k=0;k<75;k++)type("a");modal_wait(NCMAIN_DIALOG_KEY);
 require(r[core_base+NCMAIN_EDIT_CURSOR]==75&&r[core_base+NCMAIN_EDIT_OFFSET]>0,"long dialog input scrolls to keep its caret visible");
 modal_key(0x47,NCMAIN_DIALOG_KEY);
 require(r[core_base+NCMAIN_EDIT_CURSOR]==0&&r[core_base+NCMAIN_EDIT_OFFSET]==0,"Home scrolls the input back to the start");
 modal_key(0x4f,NCMAIN_DIALOG_KEY);
 require(r[core_base+NCMAIN_EDIT_CURSOR]==75,"End returns to the end of long input");
 modal_key(0x0f,NCMAIN_DIALOG_KEY);modal_key(0x0f,NCMAIN_DIALOG_KEY);key(0x1c);panels(after);
 after=wait_entries;key(0x41);modal_wait(NCMAIN_DIALOG_KEY);snapshot(video,"dialog");type("nwdir");
 modal_key(0x47,NCMAIN_DIALOG_KEY);modal_key(0x4d,NCMAIN_DIALOG_KEY);type("e");
 modal_key(0x4f,NCMAIN_DIALOG_KEY);modal_key(0x0e,NCMAIN_DIALOG_KEY);type("r");
 modal_key(0x47,NCMAIN_DIALOG_KEY);modal_key(0x53,NCMAIN_DIALOG_KEY);type("n");
 modal_key(0x4d,NCMAIN_DIALOG_KEY);modal_key(0x4b,NCMAIN_DIALOG_KEY);
 require(!strcmp((char*)r+core_base+NCMAIN_INPUT,"newdir"),"dialog insertion, arrows, Home/End, Backspace and Delete edit in place");
 modal_key(0x0f,NCMAIN_DIALOG_KEY);key(0x1c);panels(after);
 select_name("NEWDIR  ");after=wait_entries;key(0x1c);panels(after);
 require(strstr((char*)r+nc_base+NC_STATE+NC_S_PATHS,"NEWDIR")!=NULL,"Enter opens a directory");
 panel_key(0x0e);
 select_name("RENAMED ");after=wait_entries;key(0x42);modal_wait(NCMAIN_CONFIRM_KEY);snapshot(video,"confirm");key(0x1c);panels(after);
 file_check("b:RENAMED.TXT",(const unsigned char*)"",0);
 after=wait_entries;key(0x42);modal_wait(NCMAIN_CONFIRM_KEY);modal_key(0x4b,NCMAIN_CONFIRM_KEY);key(0x1c);panels(after);
 after=wait_entries;key(0x0f);panels(after);
 require(r[core_base+NCMAIN_ACTIVE]==1,"Tab switches active panel");
 after=wait_entries;KBDModKeyDown(1);key(0x18);KBDModKeyUp(1);until(virtual_cycles+1000000);
 require(r[nc_base+NC_STATE+NC_S_REQUEST]==2,"Ctrl+O unloads panels before nested shell");
 type("exit");key(0x1c);loaded(4);panels(after);
 require(core_entries==4,"EXIT reloads the panel executable");
 require(r[core_base+NCMAIN_ACTIVE]==1,"active panel survives shell return");
 key(0x44);prompt_wait();
 require(SP==original_sp&&ram_word(0xee1e)==original_himem&&ram_word(0xee1a)==original_resident,"F10 releases all NC memory and restores original shell stack");
 if(!strcmp(backend,"missing"))invoke(0x2f,0xe5,ram_vector_page,ram_vector);
 if(held_length){memcpy(r+0x9000,held_lease,held_length);require(invoke(0xe5,2,0,0x9000)==0,"release the foreign test lease");}
 require(invoke(0xe5,0,0,0)==1&&result_b==banks_before,"all optional cache banks released after programs, shell and F10");
 require(!resets&&!fdc_port_accesses,"no resets or FDC accesses");
 printf("PASS NC %s/%s video %u backend %s: loader/overwrite released memory, navigation, F3, F5 76800 bytes, F6, F7, F8, shell EXIT/reload, F10 stack/heap/bank cleanup\n",argv[2],argv[3],video,backend);
 return 0;
}
