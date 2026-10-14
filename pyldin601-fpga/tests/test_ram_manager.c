// Real INT E5 and UniDOS ownership/termination; independent bank-set oracle.
#define COMPACT_FIXTURE 1
#define DIRECT_SD_FIXTURE 1
#define ROMDISK_MAIN unused_romdisk_main
#include "test_romdisk_unidos.c"
#undef ROMDISK_MAIN

static unsigned info(void){
 unsigned char*r=MC6800GetCpuRam();unsigned pc=PC,sp=SP,x=X,a=A,b=B,old_i=i;
 r[0x210]=0x3f;r[0x211]=0xe5;r[0x212]=1;
 PC=0x210;A=0;B=0;X=0x3000;
 uint64_t deadline=virtual_cycles+2000000;
 while(PC!=0x212){until(virtual_cycles+1);require(virtual_cycles<deadline,"info returns");}
 if(A!=1||X!=111||SP!=sp)fprintf(stderr,"info A=%u B=%u X=%04x SP=%04x/%04x state=%02x%02x vector=%02x%02x page=%u group=%u\n",A,B,X,SP,sp,r[0xefca],r[0xefcb],r[0xefca],r[0xefcb],page,ram_group); require(A==1&&X==111&&SP==sp,"manager ABI/total/stack");unsigned result=B;
 PC=pc;SP=sp;X=x;A=a;B=b;i=old_i;return result;
}
static unsigned call(unsigned op,unsigned count,unsigned desc){
 unsigned char*r=MC6800GetCpuRam();unsigned pc=PC,sp=SP,x=X,a=A,b=B,old_i=i,p=page,g=ram_group;
 r[0x210]=0x3f;r[0x211]=0xe5;r[0x212]=1;PC=0x210;A=op;B=count;X=desc;i=0;
 uint64_t deadline=virtual_cycles+3000000;
 while(PC!=0x212){until(virtual_cycles+1);require(virtual_cycles<deadline,"operation returns");}
 require(SP==sp&&X==desc&&B==count&&page==p&&ram_group==g,"manager preserves X/B/SP/pages");unsigned result=A;
 PC=pc;SP=sp;X=x;A=a;B=b;i=old_i;return result;
}
static unsigned token(unsigned desc){unsigned char*r=MC6800GetCpuRam();return r[desc]*256+r[desc+1];}
int main(int argc,char**argv){
 if(argc!=4)return 2;model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);
 require(n==ROM_BYTES+512,"ROM length");memcpy(config,rom,HEADER_BYTES);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load(argv[1],&image_size);committed=1;MC6800Init();MC6800Reset();until(60000000);key(0x1c);key(0x1c);prompt_wait();
 unsigned char*r=MC6800GetCpuRam();unsigned pcb=r[0xec00]*256+r[0xec01],sp=SP;
 require(pcb&&info()==111,"fresh manager has all banks");
 unsigned state=r[0xefca]*256+r[0xefcb];require(state>=0x100&&state+240<=0xbe00,"resident state exists");
 for(unsigned v=0;v<909312;v++)physical[0x22000+v]=(v*17+(v>>13)*31)&255;
 unsigned char*saved=malloc(909312);memcpy(saved,physical+0x22000,909312);
 // RAMMAN enters its ROM in group zero, then must return to the exact
 // caller selectors. Cover every valid group and every legacy page,
 // including page 0/7, ROM overlays and the last group's invalid RAM slots.
 unsigned saved_page=page,saved_group=ram_group;
 for(unsigned group=0;group<=18;group++)for(unsigned pg=0;pg<16;pg++){
  page=0xa0|pg;ram_group=group;
  require(call(1,1,0x3000)==0,"allocation from any caller page/group");
  require(call(2,0,0x3000)==0,"release retains any caller page/group");
 }
 page=saved_page;ram_group=saved_group;
 require(info()==111,"all page/group context checks release their lease");
 require(call(1,1,0x3000)==0&&r[0x3003]==0,"first allocation bank0");
 require(call(1,1,0x3100)==0&&r[0x3103]==1,"second allocation bank1");
 require(call(1,1,0x3200)==0&&r[0x3203]==2,"third allocation bank2");
 unsigned stale=token(0x3100);require(call(2,0,0x3100)==0&&info()==109,"release middle bank");
 require(call(1,3,0x3300)==0&&r[0x3303]==1&&r[0x3304]==3&&r[0x3305]==4,"fragmented allocation gathers exact free banks");
 require(info()==106,"exact free count");
 r[0x3100]=stale>>8;r[0x3101]=stale;require(call(2,0,0x3100)==3&&info()==106,"stale token rejected");
 unsigned lease=token(0x3300);r[0xec00]=(pcb+1)>>8;r[0xec01]=pcb+1;
 require(call(2,0,0x3300)==3&&info()==106,"foreign owner cannot release");
 require(call(1,2,0x3400)==0&&info()==104,"second owner owns separate banks");
 r[0xec00]=pcb>>8;r[0xec01]=pcb;
 require(call(1,107,0x3500)==2&&info()==104,"no partial allocation on exhaustion");
 require(call(1,0,0x3500)==1&&call(1,112,0x3500)==1,"invalid counts");
 require(call(1,1,0)==1&&call(1,1,0xbfff)==1&&call(1,1,state)==1&&call(2,0,0xc000)==1,"invalid descriptors cannot overwrite state/banked/DOS RAM");
 require(call(9,0,0x3500)==1,"unknown function");
 r[state+3]=255;r[state+4]=255;
 require(call(1,1,0x3600)==0&&token(0x3600)!=token(0x3000),"cookie wrap skips zero and live cookies");
 require(call(2,0,0x3600)==0,"wrapped cookie releases normally");
 r[0x3302]=255;memset(r+0x3303,110,3);
 r[state+5]=1;require(call(1,1,0x3500)==5&&r[state+5]==1,"nested call does not unlock outer transaction");r[state+5]=0;
 require(call(3,0,0)==0&&info()==109,"process cleanup uses private ownership records, retains foreign leases");
 r[0xec00]=(pcb+1)>>8;r[0xec01]=pcb+1;require(call(2,0,0x3400)==0&&info()==111,"foreign owner can release its own lease");r[0xec00]=pcb>>8;r[0xec01]=pcb;
 for(unsigned k=0;k<16;k++)require(call(1,1,0x4000+128*k)==0,"sixteen concurrent leases");
 require(call(1,1,0x3900)==2&&info()==95,"lease exhaustion also atomic");require(call(3,0,0)==0&&info()==111,"all leases released");
 require(call(1,111,0x3000)==0&&info()==0&&r[0x3002]==111,"full capacity");
 for(unsigned k=0;k<111;k++)require(r[0x3003+k]==k,"no duplicate or reserved bank");
 require(call(2,0,0x3000)==0&&info()==111&&call(2,0,0x3000)==3,"full release and double free");
 require(call(1,1,0x3000)==0&&call(5,0,0x3000)==3&&info()==110,"pinned release rejects ordinary process leases");
 unsigned pinned_token=token(0x3000);
 require(call(4,0,0x3000)==0&&token(0x3000)==pinned_token&&info()==110,"pin retains cookie and allocated bank");
 require(call(2,0,0x3000)==3&&call(4,0,0x3000)==3,"process release and repeated pin cannot consume system lease");
 require(call(3,0,0)==0&&info()==110,"process cleanup preserves pinned lease");
 r[0xec00]=0;r[0xec01]=0;
 require(call(3,0,0)==0&&info()==110,"zero PCB cannot bulk release system leases");
 r[0xec00]=pcb>>8;r[0xec01]=pcb;
 require(call(5,0,0x3000)==0&&info()==111&&token(0x3000)==0&&call(5,0,0x3000)==3,"explicit pinned release restores capacity and rejects stale cookie");
 require(!memcmp(saved,physical+0x22000,909312),"allocator never erases or writes bank data");free(saved);
 // Native PGM owns allocation/release; UniShell has no allocator calls.
 command("b:ramexit");require(info()==111&&SP==sp,"application releases its lease before INT38");
 command("b:ramalloc");require(contains("PASS: RAM allocator, 64 KiB, SWI/IRQ")&&info()==111&&SP==sp,"allocated RAM diagnostic and timer restore/release");
 command("dir a:");command("dir b:");command("dir c:");require(SP==sp&&!fdc_port_accesses,"DOS remains intact");
 printf("PASS RAM manager %s/%s: all 19 groups x 16 pages, 111 banks, fragmentation, owners/tokens, exhaustion, nested-call lock, application release/INT38, DIR and unchanged SRAM\n",argv[2],argv[3]);return 0;
}
