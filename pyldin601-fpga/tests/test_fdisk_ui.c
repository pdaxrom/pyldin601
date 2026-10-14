/* Native keyboard commands against private media; no host partition editor. */
#define DOS_PROMPT_CYCLES 1000000000
#define PARTITION_FIXTURE 1
#define COMPACT_FIXTURE 1
#define DIRECT_SD_FIXTURE 1
#define ROMDISK_MAIN unused_romdisk_main
#include "test_romdisk_unidos.c"
#undef ROMDISK_MAIN
static void run(const char *text){printf("COMMAND %s\n",text);fflush(stdout);command(text);}
static void rejected(const char *text,const char *message){
 unsigned writes=sd_writes;run(text);require(contains(message)&&sd_writes==writes,"invalid ADD rejected before all table writes");
}
int main(int argc,char **argv){
 if(argc!=4&&argc!=5)return 2;model_a=!strcmp(argv[1],"601a");cpu_hd=!strcmp(argv[2],"hd6303");sdsc=!strcmp(argv[3],"sdsc");
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 const char *rom_dir=getenv("FAT_TEST_ROMS");char rom_path[512];
 snprintf(rom_path,sizeof rom_path,"%s/%s",rom_dir?rom_dir:"build",model_a?"rom-a.reference":"rom.reference");
 size_t n;unsigned char *rom=load(rom_path,&n);
 memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 image=load("build/fat16/sd.img",&image_size);
 size_t old=image_size;unsigned char *old_image=image;
 image_size=(sdsc?1048576u:4194304u)*(size_t)512;
 image=calloc(1,image_size);require(image!=NULL,"UI test media allocation");memcpy(image,old_image,old);free(old_image);
 memset(image+494,0,16); // Free primary slot 4; no extended container exists.
 if(argc==5){
  unsigned entries=!strcmp(argv[4],"full")?28:32;
  image[498]=15;
  for(unsigned b=0;b<4;b++){image[502+b]=40960u>>(8*b);image[506+b]=262144u>>(8*b);}
  for(unsigned i=0;i<entries;i++){
   unsigned char *t=image+(40960u+i*32)*512;memset(t,0,512);t[510]=0x55;t[511]=0xaa;
   if(!strcmp(argv[4],"full")||i==0){t[450]=0xda;t[454]=1;t[458]=8;}
   if(i+1<entries){t[466]=15;for(unsigned b=0;b<4;b++){t[470+b]=((i+1)*32)>>(8*b);t[474+b]=(262144u-(i+1)*32)>>(8*b);}}
  }
 }
 unsigned char *before=malloc(40960u*512);require(before!=NULL,"old volume snapshot");memcpy(before,image,40960u*512);
 committed=1;MC6800Init();MC6800Reset();until(60000000);key(0x1c);key(0x1c);prompt_wait();watch_resets=1;
 if(argc==5){
  if(!strcmp(argv[4],"full")){
   rejected("b:fdisk sd0: add +512","Partition table full");
   rejected("b:fdisk sd0: add logical +512","Partition table full");
   puts("PASS FDISK UI: full resident 32-record list rejects ADD before writes");return 0;
  }
  run("b:fdisk sd0: add logical +512");
  require(contains("Partition table updated.")&&image[40992u*512+450]==1&&image[40960u*512+450]==0xda,"32-link chain reuses an empty earlier EBR without adding another link or changing its neighbour");
  puts("PASS FDISK UI: 32-link EBR chain reuses empty slot without table redesign");return 0;
 }
 run("b:fdisk sd0: add logical +16m fat16");
 require(contains("Added SD0:PART5"),"ADD LOGICAL creates its missing container and reports the new partition");
 require(image[498]==15&&le32(image+502)==40960&&le32(image+506)==34816,"automatic extended slot, aligned placement and exact container extent");
 require(image[40960u*512+450]==14&&le32(image+40960u*512+454)==2048&&le32(image+40960u*512+458)==32768,"first FAT16 logical has the requested 16 MiB data size");
 run("b:fdisk sd0: list");require(contains("43008 75775 32768"),"decimal LIST reports inclusive end and sector count");
 run("b:fdisk /hex sd0: list");require(contains("0x0000A800")&&contains("0x000127FF"),"HEX LIST reports prefixed sector addresses");
 run("b:format /t:fat16 sd0:part5");run("b:mount sd0:part5");require(contains("Mounted as C"),"automatic logical volume formats and mounts through native utilities");
 rejected("b:fdisk sd0: del part5","SD: error $0F");
 rejected("b:fdisk sd0: del part4","SD: error $0F");
 run("copy a:datetime.pgm c:ui.pgm");require(contains("1 File(s) copied"),"native COPY to the automatically created logical volume");
 run("b:umount c:");
 FILE *out=fopen("build/fdisk-ui/formatted.img","wb");require(out&&fwrite(image+43008u*512,1,32768u*512,out)==32768u*512&&!fclose(out),"save native formatted/copied volume for independent FAT audit");
 run("b:fdisk sd0: del part5");require(!image[40960u*512+450],"DEL PART removes only its data entry");
 run("b:fdisk sd0: add +512");
 require(image[40960u*512+450]==1&&le32(image+40960u*512+458)==1024,"ADD falls back to logical and defaults to K and FAT12, reusing an empty EBR");
 require(contains("Added SD0:PART5"),"ADD reports the reused partition number");
 run("b:fdisk sd0: add logical 0x68000 0x69fff fat16");
 require(le32(image+40961u*512+454)==425984u-40961&&le32(image+40961u*512+458)==8192,"hexadecimal explicit bounds are inclusive and EBR placement avoids existing data/tables");
 require(le32(image+506)==434176u-40960,"explicit logical addition grows only the existing container end");
 rejected("b:fdisk sd0: add logical 43008 44031","No free range");
 rejected("b:fdisk sd0: add +4g fat16","No free range");
 rejected("b:fdisk sd0: add +2048g fat16","Invalid sector");
 rejected("b:fdisk sd0: add 0xffffffff 0xffffffff","Invalid sector");
 rejected("b:fdisk sd0: add 100 99","Invalid sector");
 rejected("b:fdisk sd0: add 0 99","No free range");
 rejected("b:fdisk sd0: add 4294967280 4294967294","No free range");
 rejected("b:fdisk sd0: add logical 40961 40962","No free range");
 run("b:fdisk sd0: del part6");run("b:fdisk sd0: del part5");run("b:fdisk sd0: del part4");
 run("b:fdisk sd0: add +1m fat16");
 require(image[498]==14&&le32(image+502)==40960&&le32(image+506)==2048,"ADD chooses a free primary slot and aligned gap");
 run("b:fdisk sd0: del part4");
 run("b:fdisk sd0: add 81920 83967");
 require(image[498]==1&&le32(image+502)==81920&&le32(image+506)==2048,"decimal explicit primary bounds, default FAT12");
 run("b:fdisk sd0: del part4");
 run("b:fdisk sd0: add logical 0x68000 0x69fff fat16");
 require(image[498]==15&&le32(image+502)==425983&&le32(image+506)==8193,"explicit ADD LOGICAL creates a missing container without changing the requested data range");
 require(image[425983u*512+450]==14&&le32(image+425983u*512+454)==1&&le32(image+425983u*512+458)==8192,"automatic EBR directly precedes explicit data in a new container");
 if(!sdsc){
  run("b:fdisk sd0: del part4");run("b:fdisk sd0: add logical +1g fat16");
  require(image[498]==15&&le32(image+40960u*512+458)==2097152,"G uses sectors without a 32-bit byte-size ceiling");
 }
 for(unsigned off=0;off<40960u*512;off++)if(image[off]!=before[off])
  require(off>=494&&off<510,"every original boot/A/B byte and other MBR entries preserved");
 require(!resets&&!fdc_port_accesses,"new commands do not reset or access floppy/CHS ports");
 printf("PASS FDISK UI %s/%s/%s: ADD primary/logical, missing-container creation, first-fit/reused EBR, K/M/G, decimal/hex inclusive bounds, LIST/HEX/DEL, errors before writes, old data preserved\n",argv[1],argv[2],argv[3]);return 0;
}
