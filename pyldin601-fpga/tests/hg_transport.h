// Shared native HG FIFO/host transport fixture; not production firmware.
static unsigned char *host_image;static size_t host_size;
static int (*host_write)(unsigned, const uint8_t *, unsigned);
static void store_host(unsigned block, const uint8_t *data, unsigned length){
 if(host_write){if(host_write(block,data,length)!=HG_OK){fprintf(stderr,"native HG durable WRITE failed\n");exit(1);}}
 else memcpy(host_image+block*512,data,length);
}
static unsigned char tx_fifo[64],rx_fifo[64],header[10],payload[514];
static unsigned tx_read,tx_write,tx_count,rx_read,rx_write,rx_count;
static unsigned hg_control,hg_selected,hg_phase,hg_pos,hg_block,hg_length,hg_operation;
static unsigned hg_reads,hg_writes,hg_times,hg_absent,hg_readonly,hg_corrupt;
static uint32_t hg_next;
static unsigned hg_v2,hg_active;
static unsigned char time_value[6]={0x16,0x69,0x03,0,0x87,0xd9};

static void rx_byte(unsigned char data){
 if(rx_count==64){fprintf(stderr,"fixture RX overflow\n");exit(1);}
 rx_fifo[rx_write++&63]=data;rx_count++;
}
static unsigned char tx_byte(void){
 if(!tx_count){fprintf(stderr,"fixture TX underflow\n");exit(1);}
 tx_count--;return tx_fifo[tx_read++&63];
}
// Functional host credits: an entire packet arrives before the CPU runs again.
// Real TCK framing/status queries are checked independently in mixed HDL.
static void hg_v2_pump(void){
 uint32_t now=MC6800GetCyclesCounter();
 if(!hg_control){hg_active=hg_selected=0;return;}
 if(hg_absent)return;
 if(!hg_active&&(hg_control&1)){hg_active=hg_selected=1;hg_phase=hg_pos=0;hg_next=now+2000;}
 if(!hg_active||(int32_t)(now-hg_next)<0)return;
 hg_next=now+1000;
 if(hg_phase==0&&tx_count){
  header[hg_pos++]=tx_byte();if(hg_pos!=10)return;
  unsigned checksum=0;for(unsigned n=0;n<9;n++)checksum^=header[n];
  if(memcmp(header,"HG\2",3)||header[4]||header[9]!=checksum){fprintf(stderr,"bad native HG v2 header\n");exit(1);}
  hg_operation=header[3];hg_block=le16(header+5);hg_length=le16(header+7);hg_phase=1;hg_pos=0;hg_selected=0;
  if(hg_length!=(hg_operation==3?6:512)||(hg_operation!=3&&(uint64_t)hg_block*512+hg_length>host_size)){fprintf(stderr,"invalid HG request op=%u block=%u len=%u\n",hg_operation,hg_block,hg_length);exit(1);}
  if(hg_operation==3){memcpy(payload,time_value,6);hg_times++;}
  else if(hg_operation==1){memcpy(payload,host_image+hg_block*512,hg_length);hg_reads++;}
  if(hg_operation!=2){unsigned sum=0;for(unsigned n=0;n<hg_length;n++)sum+=payload[n];payload[hg_length]=sum;payload[hg_length+1]=(sum>>8)^(hg_corrupt?1:0);}
 }else if(hg_phase==1&&hg_control==27){
  hg_selected=1;rx_byte(hg_readonly&&hg_operation==2?5:0);hg_phase=hg_readonly&&hg_operation==2?4:2;
 }else if(hg_phase==2){
  hg_selected=0;
  unsigned left=hg_length+2-hg_pos,chunk=left<32?left:32;
  if(hg_operation==2&&(hg_control==13||hg_control==45)&&(tx_count>=32||((hg_control&32)&&tx_count>=chunk))){
   for(unsigned n=0;n<chunk;n++)payload[hg_pos++]=tx_byte();
   if(hg_pos==hg_length+2){
    unsigned sum=0;for(unsigned n=0;n<hg_length;n++)sum+=payload[n];
    if(le16(payload+hg_length)!=(sum&65535)){fprintf(stderr,"native v2 WRITE checksum\n");exit(1);}
    store_host(hg_block,payload,hg_length);hg_writes++;hg_phase=3;
   }
  }else if(hg_operation!=2&&hg_control==11&&rx_count<=32){
   for(unsigned n=0;n<chunk;n++)rx_byte(payload[hg_pos++]);
   if(hg_pos==hg_length+2)hg_phase=4;
  }
 }else if(hg_phase==3&&hg_control==27){hg_selected=1;rx_byte(0);hg_phase=4;}
 else if(hg_phase==4){hg_selected=hg_control==25;}
}
static void hg_pump(void){
 if(hg_v2){hg_v2_pump();return;}
 uint32_t now=MC6800GetCyclesCounter();
 if(hg_absent)return;
 if(!hg_selected&&(hg_control&1)){hg_selected=1;hg_phase=hg_pos=0;hg_next=now+2000;}
 if(!hg_selected||(int32_t)(now-hg_next)<0)return;
 hg_next=now+1000; // byte-completed USB pacing; FIFO tolerates BIOS IRQs
 if(hg_phase==0&&tx_count){
  header[hg_pos++]=tx_byte();if(hg_pos!=10)return;
  unsigned checksum=0;for(unsigned n=0;n<9;n++)checksum^=header[n];
  if(memcmp(header,"HG\1",3)||header[4]||header[9]!=checksum){fprintf(stderr,"bad native HG header\n");exit(1);}
  hg_operation=header[3];hg_block=le16(header+5);hg_length=le16(header+7);hg_phase=1;hg_pos=0;
  if(hg_operation!=3&&(uint64_t)hg_block*512+hg_length>host_size){fprintf(stderr,"native HG range\n");exit(1);}
  if(hg_length!=(hg_operation==3?6:512)||(hg_operation!=3&&(uint64_t)hg_block*512+hg_length>host_size)){fprintf(stderr,"invalid HG request op=%u block=%u len=%u\n",hg_operation,hg_block,hg_length);exit(1);}
  if(hg_operation==3){memcpy(payload,time_value,6);hg_times++;}
  else if(hg_operation==1){memcpy(payload,host_image+hg_block*512,hg_length);hg_reads++;}
  if(hg_operation!=2){unsigned sum=0;for(unsigned n=0;n<hg_length;n++)sum+=payload[n];payload[hg_length]=sum;payload[hg_length+1]=(sum>>8)^(hg_corrupt?1:0);}
 }else if(hg_phase==1&&(hg_control&2)){
  rx_byte(hg_readonly&&hg_operation==2?5:0);hg_phase=hg_readonly&&hg_operation==2?4:2;
 }else if(hg_phase==2){
  if(hg_operation==2&&tx_count){
   payload[hg_pos++]=tx_byte();if(hg_pos==hg_length+2){
    unsigned sum=0;for(unsigned n=0;n<hg_length;n++)sum+=payload[n];
    if(le16(payload+hg_length)!=(sum&65535)){fprintf(stderr,"native WRITE checksum\n");exit(1);}
    store_host(hg_block,payload,hg_length);hg_writes++;hg_phase=3;
   }
  }else if(hg_operation!=2&&(hg_control&2)&&rx_count<64){
   rx_byte(payload[hg_pos++]);if(hg_pos==hg_length+2)hg_phase=4;
  }
 }else if(hg_phase==3&&(hg_control&2)){rx_byte(0);hg_phase=4;}
 else if(hg_phase==4&&!(hg_control&1)){hg_selected=0;}
}
static int hg_transport_read(uint16_t a,unsigned char*out){
 if(a<0xe670||a>0xe673)return 0;hg_pump();
 switch(a&3){
 case 0:*out=rx_count?rx_fifo[rx_read++&63]:255;if(rx_count)rx_count--;break;
 case 1:*out=(hg_v2?16:0)|(rx_count!=0)|(tx_count<64?2:0)|(hg_selected?4:0)|(tx_count==0?8:0);break;
 case 2:*out=hg_control;break;default:*out='H';
 }return 1;
}
static int hg_transport_write(uint16_t a,unsigned char d){
 if(a<0xe670||a>0xe673)return 0;hg_pump();
 if(a==0xe670){if(tx_count==64){fprintf(stderr,"native TX overflow\n");exit(1);}tx_fifo[tx_write++&63]=d;tx_count++;}
 if(a==0xe672){
  if(d&128){tx_read=tx_write=tx_count=rx_read=rx_write=rx_count=0;}
  hg_control=d&(hg_v2?63:7);
 }return 1;
}
