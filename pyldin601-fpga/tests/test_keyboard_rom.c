// Real UniAS keyboard ROM and both native BIOSes, independent MMIO latch model.
#include <stdint.h>
static int hg_read_byte(uint16_t a,unsigned char*out);
static int hg_write_byte(uint16_t a,unsigned char d);
#define HG_FIXTURE 1
#define NATIVE_STABILITY_MAIN unused_native_stability_main
#include "test_native_stability.c"
static unsigned char bytes[64],code=255;
static unsigned head,count,overflow,capture,parser_reset,raw_enable,consumed=1,strobe,legacy_irq;
static unsigned char *ram;
static void push(unsigned b){if(count<64)bytes[(head+count++)&63]=b;else overflow=1;}
static void physical_key(unsigned e,unsigned up,unsigned b){if(e)push(0xe0);if(up)push(0xf0);push(b);}
static int hg_read_byte(uint16_t a,unsigned char*out){
 if(a>=0xe6b0&&a<=0xe6b7){*out=255;switch(a&7){
 case 0:*out='R';break;
 case 1:*out=(count!=0)|(consumed<<2)|(parser_reset<<3)|((count==64)<<5)|(capture<<6)|(overflow<<7);break;
 case 2:if(count){*out=bytes[head++&63];count--;}break;
 case 3:*out=count;break;case 4:*out=2;break;}return 1;}
 if(a==0xe628){*out=capture?255:code;consumed=1;strobe=legacy_irq=0;return 1;}
 if(a==0xe62a||a==0xe62e){*out=0x37|(caps_off?8:0)|((!capture&&strobe)?128:0);if(code!=255&&!capture&&!consumed)strobe^=1;return 1;}
 return 0;
}
static int hg_write_byte(uint16_t a,unsigned char d){
 if(a==0xe628){code=capture?255:d;consumed=code==255;strobe=legacy_irq=0;return 1;}
 if(a==0xe62a||a==0xe62e){caps_off=(d&8)!=0;if(d&128&&!consumed&&code!=255&&!capture)strobe=legacy_irq=1;return 1;}
 if(a>=0xe6b0&&a<=0xe6b7){if(a==0xe6b3){
  if(d&1)head=count=0;if(d&2)overflow=0;if(d&16)raw_enable=1;if(d&64)raw_enable=0;if(d&32)parser_reset=0;
  if(d&4){if(!capture)parser_reset=1;capture=1;code=255;consumed=1;strobe=legacy_irq=0;}
  if(d&8){if(capture)parser_reset=1;capture=0;}
 }return 1;}return 0;
}
static void irq_observe(void){if(!i&&(legacy_irq||(raw_enable&&!capture&&(count||overflow||parser_reset))))MC6800SetInterrupt(1);}
static void require(int ok,const char*what){if(!ok){dump();fprintf(stderr,"FAIL %s code=%02x fifo=%u state=%02x%02x\n",what,code,count,ram[0xefce],ram[0xefcf]);exit(1);}}
static unsigned state;
static void pump(void){
 word saved_pc=PC,saved_sp=SP,saved_x=X;byte saved_a=A,saved_b=B;
 unsigned saved_flags=(h<<5)|(i<<4)|(n<<3)|(z<<2)|(v<<1)|c;
 unsigned char saved_page=page,saved_group=ram_group;
 unsigned target=ram[state+1]*256+ram[state+2];
 ram[0x900]=0xbd;ram[0x901]=target>>8;ram[0x902]=target;ram[0x903]=1;
 PC=0x900;SP=0x6fff;page=ram[0xedf3]&15;ram_group=0;i=1;
 unsigned steps=0;do{MC6800Step();}while(PC!=0x903&&++steps<20000);
 require(PC==0x903,"bounded MC6800 pump");
 PC=saved_pc;SP=saved_sp;X=saved_x;A=saved_a;B=saved_b;
 h=(saved_flags>>5)&1;i=(saved_flags>>4)&1;n=(saved_flags>>3)&1;z=(saved_flags>>2)&1;v=(saved_flags>>1)&1;c=saved_flags&1;
 page=saved_page;ram_group=saved_group;
}
static void clear(void){parser_reset=1;head=count=overflow=capture=0;ram[0xed09]=ram[0xed0b]=0;ram[0xed31]=255;pump();}
static void irq_context_test(void){
 clear();ram[0x800]=0x20;ram[0x801]=0xfe;PC=0x800;SP=0x6fff;
 A=0xa5;B=0x5a;X=0x3456;h=1;i=0;n=1;z=0;v=1;c=1;page=6;ram_group=18;
 // A raw prefix IRQ produces no legacy character; the PAL IRQ also runs.
 push(0xe0);until(virtual_cycles+40000);
 for(unsigned step=0;PC!=0x800&&step<20000;step++) {
  int cycles=MC6800Step();virtual_cycles+=cycles>0?cycles:1;
 }
 require(!count&&ram[state+3]==1,"raw IRQ invokes resident parser");
 require(PC==0x800&&SP==0x6fff&&A==0xa5&&B==0x5a&&X==0x3456
         &&h&&!i&&n&&!z&&v&&c&&page==6&&ram_group==18,
         "raw/PAL IRQ preserves registers, flags, E6F0 and E6F1");
 // Caps Lock must toggle once despite repeated PAL callbacks and make bytes.
 page=7;ram_group=0;clear();unsigned before=caps_off;
 physical_key(0,0,0x58);until(virtual_cycles+800000);
 require(caps_off!=before,"native Caps Lock toggles once");
 physical_key(0,0,0x58);until(virtual_cycles+800000);
 require(caps_off!=before,"held Caps Lock does not repeat");
 physical_key(0,1,0x58);until(virtual_cycles+200000);
 require(code==255,"native toggle release");
}
static void test_key(unsigned mode,unsigned e,unsigned scan,unsigned pc){
 clear();ram[0xe629]=(mode&4)?0:1;
 if(mode&1)physical_key(0,0,(mode&4)?0x59:0x12);
 if(mode&2)physical_key((mode&4)!=0,0,0x14);
 flagKey=((mode&2)?1:0)|((mode&1)?2:0);cyrMode=mode&4;
 unsigned expected=KBDTranslateKey(pc);physical_key(e,0,scan);pump();
 if(code!=expected){fprintf(stderr,"mode=%u E0=%u scan=%02x pc=%02x expected=%02x got=%02x\n",mode,e,scan,pc,expected,code);require(0,"independent native layout oracle");}
 if(expected!=255){require(legacy_irq&&!consumed,"published legacy strobe");
  physical_key(e,0,scan);pump();require(ram[state+8]==0,"typematic deduplicated");
  unsigned char sample;hg_read_byte(0xe628,&sample);physical_key(e,1,scan);pump();require(code==255,"break cancels held event");
 }
}
int main(int argc,char**argv){
 if(argc!=4&&argc!=5)return 2;model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*b=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);
 memcpy(config,b,64);memcpy(physical+0x10000,b+512,ROM_BYTES);free(b);image=load(argv[1],&image_size);
 if(argc==5){unsigned char temp[8192];memcpy(temp,physical+0x14000,8192);memcpy(physical+0x14000,physical+0x16000,8192);memcpy(physical+0x16000,temp,8192);}
 memcpy(config+64,image+462,32);committed=1;MC6800Init();ram=MC6800GetCpuRam();native_step_hook=irq_observe;MC6800Reset();until(60000000);
 state=ram[0xefce]*256+ram[0xefcf];require(state>=0x100&&state+64<=0xbe00,"native BIOS allocated keyboard state");
 require((ram[0xedf3]&15)==(argc==5?10:11),"E7 page follows the registered keyboard ROM");
 require(ram[state]==0x7e&&raw_enable,"resident gateway and raw IRQ initialized");
 physical_key(0,0,0x5a);until(virtual_cycles+100000);physical_key(0,1,0x5a);until(virtual_cycles+100000);
 physical_key(0,0,0x5a);until(virtual_cycles+100000);physical_key(0,1,0x5a);until(virtual_cycles+100000);
 // Every mapped key in all eight modes, compared with original keyboard.c.
 unsigned mapped[256];FILE*f=fopen("rtl/ps2_set2.mem","r");require(f!=NULL,"Set 2 fixture");
 for(unsigned k=0;k<256;k++)require(fscanf(f,"%x",mapped+k)==1,"Set 2 byte");fclose(f);
 unsigned checked=0;
 for(unsigned mode=0;mode<8;mode++)for(unsigned scan=0;scan<256;scan++){
  if(mapped[scan]==255||scan==0x77)continue;
  test_key(mode,0,scan,mapped[scan]);checked++;
 }
 static const unsigned scan2[]={0x6c,0x75,0x7d,0x6b,0x73,0x74,0x69,0x72,0x7a,0x70,0x71,0x1f,0x27};
 static const unsigned scan1[]={0x47,0x48,0x49,0x4b,0x4c,0x4d,0x4f,0x50,0x51,0x52,0x53,0x46,0x46};
 for(unsigned mode=0;mode<8;mode++)for(unsigned k=0;k<13;k++){test_key(mode,1,scan2[k],scan1[k]);checked++;}
 clear();push(0xe1);push(0x14);push(0x77);push(0xe1);push(0xf0);push(0x14);push(0xf0);push(0x77);pump();require(code==255&&!ram[state+5],"Pause ignored without stuck Ctrl");
 // Fast released events are retained through native debounce windows.
 clear();ram[0xe629]=1;ram[0xed09]=3;
 physical_key(0,0,0x16);physical_key(0,1,0x16);physical_key(0,0,0x1e);physical_key(0,1,0x1e);pump();
 require(code==255&&ram[state+8]==2,"software queue preserves taps while BIOS debounces");
 ram[0xed09]=0;pump();require(code=='1',"first queued tap");unsigned char sample;hg_read_byte(0xe628,&sample);pump();require(code=='2',"second queued tap");hg_read_byte(0xe628,&sample);pump();require(code==255,"released queue drains");
 clear();physical_key(0,0,0x12);pump();require(ram[state+5]==1,"Shift state");hg_write_byte(0xe6b3,7);physical_key(1,0,0x6b);pump();require(count==2&&code==255,"capture leaves raw bytes to game");
 hg_write_byte(0xe6b3,11);pump();require(!ram[state+5]&&!ram[state+8]&&code==255&&!parser_reset,"release resets software modifiers and queue");
 for(unsigned k=0;k<65;k++)push(k);pump();require(!count&&!overflow&&!ram[state+5],"raw overflow resynchronizes safely");
 irq_context_test();
 printf("PASS keyboard ROM %s/%s page %X: resident allocation, %u layout/navigation cases, Pause, queue, capture, overflow, IRQ context and Caps Lock\n",argv[2],argv[3],ram[0xedf3]&15,checked);return 0;
}
