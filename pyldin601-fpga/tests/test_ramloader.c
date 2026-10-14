// Actual UniDOS loader, pinned banks, native SWI and PAL IRQs. Private media only.
#define COMPACT_FIXTURE 1
#define DIRECT_SD_FIXTURE 1
#define ROMDISK_MAIN unused_romdisk_main
#include "test_romdisk_unidos.c"
#undef ROMDISK_MAIN
#include "../build/ramloader/RAMLOAD.h"
#include "../build/ramloader/RAMCORE.h"
static unsigned prefix_base,core_base,fault_mode,fault_seen;
static unsigned char sig[16],mask[16],core_sig[16],core_mask[16];
static void observe(void){
 unsigned char*r=MC6800GetCpuRam();
 if(!prefix_base&&PC>=0x100&&PC<0xbd00&&r[PC]==sig[0]){
  unsigned k;for(k=0;k<16;k++)if((r[PC+k]&mask[k])!=(sig[k]&mask[k]))break;
  if(k==16){prefix_base=PC;core_base=0;}
 }
 if(!core_base&&PC>=0x100&&PC<0xbd00&&r[PC]==core_sig[0]){
  unsigned k;for(k=0;k<16;k++)if((r[PC+k]&core_mask[k])!=(core_sig[k]&core_mask[k]))break;
  if(k==16)core_base=PC;
 }
 if(core_base&&fault_mode==1&&PC==core_base+RAMCORE_READ_PAGE&&r[core_base+RAMCORE_BLOCKS]>=2){runtime_r1=0x20;fault_mode=11;fault_seen++;}
 if(core_base&&fault_mode==3&&PC==core_base+RAMCORE_READ_PAGE&&r[core_base+RAMCORE_BLOCKS]>=2){fault_mode=0;fault_seen++;invoke(4,0,0,0);}
 if(core_base&&fault_mode==11&&PC==core_base+RAMCORE_FAIL){runtime_r1=0;fault_mode=0;}
 unsigned state=r[0xefca]*256+r[0xefcb];
 if(fault_mode==2&&page==14&&A==4&&PC==(r[state+1]*256+r[state+2])){A=9;fault_mode=0;fault_seen++;}
 if(prefix_base&&PC==prefix_base+RAMLOAD_LOADER_ERROR)fprintf(stderr,"loader error %u base=%04x arg=%s path=%s entry=%04x core=%04x\n",A,prefix_base,r+prefix_base+RAMLOAD_LOAD_ARGUMENT,r+prefix_base+RAMLOAD_LOAD_PATH,ram_group,page);
}
static unsigned free_banks(void){require(invoke(0xe5,0,0,0)==1&&result_x==111,"RAMMAN ABI");return result_b;}
static unsigned ram_word(unsigned a){unsigned char*r=MC6800GetCpuRam();return r[a]*256+r[a+1];}
static void check_crc(unsigned op,unsigned seed,unsigned size){
 unsigned char*r=MC6800GetCpuRam();word_at(0x3000,0x4000);word_at(0x3002,size);word_at(0x3004,seed);word_at(0x3006,0);
 unsigned before_irq=irq_count,g=ram_group,p=page,sp=SP;
 require(invoke(op,1,0x42,0x3000)==0,"banked CRC call returns success");
 require(result_x==0x3000&&result_b==0x42&&ram_group==g&&page==p&&SP==sp,"banked call retains registers, stack and selectors");
 unsigned expected=seed;
 for(unsigned k=0;k<size;k++){
  expected^=(unsigned)r[0x4000+k]<<8;
  for(unsigned b=0;b<8;b++)expected=(expected<<1)^((expected&0x8000)?0x1021:0);
  expected&=65535;
 }
 if(ram_word(0x3006)!=expected)fprintf(stderr,"CRC got %04x expected %04x\n",ram_word(0x3006),expected);
 require(ram_word(0x3006)==expected,"native ROM CRC agrees with independent C oracle");
 if(size>1024)require(irq_count>before_irq,"PAL IRQ interrupts executing RAM-bank code");
}
int main(int argc,char**argv){
 if(argc!=5)return 2;model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");const char*scenario=argv[4];
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);
 require(n==ROM_BYTES+512,"ROM fixture length");memcpy(config,rom,HEADER_BYTES);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load(argv[1],&image_size);committed=1;MC6800Init();MC6800Reset();until(60000000);key(0x1c);key(0x1c);prompt_wait();
 unsigned char*r=MC6800GetCpuRam();unsigned sp=SP,initial_free=free_banks();watch_resets=1;
 size_t pn;unsigned char*pgm=load("build/ramloader/RAMLOAD.prefix.PGM",&pn);unsigned off=pgm[4]*256+pgm[5],count=pgm[2]*256+pgm[3];memcpy(sig,pgm+off,16);memset(mask,255,16);for(unsigned k=0;k<count;k++){unsigned at=pgm[16+2*k]*256+pgm[17+2*k];if(at<16)mask[at]=0;}free(pgm);
 pgm=load("build/ramloader/RAMCORE.PGM",&pn);off=pgm[4]*256+pgm[5];count=pgm[2]*256+pgm[3];memcpy(core_sig,pgm+off,16);memset(core_mask,255,16);core_mask[3]=core_mask[4]=0;for(unsigned k=0;k<count;k++){unsigned at=pgm[16+2*k]*256+pgm[17+2*k];if(at<16)core_mask[at]=0;}free(pgm);native_step_hook=observe;
 command("b:ramload /l");require(contains("None.")&&SP==sp,"empty list needs no resident installation");
 if(!strcmp(scenario,"missing")){
  word_at(0xefca,0);r[0xedf2]&=15;command("b:ramload b:crc16.rom");require(contains("error $04")&&SP==sp,"missing RAMMAN returns without installing");puts("PASS ramloader missing RAMMAN: no install");return 0;
 }
 unsigned reserved=0;
 if(!strcmp(scenario,"offset"))reserved=17;
 if(!strcmp(scenario,"last"))reserved=110;
 if(!strcmp(scenario,"full"))reserved=111;
 unsigned owner=ram_word(0xec00);
 if(reserved){word_at(0xec00,0xffff);require(invoke(0xe5,1,reserved,0x3500)==0,"foreign bank reservation");word_at(0xec00,owner);}
 if(reserved==111){command("b:ramload b:crc16.rom");require(free_banks()==0&&contains("error $02"),"exhaustion is atomic");word_at(0xec00,0xffff);require(invoke(0xe5,2,0,0x3500)==0,"release foreign reservation");word_at(0xec00,owner);puts("PASS ramloader full: no partial install");return 0;}
 unsigned baseline=free_banks(),resident=ram_word(0xee1a),heap=ram_word(0xee1e);
 const char*bad[]={"b:ramload b:short.rom","b:ramload b:badsum.rom","b:ramload b:badvec.rom","b:ramload b:badaddr.rom","b:ramload b:badinit.rom","b:ramload b:absent.rom","b:ramload b:dupvec.rom","b:ramload b:taken.rom","b:ramload b:failinit.rom","b:ramload b:toomany.rom","b:ramload b:noentry.rom","b:ramload b:irq.rom"};
 for(unsigned k=0;k<sizeof bad/sizeof bad[0];k++){command(bad[k]);require(free_banks()==baseline&&ram_word(0xee1a)==resident&&ram_word(0xee1e)==heap&&SP==sp,"invalid ROM/file rollback restores banks, heap, resident boundary and stack");}
 command("b:ramnest");require(contains("error $56")&&free_banks()==baseline&&ram_word(0xee1a)==resident&&ram_word(0xee1e)==heap,"initial install from a nested PGM refuses without pinning its parent");
 fault_mode=1;fault_seen=0;command("b:ramload b:crc16.rom");require(fault_seen==1&&free_banks()==baseline&&ram_word(0xee1a)==resident&&ram_word(0xee1e)==heap,"real SD read fault rolls back the partial bank and file handle");
 fault_mode=3;fault_seen=0;command("b:ramload b:crc16.rom");require(fault_seen==1&&contains("error $FF")&&free_banks()==baseline&&ram_word(0xee1a)==resident&&ram_word(0xee1e)==heap,"native BREAK requests cancellation and frees the partial bank before returning");
 fault_mode=2;fault_seen=0;command("b:ramload b:crc16.rom");require(fault_seen==1&&contains("error $57")&&free_banks()==baseline&&ram_word(0xee1a)==resident,"old RAMMAN PIN rejection rolls back using the ordinary lease API");
 command("b:ramload b:crc16.rom");
 if(!contains("Loaded CRC16"))dump();
 require(contains("Loaded CRC16")&&free_banks()==baseline-1,"load pins one bank");
 require(invoke(0xec,0,0,0)==1,"resident manager discovery");unsigned registry=result_x;
 unsigned record=registry,bank=r[record+7];require(bank==reserved&&r[record+18]==1&&r[record+1]==0,"correct bank and initialized persistent context");
 unsigned resident_after=ram_word(0xee1a),heap_after=ram_word(0xee1e);
 fprintf(stderr,"resident %04x -> %04x heap %04x -> %04x registry=%04x SP=%04x/%04x\n",resident,resident_after,heap,heap_after,registry,SP,sp);sp=SP;
 require(resident_after==heap_after&&resident_after<resident&&resident-resident_after<1400,"only compact resident tail survives, disposable loader released");
 require(invoke(0xe5,3,0,0)==0&&free_banks()==baseline-1,"process cleanup cannot release pinned module or foreign leases");
 size_t rn;unsigned char*expected_rom=load("build/ramloader/CRC16.ROM",&rn);require(rn==8192&&!memcmp(expected_rom,physical+0x22000+bank*8192,8192),"loaded bank equals the complete source ROM including all padding");free(expected_rom);
 unsigned char snapshot[8192];memcpy(snapshot,physical+0x22000+bank*8192,8192);
 command("b:ramcheck");require(contains("PASS: banked ROM CRC16 = 29B1"),"separate PGM calls loaded ROM after loader exits");
 memcpy(r+0x4000,"123456789",9);check_crc(0xed,0xffff,9);
 for(unsigned k=0;k<9000;k++)r[0x4000+k]=(k*17+k/11)&255;
 for(unsigned g=0;g<=18;g++){
  unsigned pg=page,rg=ram_group;page=0xa0|(g%16);ram_group=g;check_crc(0xed,0x3c18,31);page=pg;ram_group=rg;
 }
 check_crc(0xed,0xffff,9000);
 require(!memcmp(snapshot,physical+0x22000+bank*8192,8192),"executed module remains byte-for-byte identical to ROM image");
 command("b:ramload /l");require(contains("CRC16")&&ram_word(0xee1a)==resident_after&&ram_word(0xee1e)==heap_after,"list reuses manager without allocating another resident");
 command("b:ramload b:dupname.rom");require(free_banks()==baseline-1&&contains(reserved==110?"error $02":"error $53"),"duplicate name rollback retains first module");
 // Post-install failures must clear slots in the persistent registry as well.
 for(unsigned k=0;k<sizeof bad/sizeof bad[0];k++){command(bad[k]);require(free_banks()==baseline-1&&ram_word(0xee1a)==resident_after&&ram_word(0xee1e)==heap_after,"failed load reuses its persistent record and releases all temporary resources");}
 if(reserved<110){
  command("b:ramload b:crcalt.rom");require(free_banks()==baseline-2&&contains("Loaded CRCALT"),"second module uses independent bank");
  require(invoke(0xee,2,0x42,0x3000)==0,"nested RAM module -> SWI -> other RAM module");
  require(r[registry+1]==0&&r[registry+144+1]==0,"nested busy counters balanced");
  command("b:ramload /u crcalt");require(free_banks()==baseline-1,"second module unload returns its bank");
 }
 if(baseline>=4){
  command("b:ramload b:third.rom");command("b:ramload b:fourth.rom");command("b:ramload b:fifth.rom");
  require(free_banks()==baseline-4,"all four registry slots usable");command("b:ramload b:crcalt.rom");require(contains("error $54")&&free_banks()==baseline-4,"registry exhaustion allocates no extra bank");
  command("b:ramload /u third");command("b:ramload /u fourth");command("b:ramload /u fifth");require(free_banks()==baseline-1,"all registry slots can be reused after unload");
  command("b:ramload b:lower.rom");require(contains("Loaded CRCLOW"),"ASCII header names are normalized without changing ROM bank");command("b:ramload /u crclow");require(free_banks()==baseline-1,"normalized header name can be unloaded");
 }
 invoke(0x2e,0xed,0,0);unsigned original_gate=result_x;
 invoke(0x2f,0xed,0,0xfff6);command("b:ramload /u crc16");require(contains("error $55")&&free_banks()==baseline-1,"changed service vector prevents freeing its underlying bank");invoke(0x2f,0xed,0,original_gate);
 r[record+1]=1;command("b:ramload /u crc16");require(contains("error $55")&&free_banks()==baseline-1,"active module cannot be unloaded");r[record+1]=0;
 command("b:ramload /u crc16");require(contains("Unloaded CRC16")&&free_banks()==baseline,"unload frees bank after detaching vectors");
 invoke(0x2e,0xed,0,0);require(result_x==0,"original empty service vector restored");
 require(ram_word(0xee1a)==resident_after&&ram_word(0xee1e)==heap_after,"resident registry reused until reset");
 command("b:ramnest");require(contains("Loaded CRC16")&&free_banks()==baseline-1&&ram_word(0xee1a)==resident_after,"a nested PGM can load through the existing registry without pinning its parent");command("b:ramload /u crc16");require(free_banks()==baseline&&ram_word(0xee1e)==heap_after,"nested load/unload retains the original resident footprint");
 if(reserved){word_at(0xec00,0xffff);require(invoke(0xe5,2,0,0x3500)==0&&free_banks()==initial_free,"foreign reservation retained and releasable");word_at(0xec00,owner);}
 command("dir a:");command("dir b:");command("dir c:");require(SP==sp&&!resets&&!fdc_port_accesses,"native DOS continues without stack leak or reset");
 printf("PASS ramloader %s/%s %s: ROM execution, IRQ/nested calls, pin/unload, validation, rollback and compact residency\n",argv[2],argv[3],scenario);
 return 0;
}
