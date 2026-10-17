// Execute the production terminal and DOS file API against an independent wire peer.
#define UART_MMIO_CUSTOM 1
static unsigned clock_mult=1;
#define TEST_KEY_CYCLES (100000*clock_mult)
#include "test_uart_app.c"
#include "../host/hg/hg.h"
#define hg_transport_read uart_host_read
#define hg_transport_write uart_host_write
#include "hg_transport.h"
#undef hg_transport_read
#undef hg_transport_write
static HgVolume uart_volume;
static int uart_durable(unsigned block,const uint8_t*data,unsigned length){return hg_volume_write(&uart_volume,block,data,length);}
static unsigned long_receive;
static char drive_letter='b';
static const char*disk_path(const char*name){static char path[100];snprintf(path,sizeof path,"%c:%s",drive_letter,name);return path;}
static unsigned char *r;
static unsigned char pal[8192];static unsigned paladdr;
#include "paint_dma_model.h"
static unsigned base,baud=7,configured,rx_n,rx_i,tx_n,host_paused,fifo_n,fifo_i,serial_error;
static unsigned char host[1000000],tx[1000000],fifo[16];
static uint64_t rx_at,tx_at;static unsigned wire_period=1041,last_irq;
static void clock_observe(void){if(irq_count!=last_irq){next_irq+=(clock_mult-1)*20000;last_irq=irq_count;}}
static void arrival(void){
 while(rx_i<rx_n&&!host_paused&&virtual_cycles>=rx_at){
  if(fifo_n<16){fifo[(fifo_i+fifo_n)%16]=host[rx_i];fifo_n++;}else serial_error|=0x20;
  rx_i++;rx_at+=wire_period;
 }
 if(host_paused)rx_at=virtual_cycles+wire_period;
}
static int hg_read_byte(unsigned short a,unsigned char*out){
 if(a<0xe644||a>0xe647)return paint_dma_read(a,out)||uart_host_read(a,out);arrival();
 switch(a&3){
 case 0:*out='U';break;case 1:*out=baud;break;
 case 2:*out=(virtual_cycles>=tx_at?2:0)|(fifo_n!=0)|serial_error;break;
 default:require(fifo_n,"wire receiver never reads empty FIFO");*out=fifo[fifo_i];fifo_i=(fifo_i+1)%16;fifo_n--;serial_error=0;break;
 }return 1;
}
static int hg_write_byte(unsigned short a,unsigned char d){
 if(a<0xe644||a>0xe647)return paint_dma_write(a,d)||uart_host_write(a,d);arrival();
 switch(a&3){
 case 1:baud=d;break;
 case 2:if(d==3){fifo_n=fifo_i=0;tx_at=virtual_cycles;}if(d==0x15)configured++;break;
 case 3:require(virtual_cycles>=tx_at&&tx_n<sizeof tx,"UART obeys TX holding backpressure");tx[tx_n++]=d;tx_at=virtual_cycles+wire_period;
  if(d==17)host_paused=0;if(base&&!MC6800GetCpuRam()[base+UART_TRANSFER]&&d==19)host_paused=1;break;
 }return 1;
}
static void feed(const void*p,unsigned n){if(rx_i!=rx_n||fifo_n)fprintf(stderr,"pending rx=%u/%u fifo%u tx%u pc%x base%x block%u err%u\n",rx_i,rx_n,fifo_n,tx_n,PC,base,r[base+UART_X_BLOCK],r[base+UART_X_ERROR]);require(rx_i==rx_n&&!fifo_n,"independent peer queue is drained");memcpy(host,p,n);rx_n=n;rx_i=0;rx_at=virtual_cycles+wire_period;}
static void settle(void){uint64_t end=virtual_cycles+100000000;do{until(virtual_cycles+1009);}while(virtual_cycles<end&&(rx_i!=rx_n||fifo_n||r[base+UART_RX_HEAD]!=r[base+UART_RX_TAIL]));until(virtual_cycles+100000);require(rx_i==rx_n&&!fifo_n,"terminal receives complete wire stream");}
static void send_text(const char*s){feed(s,strlen(s));settle();}
static unsigned cell(unsigned x,unsigned y){unsigned start=crtc[12]*256+crtc[13],step=r[base+UART_CELL_BYTES];return r[start+y*crtc[1]+x*step+(step==2)];}
static void cursor(unsigned x,unsigned y){require(r[base+UART_T_X]==x&&r[base+UART_T_Y]==y,"VT cursor logical position");unsigned want=crtc[12]*256+crtc[13]+y*crtc[1]+x*r[base+UART_CELL_BYTES]+(!model_a?2:r[base+UART_CELL_BYTES]==2);require(crtc[14]*256+crtc[15]==want,"hardware caret follows VT input position");}
static unsigned crc16(const unsigned char*p,unsigned n){unsigned c=0;for(unsigned j=0;j<n;j++){c^=p[j]<<8;for(unsigned k=0;k<8;k++)c=(c<<1)^((c&0x8000)?0x1021:0);c&=65535;}return c;}
static void packet(unsigned seq,const unsigned char*p,unsigned char*out){out[0]=1;out[1]=seq;out[2]=seq^255;memcpy(out+3,p,128);unsigned c=crc16(p,128);out[131]=c>>8;out[132]=c;}
static unsigned data_byte(unsigned k){return ((k*73)^(k>>8)^(k>>3))&255;}
static void wait_tx(unsigned n){uint64_t end=virtual_cycles+160000000;while(tx_n<n&&virtual_cycles<end)until(virtual_cycles+101);require(tx_n>=n,"XMODEM peer receives bounded response");}
static void expect(unsigned value){wait_tx(1);if(tx[0]!=value){fprintf(stderr,"peer expected %02x got %02x n=%u pc=%x err=%u\n",value,tx[0],tx_n,PC,r[base+UART_X_ERROR]);require(0,"XMODEM protocol control byte");}memmove(tx,tx+1,--tx_n);}
static void file_dialog(unsigned send,const char*path){key(send?0x3e:0x3d);require(r[base+UART_UI_ACTIVE],"F3/F4 open a modal file input");until(virtual_cycles+200000);require(cell(0,5)==0xda&&cell(r[base+UART_COLUMNS]-1,19)==0xd9,"modal border uses native table glyphs");char local[100];snprintf(local,sizeof local,"%s",path);local[0]=drive_letter;type_text(local);tx_n=0;key(0x1c);}
static void finish_dialog(const char*message){uint64_t end=virtual_cycles+5000000;while(!contains(message)&&virtual_cycles<end)until(virtual_cycles+1009);require(contains(message),"transfer result is readable");key(1);uint64_t leave_end=virtual_cycles+15000000;while(r[base+UART_UI_ACTIVE]&&virtual_cycles<leave_end)until(virtual_cycles+1009);require(!r[base+UART_UI_ACTIVE]&&!r[base+UART_TRANSFER],"transfer returns to terminal focus");while(PC!=base+UART_TERMINAL&&virtual_cycles<leave_end)until(virtual_cycles+1);require(PC==base+UART_TERMINAL,"return to terminal loop before external DOS probe");tx_n=0;}
static void receive_wrap_case(unsigned count){
 unsigned total=(count+127)&~127u;unsigned char *expected=malloc(total),pkt[133];require(expected!=NULL,"long receive oracle allocation");
 for(unsigned k=0;k<total;k++)expected[k]=k<count?data_byte(k):26;
 file_dialog(0,"b:wrap.bin");expect(17);expect('C');
 for(unsigned off=0;off<total;off+=128){unsigned seq=(off/128+1)&255;packet(seq,expected+off,pkt);feed(pkt,sizeof pkt);expect(6);if(seq==255){feed(pkt,sizeof pkt);expect(6);require(!r[base+UART_X_BLOCK],"duplicate FF is acknowledged before receive counter wraps to 00");}}
 unsigned char eot=4;feed(&eot,1);expect(6);finish_dialog("Complete.");file_check(disk_path("wrap.bin"),expected,total);free(expected);
}
static void receive_case(void){
 unsigned char block[128],pkt[133];for(unsigned k=0;k<128;k++)block[k]=data_byte(k);
 file_dialog(0,"b:rx.bin");expect(17);expect('C');
 packet(1,block,pkt);pkt[132]^=1;feed(pkt,sizeof pkt);expect(21);require(r[base+UART_X_BLOCK]==1,"bad CRC never commits bytes");
 pkt[132]^=1;serial_error=0x10;feed(pkt,sizeof pkt);expect(21);require(r[base+UART_X_BLOCK]==1,"UART header framing error rejects a packet even when its CRC matches");feed(pkt,sizeof pkt);expect(6);require(r[base+UART_X_BLOCK]==2,"good CRC commits one block");
 feed(pkt,sizeof pkt);expect(6);require(r[base+UART_X_BLOCK]==2,"lost ACK duplicate is not written twice");
 for(unsigned k=0;k<128;k++)block[k]=data_byte(k+128);packet(2,block,pkt);feed(pkt,20);expect(21);feed(pkt,sizeof pkt);expect(6);
 unsigned char eot=4;feed(&eot,1);expect(6);until(virtual_cycles+100000);feed(&eot,1);expect(6);finish_dialog("Complete.");
 unsigned char expected[256];for(unsigned k=0;k<256;k++)expected[k]=data_byte(k);file_check(disk_path("rx.bin"),expected,sizeof expected);
 file_dialog(0,"b:rx.bin");finish_dialog("Destination exists");file_check(disk_path("rx.bin"),expected,sizeof expected);
 file_dialog(0,"b:abort.bin");expect(17);expect('C');packet(1,block,pkt);feed(pkt,sizeof pkt);expect(6);key(1);expect(24);expect(24);finish_dialog("Cancelled");
 strcpy((char*)r+0x3100,disk_path("abort.bin"));word_at(0x3000,0x3100);word_at(0x3002,0);require(invoke(0x4a,1,0,0x3000)==11,"cancelled receive has no published file");
 file_dialog(0,"b:remote.bin");expect(17);expect('C');unsigned char can[]={24,24};feed(can,2);expect(24);expect(24);finish_dialog("Remote cancelled");
 file_dialog(0,"b:ut0000.tmp");expect(17);expect('C');feed(&eot,1);expect(6);finish_dialog("Complete.");file_check(disk_path("ut0000.tmp"),block,0);
 file_dialog(0,"b:bad1k.bin");expect(17);expect('C');unsigned char stx=2;feed(&stx,1);expect(24);expect(24);finish_dialog("Transfer failed");
 file_dialog(0,"b:missing\\bad.bin");finish_dialog("Disk error");
 if(long_receive)receive_wrap_case(long_receive);

}
static void send_case(unsigned count){
 file_dialog(1,"b:send.bin");expect(17);unsigned char request='C';feed(&request,1);
 unsigned char previous[133];unsigned seq=1;
 for(unsigned off=0;off<count;off+=128,seq++){
  wait_tx(133);require(r[base+UART_UI_FILLED]==(unsigned)((uint64_t)off*30/count),"send progress bar scales actual acknowledged blocks against file size");require(tx[0]==1&&tx[1]==(seq&255)&&tx[2]==((seq^255)&255),"native sender generates SOH and wrapping block numbers");
  for(unsigned k=0;k<128;k++)require(tx[3+k]==(off+k<count?data_byte(off+k):26),"native sender preserves every binary byte and pads final block");
  require(crc16(tx+3,128)==(tx[131]*256+tx[132]),"native sender CRC matches independent oracle");memcpy(previous,tx,133);memmove(tx,tx+133,tx_n-133);tx_n-=133;
  if(seq==1){unsigned char nak=21;feed(&nak,1);wait_tx(133);require(!memcmp(previous,tx,133),"NAK resends identical packet without rereading disk");memmove(tx,tx+133,tx_n-133);tx_n-=133;}
  if(seq==2){wait_tx(133);require(!memcmp(previous,tx,133),"ACK timeout resends the same packet");memmove(tx,tx+133,tx_n-133);tx_n-=133;}
  unsigned char ack=6;feed(&ack,1);
 }
 expect(4);unsigned char nak=21;feed(&nak,1);expect(4);unsigned char ack=6;feed(&ack,1);finish_dialog("Complete.");
}
int main(int argc,char**argv){
 if(argc<5)return 2;model_a=!strcmp(argv[2],"601a");cpu_hd=!strcmp(argv[3],"hd6303");unsigned mode=atoi(argv[4]);long_receive=argc>5&&atoi(argv[5])>32768?atoi(argv[5]):0;MC6800SetMachine(cpu_hd?PYLDIN_MACHINE_HD6303:PYLDIN_MACHINE_601);
 size_t n;unsigned char*rom=load(model_a?"build/rom-a.reference":"build/rom.reference",&n);memcpy(config,rom,64);memcpy(physical+0x10000,rom+512,ROM_BYTES);free(rom);image=load(argv[1],&image_size);committed=1;
 MC6800Init();MC6800Reset();until(60000000);key(0x1c);key(0x1c);prompt_wait();r=MC6800GetCpuRam();if(argc>7){require(!hg_volume_open(&uart_volume,argv[7],true,HG_MAX_SECTORS,false),"open private durable HG volume");host_image=uart_volume.image;host_size=uart_volume.size;host_write=uart_durable;hg_v2=1;unsigned hd=0;while(hd<8&&(r[0xeb03+hd*2]||r[0xeb04+hd*2]))hd++;require(hd<8,"free drive for HG");drive_letter='a'+hd;command("b:hg");require(contains("HG 2.0 remote disk"),"real HG resident installed");}invoke(0x12,mode,mode?0:0x71,0);unsigned sp0=SP,heap0=r[0xee1e]*256+r[0xee1f];
 char launch[100];snprintf(launch,sizeof launch,"%s%s",disk_path("uart"),argc>6&&atoi(argv[6])>1?" 115200":" 9600");type_text(launch);key(0x1c);until(virtual_cycles+20000000);require(configured==1,"native UART configured");
 unsigned char*pgm=load("build/input/UART.PGM",&n),sig[24],mask[24];unsigned off=pgm[4]*256+pgm[5];memcpy(sig,pgm+off,24);memset(mask,255,24);for(unsigned k=0;k<pgm[2]*256+pgm[3];k++){unsigned a=pgm[16+2*k]*256+pgm[17+2*k];if(a<24)mask[a]=0;}free(pgm);
 for(unsigned p=0x400;p<0xb000;p++){unsigned k;for(k=0;k<24;k++)if((r[p+k]&mask[k])!=(sig[k]&mask[k]))break;if(k==24){base=p;break;}}require(base,"locate relocated native terminal");last_irq=irq_count;native_step_hook=clock_observe;if(argc>6&&atoi(argv[6])>1){clock_mult=atoi(argv[6]);last_irq=irq_count;native_step_hook=clock_observe;wire_period=clock_mult*10000000/115200;require(baud==10,"high-speed case configures 115200 on real UART registers");}
 send_text("\033[2J\033[Habc\033[3;5HXYZ");require(cell(0,0)=='a'&&cell(4,2)=='X'&&cell(6,2)=='Z',"CUP and erase render actual video cells");cursor(7,2);
 send_text("\0337\033[9;9H!\0338Q");require(cell(7,2)=='Q'&&cell(8,8)=='!',"DECSC/DECRC preserve cursor");cursor(8,2);
 send_text("\033[31;44;1mR\033[0m");if(r[base+UART_CELL_BYTES]==2){unsigned a=crtc[12]*256+crtc[13]+2*crtc[1]+8*2;require(r[a]==0x41,"ANSI foreground/background and bold use colour attributes");}
 send_text("\033[999999999;99H\033[1;1HOK\033]0;hidden title\007\033[2;1Hyes");if(cell(0,0)!='O'||cell(0,1)!='y')fprintf(stderr,"parse err%02x ser%02x state%u rx%u/%u pos%u,%u cells %c %c %c\n",r[base+UART_ERRORS],serial_error,r[base+UART_T_STATE],rx_i,rx_n,r[base+UART_T_X],r[base+UART_T_Y],cell(0,1),cell(1,1),cell(2,1));require(cell(0,0)=='O'&&cell(0,1)=='y',"oversized CSI and OSC cannot escape parser bounds");
 send_text("\033[2J\033[H\033[3;6r\033[6;1Hbottom\nnext");require(cell(0,4)=='b'&&cell(6,5)=='n'&&cell(0,6)==' ',"DECSTBM scrolls only its window");
 send_text("\033[r\033[2J\033[H\033(0lqqk\033(B");require(cell(0,0)==0xda&&cell(1,0)==0xc4&&cell(3,0)==0xcf,"DEC graphics use native table glyphs");
 tx_n=0;send_text("\033[4;9H\033[6n\033[5n\033[c");require(tx_n==17&&!memcmp(tx,"\033[4;9R\033[0n\033[?1;0c",17),"VT status and cursor reports reach serial peer");
 tx_n=0;key(1);key(0x48);key(0x4b);require(tx_n==7&&!memcmp(tx,"\033\033[A\033[D",7),"Esc and arrows are sent to host");
 send_text("\033[?1h");tx_n=0;key(0x50);require(tx_n==3&&!memcmp(tx,"\033OB",3),"DECCKM switches cursor-key encoding");
 unsigned char saved[2200];unsigned start=crtc[12]*256+crtc[13],pitch=crtc[1];memcpy(saved,r+start,25*pitch);key(0x3b);until(virtual_cycles+1000000);key(1);until(virtual_cycles+1000000);require(!memcmp(saved,r+start,25*pitch),"help restores every terminal cell and attribute");
 // Remote XOFF holds keyboard bytes without blocking the application.
 send_text("\023");tx_n=0;type_text("pause");until(virtual_cycles+3000000*clock_mult);require(!tx_n&&r[base+UART_TX_HEAD]!=r[base+UART_TX_TAIL],"remote XOFF queues keyboard input beyond two seconds");send_text("\021");require(tx_n==5&&!memcmp(tx,"pause",5),"XON drains queued keyboard input in order");
 // Full-speed terminal stream forces flow control while scrolling.
 char flood[5000];unsigned flood_n=0;for(unsigned j=0;j<100;j++)flood_n+=snprintf(flood+flood_n,sizeof flood-flood_n,"row %03u abcdefghijklmnop\r\n",j);send_text("\033[r\033[2J\033[H");feed(flood,flood_n);settle();require(!r[base+UART_ERRORS],"XON/XOFF protects the hardware FIFO and terminal ring during scrolling");
 receive_case();send_case(argc>5?atoi(argv[5]):257);
 key(0x44);prompt_wait();require(SP==sp0&&r[0xee1e]*256+r[0xee1f]==heap0&&!resets,"terminal and file transfers restore DOS stack/heap without reset");
 if(argc>7){require(!hg_volume_sync(&uart_volume),"sync transferred HG files");hg_volume_close(&uart_volume);}
 printf("PASS ANSI/XMODEM %s/%s mode%u: cursor, colour, parser, margins, glyphs, replies, modal restore, CRC/retry/duplicate/cancel, binary send/receive, cleanup\n",argv[2],argv[3],mode);return 0;
}
