// Actual editor, UniDOS and native FPGA PS/2 translator; private media only.
#define HG_FIXTURE 1
#define TEST_RAW_KEYBOARD 1
#define TEST_FILE_IO_BASE 0x1800
#define TEST_FILE_DATA_BASE 0x2800
static int hg_read_byte(unsigned short a,unsigned char*out);
static int hg_write_byte(unsigned short a,unsigned char d);
static void nc_ps2_key(unsigned n,unsigned up);
static void nc_ps2_mod(unsigned n,unsigned up);
static void editor_write_watch(unsigned short a,unsigned char d);
#define NC_MAIN panels_unused_main
#include "test_nc.c"
#undef NC_MAIN
#include "../build/nc/NCEDIT.h"
#include "../build/nc/NCELOAD.h"
// Independent byte FIFO/MMIO model. Translation runs in the real ROM IRQ,
// not KBDTranslateKey; the latter's legacy latch is deliberately disconnected.
static unsigned char raw_fifo[64],raw_code=255;
static unsigned raw_head,raw_count,raw_overflow,raw_capture,raw_reset,raw_enable,raw_consumed=1,raw_strobe,raw_irq;
static const unsigned char raw_scans[128]={0xff,0x76,0x16,0x1e,0x26,0x25,0x2e,0x36,0x3d,0x3e,0x46,0x45,0x4e,0x55,0x66,0xd,0x15,0x1d,0x24,0x2d,0x2c,0x35,0x3c,0x43,0x44,0x4d,0x54,0x5b,0x5a,0xff,0x1c,0x1b,0x23,0x2b,0x34,0x33,0x3b,0x42,0x4b,0x4c,0x52,0xe,0xff,0x5d,0x1a,0x22,0x21,0x2a,0x32,0x31,0x3a,0x41,0x49,0x4a,0xff,0xff,0xff,0x29,0x58,0x5,0x6,0x4,0xc,0x3,0xb,0x83,0xa,0x1,0x9,0xff,0xff,0x6c,0x75,0x7d,0xff,0x6b,0x73,0x74,0xff,0x69,0x72,0x7a,0x70,0x71,0xff,0xff,0xff,0x78,0x7,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff};
static void raw_push(unsigned b){if(raw_count<64)raw_fifo[(raw_head+raw_count++)&63]=b;else raw_overflow=1;}
static void raw_event(unsigned e,unsigned up,unsigned code){if(e)raw_push(0xe0);if(up)raw_push(0xf0);raw_push(code);}
static void nc_ps2_key(unsigned n,unsigned up){if(n==0x46){raw_event(1,up,0x1f);return;}if(n<128&&raw_scans[n]!=255)raw_event(n>=0x47&&n<=0x53,up,raw_scans[n]);}
static void nc_ps2_mod(unsigned n,unsigned up){if(n&1)raw_event(0,up,0x14);if(n&2)raw_event(0,up,0x12);}
static int hg_read_byte(unsigned short a,unsigned char*out){
 if(mouse_ui_read_byte(a,out))return 1;
 if(a>=0xe6b0&&a<=0xe6b7){*out=255;switch(a&7){
 case 0:*out='R';break;case 1:*out=(raw_count!=0)|(raw_consumed<<2)|(raw_reset<<3)|((raw_count==64)<<5)|(raw_capture<<6)|(raw_overflow<<7);break;
 case 2:if(raw_count){*out=raw_fifo[raw_head++&63];raw_count--;}break;case 3:*out=raw_count;break;case 4:*out=2;break;}return 1;}
 if(a==0xe628){*out=raw_capture?255:raw_code;raw_consumed=1;raw_strobe=raw_irq=0;return 1;}
 if(a==0xe62a||a==0xe62e){*out=0x37|(caps_off?8:0)|((!raw_capture&&raw_strobe)?128:0);if(raw_code!=255&&!raw_capture&&!raw_consumed)raw_strobe^=1;return 1;}
 return 0;
}
static int hg_write_byte(unsigned short a,unsigned char d){
 editor_write_watch(a,d);
 if(mouse_ui_write_byte(a,d))return 1;
 if(a==0xe628){raw_code=raw_capture?255:d;raw_consumed=raw_code==255;raw_strobe=raw_irq=0;return 1;}
 if(a==0xe62a||a==0xe62e){caps_off=(d&8)!=0;if(d&128&&!raw_consumed&&raw_code!=255&&!raw_capture)raw_strobe=raw_irq=1;return 1;}
 if(a>=0xe6b0&&a<=0xe6b7){if(a==0xe6b3){
  if(d&1)raw_head=raw_count=0;if(d&2)raw_overflow=0;if(d&16)raw_enable=1;if(d&64)raw_enable=0;if(d&32)raw_reset=0;
  if(d&4){if(!raw_capture)raw_reset=1;raw_capture=1;raw_code=255;raw_consumed=1;raw_strobe=raw_irq=0;}
  if(d&8){if(raw_capture)raw_reset=1;raw_capture=0;}
 }return 1;}return 0;
}
static void raw_observe(void){keyConsumed=1;if(!i&&(raw_irq||(raw_enable&&!raw_capture&&(raw_count||raw_overflow||raw_reset))))MC6800SetInterrupt(1);}

