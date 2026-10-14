// Real keyboard/shell front ends, separate from the file API mutation fixture.
#define DOS_PROMPT_CYCLES 500000000
#define PARTITION_FIXTURE 1
#define COMPACT_FIXTURE 1
#define DIRECT_SD_FIXTURE 1
#define ROMDISK_MAIN unused_romdisk_main
#include "test_romdisk_unidos.c"
#undef ROMDISK_MAIN
int main(int argc,char**argv){
 if(argc!=5&&argc!=6)return 2;model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");sdsc=!strcmp(argv[4],"sdsc");
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);
 memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load(argv[1],&image_size);
 if(argc==5||(argc==6&&!strcmp(argv[5],"resize-overlap"))){
  size_t old=image_size;image_size+=16384u*512;image=realloc(image,image_size);require(image!=NULL,"tools fixture allocation");memset(image+old,0,image_size-old);
 }
 if(argc==6&&!strcmp(argv[5],"resize-overlap")){
  image[450]=0xda;image[498]=15;
  for(unsigned i=0;i<4;i++){image[454+i]=296000u>>(i*8);image[458+i]=1024u>>(i*8);image[506+i]=253952u>>(i*8);}
  memset(image+40960u*512+446,0,64);
 }
 committed=1;MC6800Init();MC6800Reset();until(60000000);
 key(0x1c);key(0x1c);prompt_wait();watch_resets=1;
 if(argc==6&&!strcmp(argv[5],"overwrite")){
  unsigned char *a_before=malloc(1440u*512);require(a_before!=NULL,"source volume snapshot");memcpy(a_before,image+34816u*512,1440u*512);
  command("copy a:datetime.pgm b:fdisk.pgm");require(contains("1 File(s) copied")&&!contains("File creation failure"),"COPY overwrites existing FAT12 file on its own volume");
  command("copy a:datetime.pgm c:hichain.bin");require(contains("1 File(s) copied")&&!contains("File creation failure"),"COPY overwrites existing high-cluster FAT16 file");
  require(!memcmp(a_before,image+34816u*512,1440u*512),"overwrite never frees or changes source volume FAT/data");free(a_before);
  PC=0x212;SP=0x7000;MC6800GetCpuRam()[0]=0;
  size_t bytes;unsigned char *expected=load("build/fat16/datetime.expected",&bytes);
  file_check("B:FDISK.PGM",expected,bytes);file_check("C:HICHAIN.BIN",expected,bytes);free(expected);
  require(!resets&&!fdc_port_accesses,"overwrite has no reset or floppy access");
  FILE *f=fopen("build/fat16/overwrite.img","wb");require(f&&fwrite(image+40960u*512,1,262144u*512,f)==262144u*512&&!fclose(f),"save overwritten FAT16 for independent audit");
  printf("PASS native overwrite %s/%s/%s: existing FAT12/FAT16 destinations, high clusters, exact file contents, source FAT/data unchanged\n",argv[2],argv[3],argv[4]);return 0;
 }
 if(argc==6&&!strcmp(argv[5],"resize-overlap")){
  unsigned char mbr_before[512];memcpy(mbr_before,image,512);unsigned writes_before=sd_writes;
  command("b:fdisk sd0: resize 4 266240");require(contains("SD: error $04"),"RESIZE rejects a foreign primary inside the grown container");
  command("b:fdisk sd0: logical 294912 299008 8192 /t:fat16");require(contains("SD: error $04"),"LOGICAL rejects primary in gap before new data even when EBR/data do not overlap it");
  require(sd_writes==writes_before&&!memcmp(mbr_before,image,512),"overlap rejected before MBR or EBR writes");
  require(!resets&&!fdc_port_accesses,"resize overlap path has no reset/floppy access");
  printf("PASS FDISK resize overlap %s/%s/%s: foreign primary in extension gap rejected without writes\n",argv[2],argv[3],argv[4]);return 0;
 }
 if(argc==6){
  unsigned char*r=MC6800GetCpuRam();unsigned banked=r[0xead6]==1;
  for(unsigned drive=0;drive<8;drive++){
   unsigned header=r[0xeb03+drive*2]*256+r[0xeb04+drive*2];require(header,"all eight native drives mount");
   if(banked&&drive>=2&&drive<7)require(header==0xe205+(drive-2)*93,"five headers occupy reclaimed file buffer");
   if(banked&&drive==7)require(header<0xbe00,"eighth drive uses heap after pool is full");
  }
  unsigned heap=r[0xee1e]*256+r[0xee1f];
  for(char drive='d';drive<='h';drive++){
   char line[96];snprintf(line,sizeof line,"md %c:test",drive);command(line);
   snprintf(line,sizeof line,"copy a:datetime.pgm %c:test\\one.pgm",drive);command(line);
   snprintf(line,sizeof line,"dir %c:test",drive);command(line);require(contains("ONE"),"each pooled/heap volume writes a nested file");
   snprintf(line,sizeof line,"del %c:test\\one.pgm",drive);command(line);
   snprintf(line,sizeof line,"rd %c:test",drive);command(line);
   snprintf(line,sizeof line,"b:umount %c:",drive);command(line);require(contains("Unmounted."),"unmount pooled/heap volume");
   snprintf(line,sizeof line,"b:mount sd0:part%u",drive-'d'+5);command(line);
   char mounted[24];snprintf(mounted,sizeof mounted,"Mounted as %c",drive-'a'+'A');require(contains(mounted),"remount keeps native drive letter");
   require(r[0xee1e]*256+r[0xee1f]==heap,"metadata remounts and utilities leave heap unchanged");
  }
  require(!resets&&!fdc_port_accesses,"header pool has no reset/FDC access");
  printf("PASS header pool %s/%s/%s mode=%s: A..H, five resident headers, heap overflow slot, nested COPY/MD/RD, remount and stable heap\n",argv[2],argv[3],argv[4],banked?"RAMMAN":"CPU");return 0;
 }
 command("dir c:");require(contains("HICHAIN"),"FAT16 shell DIR");
 command("b:umount c:");require(contains("Unmounted."),"FAT16 shell UMOUNT");
 command("b:fdisk sd0: delete 4");require(!image[498],"delete unmounted FAT16 primary");
 command("b:fdisk sd0: create 4 40960 262144 /t:fat16");require(image[498]==0x0e,"FDISK creates FAT16 LBA primary");
 command("b:format /t:fat16 sd0:part4");require(contains("FAT16 formatted."),"FORMAT /T:FAT16 primary");
 command("b:mount /t:fat12 sd0:part4");require(contains("SD: error $09"),"MOUNT rejects mismatched filesystem filter");
 command("b:mount /t:fat16 sd0:part4");require(contains("Mounted as C"),"FAT16 primary preserves C");
 command("dir c:");require(contains("132890624 bytes free"),"DIR prints all nine digits of the empty 128 MiB FAT16 free space");
 command("copy a:datetime.pgm c:check.pgm");command("dir c:");require(contains("CHECK"),"COPY writes formatted FAT16");
 require(contains("132886528 bytes free"),"DIR accounts for the two clusters of the copied program");
 command("b:umount c:");command("b:fdisk sd0: delete 4");
 command("b:fdisk sd0: extended 4 40960 253952");require(image[498]==15,"create extended container");
 command("b:fdisk sd0: logical 40960 43008 250000 /t:fat16");
 require(image[40960*512+450]==0x0e,"FDISK creates logical FAT16 LBA volume");
 command("b:format /t:fat16 sd0:part5");require(contains("FAT16 formatted."),"FORMAT logical FAT16");
 command("b:mount /t:fat16 sd0:part5");require(contains("Mounted as C"),"logical FAT16 mounts as C");
 command("copy a:datetime.pgm c:logical.pgm");command("dir c:");require(contains("LOGICAL"),"COPY writes logical FAT16");
 unsigned char mbr_before[512];memcpy(mbr_before,image,512);unsigned writes_before=sd_writes;
 command("b:fdisk sd0: resize 4 253951");require(contains("SD: error $04"),"RESIZE rejects shrinking extended container");
 command("b:fdisk sd0: resize 2 262144");require(contains("SD: error $04"),"RESIZE rejects a data partition");
 command("b:fdisk sd0: resize 4 300000");require(contains("SD: error $04"),"RESIZE rejects end beyond card capacity");
 command("b:fdisk sd0: resize 4 4294967295");require(contains("SD: error $04"),"RESIZE rejects unsigned end overflow");
 require(sd_writes==writes_before&&!memcmp(mbr_before,image,512),"invalid resize leaves all sectors unchanged");
 command("b:fdisk sd0: resize 4 262144");require(le32(image+506)==262144,"RESIZE grows existing extended container");
 memcpy(mbr_before+506,image+506,4);require(!memcmp(mbr_before,image,512),"RESIZE changes only the extended count in MBR");
 command("dir c:");require(contains("LOGICAL"),"mounted child and copied file survive extended resize");
 command("b:fdisk sd0: resize 4 262144");require(le32(image+506)==262144&&contains("Partition table updated."),"RESIZE accepts the existing size");
 command("b:fdisk sd0: logical 303104 305152 8192 /t:fat16");
 require(le32(image+506)==272384&&image[303104u*512+450]==0x0e,"LOGICAL automatically grows container to fit new FAT16");
 require(le32(image+40960u*512+470)==262144,"automatic grow preserves EBR relative addressing");
 command("b:format /t:fat16 sd0:part6");require(contains("FAT16 formatted."),"FORMAT automatically appended FAT16");
 command("b:mount /t:fat16 sd0:part6");require(contains("Mounted as D"),"automatically appended FAT16 mounts as D");
 command("copy a:datetime.pgm d:auto.pgm");command("dir d:");require(contains("AUTO"),"COPY to automatically appended FAT16");
 command("dir c:");require(contains("LOGICAL"),"previous mounted child survives automatic grow and copy");
 require(!resets&&!fdc_port_accesses,"FAT16 tools make no reset or CHS/FDC access");
 printf("PASS FAT16 tools %s/%s/%s: DIR/COPY, typed MOUNT/FORMAT, primary/logical FDISK and checked extended RESIZE with mounted child\n",argv[2],argv[3],argv[4]);return 0;
}
