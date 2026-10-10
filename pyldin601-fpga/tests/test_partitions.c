// Execute the actual partition ROM with native BIOS/UniDOS and byte-level SPI.
#define PARTITION_FIXTURE 1
#define COMPACT_FIXTURE 1
#define DIRECT_SD_FIXTURE 1
#define ROMDISK_MAIN unused_romdisk_main
#include "test_romdisk_unidos.c"
#undef ROMDISK_MAIN
static void replace_page(unsigned slot,const char*path){size_t n;unsigned char*p=load(path,&n);require(n==8192,"page length");memcpy(physical+0x10000+slot*8192,p,n);free(p);}
int main(int argc,char**argv){
 if(argc!=5)return 2;model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");
 sdsc=!strcmp(argv[4],"sdsc");
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);
 memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 replace_page(2,"build/partitions/PARTS.ROM");replace_page(3,"build/partitions/SD.ROM");replace_page(7,"build/partitions/SHELL.ROM");memset(physical+0x1c000,255,8192);
 rom=load(model_a?"build/partitions/BIOS_A.ROM":"build/partitions/BIOS.ROM",&n);memcpy(physical+ROM_BIOS,rom,n);free(rom);
 image=load(argv[1],&image_size);memcpy(config+64,image+462,32);committed=1;
 MC6800Init();MC6800Reset();until(60000000);key(0x1c);key(0x1c);prompt_wait();watch_resets=1;
 command("dir a:");command("dir b:");command("dir c:");
 require(contains("GD")&&contains("BASIC"),"extracted data volume mounted C");
 command("b:umount c:");require(contains("Unmounted."),"UMOUNT utility");

 unsigned resident0=MC6800GetCpuRam()[0xee1a]*256+MC6800GetCpuRam()[0xee1b];
 command("b:mount sd0:part4");require(contains("Mounted as C"),"MOUNT utility");
 require(MC6800GetCpuRam()[0xee1a]*256+MC6800GetCpuRam()[0xee1b]==resident0,"remount does not retain utility or allocate again");
 command("copy a:datetime.pgm c:check.pgm");
 command("b:umount sd0:part4");
 command("b:format /t:fat12 sd0:part4");require(contains("FAT12 formatted."),"FORMAT utility");
 unsigned char*vol=image+40960*512;require(le16(vol+19)==32400&&vol[13]==8&&le16(vol+22)==12&&le16(vol+17)==512,"exact FAT12 profile");
 require(!memcmp(vol+512,vol+13*512,12*512)&&vol[512]==0xf8,"both empty FATs agree");
 command("b:mount /t:fat12 sd0:part4");command("dir c:");require(contains("0 File(s)"),"newly formatted root usable");
 command("b:fdisk sd0:");require(contains("PART TYPE BOOT DRIVE"),"FDISK listing");
 command("b:fdisk sd0: delete 4");require(contains("SD: error $0F"),"FDISK rejects mounted deletion");
 command("b:umount c:");
 command("b:fdisk sd0: delete 4");require(image[446+48+4]==0,"FDISK deletes unmounted primary");
 command("b:fdisk sd0: extended 4 40960 65536");require(image[446+48+4]==15,"FDISK creates extended container");
 command("b:fdisk sd0: logical 40960 43008 32400");require(image[40960*512+450]==1,"FDISK creates first logical partition");
 command("b:format sd0:part5");command("b:mount sd0:part5");require(contains("Mounted as C"),"logical FAT12 mount");
 command("b:fdisk sd0: logical 77824 79872 16000");require(le32(image+40960*512+470)==36864,"FDISK appends EBR relative to extended base");
 command("b:format sd0:part6");command("b:mount sd0:part6");require(contains("Mounted as D"),"second logical volume mount");
 command("copy a:datetime.pgm d:check.pgm");command("dir d:");require(contains("CHECK"),"logical volume file write/read");
 command("b:fdisk sd0: active 6");require(image[77824*512+446]==128,"logical boot flag set");
 command("b:umount c:");command("b:fdisk sd0: delete 5");require(image[40960*512+450]==0&&image[40960*512+466]==15,"logical deletion keeps EBR links and numbering");
 command("dir d:");require(contains("CHECK"),"mounted D preserved across EBR updates");
 require(!resets&&!fdc_port_accesses,"no reset/floppy access");
 // API fault tests run in an independent context, outside a suspended BIOS
 // keyboard SWI. Calling a second root SWI during that poll is not legal ABI.
 PC=0x212;SP=0x7000;MC6800GetCpuRam()[0]=0;
 require(invoke(0xe1,3,2,0)==15,"current boot drive cannot be unmounted");
 require(invoke(0xe1,6,6,0)==15,"mounted partition cannot be formatted");
 require(invoke(0xe1,5,0,0)==0,"rescan preserves mounted mapping");
 resident0=MC6800GetCpuRam()[0xee1a]*256+MC6800GetCpuRam()[0xee1b];
 unsigned char*r=MC6800GetCpuRam();unsigned work=r[0xbf80]*256+r[0xbf81];
 unsigned char records[768];memcpy(records,r+work+512,768);unsigned count=r[0xbf82];
 unsigned himem0=r[0xee1e]*256+r[0xee1f];
 unsigned char*second=image+79872*512;
 second[24]++;require(invoke(0xe1,5,0,0)==15,"rescan rejects valid changed mounted BPB geometry");second[24]--;
 require(r[0xbf82]==count&&!memcmp(records,r+work+512,768),"geometry rejection restores every record");
 runtime_bad_crc=1;require(invoke(0xe1,5,0,0)==15,"rescan CRC fault");runtime_bad_crc=0;
 require(r[0xbf82]==count&&!memcmp(records,r+work+512,768),"I/O rejection keeps drive mapping");
 image[510]=0;require(invoke(0xe1,5,0,0)==15,"invalid MBR rejected");image[510]=0x55;
 unsigned char*ebr=image+77824*512;
 ebr[466]=15;ebr[470]=0;ebr[471]=0;ebr[472]=0;ebr[473]=0;
 require(invoke(0xe1,5,0,0)==15,"cyclic/empty EBR link rejected");memset(ebr+462,0,16);
 require(invoke(0xe1,5,0,0)==0,"scan recovers after faults");
 require(r[0xee1e]*256+r[0xee1f]==himem0,"successful and failed rescans free temporary rollback copy");
 unsigned lomem0=r[0xee1c]*256+r[0xee1d];word_at(0xee1c,himem0);
 require(invoke(0xe1,5,0,0)==6,"rescan reports exhausted heap before modifying records");
 word_at(0xee1c,lomem0);
 require(r[0xbf82]==count&&!memcmp(records,r+work+512,768)&&r[0xee1e]*256+r[0xee1f]==himem0,"failed snapshot allocation preserves all mappings and heap");
 strcpy((char*)r+0x3100,"D:CHECK.PGM");word_at(0x3000,0x3100);word_at(0x3002,0);
 require(invoke(0x4a,1,0,0x3000)==0,"open file on mounted logical volume");unsigned handle=result_b;
 require(invoke(0xe1,3,6,0)==15,"open file prevents unmount");
 require(invoke(0x4e,handle,0,0)==0,"close file before unmount");
 require(invoke(0xe1,3,6,0)==0,"closed logical partition unmounts");
 unsigned before=sd_writes;sd_deny_write=1;
 require(invoke(0xe1,6,6,0)==3&&sd_writes==before,"denied FORMAT performs no writes");sd_deny_write=0;
 require(invoke(0xe1,2,6,0)==0,"mount recovers after denied format");
 require(r[0xee1a]*256+r[0xee1b]==resident0,"all remounts reuse owned resident headers");
 printf("PASS partitions %s/%s: native boot, direct A/B/C directories, filesystem commands, format, MBR/EBR edits, CRC/geometry rollback, open-file/format protection\n",argv[2],argv[3]);return 0;
}
