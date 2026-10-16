#define UART_MMIO_CUSTOM 1
#include "test_uart_app.c"
static unsigned baud=7,configured,rx_count,rx_head,tx_count,errors;
static unsigned char rx[65536],tx[65540];
static uint64_t rx_at,tx_at;
static int hg_read_byte(unsigned short a,unsigned char*out){
 if(a<0xe644||a>0xe647)return 0;
 switch(a&3){
 case 0:*out='U';break;case 1:*out=baud;break;
 case 2:*out=(virtual_cycles>=tx_at?2:0)|((rx_count&&virtual_cycles>=rx_at)?1:0)|errors;break;
 default:require(rx_count&&virtual_cycles>=rx_at,"binary RX consumes only available data");*out=rx[rx_head++];rx_count--;rx_at=virtual_cycles+173;errors=0;break;
 }return 1;
}
static int hg_write_byte(unsigned short a,unsigned char d){
 if(a<0xe644||a>0xe647)return 0;
 switch(a&3){
 case 1:baud=d;break;
 case 2:if(d==3){require(!rx_count,"rate change does not discard unconsumed host bytes");tx_at=virtual_cycles;}if(d==0x15)configured++;break;
 case 3:require(virtual_cycles>=tx_at&&tx_count<sizeof tx,"binary echo obeys TX backpressure");tx[tx_count++]=d;tx_at=virtual_cycles+227;break;
 }return 1;
}
static void feed(const unsigned char*p,unsigned n){require(!rx_count,"host queue drained");memcpy(rx,p,n);rx_count=n;rx_head=0;rx_at=virtual_cycles;}
static void wait_value(unsigned *p,unsigned value){uint64_t end=virtual_cycles+250000000;while(*p!=value&&virtual_cycles<end)until(virtual_cycles+1);require(*p==value,"binary diagnostic makes bounded progress");}
int main(int argc,char**argv){
 if(argc!=4)return 2;model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);image=load(argv[1],&image_size);committed=1;
 MC6800Init();MC6800Reset();until(60000000);key(0x1c);key(0x1c);prompt_wait();unsigned sp0=SP,heap0=MC6800GetCpuRam()[0xee1e]*256+MC6800GetCpuRam()[0xee1f];
 type_text("b:uarttest");key(0x1c);wait_value(&configured,1);
 for(unsigned rate=0;rate<11;rate++){
  unsigned count=rate==10?32768:257+rate;unsigned char header[]={0x55,0xaa,rate,count>>8,count,0};for(unsigned k=0;k<5;k++)header[5]^=header[k];
  // A damaged header must not enter a payload transfer or change the baud.
  if(!rate){header[5]^=1;feed(header,6);wait_value(&configured,2);header[5]^=1;}
  unsigned old=configured;feed(header,6);wait_value(&configured,old+1);require(baud==rate,"binary diagnostic selects every hardware rate");
  tx_count=0;unsigned char sync=0xa5;feed(&sync,1);wait_value(&tx_count,1);require(tx[0]==0x5a,"binary diagnostic acknowledges at requested speed");
  unsigned char *payload=malloc(count);for(unsigned k=0;k<count;k++)payload[k]=((k*73)^(k>>8)^(k>>3))&255;
  tx_count=0;feed(payload,count);if(rate==4)errors=0x70;wait_value(&tx_count,count+3);
  require(!rx_count&&!memcmp(payload,tx,count),"binary echo preserves every payload byte");require(tx[count]=='D'&&tx[count+1]==(rate==4?0x70:0)&&tx[count+2]==rate,"binary trailer retains parity/overrun/framing flags and baud");free(payload);
  unsigned char ack=0xcc;old=configured;feed(&ack,1);wait_value(&configured,old+1);require(baud==7,"host ACK returns diagnostic to baseline speed");
 }
 key(1);prompt_wait();require(SP==sp0&&MC6800GetCpuRam()[0xee1e]*256+MC6800GetCpuRam()[0xee1f]==heap0,"binary diagnostic exits without stack/heap leaks");
 printf("PASS native UART binary %s/%s: 11 rates, 32768-byte stream, corrupt header, backpressure, RX errors, cleanup\n",argv[2],argv[3]);return 0;
}
