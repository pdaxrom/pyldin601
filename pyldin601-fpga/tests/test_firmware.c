// Execute real MC6800 firmware against a byte-level SPI SD model, no FAT helper.
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include "core/mc6800.h"
#include "core/i8272.h"
#include "core/keyboard.h"
static unsigned char resident[8192],physical[2*1024*1024],config[96];
static unsigned char *image;static size_t image_size;
static uint32_t physical_address,crc=0xffffffff,disk_address;
static unsigned config_index,rom_writes,all_writes,committed,error,debug;
static unsigned sram_fault,aperture_reads;static unsigned char aperture_byte;
static unsigned spi_control=0x23,spi_low=255,spi_high=255,spi_div,spi_pout,spi_pending;
static unsigned missing_sd,seen_stages,video_mode,screen_checked;
static unsigned sdsc,sd_idle=1,sd_commands,sd_reads,spi_transfers,sd_mode;
static unsigned char cmd[6],queue[520];static unsigned cmd_index,queue_count,queue_pos;
static unsigned char page,crtc_index,crtc[16],tick;
static unsigned fdc_reads;
static unsigned caps_off=1;
static unsigned model_a,cpu_hd,menu_phase,menu_key[2],menu_key_sent[2],boot_tick_number;
static uint32_t menu_start_cycles[2],menu_end_cycles[2];
static unsigned boot_speed,setup_script[64],setup_length,setup_position,setup_release,sd_writes;
static unsigned sd_write_phase,sd_write_count,sd_write_lba,sd_write_crc,sd_received_crc;
static unsigned sd_deny_write,setup_error_exit;
static unsigned setup_frequency,setup_frequency_left;
static unsigned sd_busy_active,sd_busy_reads,sd_busy_remaining,sd_busy_transition,sd_busy_tail;
static unsigned sd_cmd0_count,sd_startup_clocks,sd_cmd0_silent,sd_cmd8_silent,sd_cmd55_silent,sd_acmd_silent;
static unsigned sd_init_reject,sd_init_never,sd_bad_r7,sd_reply_delay,sd_tick_stopped;
static uint32_t sd_power_ready_cycles,sd_first_cmd0_cycles,sd_first_acmd_cycles,sd_acmd_delay_cycles;
static unsigned char sd_write_data[512];
static void setup_keys(unsigned a,unsigned hd,unsigned save){
 setup_script[setup_length++]=0xf9;
 if(a)setup_script[setup_length++]=0xc2;
 setup_script[setup_length++]=0xc3;
 if(hd)setup_script[setup_length++]=0xc2;
 setup_script[setup_length++]=0xc3;
 for(unsigned n=0;n<setup_frequency;n++)setup_script[setup_length++]=setup_frequency_left?0xc1:0xc2;
 setup_script[setup_length++]=0xc3;
 if(!save)setup_script[setup_length++]=0xc3;
 setup_script[setup_length++]=0xc0;
}
static int screen_is(unsigned address,const char*text){
 unsigned char*r=MC6800GetCpuRam();
 for(unsigned n=0;text[n];n++)if(r[address+n*(model_a?2:1)+model_a]!=(unsigned char)text[n])return 0;
 return 1;
}
static uint16_t le16(const unsigned char*p){return p[0]|p[1]<<8;}
static uint32_t le32(const unsigned char*p){return le16(p)|(uint32_t)le16(p+2)<<16;}
static uint32_t crc_byte(uint32_t c,unsigned char b){c^=b;for(int n=0;n<8;n++)c=c&1?(c>>1)^0xedb88320:c>>1;return c;}
static void screen_dump(const char*path){FILE*f=fopen(path,"wb");if(!f||fwrite(MC6800GetCpuRam()+0x400,1,960,f)!=960)exit(1);fclose(f);}
static void sd_command(void){
 unsigned op=cmd[0]&63;uint32_t arg=(uint32_t)cmd[1]<<24|(uint32_t)cmd[2]<<16|cmd[3]<<8|cmd[4];
 if(!screen_checked){
  if(video_mode||crtc[1]!=(model_a?80:40)||crtc[6]!=(model_a?12:24)||crtc[10]!=0x20||crtc[12]!=4||crtc[13]
   ||!screen_is(0x400,model_a?"PYLDIN-601A SYSTEM INITIALIZATION":"PYLDIN-601 SYSTEM INITIALIZATION")
   ||!screen_is(0x450,"STEP 01: INITIALIZING SD")){
   fprintf(stderr,"boot text screen not initialized before SD\n");exit(1);
  }screen_checked=1;
 }
 sd_commands++;queue_pos=0;queue_count=1;queue[0]=sd_idle?1:0;
 if(op==0||op==8||op==55||op==41||op==58||op==16){if(spi_div!=29){fprintf(stderr,"SD initialization exceeded 400 kHz\n");exit(1);}}
 if(op==0){
  if(!sd_cmd0_count){sd_first_cmd0_cycles=MC6800GetCyclesCounter();if(sd_startup_clocks<74){fprintf(stderr,"missing startup clocks\n");exit(1);}}
  sd_cmd0_count++;
  if(cmd[5]!=0x95){fprintf(stderr,"CMD0 CRC\n");exit(1);}
  if(MC6800GetCyclesCounter()<sd_power_ready_cycles||sd_init_never==1||sd_cmd0_silent){if(sd_cmd0_silent)sd_cmd0_silent--;queue_count=0;return;}
 }
 if(op==8&&sd_cmd8_silent){sd_cmd8_silent--;queue_count=0;return;}
 if(op==55&&sd_cmd55_silent){sd_cmd55_silent--;queue_count=0;return;}
 if(op==41&&sd_acmd_silent){sd_acmd_silent--;queue_count=0;return;}
 switch(op){
 case 0:sd_idle=1;queue[0]=1;break;
 case 8:if(sdsc)queue[0]=5;else{queue[0]=1;queue[1]=0;queue[2]=0;queue[3]=1;queue[4]=sd_bad_r7?0xab:0xaa;queue_count=5;}break;
 case 55:break;
 case 41:if(!sd_first_acmd_cycles)sd_first_acmd_cycles=MC6800GetCyclesCounter();
  if(sd_init_never==2||MC6800GetCyclesCounter()-sd_first_acmd_cycles<sd_acmd_delay_cycles)queue[0]=1;
  else{sd_idle=0;queue[0]=0;}break;
 case 58:queue[0]=0;queue[1]=sdsc?0x80:0xc0;queue[2]=0xff;queue[3]=0x80;queue[4]=0;queue_count=5;break;
 case 16:if(arg!=512)queue[0]=4;break;
 case 17:{uint32_t lba=sdsc?arg/512:arg;sd_reads++;
  if((uint64_t)lba*512+512>image_size){queue[0]=0x20;break;}
  queue[0]=0;queue[1]=255;queue[2]=0xfe;memcpy(queue+3,image+lba*512,512);unsigned c=0;for(unsigned i=0;i<512;i++){c^=queue[3+i]<<8;for(unsigned bit=0;bit<8;bit++)c=c&0x8000?(c<<1)^0x1021:c<<1;c&=65535;}queue[515]=c>>8;queue[516]=c;queue_count=517;break;}
 case 24:sd_write_lba=sdsc?arg/512:arg;sd_write_phase=1;break;
 default:queue[0]=4;
 }
 if(sd_reply_delay&&op!=17&&op!=24){memmove(queue+sd_reply_delay,queue,queue_count);memset(queue,255,sd_reply_delay);queue_count+=sd_reply_delay;}
}
static unsigned char transfer(unsigned char d){
 spi_transfers++;if(spi_control&2){if(!sd_cmd0_count&&spi_div==29&&d==255)sd_startup_clocks+=8;return 255;}if(missing_sd)return 255;
 if(queue_pos<queue_count)return queue[queue_pos++];
 if(sd_busy_active){
  if(sd_busy_remaining){sd_busy_remaining--;return 0;}
  if(sd_busy_tail){unsigned b=sd_busy_tail;sd_busy_tail=0;return b;}
  sd_busy_active=0;return 255;
 }
 if(sd_write_phase){
  if(sd_write_phase==1){if(d==0xfe){sd_write_phase=2;sd_write_count=sd_write_crc=0;}return 255;}
  if(sd_write_phase==2){sd_write_data[sd_write_count++]=d;sd_write_crc^=d<<8;for(unsigned bit=0;bit<8;bit++)sd_write_crc=sd_write_crc&0x8000?(sd_write_crc<<1)^0x1021:sd_write_crc<<1;sd_write_crc&=65535;if(sd_write_count==512)sd_write_phase=3;return 255;}
  if(sd_write_phase==3){sd_received_crc=d<<8;sd_write_phase=4;return 255;}
  sd_received_crc|=d;if(sd_received_crc!=sd_write_crc||(uint64_t)sd_write_lba*512+512>image_size){fprintf(stderr,"bad CMD24 CRC/address\n");exit(1);}
  if(!sd_deny_write){memcpy(image+sd_write_lba*512,sd_write_data,512);sd_writes++;}sd_write_phase=0;
  queue_pos=0;queue_count=1;queue[0]=sd_deny_write?0x0d:5;
  sd_busy_active=!sd_deny_write;sd_busy_remaining=sd_busy_reads?sd_busy_reads:2;sd_busy_tail=sd_busy_transition?(1u<<sd_busy_transition)-1:0;return 255;
 }
 if(!cmd_index){if((d&0xc0)!=0x40)return 255;cmd[cmd_index++]=d;return 255;}
 cmd[cmd_index++]=d;if(cmd_index==6){cmd_index=0;sd_command();}return 255;
}
byte*allocateCpuRam(dword size){return calloc(1,size);}
int SuperIoInit(void){return 0;}int SuperIoFinish(void){return 0;}
void SuperIoReset(void){page=0;disk_address=0;crtc_index=0;memset(crtc,0,sizeof(crtc));tick=0;KBDReset();}
void SuperIoUpdate(void){KBDUpdate();}
void SuperIoPs2KeyDown(unsigned n){}void SuperIoPs2KeyUp(unsigned n){}
void SuperIoPs2ModKeyDown(byte n){}void SuperIoPs2ModKeyUp(byte n){}
void resetRequested(void){}
int SWIemulator(int n,byte*a,byte*b,word*x,byte*t,word*pc){return 0;}
byte i8272ReadByte(byte a);void i8272WriteByte(byte a,byte d);
int SuperIoReadByte(word a,byte*out){
#ifdef HG_FIXTURE
 if(hg_read_byte(a,out))return 1;
#endif
 if(a>=0xe680&&a<=0xe682){*out=0;return 1;}
 if(a==0xe683){*out=physical[0x80000+disk_address];disk_address=(disk_address+1)&0x7ffff;return 1;}
 if(a==0xe600||a==0xe604){*out=crtc_index;return 1;}
 if(a==0xe601||a==0xe605){*out=crtc[crtc_index&15];return 1;}
 if(a>=0xf000){*out=committed?physical[0x60000+a-0xf000]:resident[a-0xf000];return 1;}
 if(!committed&&a>=0xd000&&a<0xe000){*out=resident[4096+a-0xd000];return 1;}
 if(committed&&a>=0xc000&&a<0xe000&&(page&8)){*out=physical[0x10000+(page>>4)%5*65536+(page&7)*8192+a-0xc000];return 1;}
 if(a>=0xe660&&a<=0xe664){switch(a&7){case 0:*out=spi_high;break;case 1:*out=spi_low;break;case 2:*out=0x80|spi_control;break;case 3:*out=spi_div;break;default:*out=spi_pout;}return 1;}
 if(a>=0xe6a0&&a<=0xe6af){unsigned p=a&15;*out=255;
  if(p==0)*out=(committed?0x80:0)|(cpu_hd<<1)|model_a;else if(p==1)*out=debug;else if(p==8)*out=error?128:0;
  else if(p==11)*out=aperture_byte;
  else if(p>=12)*out=(crc^0xffffffff)>>((p-12)*8);return 1;}
 if(!committed&&a==0xe62b){
  unsigned number=MC6800GetCyclesCounter()/80000;
  *out=0x37|(!sd_tick_stopped&&number!=boot_tick_number?128:0);boot_tick_number=number;
  if(!menu_start_cycles[0]&&screen_is(0x400,"PYLDIN SYSTEM BIOS"))menu_start_cycles[0]=MC6800GetCyclesCounter();return 1;
 }
 if(a==0xe628||a==0xe62a||a==0xe62e){
  KBDUpdate();
  if(!committed&&a==0xe628){
   if(setup_error_exit&&setup_position==setup_length&&screen_is(0x630,"SAVE FAILED - CHECK SD")){setup_script[setup_length++]=0xc3;setup_script[setup_length++]=0xc0;setup_error_exit=0;}
   if(setup_release){setup_release=0;*out=255;return 1;}
   if(setup_position<setup_length){*out=setup_script[setup_position++];setup_release=1;return 1;}
   *out=255;return 1;
  }
  *out=a==0xe628?KBDReadKey():KBDCheckKey()|0x37|(caps_off?8:0);return 1;
 }
 if(committed){switch(a){
  case 0xe600:case 0xe604:*out=crtc_index;return 1;
  case 0xe601:case 0xe605:*out=crtc[crtc_index&15];return 1;
  case 0xe628:*out=KBDReadKey();return 1;case 0xe62a:case 0xe62e:*out=KBDCheckKey()|0x37|(caps_off?8:0);return 1;
  case 0xe62b:*out=tick|0x37;tick=0;return 1;
  case 0xe632:*out=0x80;return 1;
  case 0xe6c0:case 0xe6d0:case 0xe6d1:*out=i8272ReadByte(a&31);return 1;
 }}return 0;
}
int SuperIoWriteByte(word a,byte d){
#ifdef HG_FIXTURE
 if(hg_write_byte(a,d))return 1;
#endif
 if(a==0xe680){disk_address=(disk_address&0xffff)|((d&7)<<16);return 1;}
 if(a==0xe681){disk_address=(disk_address&0x700ff)|(d<<8);return 1;}
 if(a==0xe682){disk_address=(disk_address&0x7ff00)|d;return 1;}
 if(a==0xe683){physical[0x80000+disk_address]=d;disk_address=(disk_address+1)&0x7ffff;return 1;}
 if(a==0xe600||a==0xe604){crtc_index=d;return 1;}
 if(a==0xe601||a==0xe605){crtc[crtc_index&15]=d;return 1;}
 if(a==0xe629){video_mode=d&0x20;KBDSetCyrMode((d&1)?0:4);MC6800GetCpuRam()[a]=d;MC6800GetCpuRam()[0xe62d]=d;return 1;}
 if(a>=0xe660&&a<=0xe664){switch(a&7){
 case 0:spi_high=d;spi_pending=1;break;
 case 1:if(spi_control&16){if(spi_pending){spi_high=transfer(spi_high);spi_low=transfer(d);spi_pending=0;}}else spi_low=transfer(d);break;
 case 2:if((d^spi_control)&2){cmd_index=queue_count=queue_pos=0;}spi_control=d&0x33;if(!(d&16))spi_pending=0;break;
 case 3:spi_div=d;break;case 4:spi_pout=d&3;break;}return 1;}
 if(a>=0xe6a0&&a<=0xe6af&&!committed){unsigned p=a&15;
  if(p==1){
   if(d>=1&&d<=12)seen_stages|=1u<<d;
   if(d==7){if(!screen_is(0x4a0,"BLOCK 05/05")){fprintf(stderr,"ROM block progress failed\n");exit(1);}screen_dump("build/boot-status-screen.bin");}
   if(d==12){
    if(!screen_is(0x4a0,"BLOCK 08/08")){fprintf(stderr,"electronic disk progress missing\n");exit(1);}
    if(sram_fault)physical[0x31234]^=0x80;
   }
   debug=d;
  }else if(p==2)sd_mode=d;
  else if(p==3){if(config_index<96)config[config_index++]=d;else error=1;}
  else if(p>=4&&p<=6){unsigned shift=(p-4)*8;physical_address=(physical_address&~(255u<<shift))|(unsigned)d<<shift;}
  else if(p==7){if(physical_address>=sizeof(physical)){error=1;return 1;}
   if(physical_address<65536)MC6800GetCpuRam()[physical_address]=d;else physical[physical_address]=d;
   if(physical_address>=0x10000&&physical_address<0x61800)rom_writes++;physical_address++;all_writes++;}
  else if(p==11){if(physical_address>=sizeof(physical)){error=1;return 1;}
   aperture_byte=physical_address<65536?MC6800GetCpuRam()[physical_address]:physical[physical_address];physical_address++;aperture_reads++;}
  else if(p==9)crc=crc_byte(crc,d);else if(p==10)crc=0xffffffff;
  else if(p==0){if(d<=15&&config_index==0){model_a=d&1;cpu_hd=(d>>1)&1;boot_speed=d>>2;menu_end_cycles[menu_phase++]=MC6800GetCyclesCounter();return 1;}if(d!=0xa5||error||config_index!=96||memcmp(config,"P601BOOT",8)
   ||config[25]!=model_a||le32(config+8)!=1||le32(config+12)!=0x10000||le32(config+16)!=0x51800
   ||le32(config+20)!=(crc^0xffffffff)||(spi_control&2)==0)error=1;else{committed=1;MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);}}
  return 1;
 }
 if(committed)switch(a){
 case 0xe62a:case 0xe62e:caps_off=(d&8)!=0;return 1;
 case 0xe6f0:page=d;break;
 case 0xe600:case 0xe604:crtc_index=d;return 1;
 case 0xe601:case 0xe605:crtc[crtc_index&15]=d;return 1;
 case 0xe6c0:case 0xe6d0:case 0xe6d1:i8272WriteByte(a&31,d);return 1;
 }return 0;
}
int FloppyInit(void){return 0;}int FloppyStatus(int Disk){return 0;}
static int floppy_sector(int disk,int track,int sector,int head,unsigned char*data,int write){
 unsigned off=32+disk*16,start=le32(config+off),len=le32(config+off+4),spt=le16(config+off+8),heads=le16(config+off+10);
 if(track<0||track>=80||sector<1||sector>spt||head<0||head>=heads)return 0x40;
 unsigned rel=(track*heads+head)*spt+sector-1;if(rel>=len||(uint64_t)(start+rel)*512+512>image_size)return 0x40;
 if(write)memcpy(image+(start+rel)*512,data,512);else{memcpy(data,image+(start+rel)*512,512);fdc_reads++;}return 0;
}
int FloppyReadSector(int D,int T,int S,int H,unsigned char*d){return floppy_sector(D,T,S,H,d,0);}
int FloppyWriteSector(int D,int T,int S,int H,unsigned char*d){return floppy_sector(D,T,S,H,d,1);}
int FloppyFormatTrack(int D,int T,int H){return 0;}
#include "core/mc6800.c"
#include "core/i8272.c"
#include "core/keyboard.c"
static unsigned char*load(const char*path,size_t*size){FILE*f=fopen(path,"rb");if(!f){perror(path);exit(1);}fseek(f,0,SEEK_END);*size=ftell(f);rewind(f);unsigned char*p=malloc(*size);if(fread(p,1,*size,f)!=*size)exit(1);fclose(f);return p;}
int main(int argc,char**argv){
 if(argc<3)return 2;size_t n;unsigned char*b=load(argv[1],&n);if(n!=8192)return 2;memcpy(resident,b,n);free(b);
 image=load(argv[2],&image_size);sdsc=argc>3&&(!strcmp(argv[3],"sdsc")||!strcmp(argv[3],"save-sdsc")||!strcmp(argv[3],"save-sdsc-busy"));missing_sd=argc>3&&!strcmp(argv[3],"no-sd");sram_fault=argc>3&&!strcmp(argv[3],"sram-fault");unsigned reject=missing_sd||sram_fault||(argc>3&&!strcmp(argv[3],"reject"));
 if(argc>3){unsigned a=!strcmp(argv[3],"601a")||!strcmp(argv[3],"601a-reject")||!strcmp(argv[3],"601a-hd6303");unsigned hd=!strcmp(argv[3],"hd6303")||!strcmp(argv[3],"601a-hd6303");if(a||hd)setup_keys(a,hd,0);if(!strcmp(argv[3],"save"))setup_keys(1,1,1);if(!strcmp(argv[3],"exit")){setup_script[setup_length++]=0xf9;setup_script[setup_length++]=0xc2;setup_script[setup_length++]=0x1b;}if(!strcmp(argv[3],"setup-default")){setup_script[setup_length++]=0xc4;setup_script[setup_length++]=0xc0;}if(!strcmp(argv[3],"601a-reject"))reject=1;}
 if(argc>3&&!strcmp(argv[3],"save-sdsc"))setup_keys(1,1,1);
 if(argc>3&&!strcmp(argv[3],"save8")){setup_frequency=3;setup_keys(1,1,1);}
 if(argc>3&&!strcmp(argv[3],"save-left")){setup_frequency=1;setup_frequency_left=1;setup_keys(1,1,1);}
 if(argc>3&&!strcmp(argv[3],"save-denied")){setup_keys(1,1,1);sd_deny_write=1;setup_error_exit=1;}
 if(argc>3&&!strcmp(argv[3],"save-readonly")){setup_keys(1,1,1);setup_error_exit=1;}
 if(argc>3&&!strcmp(argv[3],"save-busy-transition")){setup_keys(1,1,1);sd_busy_transition=1;}
 if(argc>3&&!strcmp(argv[3],"save-busy-long")){setup_keys(1,1,1);sd_busy_transition=7;sd_busy_reads=4096;}
 if(argc>3&&!strcmp(argv[3],"save-sdsc-busy")){setup_keys(1,1,1);sd_busy_transition=5;}
 if(argc>3&&!strncmp(argv[3],"save-busy-",10)&&argv[3][10]>='1'&&argv[3][10]<='7'&&argv[3][11]==0){setup_keys(1,1,1);sd_busy_transition=argv[3][10]-'0';}
 if(argc>3&&!strcmp(argv[3],"init-late-power"))sd_power_ready_cycles=2800000;
 if(argc>3&&!strcmp(argv[3],"init-cmd0-retry"))sd_cmd0_silent=3;
 if(argc>3&&!strcmp(argv[3],"init-cmd8-retry"))sd_cmd8_silent=2;
 if(argc>3&&!strcmp(argv[3],"init-app-retry")){sd_cmd55_silent=2;sd_acmd_silent=2;}
 if(argc>3&&!strcmp(argv[3],"init-long-idle"))sd_acmd_delay_cycles=6000000;
 if(argc>3&&!strcmp(argv[3],"init-sdsc-idle")){sdsc=1;sd_acmd_delay_cycles=1600000;}
 if(argc>3&&!strcmp(argv[3],"init-last-r1"))sd_reply_delay=31;
 if(argc>3&&!strcmp(argv[3],"init-cmd0-timeout")){sd_init_never=1;sd_init_reject=reject=1;}
 if(argc>3&&!strcmp(argv[3],"init-acmd-timeout")){sd_init_never=2;sd_init_reject=reject=1;}
 if(argc>3&&!strcmp(argv[3],"init-bad-r7")){sd_bad_r7=1;sd_init_reject=reject=1;}
 if(argc>3&&!strcmp(argv[3],"init-no-tick")){sd_tick_stopped=1;sd_init_reject=reject=1;}
 MC6800SetMachine(PYLDIN_MACHINE_HD6303);MC6800Init();memset(physical,0xcc,sizeof(physical));memset(MC6800GetCpuRam(),0xcc,65536);MC6800Reset();
 unsigned steps;for(steps=0;steps<100000000&&!committed&&debug!=0xee;steps++)MC6800Step();
 if(!missing_sd&&!sd_init_reject&&menu_phase!=1){fprintf(stderr,"BIOS configuration was not applied pc=%04x debug=%02x; SD writes=%u; save-error=%d\n",PC,debug,sd_writes,screen_is(0x630,"SAVE FAILED - CHECK SD"));return 1;}
 if(!setup_length&&!missing_sd&&!sd_init_reject){unsigned elapsed=menu_end_cycles[0]-menu_start_cycles[0];if(elapsed<39920000||elapsed>40100000){fprintf(stderr,"BIOS timeout not 10 seconds: %u cycles\n",elapsed);return 1;}}
 if(argc>3&&!strcmp(argv[3],"save")&&!sd_writes){fprintf(stderr,"SAVE did not write SD\n");return 1;}
 if(argc>3&&!strcmp(argv[3],"exit")&&(model_a||cpu_hd||boot_speed||sd_writes)){fprintf(stderr,"EXIT did not discard changes\n");return 1;}
 if(reject){
  char message[40];snprintf(message,sizeof(message),"BOOT ERROR AT STEP %02X",MC6800GetCpuRam()[0x18a]);
  if(committed||debug!=0xee||crtc[1]!=(model_a?80:40)||crtc[6]!=(model_a?12:24)||crtc[12]!=4
   ||!screen_is(0x4f0,message)
   ||!screen_is(0x590,"PRESS RESET TO RETRY")){
   fprintf(stderr,"bad ROM accepted/stalled or missing text error pc=%04x error=%u\n",PC,error);return 1;
  }screen_dump("build/boot-error-screen.bin");
  if(sram_fault&&(aperture_reads!=0x51800||MC6800GetCpuRam()[0x18a]!=12)){fprintf(stderr,"SRAM fault not rejected by readback\n");return 1;}
  if((missing_sd||sd_init_reject)&&(MC6800GetCpuRam()[0x18a]!=1||sd_reads||sd_writes||rom_writes||spi_control!=0x23)){fprintf(stderr,"init failure did not stop before disks/ROM with CS high\n");return 1;}
  uint32_t elapsed=MC6800GetCyclesCounter()-(sd_init_never==2?sd_first_acmd_cycles:sd_first_cmd0_cycles);
  if(sd_init_never&&(elapsed<8000000||elapsed>8400000)){fprintf(stderr,"init timeout not two seconds: %u cycles\n",elapsed);return 1;}
  printf("PASS CPU/SPI boot rejects %s and displays %s; init-time=%u cycles; CMD0 attempts=%u\n",missing_sd?"missing SD":sd_init_reject?"SD initialization fault":sram_fault?"corrupted SRAM after valid SD CRC":"damaged ROM/FAT",message,elapsed,sd_cmd0_count);return 0;
 }
 if(sd_first_cmd0_cycles<1200000){fprintf(stderr,"CMD0 sent before 300 ms power delay: %u cycles\n",sd_first_cmd0_cycles);return 1;}
 if(sd_acmd_delay_cycles&&MC6800GetCyclesCounter()-sd_first_acmd_cycles<sd_acmd_delay_cycles){fprintf(stderr,"ACMD41 ignored real-time readiness\n");return 1;}
 if(!committed||error||rom_writes!=0x51800||sd_reads<650){fprintf(stderr,"boot failure pc=%04x err=%u debug=%02x writes=%u steps=%u SD reads=%u commands=%u\n",PC,error,debug,rom_writes,steps,sd_reads,sd_commands);return 1;}
 if(seen_stages!=0x1ffe||!screen_checked||aperture_reads!=0x51800){fprintf(stderr,"missing boot text stages/readback mask=%x reads=%u\n",seen_stages,aperture_reads);return 1;}
 for(unsigned a=0x80000;a<0x100000;a++)if(physical[a]!=0){fprintf(stderr,"electronic disk not initialized at %x\n",a);return 1;}
 size_t reference_size;unsigned char*reference=load(model_a?"build/rom-a.reference":"build/rom.reference",&reference_size);
 if(reference_size!=0x51a00||memcmp(physical+0x10000,reference+512,0x51800)){fprintf(stderr,"physical ROM content mismatch\n");return 1;}free(reference);
 unsigned reset_vector=physical[0x60ffe]*256+physical[0x60fff];
 for(unsigned n=0;n<10&&PC!=reset_vector;n++)MC6800Step();
 if(PC!=reset_vector){fprintf(stderr,"handoff failed pc=%04x expected=%04x\n",PC,reset_vector);return 1;}
 for(unsigned n=0;n<200000;n++){if(n%10000==0){tick=128;MC6800SetInterrupt(1);}MC6800Step();}
 unsigned reads=sd_reads,writes=all_writes;physical[0x81234]=0x5a;
 unsigned saved_model=model_a,saved_cpu=cpu_hd;MC6800Reset();if(cpu_hd!=saved_cpu||MC6800GetMachine()!=(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601)||model_a!=saved_model||PC!=reset_vector||!committed||physical[0x81234]!=0x5a){fprintf(stderr,"warm reset failed\n");return 1;}
 for(unsigned n=0;n<1000;n++)MC6800Step();
 if(reads!=sd_reads||writes!=all_writes||physical[0x81234]!=0x5a){fprintf(stderr,"warm reload/memory loss\n");return 1;}
 if(argc>3&&!strcmp(argv[3],"init-reload")){
  unsigned commands_before=sd_cmd0_count;
  // Reset the FPGA/CPU registers while retaining CPU RAM, ROM SRAM, card
  // power, card protocol state and all disk sectors.
  if(sd_idle||sd_write_phase||sd_busy_active)return 1;
  committed=error=debug=config_index=model_a=cpu_hd=boot_speed=0;
  crc=0xffffffff;physical_address=0;memset(config,0,sizeof(config));
  spi_control=0x23;spi_div=29;spi_pending=0;
  spi_low=spi_high=255;cmd_index=queue_count=queue_pos=0;
  boot_tick_number=MC6800GetCyclesCounter()/80000;screen_checked=0;
  MC6800SetMachine(PYLDIN_MACHINE_HD6303);MC6800Reset();
  for(unsigned n=0;n<2000000&&debug<2;n++)MC6800Step();
  if(debug!=2||sd_idle||sd_cmd0_count!=commands_before+1||sd_reads!=reads
   ||physical[0x81234]!=0x5a){fprintf(stderr,"powered SD reload failed PC=%04x debug=%02x phase=%02x CMD=%02x R1=%02x\n",PC,debug,MC6800GetCpuRam()[0x193],MC6800GetCpuRam()[0x144],MC6800GetCpuRam()[0x146]);return 1;}
  printf("PASS full reset reinitializes powered SD before FAT/ROM reload; retained RAM and disks unchanged\n");
 }
 if(argc>4){FILE*f=fopen(argv[4],"wb");if(!f||fwrite(image,1,image_size,f)!=image_size||fclose(f))return 1;}
 printf("PASS selectable CPU software SD/FAT boot (%s): %u steps, %u SPI commands, %u sectors; BIOS executed; 512KiB electronic disk initialized; warm reset keeps ROM/disk; FDC reads=%u; settings=%u/%u/%uMHz, SD writes=%u\n",sdsc?"SDSC":"SDHC",steps,sd_commands,sd_reads,fdc_reads,model_a,cpu_hd,1u<<boot_speed,sd_writes);
 return 0;
}
