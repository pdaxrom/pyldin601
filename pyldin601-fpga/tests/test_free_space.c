// Real DOS APIs and SPI sectors; expected counts come from the disk image.
#define FAT16_MAIN unused_fat16_main
#include "test_fat16.c"
#undef FAT16_MAIN

static unsigned bits,unit,count,reserved,spf;
static unsigned char*volume;
static unsigned late_crc_read;
static void late_crc_hook(void){runtime_bad_crc=sd_reads>=late_crc_read;}
static unsigned value(unsigned cluster){
 const unsigned char*f=volume+reserved*512u;
 return bits==16?le16(f+cluster*2u):fat_next(f,cluster);
}
static uint32_t oracle(void){
 unsigned available=0;
 for(unsigned cluster=2;cluster<count+2;cluster++)available+=value(cluster)==0;
 return available*unit;
}
static uint32_t available(unsigned drive){
 unsigned char*r=MC6800GetCpuRam();
 unsigned status=invoke(0x52,drive,0,0x8110);
 if(status)fprintf(stderr,"free-space status=%u descriptor=%04x\n",status,r[UK_FS_FREE_DESC]*256+r[UK_FS_FREE_DESC+1]);
 require(!status,"free-space query succeeds");
 return (uint32_t)r[0x8110]<<24|r[0x8111]<<16|r[0x8112]<<8|r[0x8113];
}
static unsigned cached(unsigned drive){
 const unsigned char*r=MC6800GetCpuRam();unsigned p=UK_FS_FREE_BASE+2*drive;
 return r[p]*256+r[p+1];
}
static void warm(uint32_t expected){
 static unsigned query;
 unsigned before=sd_reads;
 uint32_t actual=available(2);query++;
 if(actual!=expected)fprintf(stderr,"warm query=%u got=%u expected=%u counter=%u unit=%u reads=%u\n",query,actual,expected,cached(2),unit,sd_reads-before);
 require(actual==expected,"cached bytes agree with expected allocation");
 require(sd_reads==before,"warm query does not reread FAT");
 require(cached(2)==expected/unit,"resident free-cluster count is exact");
 require(MC6800GetCpuRam()[UK_FS_WRITE_CONTEXT]==0,"internal-write marker is balanced");
}
static void sector_descriptor(unsigned relative){
 unsigned char*r=MC6800GetCpuRam();word_at(0x8100,0x4000);r[0x8102]=2;
 r[0x8103]=relative>>24;r[0x8104]=relative>>16;r[0x8105]=relative>>8;r[0x8106]=relative;
}
static void raw_descriptor(unsigned physical_sector){
 unsigned char*r=MC6800GetCpuRam();word_at(0x8180,0x4000);
 for(unsigned i=0;i<4;i++)r[0x8182+i]=physical_sector>>(8*i);
}
static void boundary_volume(int full){
 // Six BPB clusters at the maximum extent have reserved-marker indices.
 // Leave them free: neither the scan nor delta updates may count them.
 volume=image+40960u*512;
 unsigned fats=volume[16],sectors=le16(volume+22),first=le16(volume+14);
 unsigned data=first+fats*sectors+(le16(volume+17)+15)/16;
 unsigned total=le16(volume+19);if(!total)total=le32(volume+32);
 unsigned clusters=(total-data)/volume[13]<4085?4084:65524;
 total=data+clusters;
 volume[13]=1;volume[19]=volume[20]=0;
 for(unsigned i=0;i<4;i++)volume[32+i]=image[506+i]=total>>(i*8);
 for(unsigned copy=0;copy<fats;copy++){
  unsigned char*f=volume+(first+copy*sectors)*512u;
  memset(f,full?255:0,sectors*512u);f[0]=0xf8;f[1]=f[2]=255;
  if(clusters>4084)f[3]=255;
  unsigned limit=clusters>4084?65518:4078;
  for(unsigned c=limit+2;c<clusters+2;c++){
   if(clusters>4084)f[c*2]=f[c*2+1]=0;
   else{
    unsigned off=c+c/2,old=le16(f+off),next=c&1?old&15:old&0xf000;
    f[off]=next;f[off+1]=next>>8;
   }
  }
 }
}
int main(int argc,char**argv){
 if(argc!=5&&argc!=6)return 2;
 model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");sdsc=!strcmp(argv[4],"sdsc");
 MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);
 memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);
 if(argc==6&&!strcmp(argv[5],"no-ram"))ram_hardware_missing=1;
 if(argc==6&&!strcmp(argv[5],"no-e5"))memset(physical+0x1c000,255,8192);
 image=load(argv[1],&image_size);
 int boundary=argc==6&&(!strcmp(argv[5],"empty")||!strcmp(argv[5],"full"));
 if(boundary)boundary_volume(!strcmp(argv[5],"full"));
 committed=1;MC6800Init();MC6800Reset();until(60000000);
 key(0x1c);key(0x1c);prompt_wait();watch_resets=1;
 unsigned char*r=MC6800GetCpuRam();PC=0x212;SP=0x7000;r[0]=0;
 if(argc==6&&(!strcmp(argv[5],"no-ram")||!strcmp(argv[5],"no-e5")))
  require(r[UK_FS_AREA+UK_FS_BANK]!=1&&r[UK_FS_AREA+UK_FS_FILE_FLAG]!=1,"unavailable RAMMAN selects ordinary RAM buffers");
 volume=image+40960u*512;
 reserved=le16(volume+14);spf=le16(volume+22);unit=volume[13]*512u;
 unsigned total=le16(volume+19);if(!total)total=le32(volume+32);
 unsigned data=reserved+volume[16]*spf+(le16(volume+17)+15)/16;
 count=(total-data)/volume[13];bits=count<4085?12:16;
 if(count>(bits==12?0xfee:0xffee))count=bits==12?0xfee:0xffee;
 require(cached(2)==65535,"mounted free-space count starts unknown");
 unsigned heap=r[0xee1e]*256+r[0xee1f],reads=sd_reads;uint64_t cold=virtual_cycles;
 uint32_t initial=available(2);cold=virtual_cycles-cold;
 require(initial==oracle(),"cold count matches on-disk FAT including the last partial sector");
 unsigned cold_reads=sd_reads-reads;
 require(cold_reads==(bits==16?(count+2+255)/256:((count+2)*3+1023)/1024),"one read per required FAT sector");
 uint64_t hit=virtual_cycles;warm(initial);hit=virtual_cycles-hit;
 require((r[0xee1e]*256+r[0xee1f])==heap,"queries use no heap");
 require(invoke(0x5c,2,0,0)==0,"ordinary media check succeeds");warm(initial);
 if(boundary){
  require(initial==(!strcmp(argv[5],"empty")?count*unit:0),"zero and maximum free counts are cacheable");
  require(invoke(0xeb,3,2,0)==0,"boundary volume descriptor");unsigned d=result_x;
  unsigned eof=bits==16?0xffff:0xfff;
  word_at(d+26,count+2);word_at(d+28,eof);
  require(invoke(0xe9,2,0,d)==0,"write an excluded reserved-marker entry");warm(initial);
  word_at(d+26,count+2);word_at(d+28,0);
  require(invoke(0xe9,2,0,d)==0,"free an excluded reserved-marker entry");warm(initial);
  word_at(d+26,2);word_at(d+28,eof);
  require(invoke(0xe9,2,0,d)==0,"occupy first allocatable cluster");
  warm(initial?initial-unit:0);
  word_at(d+26,2);word_at(d+28,0);
  require(invoke(0xe9,2,0,d)==0,"free first allocatable cluster");warm(initial?initial:unit);
  printf("PASS free space %s/%s/%s FAT%u %s: %u allocatable clusters; zero/max cache and reserved tail excluded\n",argv[2],argv[3],argv[4],bits,argv[5],count);
  return 0;
 }
 uint32_t ab[2]={available(0),available(1)};

 unsigned char bytes[7000];for(unsigned i=0;i<sizeof bytes;i++)bytes[i]=i*7+0x39;
 unsigned h=create_file("C:SPACE.BIN");write_bytes(h,bytes,sizeof bytes);
 warm(initial-((sizeof bytes+unit-1)/unit)*unit);
 seek_file(h,700,0);require(invoke(0x6c,h,0,0)==0,"truncate frees the excess clusters");
 warm(initial-unit);
 seek_file(h,0,0);write_bytes(h,bytes,400);warm(initial-unit);
 require(invoke(0x4e,h,0,0)==0,"close preserves the count");warm(initial-unit);
 require(oracle()==initial-unit,"committed allocation matches disk");
 named_call(0x4f,"C:SPACE.BIN");warm(initial);
 named_call(0x48,"C:SPACE");warm(initial-unit);
 named_call(0x49,"C:SPACE");warm(initial);require(oracle()==initial,"deletion restores free clusters");
 reads=sd_reads;
 require(available(0)==ab[0]&&available(1)==ab[1]&&sd_reads==reads,"C mutations preserve independent A/B counters");

 require(invoke(0xeb,3,2,0)==0,"volume descriptor");unsigned descriptor=result_x;
 unsigned target=2;while(target<count+2&&value(target))target++;
 require(target<count+2,"fixture contains a free cluster");
 // Link changes used->used and free->free do not change the count.
 word_at(descriptor+26,target);word_at(descriptor+28,bits==16?0xffff:0xfff);
 require(invoke(0xe9,2,0,descriptor)==0,"direct FAT allocation");warm(initial-unit);
 word_at(descriptor+28,bits==16?0xfff8:0xff8);
 require(invoke(0xe9,2,0,descriptor)==0,"change an occupied FAT value");warm(initial-unit);
 word_at(descriptor+28,0);require(invoke(0xe9,2,0,descriptor)==0,"release direct FAT allocation");warm(initial);
 word_at(descriptor+28,0);require(invoke(0xe9,2,0,descriptor)==0,"repeat freeing an already-free entry");warm(initial);
 require(invoke(0xeb,2,2,0)==0&&oracle()==initial,"flush matches free-space oracle");

 if(bits==16){
  unsigned relative=reserved+target/256;
  sector_descriptor(relative);require(invoke(0xea,1,0,0x8100)==0,"read raw FAT sector");
  unsigned char original[512];memcpy(original,r+0x4000,512);
  r[0x4000+(target%256)*2]=r[0x4001+(target%256)*2]=255;
  require(invoke(0xea,2,0,0x8100)==0&&cached(2)==65535,"external EA write invalidates count");
  require(available(2)==initial-unit,"raw edit is visible despite a previously cached FAT sector");warm(initial-unit);
  memcpy(r+0x4000,original,512);sector_descriptor(relative);
  word_at(0x8103,relative);
  require(invoke(0x40,2,0,0x8100)==0&&cached(2)==65535&&available(2)==initial,"legacy INT40 write restores FAT and invalidates the count");
  sector_descriptor(relative);
  require(invoke(0xe1,9,0,0x8100)==0&&cached(2)==65535&&available(2)==initial,"direct partition write invalidates the count");
  // Both an internal dirty FAT and an external request use PARTS' physical
  // descriptor. The nested flush must preserve the external buffer and LBA.
  unsigned other=target+256;while(other<count+2&&value(other))other++;
  require(other<count+2&&other/256!=target/256,"second free FAT sector");
  relative=reserved+other/256;sector_descriptor(relative);
  require(invoke(0xea,1,0,0x8100)==0,"read second raw FAT sector");memcpy(original,r+0x4000,512);
  word_at(descriptor+26,target);word_at(descriptor+28,0xffff);
  require(invoke(0xe9,2,0,descriptor)==0&&r[descriptor+25],"dirty internal FAT before external write");
  unsigned writes=sd_writes;raw_descriptor(40960+relative);
  unsigned char rejected_descriptor[6];memcpy(rejected_descriptor,r+0x8180,6);sd_deny_write=1;
  require(invoke(0xe2,2,0,0x8180)==3&&sd_writes==writes&&r[descriptor+25]&&cached(2)==65535,"failed preflush preserves dirty FAT and rejects external write");
  require(!memcmp(rejected_descriptor,r+0x8180,6)&&!r[UK_FS_WRITE_CONTEXT],"failed preflush preserves caller descriptor and context");
  sd_deny_write=0;raw_descriptor(image_size/512);
  require(invoke(0xe2,2,0,0x8180)==4&&sd_writes==writes&&r[descriptor+25],"invalid raw request does not flush dirty FAT");
  r[0x4000+(other%256)*2]=r[0x4001+(other%256)*2]=255;
  sector_descriptor(relative);require(invoke(0xea,2,0,0x8100)==0,"external write drains dirty FAT and preserves its own descriptor");
  require(value(target)==0xffff&&value(other)==0xffff&&available(2)==initial-2*unit,"both nested and external writes reached their own sectors");
  word_at(descriptor+26,target);word_at(descriptor+28,0);
  require(invoke(0xe9,2,0,descriptor)==0,"restore internal FAT value");
  memcpy(r+0x4000,original,512);raw_descriptor(40960+relative);
  unsigned char raw_before[6];memcpy(raw_before,r+0x8180,6);
  require(invoke(0xe2,2,0,0x8180)==0&&!memcmp(raw_before,r+0x8180,6),"raw E2 preserves caller descriptor during nested flush");
  require(available(2)==initial&&oracle()==initial,"raw restore recounts correctly");warm(initial);
 }

 // A CRC error never publishes a partial count, including after an old hit.
 raw_descriptor(40960);runtime_bad_crc=1;
 require(invoke(0xe2,1,0,0x8180)==5&&cached(2)==65535,"raw read CRC error invalidates counts");
 require(cached(0)==65535&&cached(1)==65535,"physical SD error forgets all mounted counts");
 require(invoke(0x52,2,0,0x8110)==5&&cached(2)==65535,"failed cold scan stays unknown");
 require(!r[0x8110]&&!r[0x8111]&&!r[0x8112]&&!r[0x8113],"failed INT52 leaves its original zero result");
 runtime_bad_crc=0;require(available(2)==initial,"scan recovers after CRC failure");warm(initial);
 // The first sector is valid, but a later read overwrites the old cache
 // before failing CRC. Its previous key must not survive the failed read.
 require(invoke(0xe1,15,0,descriptor)==0,"forget before late scan error");r[descriptor+24]=0;
 reads=sd_reads;late_crc_read=reads+1;native_step_hook=late_crc_hook;
 require(invoke(0x52,2,0,0x8110)==5&&cached(2)==65535&&sd_reads==reads+2,"late scan failure does not cache a partial count");
 native_step_hook=NULL;runtime_bad_crc=0;
 require(!r[descriptor+24],"CRC failure discards overwritten FAT sector cache");
 require(!r[0x8110]&&!r[0x8111]&&!r[0x8112]&&!r[0x8113],"late scan error leaves zero result");
 require(available(2)==initial,"complete rescan after late CRC failure");warm(initial);
 word_at(descriptor+26,target);word_at(descriptor+28,bits==16?0xffff:0xfff);
 require(invoke(0xe9,2,0,descriptor)==0,"allocate before a denied flush");
 sd_deny_write=1;require(invoke(0xeb,2,2,0)==3&&cached(2)==65535&&r[descriptor+25],"failed flush forgets count while retaining dirty FAT");
 sd_deny_write=0;require(invoke(0xeb,2,2,0)==0&&available(2)==initial-unit,"retry rebuilds from committed FAT");
 word_at(descriptor+26,target);word_at(descriptor+28,0);
 require(invoke(0xe9,2,0,descriptor)==0,"release retried allocation");warm(initial);
 require(invoke(0xeb,2,2,0)==0,"clean FAT before a failed mirror write");
 word_at(descriptor+26,target);word_at(descriptor+28,bits==16?0xffff:0xfff);
 require(invoke(0xe9,2,0,descriptor)==0,"allocate before a failed second FAT copy");
 sd_deny_write_lba=40960+reserved+spf+(bits==16?target*2:target+target/2)/512;
 require(invoke(0xeb,2,2,0)==3&&cached(2)==65535&&r[descriptor+25],"second-copy failure forgets count and preserves dirty state");
 sd_deny_write_lba=UINT32_MAX;
 require(invoke(0xeb,2,2,0)==0&&available(2)==initial-unit,"mirror retry rebuilds exact count");
 word_at(descriptor+26,target);word_at(descriptor+28,0);
 require(invoke(0xe9,2,0,descriptor)==0,"release mirror-test allocation");warm(initial);

 if(bits==12){
  unsigned split=341,old=value(split);require(old!=0,"split FAT12 entry fixture");
  word_at(descriptor+26,split);word_at(descriptor+28,0);
  require(invoke(0xe9,2,0,descriptor)==0,"free a FAT12 entry across two sectors");warm(initial+unit);
  word_at(descriptor+26,split);word_at(descriptor+28,old);
  require(invoke(0xe9,2,0,descriptor)==0,"restore a split FAT12 entry");warm(initial);
  require(invoke(0xeb,2,2,0)==0,"clean FAT before split-entry failure");
  word_at(descriptor+26,split);word_at(descriptor+28,0);sd_deny_write=1;
  require(invoke(0xe9,2,0,descriptor)==3&&cached(2)==65535,"partial split-entry write never publishes a delta");
  sd_deny_write=0;word_at(descriptor+26,split);word_at(descriptor+28,old);
  require(invoke(0xe9,2,0,descriptor)==0&&invoke(0xeb,2,2,0)==0,"restore split entry after write retry");
  require(available(2)==initial&&oracle()==initial,"FAT12 split-entry recovery recounts correctly");warm(initial);
 }
 require(invoke(0xe1,3,4,0)==0&&cached(2)==65535,"unmount forgets its count");
 require(invoke(0xe1,13,4,0)==0&&result_b==2&&cached(2)==65535,"read-only remount retains C and starts unknown");
 require(available(2)==initial,"read-only first query");unsigned writes=sd_writes;
 require(invoke(0xeb,3,2,0)==0,"read-only descriptor");descriptor=result_x;
 word_at(descriptor+26,target);word_at(descriptor+28,0xffff);
 require(invoke(0xe9,2,0,descriptor)==3&&sd_writes==writes,"read-only FAT edit is refused");warm(initial);
 require(invoke(0xe1,3,4,0)==0&&invoke(0xe1,2,4,0)==0&&result_b==2,"RW remount keeps its letter");
 require(available(2)==initial,"RW remount recounts");warm(initial);
 require(!resets&&!fdc_port_accesses,"queries leave CPU reset and legacy ports untouched");
 printf("PASS free space %s/%s/%s FAT%u: cold=%llu cycles/%u sectors, hit=%llu cycles/0 sectors; deltas, raw/nested writes, CRC/flush/split errors, media check, remount/RO, no heap\n",argv[2],argv[3],argv[4],bits,(unsigned long long)cold,cold_reads,(unsigned long long)hit);
 return 0;
}
