// Real shell parsing/listing and native read-only enforcement on FAT12/FAT16.
#define DOS_PROMPT_CYCLES 500000000
#define DOS_API_CYCLES 500000000
#define PARTITION_FIXTURE 1
#define COMPACT_FIXTURE 1
#define DIRECT_SD_FIXTURE 1
#define ROMDISK_MAIN unused_romdisk_main
#include "test_romdisk_unidos.c"
#undef ROMDISK_MAIN
#include "../build/partitions/kernel_labels.h"

static unsigned mounted(unsigned partition){
 unsigned char*r=MC6800GetCpuRam();unsigned work=r[0xbf80]*256+r[0xbf81];
 for(unsigned j=0;j<r[0xbf82];j++)if(r[work+512+j*24+8]==partition)return work+512+j*24;
 require(0,"partition record exists");return 0;
}
static unsigned path_call(unsigned op,unsigned a,unsigned b,const char*name){
 strcpy((char*)MC6800GetCpuRam()+0x8000,name);return invoke(op,a,b,0x8000);
}
static void list(void){command("cls");command("b:mount /l");}
int main(int argc,char**argv){
 if(argc!=6)return 2;model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");sdsc=!strcmp(argv[4],"sdsc");
 unsigned fat12=!strcmp(argv[5],"fat12"),pool=!strcmp(argv[5],"pool");
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);
 memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load(argv[1],&image_size);committed=1;MC6800Init();MC6800Reset();until(60000000);
 key(0x1c);key(0x1c);prompt_wait();watch_resets=1;
 unsigned char*r=MC6800GetCpuRam();
 list();require(contains("A: SD0:PART2 FAT12 RW")&&contains("B: SD0:PART3 FAT12 RW"),"list preserves boot-selected A/B");
 require(contains(fat12?"C: SD0:PART4 FAT12 RW":"C: SD0:PART4 FAT16 RW"),"list includes native C geometry");
 require(!contains("SD0:PART1"),"list omits unmounted bootstrap");
 if(pool){
  require(contains("D: SD0:PART5 FAT12 RW")&&contains("H: SD0:PART9 FAT12 RW"),"list includes logical partitions and all eight letters");
  command("b:umount h:");command("b:mount sd0:part9 /r");require(contains("Mounted as H"),"read-only logical mount reuses H");
  list();require(contains("H: SD0:PART9 FAT12 RO"),"list reports logical read-only mode");
  printf("PASS mount list pool %s/%s/%s: A..H and logical read-only\n",argv[2],argv[3],argv[4]);return 0;
 }
 command("md c:empty");
 command("b:mount /r sd0:part4");require(contains("SD: error $0F")&&!r[mounted(4)+23],"changing mounted mode requires unmount");
 command("b:umount c:");list();require(!contains("C: SD0:PART4"),"unmounted partition disappears from list");
 command(fat12?"b:mount /r /t:fat12 sd0:part4":"b:mount /t:fat16 /r sd0:part4");
 require(contains("Mounted as C")&&r[mounted(4)+23]==1,"typed read-only mount keeps C");
 command(fat12?"b:mount sd0:part4 /t:fat12 /r":"b:mount sd0:part4 /r /t:fat16");
 require(contains("Mounted as C"),"same mode is idempotent and accepts option order");
 command("b:mount sd0:part4");require(contains("SD: error $0F")&&r[mounted(4)+23]==1,"ordinary remount cannot clear read-only");
 const char*bad[]={"b:mount /l /r","b:mount /l sd0:part4","b:mount /r","b:mount /x sd0:part4","b:mount /r /r sd0:part4","b:mount sd0:part4 sd0:part3","b:mount /t:fat12 /t:fat16 sd0:part4"};
 for(unsigned j=0;j<sizeof bad/sizeof*bad;j++){
  command("cls");command(bad[j]);require(contains("MOUNT [/R]")&&r[mounted(4)+23]==1,"invalid options print usage without remounting");
 }
 list();require(contains(fat12?"C: SD0:PART4 FAT12 RO":"C: SD0:PART4 FAT16 RO"),"list reports read-only C");
 const size_t bytes=262144u*512;unsigned char*snapshot=malloc(bytes);require(snapshot!=NULL,"read-only snapshot allocation");
 memcpy(snapshot,image+40960u*512,bytes);
 // COPY can read the protected volume and write another volume.
 command(fat12?"copy c:wide.bin b:rocopy.bin":"copy c:hichain.bin b:rocopy.bin");
 command("dir b:");require(contains("ROCOPY"),"shell COPY reads a read-only volume");
 command("copy a:datetime.pgm c:denied.pgm");
 command("del b:rocopy.bin");
 require(!memcmp(snapshot,image+40960u*512,bytes),"shell COPY leaves protected volume unchanged");

 // API calls use a separate root stack, outside the shell's keyboard SWI.
 PC=0x212;SP=0x7000;r[0]=0;
 const char*file=fat12?"C:WIDE.BIN":"C:HICHAIN.BIN";
 const char*directory="C:EMPTY";
 unsigned writes=sd_writes;
 require(invoke(0xe1,5,0,0)==0&&r[mounted(4)+23]==1,"rescan preserves read-only record");
 require(invoke(0xeb,3,2,0)==0,"read-only descriptor");unsigned descriptor=result_x;
 require(r[descriptor+3]&4,"descriptor carries write protection");
 image[510]=0;require(invoke(0xe1,5,0,0)==15,"failed rescan rolls back");image[510]=0x55;
 require(r[mounted(4)+23]==1,"rollback retains read-only mode");
 unsigned handle_addresses[10],hp=r[UK_FILE_HANDLES]*256+r[UK_FILE_HANDLES+1];unsigned char handles[10][59];
 for(unsigned j=0;j<10;j++){handle_addresses[j]=hp;memcpy(handles[j],r+hp,59);hp=r[hp]*256+r[hp+1];}
 unsigned header=r[0xeb07]*256+r[0xeb08],open_count=r[header+13];
 strcpy((char*)r+0x8000,file);word_at(0x8100,0x8000);word_at(0x8102,0);
 require(invoke(0x4a,2,0,0x8100)==3&&invoke(0x4a,3,0,0x8100)==3,"OPEN WO/RW refuses read-only");
 require(invoke(0x4b,0,0,0x8100)==3,"CREATE cannot truncate existing file");
 strcpy((char*)r+0x8000,"C:DENIED.PGM");
 require(invoke(0x4b,0,0,0x8100)==3&&invoke(0x6b,0,0,0x8100)==3,"CREATE/new CREATE refuse before claiming cache");
 require(r[header+13]==open_count,"denied opens/creates leave open count unchanged");
 for(unsigned j=0;j<10;j++)require(!memcmp(handles[j],r+handle_addresses[j],59),"denied opens/creates leave each handle unchanged");
 require(path_call(0x4f,0,0,file)==3,"DELETE refused");
 require(path_call(0x48,0,0,"C:NEWDIR")==3&&path_call(0x49,0,0,directory)==3,"MD/RD refused");
 require(path_call(0x54,1,0,file)==3&&path_call(0x54,0,0,file)==0,"setting attributes refused, reading allowed");
 strcpy((char*)r+0x8000,file);strcpy((char*)r+0x8040,"C:RENAMED.BIN");word_at(0x8100,0x8000);word_at(0x8102,0x8040);
 require(invoke(0x56,0,0,0x8100)==3,"RENAME refused");
 word_at(descriptor+26,2);word_at(descriptor+28,0);
 require(invoke(0xe9,2,0,descriptor)==3&&invoke(0xe9,8,0,descriptor)==3,"FAT update/allocation refused");
 word_at(0x8100,0x4000);r[0x8102]=2;word_at(0x8103,0);
 require(invoke(0x40,2,0,0x8100)==3,"legacy relative-sector write refused");
 word_at(0x8103,0);word_at(0x8105,0x10000-1);
 require(invoke(0xea,2,0,0x8100)==3&&invoke(0xe1,9,0,0x8100)==3,"full 32-bit sector write refused");
 require(invoke(0xea,1,0,0x8100)==0,"full-sector read allowed");
 memset(r+0x6000,0,517);r[0x6200]=255;
 strcpy((char*)r+0x8000,file);word_at(0x8100,0x8000);word_at(0x8102,0x6000);
 require(invoke(0x4a,1,0,0x8100)==0,"read-only OPEN allowed");unsigned h=result_b;
 require(invoke(0xe1,3,4,0)==15,"read handle prevents unmount");
 word_at(0x8100,0x4000);word_at(0x8102,32);
 require(invoke(0x4c,h,0,0x8100)==0&&result_x==32,"READ allowed");
 size_t expected_size;unsigned char*expected=load(fat12?"build/fat16/wide12.expected":"build/fat16/high.expected",&expected_size);
 require(expected_size>=32&&!memcmp(r+0x4000,expected,32),"read-only custom-buffer data matches oracle");free(expected);
 require(invoke(0x4d,h,0,0x8100)!=0&&invoke(0x6c,h,0,0)!=0,"read handle cannot WRITE/TRUNCATE");
 hp=r[UK_FILE_HANDLES]*256+r[UK_FILE_HANDLES+1];for(unsigned j=0;j<h;j++)hp=r[hp]*256+r[hp+1];
 unsigned char handle_before[59];memcpy(handle_before,r+hp,59);
 word_at(0x8120,0x4a21);word_at(0x8122,0x4200);
 require(invoke(0x55,1,h,0x8120)==3&&!memcmp(handle_before,r+hp,59),"SET date/time refused before modifying the read handle");
 require(invoke(0x55,0,h,0x8128)==0,"GET date/time allowed");
 require(invoke(0x5a,h,0,0)==0&&invoke(0x4e,h,0,0)==0,"read handle COMMIT/CLOSE stay clean");
 require(invoke(0x44,2,0,0)==0,"select read-only current drive");
 require(path_call(0x48,0,0,"DENIED")==3&&path_call(0x4f,0,0,file+2)==3,"implicit current-drive mutations refused");
 require(invoke(0x44,0,0,0)==0,"restore current drive before unmount");
 require(invoke(0xeb,2,2,0)==0,"no dirty metadata left by failed mutations");
 require(sd_writes==writes&&!memcmp(snapshot,image+40960u*512,bytes),"protected volume is byte-identical with zero sector writes");free(snapshot);
 require(invoke(0xe1,3,4,0)==0&&invoke(0xe1,2,4,0)==0&&result_b==2,"unmount/remount restores RW at C");
 require(!r[mounted(4)+23]&&invoke(0xeb,3,2,0)==0&&!(r[result_x+3]&4),"RW mount clears both protection flags");
 strcpy((char*)r+0x8000,"C:ALLOWED.PGM");word_at(0x8100,0x8000);word_at(0x8102,0);
 require(invoke(0x4b,0,0,0x8100)==0,"CREATE works after RW remount");h=result_b;
 require(invoke(0x55,1,h,0x8120)==0&&invoke(0x55,0,h,0x8128)==0&&!memcmp(r+0x8120,r+0x8128,4),"SET/GET date/time works after RW remount");
 require(invoke(0x4e,h,0,0)==0&&path_call(0x4f,0,0,"C:ALLOWED.PGM")==0,"RW close/delete recover");
 require(!resets&&!fdc_port_accesses,"no resets/CHS/FDC accesses");
 printf("PASS mount FAT%u %s/%s/%s: /R, /L, option order/errors, API/sector protection, rescan, zero writes, RW recovery\n",fat12?12:16,argv[2],argv[3],argv[4]);return 0;
}