static unsigned loader_base;static unsigned char loader_sig[24],loader_mask[24];
static unsigned editor_base,editor_active,editor_entries,editor_waits;
static unsigned editor_progress_captured;
static void editor_snapshot(unsigned video,const char*name);
static uint32_t eread(unsigned label);
static unsigned inject_clip_read,inject_cancel_paste;
static unsigned inject_save_fault,inject_read_fault,inject_apply_fault,inject_cancel_save,editor_boundary;
static unsigned saved_ram_vector,saved_ram_page,expected_free_banks;
static unsigned char reserved_lease[114];static unsigned reserved_bytes;
static unsigned profile_save,last_profile_pc;static uint64_t last_profile_cycles,profile_bins[5];
static unsigned char editor_sig[24],editor_mask[24];
static const char*editor_stage="idle";
static void editor_write_watch(unsigned short a,unsigned char d){
 if(editor_active&&PC>=editor_base&&PC<editor_base+NCEDIT_OWNER&&a>=editor_base&&a<editor_base+NCEDIT_OWNER){
  fprintf(stderr,"editor code write at=%04x offset=%04x value=%02x PC=%04x SP=%04x\n",a,a-editor_base,d,PC,SP);
  require(0,"editor writes only its BSS, buffers and video memory");
 }
}
static void editor_observe(void){
 raw_observe();
 if(!editor_active&&PC>=0x100&&PC<0xbc00&&matches(PC,loader_sig,loader_mask))loader_base=PC;
 if(loader_base&&PC==loader_base+NCELOAD_LOADER_ERROR)fprintf(stderr,"editor loader error A=%u base=%04x core=%04x size=%u top=%04x SP=%04x\n",A,loader_base,ram_word(loader_base+NCELOAD_LOAD_BASE),ram_word(loader_base+NCELOAD_LOAD_RAM),ram_word(0xee1e),SP);

 if(profile_save){
  if(last_profile_cycles){unsigned relative=last_profile_pc-editor_base;unsigned bin=last_profile_pc>=0xc000?0:relative>=NCEDIT_STREAM_INIT&&relative<NCEDIT_DOC_BYTE?1:relative>=NCEDIT_Q_LOAD&&relative<NCEDIT_BLOCK_GET?2:relative>=NCEDIT_BLOCK_GET&&relative<NCEDIT_LEAF_ENTRY?3:4;profile_bins[bin]+=virtual_cycles-last_profile_cycles;}
  last_profile_pc=PC;last_profile_cycles=virtual_cycles;
 }

 if(editor_active){
  if(PC==editor_base+NCEDIT_FILE_SEEK_RETURN&&A)fprintf(stderr,"editor seek failed stage=%s file=%u pos=%u leaf=%u size=%u slots=%u phase=%u history=%u\n",editor_stage,MC6800GetCpuRam()[editor_base+NCEDIT_IO_FILE],eread(NCEDIT_IO_POSITION),eread(NCEDIT_LEAF_ID),eread(NCEDIT_DOC_SIZE),MC6800GetCpuRam()[editor_base+NCEDIT_CACHE_COUNT],MC6800GetCpuRam()[editor_base+NCEDIT_APPLY_PHASE],eread(NCEDIT_HISTORY_CURSOR));
  if(PC==editor_base+NCEDIT_ERROR)fprintf(stderr,"editor error A=%u mode=%u columns=%u body=%u head=%04x tail=%04x HIMEM=%04x SP=%04x\n",A,MC6800GetCpuRam()[editor_base+NCEDIT_MODE],MC6800GetCpuRam()[editor_base+NCEDIT_COLUMNS],MC6800GetCpuRam()[editor_base+NCEDIT_BODY_ROWS],ram_word(editor_base+NCEDIT_SCREEN_HEAD),ram_word(editor_base+NCEDIT_SCREEN_CHARS),ram_word(0xee1e),SP);
  if(!editor_progress_captured&&PC==editor_base+NCEDIT_SAVE_WRITE){
   unsigned char*r=MC6800GetCpuRam();unsigned d=editor_base+NCEDIT_SAVE_DONE,t=editor_base+NCEDIT_BLOCK_STATE+96;uint32_t done=(uint32_t)r[d]<<24|(uint32_t)r[d+1]<<16|r[d+2]<<8|r[d+3],total=(uint32_t)r[t]<<24|(uint32_t)r[t+1]<<16|r[t+2]<<8|r[t+3];
   require(done<=total&&r[editor_base+NCEDIT_SAVE_CELLS]<=r[editor_base+NCEDIT_SAVE_BAR_WIDTH],"editor progress reports written bytes inside its frame");
   if(done>=total/3&&done<total&&total>1024){editor_snapshot(r[editor_base+NCEDIT_MODE],r[editor_base+NCEDIT_BLOCK_STATE+104]?"copy-progress":"save-progress");editor_progress_captured=1;}
  }
  if(measure_key){
   if(PC==editor_base+NCEDIT_MOUSE_KEY_READY&&!key_started)key_started=virtual_cycles;
   if(key_started&&!key_cycles&&PC==editor_base+NCEDIT_EDITOR_KEY)key_cycles=virtual_cycles-key_started;
  }
  if(PC==editor_base+NCEDIT_EDITOR_KEY)editor_waits++;
  if(PC==editor_base+NCEDIT_MESSAGE_KEY||PC==editor_base+NCEDIT_DIALOG_KEY||PC==editor_base+NCEDIT_EXIT_KEY||PC==editor_base+NCEDIT_EDITOR_PENDING_KEY)editor_boundary=PC-editor_base;
  if(inject_clip_read==1&&PC==editor_base+NCEDIT_BLOCK_PASTE_READ&&eread(NCEDIT_BLOCK_STATE+56)<eread(NCEDIT_BLOCK_STATE+80)){runtime_r1=0x20;inject_clip_read=2;}
  if(inject_clip_read==2&&PC==editor_base+NCEDIT_EDITOR_ERROR){runtime_r1=0;inject_clip_read=3;}
  if(inject_cancel_paste==1&&PC==editor_base+NCEDIT_BLOCK_PASTE_READ){KBDKeyDown(1);inject_cancel_paste=2;}
  if(inject_cancel_save==1&&PC==editor_base+NCEDIT_SAVE_WRITE){KBDKeyDown(1);inject_cancel_save=2;}
  if((inject_cancel_save==2||inject_cancel_paste==2)&&PC==editor_base+NCEDIT_EDITOR_ERROR&&A==255)KBDKeyUpCode(1);
  if(inject_save_fault==1&&PC==editor_base+NCEDIT_SAVE_WRITE&&ram_word(editor_base+NCEDIT_SAVE_DONE+2)>=512){runtime_r1=0x20;inject_save_fault=2;}
  if(inject_save_fault==2&&PC==editor_base+NCEDIT_SAVE_FAIL){runtime_r1=0;inject_save_fault=3;}
  if(inject_apply_fault==1&&PC==editor_base+NCEDIT_DELETE_MORE&&ram_word(editor_base+NCEDIT_REMOVE_LEFT+2)<1000){runtime_r1=0x20;inject_apply_fault=2;}
  if(inject_read_fault==1&&PC==editor_base+NCEDIT_EDITOR_ERROR){runtime_r1=0;inject_read_fault=2;}
 }
 if(!editor_active)observe();
 if(nc_base&&PC==nc_base+NC_RELOAD){editor_active=0;observe();}
 if(!editor_active&&PC>=0x100&&PC<0xbc00&&MC6800GetCpuRam()[PC]==editor_sig[0]&&matches(PC,editor_sig,editor_mask)){
  editor_base=PC;editor_active=1;editor_entries++;
 }
}
static unsigned editor_call(unsigned label,unsigned arg){
 unsigned pc0=PC,sp0=SP,a0=A,b0=B,x0=X,h0=h,i0=i,n0=n,z0=z,v0=v,c0=c,page0=page;
 unsigned char*r=MC6800GetCpuRam();unsigned target=editor_base+label;
 r[0x210]=0xbd;r[0x211]=target>>8;r[0x212]=target;r[0x213]=1;PC=0x210;A=arg;
 uint64_t end=virtual_cycles+100000000;
 do{until(virtual_cycles+1);if(virtual_cycles>=end){fprintf(stderr,"editor call label=%04x base=%04x at=%04x slot=%u file=%u count=%u leafptr=%04x entry=%04x\n",label,editor_base,PC-editor_base,r[editor_base+NCEDIT_CACHE_SLOT],r[editor_base+NCEDIT_IO_FILE],r[editor_base+NCEDIT_SPLIT_COUNT],ram_word(editor_base+NCEDIT_LEAF_PTR),ram_word(editor_base+NCEDIT_ENTRY_PTR));require(0,"editor subroutine returns");}}while(PC!=0x213);
 unsigned result=A;result_b=B;result_x=X;
 require(SP==sp0&&page==page0,"editor subroutine preserves stack and bank mapping");
 PC=pc0;A=a0;B=b0;X=x0;h=h0;i=i0;n=n0;z=z0;v=v0;c=c0;return result;
}
static void eword(unsigned label,uint32_t value){unsigned char*r=MC6800GetCpuRam()+editor_base+label;for(unsigned k=0;k<4;k++)r[k]=value>>(24-8*k);}
static uint32_t eread(unsigned label){unsigned char*r=MC6800GetCpuRam()+editor_base+label;return (uint32_t)r[0]<<24|(uint32_t)r[1]<<16|r[2]<<8|r[3];}
static void editor_pixel(unsigned col,unsigned row,unsigned code,unsigned foreground,unsigned background){
 unsigned char*r=MC6800GetCpuRam();unsigned mode=r[editor_base+NCEDIT_MODE],bits=mode==2?2:1,unit=8/bits,base=ram_word(editor_base+NCEDIT_SCREEN_BASE);
 for(unsigned y=0;y<8;y++)for(unsigned x=0;x<8;x++){
  unsigned at=base+(row*8+y)/8*(model_a?640:320)+((col*8+x)/unit)*8+y;
  unsigned pixel=(r[at]>>(8-bits*((col*8+x)%unit+1)))&((1u<<bits)-1),dot=(physical[0x11800+code*8+y]>>(7-x))&1;
  require(pixel==(dot?foreground:background),"editor native pixels match the ROM glyph and focus colours");
 }
}
static void editor_check_caret(void){
 unsigned char*r=MC6800GetCpuRam();unsigned col=r[editor_base+NCEDIT_CARET_X],row=r[editor_base+NCEDIT_CARET_Y],mode=r[editor_base+NCEDIT_MODE];
 if(!(col<r[editor_base+NCEDIT_COLUMNS]&&row>=1&&row<=r[editor_base+NCEDIT_BODY_ROWS]))fprintf(stderr,"CURSOR base=%04x cols=%u rows=%u caret=%u,%u cursorrow=%u screenptr=%04x mode=%u SP=%04x himem=%04x\n",editor_base,r[editor_base+NCEDIT_COLUMNS],r[editor_base+NCEDIT_BODY_ROWS],col,row,r[editor_base+NCEDIT_CURSOR_ROW],ram_word(editor_base+NCEDIT_SCREEN_CHARS),mode,SP,ram_word(0xee1e));
 require(col<r[editor_base+NCEDIT_COLUMNS]&&row>=1&&row<=r[editor_base+NCEDIT_BODY_ROWS],"editor caret remains inside its visible text area");
 if(mode&3){require(crtc[14]*256+crtc[15]==0x3fff,"graphics editor parks the hardware cursor");unsigned selected=r[editor_base+NCEDIT_BLOCK_STATE+36]==3;editor_pixel(col,row,r[editor_base+NCEDIT_CARET_CHAR],selected?(mode==2?3:1):0,selected?0:1);}
 else{unsigned step=model_a&&!mode?2:1,expected=ram_word(editor_base+NCEDIT_SCREEN_BASE)+row*crtc[1]+col*step+(step==2)+(model_a?0:2);require(crtc[14]*256+crtc[15]==expected,"text editor caret follows the document cursor");}
}
static void editor_wait(void){
 uint64_t end=virtual_cycles+3000000000ull;
 do{until(virtual_cycles+(mouse_ui_enabled?1:1009));if(editor_base&&editor_active&&PC==editor_base+NCEDIT_MOUSE_KEY_POLL&&MC6800GetCpuRam()[editor_base+NCEDIT_MOUSE_CONTEXT]==1){editor_check_caret();return;}}while(virtual_cycles<end);
 fprintf(stderr,"editor not ready base=%04x active=%u entries=%u loader=%04x req=%u error=%u\n",editor_base,editor_active,editor_entries,loader_base,MC6800GetCpuRam()[nc_base+NC_STATE+NC_S_REQUEST],MC6800GetCpuRam()[nc_base+NC_STATE+NC_S_ERROR]);require(0,"F4 loads the editor and reaches input");
}
static void editor_input(unsigned after){
 uint64_t end=virtual_cycles+3000000000ull;
 do{until(virtual_cycles+(mouse_ui_enabled?1:1009));if(editor_waits>after&&PC==editor_base+NCEDIT_MOUSE_KEY_POLL&&MC6800GetCpuRam()[editor_base+NCEDIT_MOUSE_CONTEXT]==1){editor_check_caret();return;}}while(virtual_cycles<end);require(0,"editor key returns to its input field");
}
static void editor_key(unsigned scan){unsigned after=editor_waits;key(scan);editor_input(after);}
static void editor_profile_key(unsigned scan,const char*name){
 unsigned reads=sd_reads,writes=sd_writes;measure_key=1;key_started=key_cycles=0;editor_key(scan);measure_key=0;
 printf("NC EDIT PERF %s: %llu cycles, %u reads/%u writes\n",name,(unsigned long long)key_cycles,sd_reads-reads,sd_writes-writes);fflush(stdout);
 require(key_cycles&&key_cycles<200000,"cached editor input stays below a 200 ms budget at 1 MHz");
 require(sd_reads==reads&&sd_writes==writes,"cached editor input has no disk I/O");
}
static void editor_ctrl(unsigned scan){KBDModKeyDown(1);editor_key(scan);KBDModKeyUp(1);}
static void editor_shift(unsigned scan){KBDModKeyDown(2);editor_key(scan);KBDModKeyUp(2);}
static void clipboard_absent(const char*path){
 unsigned char*r=MC6800GetCpuRam(),saved[512];memcpy(saved,r+0x3000,sizeof saved);strcpy((char*)r+0x3100,path);word_at(0x3000,0x3100);word_at(0x3002,0);require(invoke(0x4a,1,0,0x3000)==11,"supervisor removes its session clipboard on F10");memcpy(r+0x3000,saved,sizeof saved);
}
static void editor_snapshot(unsigned video,const char*name){
 unsigned char*r=MC6800GetCpuRam();char path[180];snprintf(path,sizeof path,"build/nc/screen-editor-%s-%u-%s.bin",model_a?"601a":"601",video,name);
 FILE*f=fopen(path,"wb");require(f&&fwrite(r,1,65536,f)==65536&&!fclose(f),"editor screenshot");
 snprintf(path,sizeof path,"build/nc/screen-editor-%s-%u-%s.txt",model_a?"601a":"601",video,name);
 f=fopen(path,"w");require(f!=NULL,"editor image metadata");fprintf(f,"%u %u %u %u %u %u %u\n",model_a,video,ram_word(editor_base+NCEDIT_SCREEN_BASE),crtc[1],crtc[14]*256+crtc[15],crtc[10],crtc[11]);fclose(f);
 f=fopen("build/nc/font.bin","wb");require(f&&fwrite(physical+0x11800,1,2048,f)==2048&&!fclose(f),"editor ROM font");
}
static void editor_modal(unsigned boundary){
 uint64_t end=virtual_cycles+1000000000ull;
 do{until(virtual_cycles+(mouse_ui_enabled?1:1009));if(editor_boundary==boundary&&PC==editor_base+NCEDIT_MOUSE_KEY_POLL)return;}while(virtual_cycles<end);require(0,"editor modal reaches keyboard focus");
}
static void raw_file_check(const char*name,const unsigned char*expected,unsigned size){
 unsigned start=le32(image+446+2*16+8)*512;const unsigned char*v=image+start;
 unsigned fat=le16(v+14)*512,root=(le16(v+14)+v[16]*le16(v+22))*512,data=root+((le16(v+17)*32+511)/512)*512;
 const unsigned char*entry=NULL;for(unsigned k=0;k<le16(v+17);k++){const unsigned char*e=v+root+k*32;if(!memcmp(e,name,11)){entry=e;break;}}
 require(entry&&le32(entry+28)==size,"original directory entry remains intact");unsigned cluster=le16(entry+26),offset=0;
 while(offset<size){unsigned take=v[13]*512;if(take>size-offset)take=size-offset;require(cluster>=2&&cluster<4085&&!memcmp(v+data+(cluster-2)*v[13]*512,expected+offset,take),"original file data survives failed publication");offset+=take;cluster=fat_next(v+fat,cluster);}
}
static void editor_check_banks(void){
 if(saved_ram_vector)invoke(0x2f,0xe5,saved_ram_page,saved_ram_vector);
 require(invoke(0xe5,0,0,0)==1&&result_b==expected_free_banks,"editor and panels release exactly their RAMMAN leases");
 if(reserved_bytes){
  for(unsigned k=3;k<reserved_bytes;k++)for(unsigned j=0;j<8192;j+=127)require(physical[0x22000+reserved_lease[k]*8192+j]==(unsigned char)(k^0x5a),"foreign RAMMAN banks remain untouched");
  memcpy(MC6800GetCpuRam()+0x9000,reserved_lease,reserved_bytes);require(!invoke(0xe5,2,0,0x9000),"release the fixture's foreign lease");
 }
}
static void insert_piece(unsigned pos,const unsigned char*data,unsigned length){
 uint32_t start=eread(NCEDIT_ADD_TAIL);
 for(unsigned k=0;k<length;k++)require(!editor_call(NCEDIT_ADD_BYTE,data[k]),"append inserted text");
 eword(NCEDIT_WHERE,pos);eword(NCEDIT_INSERT_OFF,start);eword(NCEDIT_INSERT_LEN,length);
 require(!editor_call(NCEDIT_DOC_INSERT,0),"insert a disk-backed piece");
}
static void delete_piece(unsigned pos,unsigned length){
 eword(NCEDIT_WHERE,pos);eword(NCEDIT_REMOVE_LEN,length);require(!editor_call(NCEDIT_DOC_DELETE,0),"delete disk-backed text");
}
static void check_document(const unsigned char*expected,unsigned size){
 require(eread(NCEDIT_DOC_SIZE)==size,"editor logical size matches the oracle");
 eword(NCEDIT_WHERE,0);require(!editor_call(NCEDIT_STREAM_INIT,0),"start document stream");
 for(unsigned k=0;k<size;k++){
  unsigned got=editor_call(NCEDIT_STREAM_NEXT,0);
  if(got!=expected[k]){fprintf(stderr,"editor byte %u got=%02x expected=%02x leaf=%u leafStart=%u index=%u remaining=%u\n",k,got,expected[k],eread(NCEDIT_LEAF_ID),eread(NCEDIT_LEAF_START),MC6800GetCpuRam()[editor_base+NCEDIT_PIECE_INDEX],eread(NCEDIT_STREAM_REMAINING));require(0,"stream matches edited document");}
 }
}
static void mouse_editor_event(unsigned col,unsigned row,unsigned buttons){
 unsigned cols=MC6800GetCpuRam()[editor_base+NCEDIT_COLUMNS];
 mouse_ui_place(editor_base,NCEDIT_MOUSE_PRESENT,NCEDIT_MOUSE_X,NCEDIT_MOUSE_Y,col,row,cols,buttons);
 uint64_t end=virtual_cycles+200000000;
 // Sample every instruction: a fixed 1009-cycle stride can lock to the
 // mouse-enabled polling loop and miss this boundary indefinitely.
 do{until(virtual_cycles+1);if(!mouse_ui_count&&PC==editor_base+NCEDIT_MOUSE_KEY_POLL)return;}while(virtual_cycles<end);
 fprintf(stderr,"mouse input failed target=%u,%u buttons=%u base=%04x PCoff=%04x context=%u phase=%u fifo=%u last=%02x cursor=%u selection=%u\n",col,row,buttons,editor_base,(PC-editor_base)&65535,MC6800GetCpuRam()[editor_base+NCEDIT_MOUSE_CONTEXT],MC6800GetCpuRam()[editor_base+NCEDIT_MOUSE_PHASE],mouse_ui_count,MC6800GetCpuRam()[editor_base+NCEDIT_LAST_KEY],eread(NCEDIT_E_CURSOR),MC6800GetCpuRam()[editor_base+NCEDIT_BLOCK_STATE+24]);
 require(0,"editor mouse event returns to input");
}
static void mouse_editor_tests(unsigned original_sp,unsigned original_himem){
 unsigned char*r=MC6800GetCpuRam();
 mouse_editor_event(5,1,1);
 require(eread(NCEDIT_E_CURSOR)==1&&eread(NCEDIT_E_COLUMN)==1,"mouse click inside a tab chooses the byte before that tab");
 mouse_editor_event(5,1,0);mouse_editor_event(8,1,1);
 require(eread(NCEDIT_E_CURSOR)==2&&eread(NCEDIT_E_COLUMN)==8,"mouse click after a tab uses visual columns");
 mouse_editor_event(8,1,0);mouse_editor_event(0,1,1);mouse_editor_event(9,1,1);mouse_editor_event(9,1,0);
 require(r[editor_base+NCEDIT_BLOCK_STATE+24]&&eread(NCEDIT_BLOCK_STATE+8)==0&&eread(NCEDIT_BLOCK_STATE+12)==3,"mouse drag selects the exact byte interval across a tab");
 editor_ctrl(0x2e);
 char clip[80];strcpy(clip,(char*)r+nc_base+NC_STATE+NC_S_CLIP_PATH);require(clip[0],"mouse selection can use the session clipboard");
 file_check(clip,(const unsigned char*)"A\tB",3);
 mouse_editor_event(0,2,1);mouse_editor_event(0,2,0);
 require(eread(NCEDIT_E_CURSOR)==4&&!r[editor_base+NCEDIT_BLOCK_STATE+24],"a new mouse click clears the previous selection and moves to the next logical line");
 unsigned at=eread(NCEDIT_E_CURSOR),row=r[editor_base+NCEDIT_CURSOR_ROW];
 mouse_editor_event(4,20,1);mouse_editor_event(4,20,0);
 require(eread(NCEDIT_E_CURSOR)==at&&r[editor_base+NCEDIT_CURSOR_ROW]==row,"clicking below EOF preserves the document cursor");
 unsigned bx=B,xx=X,cols=r[editor_base+NCEDIT_COLUMNS];
 require(editor_call(NCEDIT_MOUSE_CANCEL,0)==255&&result_b==bx&&result_x==xx,"nonblocking mouse poll preserves BIOS B/X contract");
 nc_ps2_key(0x1e,0);
 require(editor_call(NCEDIT_MOUSE_WAIT,8)=='a'&&result_b==bx&&result_x==xx,"mouse-aware key wait preserves BIOS B/X contract");
 nc_ps2_key(0x1e,1);
 unsigned wl=r[editor_base+NCEDIT_WINDOW_LEFT],wi=r[editor_base+NCEDIT_WINDOW_INNER];
 r[editor_base+NCEDIT_WINDOW_LEFT]=2;r[editor_base+NCEDIT_WINDOW_INNER]=cols-4;
 for(unsigned enabled=0;enabled<2;enabled++){
  mouse_ui_place(editor_base,NCEDIT_MOUSE_PRESENT,NCEDIT_MOUSE_X,NCEDIT_MOUSE_Y,cols/2,16,cols,1);
  require(editor_call(NCEDIT_MOUSE_CANCEL,enabled)==(enabled?27:255),"left-click cancels only a visible progress window");
  mouse_ui_place(editor_base,NCEDIT_MOUSE_PRESENT,NCEDIT_MOUSE_X,NCEDIT_MOUSE_Y,cols/2,16,cols,0);
  require(editor_call(NCEDIT_MOUSE_CANCEL,0)==255,"busy poll consumes release without cancelling");
 }
 mouse_ui_place(editor_base,NCEDIT_MOUSE_PRESENT,NCEDIT_MOUSE_X,NCEDIT_MOUSE_Y,3,1,cols,2);
 require(editor_call(NCEDIT_MOUSE_CANCEL,0)==27,"right-click cancels a long scan without an input dialog");
 mouse_ui_place(editor_base,NCEDIT_MOUSE_PRESENT,NCEDIT_MOUSE_X,NCEDIT_MOUSE_Y,3,1,cols,0);
 require(editor_call(NCEDIT_MOUSE_CANCEL,0)==255,"busy poll releases right button");
 r[editor_base+NCEDIT_WINDOW_LEFT]=wl;r[editor_base+NCEDIT_WINDOW_INNER]=wi;
 unsigned after=wait_entries;key(0x44);panels(after);key(0x44);prompt_wait();editor_check_banks();
 require(SP==original_sp&&ram_word(0xee1e)==original_himem&&!mouse_ui_lines&&!(mouse_ui_index&128),"mouse editor and panels release pins, pointer, allocations and stack");
 clipboard_absent(clip);
 puts("PASS NC editor mouse: tab-aware click, exact drag selection, byte-exact Copy, new-click reset, EOF bounds, clipboard/focus/heap cleanup");
}
int main(int argc,char**argv){
 if(argc!=6)return 2;model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");unsigned video=atoi(argv[4]);
 unsigned is_long=!strncmp(argv[5],"long",4);
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load(argv[1],&image_size);committed=1;native_step_hook=raw_observe;MC6800Init();MC6800Reset();until(60000000);key(0x1c);key(0x1c);prompt_wait();
 if(!strcmp(argv[5],"ui"))command("md b:work");
 if(!strcmp(argv[5],"readonly"))require(!invoke(0xe1,3,3,0)&&!invoke(0xe1,13,3,0)&&result_b==1,"remount the source B volume read-only");
 unsigned original_sp=SP,original_himem=ram_word(0xee1e);
 invoke(0x2e,0xe5,0,0);saved_ram_vector=result_x;saved_ram_page=result_b;
 require(invoke(0xe5,0,0,0)==1,"editor fixture RAMMAN ABI");expected_free_banks=result_b;
 if(!strcmp(argv[5],"missing")||strstr(argv[5],"-missing")){invoke(0x2f,0xe5,0,0);}
 if(!strcmp(argv[5],"busy")||!strcmp(argv[5],"offset")){
  unsigned count=!strcmp(argv[5],"offset")?7:expected_free_banks;
  require(!invoke(0xe5,1,count,0x9000),"reserve banks for another owner");reserved_bytes=count+3;memcpy(reserved_lease,MC6800GetCpuRam()+0x9000,reserved_bytes);expected_free_banks-=count;
  for(unsigned k=3;k<reserved_bytes;k++)memset(physical+0x22000+reserved_lease[k]*8192,k^0x5a,8192);
 }
 if(model_a&&(video==0||video==4))invoke(0x12,video,video==0?0x71:0,0);
 signature("build/nc/NC.PGM",nc_sig,nc_mask);signature("build/nc/NCMAIN.PGM",core_sig,core_mask);signature("build/nc/NCPROBE.PGM",probe_sig,probe_mask);signature("build/nc/NCEDIT.core.PGM",editor_sig,editor_mask);signature("build/nc/NCEDIT.PGM",loader_sig,loader_mask);
 native_step_hook=editor_observe;watch_resets=1;
 type((video&3)?(video==2?"b:ncgraf2":"b:ncgraf3"):"b:nc");key(0x1c);panels(0);drive_b();select_name("HELLO   ");
 if(!strcmp(argv[5],"ui")){
  unsigned settings_after=wait_entries;open_settings();type("w");modal_wait(NCMAIN_DIALOG_KEY);type("b:\\work");key(0x1c);modal_wait(NCMAIN_SETTINGS_KEY);key(1);panels(settings_after);
  require(!MC6800GetCpuRam()[nc_base+NC_STATE+NC_S_WORKDIR],"Cancel discards the staged work directory");
  settings_after=wait_entries;open_settings();type("w");modal_wait(NCMAIN_DIALOG_KEY);type("b:\\work");key(0x1c);modal_wait(NCMAIN_SETTINGS_KEY);modal_key(0x0f,NCMAIN_SETTINGS_KEY);key(0x1c);panels(settings_after);
  require(!strcmp((char*)MC6800GetCpuRam()+nc_base+NC_STATE+NC_S_WORKDIR,"B:\\WORK\\"),"Settings applies the normalized editor work directory");
 }
 const char*selected=(!strcmp(argv[5],"block")||!strcmp(argv[5],"block-missing")||!strcmp(argv[5],"keys"))?"EMPTY   ":(!strcmp(argv[5],"large")||!strncmp(argv[5],"block-large",11))?"HUGE    ":is_long?"LONG    ":(!strcmp(argv[5],"raw")||!strcmp(argv[5],"mouse"))?"RAW     ":!strcmp(argv[5],"edge")?"EDGE    ":!strcmp(argv[5],"empty")?"EMPTY   ":"HELLO   ";
 select_name(selected);
 if(!strcmp(argv[5],"full"))strcpy((char*)MC6800GetCpuRam()+nc_base+NC_STATE+NC_S_WORKDIR,"A:\\");
 if(!strcmp(argv[5],"sort-return")){
  unsigned after=wait_entries;open_settings();type("s");key(0x1c);panels(after);select_name("HELLO   ");
 }
 unsigned source_size=29+26*100;unsigned char expected[65536];
 const char*first="Pyldin Commander text viewer\r\n";source_size=strlen(first);memcpy(expected,first,source_size);
 for(unsigned k=0;k<100;k++){memcpy(expected+source_size,"Line of text for paging.\r\n",26);source_size+=26;}
 unsigned char original[3000];unsigned original_size=source_size;memcpy(original,expected,original_size);
 unsigned writes=sd_writes;
 if(!strcmp(argv[5],"missing-editor")||!strcmp(argv[5],"bad-editor")){
  unsigned after=wait_entries;key(0x3e);until(virtual_cycles+15000000);
  require(!editor_entries&&(contains("NC:")||contains("NC editor:")),"missing/damaged editor reports a readable error");
  key(1);panels(after);require(core_entries==2,"loader error reloads the panels");key(0x44);prompt_wait();editor_check_banks();
  require(SP==original_sp&&ram_word(0xee1e)==original_himem,"loader errors release ordinary memory");
  printf("PASS NC editor %s: error acknowledgement, panel reload, clean stack/heap/banks\n",argv[5]);return 0;
 }
 key(0x3e);editor_wait();
 require(MC6800GetCpuRam()[editor_base+NCEDIT_MODE]==video&&MC6800GetCpuRam()[0xed12]==video,"F4 preserves the panel video mode across native child exit and streamed loading");
 editor_snapshot(video,"open");
 require(editor_entries==1&&MC6800GetCpuRam()[editor_base+NCEDIT_CACHE_LEASED]==(strcmp(argv[5],"missing")&&strcmp(argv[5],"busy")&&!strstr(argv[5],"-missing")),"editor optional RAMMAN cache");
 if(!strcmp(argv[5],"mouse")){
  mouse_editor_tests(original_sp,original_himem);return 0;
 }
 if(!strcmp(argv[5],"readonly")){
  unsigned char*r=MC6800GetCpuRam();unsigned ew=editor_waits;editor_boundary=0;key(0x1e);editor_modal(NCEDIT_MESSAGE_KEY);
  require(!r[editor_base+NCEDIT_MODIFIED]&&sd_writes==writes,"read-only default workspace refuses editing without changing the source");key(0x1c);editor_input(ew);
  require(eread(NCEDIT_DOC_SIZE)==original_size,"failed workspace creation retains the document");
  unsigned after=wait_entries;key(1);panels(after);strcpy((char*)r+nc_base+NC_STATE+NC_S_WORKDIR,"A:\\");key(0x3e);editor_wait();editor_key(0x1e);memmove(expected+1,expected,source_size);expected[0]='a';source_size++;
  ew=editor_waits;editor_boundary=0;key(0x3c);editor_modal(NCEDIT_MESSAGE_KEY);require(r[editor_base+NCEDIT_MODIFIED],"read-only Save retains edits in the alternate workspace");raw_file_check("HELLO   TXT",original,original_size);key(0x1c);editor_input(ew);
  ew=editor_waits;KBDModKeyDown(2);key(0x3c);KBDModKeyUp(2);editor_modal(NCEDIT_DIALOG_KEY);key(0x47);unsigned len=strlen((char*)r+editor_base+NCEDIT_INPUT);for(unsigned k=0;k<len;k++)key(0x53);type("a:ncero.txt");key(0x1c);editor_input(ew);file_check("a:NCERO.TXT",expected,source_size);raw_file_check("HELLO   TXT",original,original_size);
  after=wait_entries;key(1);panels(after);key(0x44);prompt_wait();editor_check_banks();require(SP==original_sp&&ram_word(0xee1e)==original_himem,"read-only editor cleanup");
  puts("PASS NC editor read-only: lazy opening, refused default workspace, alternate work disk, original preserved, Save As to writable disk");return 0;
 }
 if(!strncmp(argv[5],"block-large",11)){
  unsigned char*r=MC6800GetCpuRam();unsigned size=64*32768+18;unsigned char*data=malloc(size);require(data!=NULL,"large clipboard oracle");for(unsigned k=0;k<32768;k++)memcpy(data+64*k,"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz\r\n",64);memcpy(data+64*32768,"UNIQUE LAST LINE\r\n",18);
  editor_stage="copy";editor_ctrl(0x1e);editor_ctrl(0x2e);require(!r[editor_base+NCEDIT_WORK_READY]&&!r[editor_base+NCEDIT_MODIFIED],"Copy All does not create a document editing journal");char clip[80];strcpy(clip,(char*)r+nc_base+NC_STATE+NC_S_CLIP_PATH);file_check(clip,data,size);
  unsigned after=wait_entries;key(0x44);panels(after);select_name("EMPTY   ");key(0x3e);editor_wait();editor_stage="paste";editor_ctrl(0x2f);require(eread(NCEDIT_DOC_SIZE)==size,"Paste a clipboard larger than 2 MiB into another file");editor_stage="undo";editor_ctrl(0x2c);require(!eread(NCEDIT_DOC_SIZE),"one Undo removes the whole 2 MiB Paste");editor_stage="redo";editor_ctrl(0x15);require(eread(NCEDIT_DOC_SIZE)==size,"one Redo restores the whole 2 MiB Paste");editor_stage="save";editor_key(0x3c);file_check("b:EMPTY.TXT",data,size);
  after=wait_entries;key(1);panels(after);key(0x44);prompt_wait();clipboard_absent(clip);editor_check_banks();require(SP==original_sp&&ram_word(0xee1e)==original_himem,"large cross-file clipboard cleanup");free(data);printf("PASS NC editor large clipboard %s: >2 MiB Copy/Paste across F4, one-record Undo/Redo, byte-exact Save, cleanup\n",argv[5]);return 0;
 }
 if(!strcmp(argv[5],"block-faults")){
  unsigned char*r=MC6800GetCpuRam(),data[6000];char clip[80];editor_ctrl(0x1e);editor_ctrl(0x2e);strcpy(clip,(char*)r+nc_base+NC_STATE+NC_S_CLIP_PATH);file_check(clip,original,original_size);
  unsigned ew=editor_waits;editor_boundary=0;inject_save_fault=1;KBDModKeyDown(1);key(0x2e);KBDModKeyUp(1);editor_modal(NCEDIT_MESSAGE_KEY);require(inject_save_fault==3&&!r[editor_base+NCEDIT_MODIFIED]&&!strcmp(clip,(char*)r+nc_base+NC_STATE+NC_S_CLIP_PATH),"failed Copy keeps the old clipboard and document");key(0x1c);editor_input(ew);file_check(clip,original,original_size);
  inject_cancel_save=1;editor_ctrl(0x2e);KBDKeyUpCode(1);require(inject_cancel_save==2&&!strcmp(clip,(char*)r+nc_base+NC_STATE+NC_S_CLIP_PATH),"cancelled Copy keeps the old clipboard");editor_ctrl(0x47);
  ew=editor_waits;editor_boundary=0;inject_clip_read=1;KBDModKeyDown(1);key(0x2f);KBDModKeyUp(1);editor_modal(NCEDIT_MESSAGE_KEY);require(inject_clip_read==3&&!r[editor_base+NCEDIT_MODIFIED]&&eread(NCEDIT_DOC_SIZE)==original_size,"late clipboard read failure applies no Paste");key(0x1c);editor_input(ew);check_document(original,original_size);
  inject_cancel_paste=1;editor_ctrl(0x2f);KBDKeyUpCode(1);require(inject_cancel_paste==2&&!r[editor_base+NCEDIT_MODIFIED]&&eread(NCEDIT_DOC_SIZE)==original_size,"cancelled Paste applies no text");
  editor_ctrl(0x2f);memcpy(data,original,original_size);memcpy(data+original_size,original,original_size);editor_key(0x3c);file_check("b:HELLO.TXT",data,2*original_size);
  unsigned after=wait_entries;key(1);panels(after);key(0x44);prompt_wait();clipboard_absent(clip);editor_check_banks();require(SP==original_sp&&ram_word(0xee1e)==original_himem,"clipboard faults release handles and memory");puts("PASS NC editor clipboard faults: old clipboard survives failed/cancelled Copy, failed/cancelled Paste leaves document unchanged, retry/Save and cleanup");return 0;
 }
 if(!strcmp(argv[5],"block")||!strcmp(argv[5],"block-missing")){
  unsigned char*r=MC6800GetCpuRam(),data[8192];unsigned st=editor_base+NCEDIT_BLOCK_STATE;char clip[80];
  editor_key(0x1e);editor_key(0x30);editor_key(0x2e);editor_key(0x1c);editor_key(0x20);editor_key(0x12);editor_key(0x21);editor_key(0x1c);editor_key(0x22);editor_key(0x23);editor_key(0x17);editor_key(0x3c);
  memcpy(data,"abc\r\ndef\r\nghi",13);file_check("b:EMPTY.TXT",data,13);
  editor_shift(0x4b);require(eread(NCEDIT_E_CURSOR)==12&&eread(NCEDIT_BLOCK_STATE+8)==12&&eread(NCEDIT_BLOCK_STATE+12)==13,"Shift+Left selects one physical character instead of native Home");
  editor_shift(0x4b);require(eread(NCEDIT_BLOCK_STATE+8)==11,"Shift selection extends");editor_shift(0x4d);require(eread(NCEDIT_BLOCK_STATE+8)==12,"Shift selection shrinks");
  editor_ctrl(0x47);editor_key(0x4d);editor_shift(0x4b);editor_shift(0x4d);editor_shift(0x4d);require(eread(NCEDIT_BLOCK_STATE+8)==1&&eread(NCEDIT_BLOCK_STATE+12)==2,"selection reverses around its anchor");
  editor_ctrl(0x47);editor_key(0x4d);editor_shift(0x50);require(eread(NCEDIT_E_CURSOR)==6&&r[st+24],"Shift+Down selects across CRLF");
  require(r[editor_base+NCEDIT_BLOCK_MARKS]==1&&r[editor_base+NCEDIT_BLOCK_MARKS+1]==r[editor_base+NCEDIT_COLUMNS]&&r[editor_base+NCEDIT_BLOCK_MARKS+2]==0&&r[editor_base+NCEDIT_BLOCK_MARKS+3]==1,"multiline selection has exact visible row intervals");
  editor_snapshot(video,"selection");editor_ctrl(0x2e);strcpy(clip,(char*)r+nc_base+NC_STATE+NC_S_CLIP_PATH);require(clip[0]&&!r[editor_base+NCEDIT_MODIFIED]&&eread(NCEDIT_DOC_SIZE)==13,"Copy publishes a disk clipboard without modifying text");file_check(clip,(unsigned char*)"bc\r\nd",5);
  editor_key(0x4d);require(!r[st+24],"ordinary navigation clears the selection");editor_ctrl(0x4f);editor_ctrl(0x2f);memcpy(data+13,"bc\r\nd",5);require(eread(NCEDIT_DOC_SIZE)==18,"Paste inserts the copied multiline block");check_document(data,18);editor_ctrl(0x2c);require(eread(NCEDIT_DOC_SIZE)==13,"Paste is one Undo record");editor_ctrl(0x15);check_document(data,18);editor_ctrl(0x2c);
  editor_ctrl(0x47);editor_key(0x3d);editor_key(0x4d);editor_key(0x4d);editor_key(0x4d);editor_key(0x3d);require(r[st+24]&&!r[st+25],"F3 freezes a block selected with ordinary arrows");editor_ctrl(0x2d);require(eread(NCEDIT_DOC_SIZE)==10,"Cut removes the selected bytes");check_document((unsigned char*)"\r\ndef\r\nghi",10);clipboard_absent(clip);strcpy(clip,(char*)r+nc_base+NC_STATE+NC_S_CLIP_PATH);file_check(clip,(unsigned char*)"abc",3);editor_ctrl(0x2c);check_document(data,13);
  editor_ctrl(0x47);editor_ctrl(0x2f);check_document((unsigned char*)"abcabc\r\ndef\r\nghi",16);editor_ctrl(0x2c);editor_ctrl(0x1e);editor_key(0x2d);check_document((unsigned char*)"x",1);editor_ctrl(0x2c);check_document(data,13);
  editor_ctrl(0x1e);editor_ctrl(0x2d);require(!eread(NCEDIT_DOC_SIZE),"Cut All can leave an empty document");editor_ctrl(0x2c);check_document(data,13);editor_ctrl(0x15);require(!eread(NCEDIT_DOC_SIZE),"Redo Cut All");editor_ctrl(0x2c);check_document(data,13);
  strcpy(clip,(char*)r+nc_base+NC_STATE+NC_S_CLIP_PATH);file_check(clip,data,13);
  unsigned after=wait_entries;editor_boundary=0;key(0x44);if(r[editor_base+NCEDIT_MODIFIED]){editor_modal(NCEDIT_EXIT_KEY);type("d");}panels(after);select_name("HELLO   ");key(0x3e);editor_wait();editor_ctrl(0x47);editor_ctrl(0x2f);
  memmove(data+13,original,original_size);editor_key(0x3c);file_check("b:HELLO.TXT",data,13+original_size);editor_ctrl(0x2c);require(eread(NCEDIT_DOC_SIZE)==original_size,"Undo a cross-file Paste after Save");editor_ctrl(0x15);editor_key(0x3c);
  after=wait_entries;key(1);panels(after);key(0x44);prompt_wait();clipboard_absent(clip);editor_check_banks();require(SP==original_sp&&ram_word(0xee1e)==original_himem,"selection and cross-file clipboard release memory");
  printf("PASS NC editor block %s/%s mode %u: Shift/F3 selection, reverse/multiline ranges, Copy/Cut/Paste/replace/All, grouped Undo/Redo, clipboard across F4, Save and cleanup\n",argv[2],argv[3],video);return 0;
 }
 if(!strcmp(argv[5],"keys")){
  unsigned char data[256];unsigned char*r=MC6800GetCpuRam();editor_key(0x1e);editor_key(0x30);editor_key(0x2e);
  unsigned ew=editor_waits;editor_boundary=0;key(0x44);editor_modal(NCEDIT_EXIT_KEY);require(r[editor_base+NCEDIT_EXIT_FOCUS]==2,"unsaved exit defaults to Cancel");key(0x1c);editor_input(ew);require(r[editor_base+NCEDIT_MODIFIED],"Cancel keeps the editor open");
  editor_key(0x4b);editor_key(0x52);editor_key(0x2c);require(eread(NCEDIT_DOC_SIZE)==3,"Insert switches to overwrite mode");editor_key(0x52);editor_key(0x47);editor_key(0x53);editor_key(0x4d);editor_key(0x0e);editor_key(0x0f);
  require(eread(NCEDIT_E_COLUMN)==8&&eread(NCEDIT_E_CURSOR)==1,"Tab remains one byte and advances to a tab stop");editor_key(0x4d);editor_key(0x47);editor_key(0x4d);editor_key(0x4b);require(!eread(NCEDIT_E_COLUMN)&&!eread(NCEDIT_E_CURSOR),"Left across a tab restores its exact column");
  editor_key(0x4f);editor_key(0x1c);editor_key(0x14);editor_key(0x1e);editor_key(0x17);editor_key(0x26);editor_key(0x48);require(!eread(NCEDIT_E_COLUMN),"Up chooses the byte before a tab covering the desired column");editor_key(0x50);require(eread(NCEDIT_E_COLUMN)==4,"Down retains the desired column across a tabbed line");
  editor_key(0x51);KBDModKeyDown(1);editor_key(0x47);KBDModKeyUp(1);editor_key(0x49);KBDModKeyDown(1);editor_key(0x4f);KBDModKeyUp(1);
  for(unsigned k=0;k<100;k++)editor_key(0x2d);require(eread(NCEDIT_DOC_SIZE)==108,"horizontal scrolling accepts a line wider than the screen");
  for(unsigned k=0;k<90;k++)editor_key(0x4b);require(eread(NCEDIT_E_COLUMN)==14,"horizontal rewind retains exact positions");
  KBDModKeyDown(1);editor_key(0x2c);KBDModKeyUp(1);require(eread(NCEDIT_DOC_SIZE)==8,"grouped undo after horizontal scrolling");KBDModKeyDown(1);editor_key(0x15);KBDModKeyUp(1);
  memcpy(data,"\tz\r\ntail",8);memset(data+8,'x',100);editor_key(0x3c);file_check("b:EMPTY.TXT",data,108);
  editor_key(0x1e);data[108]='a';inject_cancel_save=1;editor_key(0x3c);KBDKeyUpCode(1);require(inject_cancel_save==2&&r[editor_base+NCEDIT_MODIFIED],"Esc cancels Save before publication");raw_file_check("EMPTY   TXT",data,108);editor_key(0x3c);file_check("b:EMPTY.TXT",data,109);
  unsigned after=wait_entries;key(1);panels(after);key(0x44);prompt_wait();editor_check_banks();require(SP==original_sp&&ram_word(0xee1e)==original_himem,"all editor key paths release memory");
  puts("PASS NC editor keys: overwrite, Delete/Backspace/Tab, arrows/Home/End/pages, horizontal scrolling, Undo/Redo, Cancel exit and Cancel Save");return 0;
 }
 if(!strcmp(argv[5],"sort-return")){
  KBDModKeyDown(1);editor_key(0x4f);KBDModKeyUp(1);for(unsigned k=0;k<1000;k++)editor_key(0x1e);
  editor_key(0x3c);unsigned after=wait_entries;key(1);panels(after);
  require(!memcmp(catalog()+MC6800GetCpuRam()[core_base+NCMAIN_PCUR]*NCMAIN_ENTRY_SIZE,"HELLO   TXT",11),"return from F4 selects the edited file beyond the previous sorted cache window");
  require(MC6800GetCpuRam()[core_base+NCMAIN_PTOP]==1,"inclusive editor pivot keeps the selected file visible");
  key(0x44);prompt_wait();editor_check_banks();require(SP==original_sp&&ram_word(0xee1e)==original_himem,"sorted editor return releases all ordinary memory");
  puts("PASS NC editor sort return: file moves beyond 180 entries after Save and remains selected");return 0;
 }
 if(!strcmp(argv[5],"large")||is_long){
  unsigned char*r=MC6800GetCpuRam();unsigned size=!strcmp(argv[5],"large")?64*32768+18:140006;
  unsigned char*data=malloc(size+4096);require(data!=NULL,"large document oracle");
  if(!strcmp(argv[5],"large")){
   for(unsigned k=0;k<32768;k++)memcpy(data+64*k,"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz\r\n",64);
   memcpy(data+64*32768,"UNIQUE LAST LINE\r\n",18);
  }else{memset(data,'a',65530);data[65530]=9;memset(data+65531,'b',74469);memcpy(data+140000,"\r\ntail",6);}
  require(eread(NCEDIT_DOC_SIZE)==size&&sd_writes==writes,"large editor opening retains a 32-bit size without temporary writes");
  if(is_long){
   editor_key(0x4f);require(eread(NCEDIT_E_CURSOR)==140000&&eread(NCEDIT_E_COLUMN)==140005,"End reaches a line larger than 64 KiB with exact tab columns");
  }else{KBDModKeyDown(1);editor_key(0x4f);KBDModKeyUp(1);require(eread(NCEDIT_E_CURSOR)==size,"Ctrl+End reaches beyond 2 MiB");}
  unsigned pos=eread(NCEDIT_E_CURSOR);editor_key(0x1e);memmove(data+pos+1,data+pos,size-pos);data[pos]='a';size++;
  unsigned reads=sd_reads,written=sd_writes;
  unsigned constrained=!r[editor_base+NCEDIT_CACHE_LEASED]&&r[editor_base+NCEDIT_CACHE_COUNT]==3;
  if(constrained)editor_key(0x30);else editor_profile_key(0x30,"far-offset typing");
  memmove(data+pos+2,data+pos+1,size-pos-1);data[pos+1]='b';size++;
  if(!constrained)require(sd_reads==reads&&sd_writes==written,"typing at a far offset remains entirely cached");
  unsigned operations=!strcmp(argv[5],"large")?1000:80;
  for(unsigned k=0;k<operations;k++){
   unsigned at=(k*7919u+65534u)%(size-2);r[editor_base+NCEDIT_GROUP_OPEN]=0;eword(NCEDIT_E_CURSOR,at);eword(NCEDIT_CHANGE_AT,at);
   r[editor_base+NCEDIT_CHANGE_DELETE]=1;r[editor_base+NCEDIT_CHANGE_ADD]=1;r[editor_base+NCEDIT_CHANGE_GROUP]=0;r[editor_base+NCEDIT_CHANGE_BYTES]='A'+k%26;
   require(!editor_call(NCEDIT_EDITOR_CHANGE,0),"fragmented edit at a 32-bit offset");data[at]='A'+k%26;
  }
  KBDModKeyDown(1);editor_key(0x47);KBDModKeyUp(1);
  uint64_t started=virtual_cycles;profile_save=1;editor_key(0x3c);profile_save=0;fprintf(stderr,"save cycles kernel=%llu stream=%llu arithmetic=%llu cache=%llu other=%llu\n",(unsigned long long)profile_bins[0],(unsigned long long)profile_bins[1],(unsigned long long)profile_bins[2],(unsigned long long)profile_bins[3],(unsigned long long)profile_bins[4]);fprintf(stderr,"NC editor save %u bytes: %llu CPU cycles\n",size,(unsigned long long)(virtual_cycles-started));
  file_check(!strcmp(argv[5],"large")?"b:HUGE.TXT":"b:LONG.TXT",data,size);
  editor_snapshot(video,argv[5]);unsigned after=wait_entries;key(1);panels(after);key(0x44);prompt_wait();
  require(SP==original_sp&&ram_word(0xee1e)==original_himem,"large editor releases code, cache and file handles");free(data);
  printf("PASS NC editor %s: %u bytes, %u disjoint edits, 32-bit positions and exact streamed save\n",argv[5],size,operations);return 0;
 }
 if(!strcmp(argv[5],"raw")||!strcmp(argv[5],"edge")||!strcmp(argv[5],"empty")){
  unsigned char data[2048];unsigned size=0;const char*path;
  if(!strcmp(argv[5],"raw")){const unsigned char raw[]="A\tB\rC\nD\r\nE\x1a" "F\0G";size=sizeof raw-1;memcpy(data,raw,size);path="b:RAW.TXT";}
  else if(!strcmp(argv[5],"edge")){memset(data,'x',511);memcpy(data+511,"\r\n",2);memset(data+513,'y',510);memcpy(data+1023,"\rZ",2);size=1025;path="b:EDGE.TXT";}
  else path="b:EMPTY.TXT";
  require(eread(NCEDIT_DOC_SIZE)==size,"empty/raw/boundary fixture size");
  if(!strcmp(argv[5],"edge")){
   editor_key(0x4f);require(eread(NCEDIT_E_CURSOR)==511,"End before a CRLF split across sectors");editor_key(0x53);memmove(data+511,data+513,size-513);size-=2;
   require(eread(NCEDIT_DOC_SIZE)==size,"Delete removes a CRLF as one newline");
   KBDModKeyDown(1);editor_key(0x2c);KBDModKeyUp(1);require(eread(NCEDIT_DOC_SIZE)==1025,"Undo restores the CRLF across sector boundaries");
   KBDModKeyDown(1);editor_key(0x15);KBDModKeyUp(1);
  }
  KBDModKeyDown(1);editor_key(0x4f);KBDModKeyUp(1);editor_key(0x2c);data[size++]='z';
  if(!strcmp(argv[5],"raw")){editor_key(0x1c);data[size++]=13;require(MC6800GetCpuRam()[editor_base+NCEDIT_EOL_LENGTH]==1,"new Enter retains the detected CR convention");}
  editor_key(0x3c);file_check(path,data,size);
  if(!strcmp(argv[5],"empty")){editor_key(0x47);editor_key(0x53);size=0;editor_key(0x3c);file_check(path,data,size);}
  unsigned after=wait_entries;key(1);panels(after);key(0x44);prompt_wait();editor_check_banks();require(SP==original_sp&&ram_word(0xee1e)==original_himem,"edge-case editor cleanup");
  printf("PASS NC editor %s: exact tabs, mixed EOL/control bytes, empty files and sector boundaries\n",argv[5]);return 0;
 }
 if(!strcmp(argv[5],"faults")||!strcmp(argv[5],"full")){
  unsigned char*r=MC6800GetCpuRam();editor_key(0x1e);memmove(expected+1,expected,source_size);expected[0]='a';source_size++;
  unsigned ew=editor_waits;editor_boundary=0;if(!strcmp(argv[5],"faults"))inject_save_fault=1;
  key(0x3c);editor_modal(NCEDIT_MESSAGE_KEY);
  if(!strcmp(argv[5],"faults"))require(inject_save_fault==3,"real output write failure injected before publication");
  raw_file_check("HELLO   TXT",original,original_size);require(r[editor_base+NCEDIT_MODIFIED],"failed Save retains unsaved edits");
  key(0x1c);editor_input(ew);
  if(!strcmp(argv[5],"full")){
   ew=editor_waits;KBDModKeyDown(2);key(0x3c);KBDModKeyUp(2);editor_modal(NCEDIT_DIALOG_KEY);key(0x47);
   unsigned len=strlen((char*)r+editor_base+NCEDIT_INPUT);for(unsigned k=0;k<len;k++)key(0x53);type("a:ncefull.txt");key(0x1c);editor_input(ew);file_check("a:NCEFULL.TXT",expected,source_size);
   raw_file_check("HELLO   TXT",original,original_size);
  }else{
   editor_key(0x3c);file_check("b:HELLO.TXT",expected,source_size);
   for(unsigned k=0;k<r[editor_base+NCEDIT_CACHE_COUNT];k++){unsigned tag=editor_base+NCEDIT_CACHE_TAGS+8*k;if(r[tag]&&!r[tag+2])r[tag]=0;}
   inject_read_fault=1;runtime_r1=0x20;ew=editor_waits;editor_boundary=0;KBDModKeyDown(1);key(0x47);KBDModKeyUp(1);editor_modal(NCEDIT_MESSAGE_KEY);require(inject_read_fault==2,"source read failure returns to a recoverable modal");key(0x1c);editor_input(ew);
   check_document(expected,source_size);
  }
  unsigned after=wait_entries;key(1);panels(after);key(0x44);prompt_wait();editor_check_banks();require(SP==original_sp&&ram_word(0xee1e)==original_himem,"failed I/O leaves no editor memory/stack leak");
  printf("PASS NC editor %s: original survives failed save, edits retained, retry/Save As and read recovery\n",argv[5]);return 0;
 }
 require(eread(NCEDIT_DOC_SIZE)==source_size&&sd_writes==writes,"opening F4 reads lazily and creates no scratch files");
 if(!strcmp(argv[5],"ui")){
  unsigned char*r=MC6800GetCpuRam();editor_key(0x4d);editor_key(0x4d);editor_key(0x4d);
  require(eread(NCEDIT_E_CURSOR)==3&&eread(NCEDIT_E_COLUMN)==3,"Right moves the document and screen caret");
  editor_key(0x1e);unsigned reads=sd_reads,writes2=sd_writes;
  editor_profile_key(0x30,"typing");editor_profile_key(0x2e,"typing");
  require(sd_reads==reads&&sd_writes==writes2,"continued typing stays in the RAM cache");
  require(eread(NCEDIT_E_CURSOR)==6&&eread(NCEDIT_DOC_SIZE)==source_size+3,"typing inserts bytes without rewriting the original");
  editor_key(0x50);require(r[editor_base+NCEDIT_CURSOR_ROW]==1&&eread(NCEDIT_E_COLUMN)==6,"Down preserves the desired column");
  editor_key(0x48);require(!r[editor_base+NCEDIT_CURSOR_ROW]&&eread(NCEDIT_E_CURSOR)==6,"Up returns to the edited line");
  editor_key(0x4f);unsigned first_end=eread(NCEDIT_E_CURSOR);editor_key(0x1c);
  require(eread(NCEDIT_E_CURSOR)==first_end+2&&r[editor_base+NCEDIT_CURSOR_ROW]==1&&!eread(NCEDIT_E_COLUMN),"Enter splits a CRLF line");
  KBDModKeyDown(1);editor_key(0x2c);KBDModKeyUp(1);
  require(eread(NCEDIT_E_CURSOR)==first_end&&eread(NCEDIT_DOC_SIZE)==source_size+3,"Ctrl+Z undoes the newline");
  KBDModKeyDown(1);editor_key(0x15);KBDModKeyUp(1);
  require(eread(NCEDIT_E_CURSOR)==first_end+2,"Ctrl+Y redoes the newline");
  editor_snapshot(video,"edited");
  memmove(expected+6,expected+3,source_size-3);memcpy(expected+3,"abc",3);source_size+=3;
  memmove(expected+first_end+2,expected+first_end,source_size-first_end);memcpy(expected+first_end,"\r\n",2);source_size+=2;
  editor_key(0x3c);require(!r[editor_base+NCEDIT_MODIFIED],"F2 publishes and clears the modified marker");file_check("b:HELLO.TXT",expected,source_size);
  check_document(expected,source_size);
  unsigned at=eread(NCEDIT_E_CURSOR);editor_key(0x1e);memmove(expected+at+1,expected+at,source_size-at);expected[at]='a';source_size++;
  editor_key(0x3c);file_check("b:HELLO.TXT",expected,source_size);
  // Save As resolves a typed absolute name and returns focus to the document.
  unsigned ew=editor_waits;KBDModKeyDown(2);key(0x3c);KBDModKeyUp(2);
  key(0x47);unsigned input_len=strlen((char*)r+editor_base+NCEDIT_INPUT);for(unsigned k=0;k<input_len;k++)key(0x53);
  type("b:newsav.txt");key(0x1c);editor_input(ew);file_check("b:NEWSAV.TXT",expected,source_size);
  require(!strcmp((char*)r+editor_base+NCEDIT_FILENAME,"B:\\NEWSAV.TXT"),"Save As updates the editor pathname");
  ew=editor_waits;key(0x41);type("paging");key(0x1c);editor_input(ew);
  unsigned found=eread(NCEDIT_E_CURSOR);require(found+6<=source_size&&!memcmp(expected+found,"paging",6),"F7 finds text through the logical piece stream");
  ew=editor_waits;KBDModKeyDown(2);key(0x41);KBDModKeyUp(2);editor_input(ew);
  require(eread(NCEDIT_E_CURSOR)>found&&!memcmp(expected+eread(NCEDIT_E_CURSOR),"paging",6),"Shift+F7 finds the next occurrence");
  // Native Cyrillic input and search use the same byte encoding as ROM text.
  unsigned cyr_at=eread(NCEDIT_E_CURSOR);key(0x46);editor_key(0x10);key(0x46);
  memmove(expected+cyr_at+1,expected+cyr_at,source_size-cyr_at);expected[cyr_at]=0xa9;source_size++;
  KBDModKeyDown(1);editor_key(0x2c);KBDModKeyUp(1);require(eread(NCEDIT_DOC_SIZE)==source_size-1,"Undo a visible native Cyrillic insertion");
  KBDModKeyDown(1);editor_key(0x15);KBDModKeyUp(1);require(eread(NCEDIT_DOC_SIZE)==source_size,"Redo a native Cyrillic insertion");editor_key(0x3c);file_check("b:NEWSAV.TXT",expected,source_size);
  ew=editor_waits;key(0x41);editor_boundary=0;key(0x47);for(unsigned k=0;k<6;k++)key(0x53);key(0x46);key(0x10);key(0x46);key(0x1c);editor_input(ew);
  require(eread(NCEDIT_E_CURSOR)==cyr_at,"native Cyrillic search preserves the document encoding");
  const char*as_names[]={"b:\\work\\child.txt","child2.txt","\\rootsav.txt"};const char*as_expected[]={"B:\\WORK\\CHILD.TXT","B:\\WORK\\CHILD2.TXT","B:\\ROOTSAV.TXT"};
  for(unsigned variant=0;variant<3;variant++){
   ew=editor_waits;KBDModKeyDown(2);key(0x3c);KBDModKeyUp(2);editor_boundary=0;key(0x47);
   unsigned len=strlen((char*)r+editor_base+NCEDIT_INPUT);for(unsigned k=0;k<len;k++)key(0x53);type(as_names[variant]);key(0x1c);editor_input(ew);
   require(!strcmp((char*)r+editor_base+NCEDIT_FILENAME,as_expected[variant]),"relative/rooted Save As follows the document's drive and directory");file_check(as_expected[variant],expected,source_size);
  }
  unsigned after=wait_entries;key(1);panels(after);
  key(0x44);prompt_wait();editor_check_banks();require(SP==original_sp&&ram_word(0xee1e)==original_himem,"UI editor cleanup");
  printf("PASS NC editor UI %s/%s mode %u: streamed viewport, typing without I/O, columns, Enter, Undo/Redo, safe Save/Save As and streaming search\n",argv[2],argv[3],video);return 0;
 }
 check_document(expected,source_size);
 fprintf(stderr,"Original stream verified\n");
 require(!editor_call(NCEDIT_WORK_OPEN,0),"create unique workspace on first edit");
 fprintf(stderr,"Workspace ready\n");
 insert_piece(0,(const unsigned char*)"start\r\n",7);memmove(expected+7,expected,source_size);memcpy(expected,"start\r\n",7);source_size+=7;
 check_document(expected,source_size);
 insert_piece(123,(const unsigned char*)"middle",6);memmove(expected+129,expected+123,source_size-123);memcpy(expected+123,"middle",6);source_size+=6;
 check_document(expected,source_size);
 for(unsigned k=0;k<120;k++){
  unsigned pos=(k*97+31)%source_size;unsigned char octet='a'+k%26;
  insert_piece(pos,&octet,1);memmove(expected+pos+1,expected+pos,source_size-pos);expected[pos]=octet;source_size++;
 }
 require(eread(NCEDIT_INDEX_END)>5*512,"piece metadata exceeds the entire ordinary cache");
 check_document(expected,source_size);
 for(unsigned k=0;k<40;k++){
  unsigned pos=(k*71+14)%(source_size-9);delete_piece(pos,9);memmove(expected+pos,expected+pos+9,source_size-pos-9);source_size-=9;
 }
 require(!editor_call(NCEDIT_CACHE_FLUSH,0),"flush dirty editor pages");check_document(expected,source_size);
 // Product editing API: contiguous typing is one undoable transaction.
 unsigned before_size=source_size;unsigned char before[65536];memcpy(before,expected,source_size);
 eword(NCEDIT_E_CURSOR,400);
 for(unsigned k=0;k<12;k++){
  eword(NCEDIT_CHANGE_AT,400+k);MC6800GetCpuRam()[editor_base+NCEDIT_CHANGE_DELETE]=0;MC6800GetCpuRam()[editor_base+NCEDIT_CHANGE_ADD]=1;
  MC6800GetCpuRam()[editor_base+NCEDIT_CHANGE_BYTES]='A'+k;MC6800GetCpuRam()[editor_base+NCEDIT_CHANGE_GROUP]=1;
  require(!editor_call(NCEDIT_EDITOR_CHANGE,0),"buffered product edit");
  memmove(expected+401+k,expected+400+k,source_size-400-k);expected[400+k]='A'+k;source_size++;
 }
 require(eread(NCEDIT_HISTORY_COUNT)==32,"continuous typing coalesces into one disk undo record");check_document(expected,source_size);
 require(!editor_call(NCEDIT_HISTORY_UNDO,0),"undo typed group");check_document(before,before_size);
 require(!editor_call(NCEDIT_HISTORY_REDO,0),"redo typed group");check_document(expected,source_size);
 require(!editor_call(NCEDIT_HISTORY_UNDO,0),"undo before branching");
 MC6800GetCpuRam()[editor_base+NCEDIT_GROUP_OPEN]=0;eword(NCEDIT_E_CURSOR,401);eword(NCEDIT_CHANGE_AT,401);
 MC6800GetCpuRam()[editor_base+NCEDIT_CHANGE_DELETE]=2;MC6800GetCpuRam()[editor_base+NCEDIT_CHANGE_ADD]=2;
 MC6800GetCpuRam()[editor_base+NCEDIT_CHANGE_BYTES]='x';MC6800GetCpuRam()[editor_base+NCEDIT_CHANGE_BYTES+1]='y';
 require(!editor_call(NCEDIT_EDITOR_CHANGE,0),"replace two bytes after undo");before[401]='x';before[402]='y';check_document(before,before_size);
 require(!editor_call(NCEDIT_HISTORY_REDO,0),"discarded redo tail is harmless");check_document(before,before_size);
 if(!strcmp(argv[5],"missing")){
  eword(NCEDIT_APPLY_POS,100);eword(NCEDIT_APPLY_LEFT,1000);eword(NCEDIT_APPLY_INSERT_LEN,0);eword(NCEDIT_APPLY_INSERT_OFF,0);eword(NCEDIT_APPLY_CURSOR,100);eword(NCEDIT_HISTORY_TARGET,0);
  MC6800GetCpuRam()[editor_base+NCEDIT_HISTORY_MODE]=1;MC6800GetCpuRam()[editor_base+NCEDIT_APPLY_PHASE]=1;inject_apply_fault=1;
  unsigned failure=editor_call(NCEDIT_HISTORY_RESUME,0);runtime_r1=0;inject_apply_fault=0;
  require(failure&&MC6800GetCpuRam()[editor_base+NCEDIT_APPLY_PHASE]==1,"an interrupted multi-page edit retains its resumable transaction");
  require(!editor_call(NCEDIT_HISTORY_RESUME,0)&&!MC6800GetCpuRam()[editor_base+NCEDIT_APPLY_PHASE],"retry continues after the last completed piece");
  memmove(before+100,before+1100,before_size-1100);before_size-=1000;check_document(before,before_size);
 }
 unsigned after=wait_entries,unsaved=MC6800GetCpuRam()[editor_base+NCEDIT_MODIFIED];key(1);if(unsaved)type("n");panels(after);
 require(core_entries==2&&!editor_active,"editor releases its code and returns to the panels");
 file_check("b:HELLO.TXT",original,original_size);
 key(0x44);prompt_wait();editor_check_banks();require(SP==original_sp&&ram_word(0xee1e)==original_himem,"editor and panels release all ordinary RAM");
 require(!resets&&!fdc_port_accesses,"editor uses only native filesystem APIs");
 printf("PASS NC editor engine %s/%s mode %u %s: lazy F4, page eviction, fragmented inserts/deletes, original retained, module reload and cleanup\n",argv[2],argv[3],video,argv[5]);return 0;
}
