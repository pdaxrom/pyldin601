// Polled MC6850 word/control layout, with the board's baud latch at E645.
// 24-MHz clock is independent of runtime CPU speed. No unhandled CPU IRQ.
module classic_uart #(
 parameter CLOCK_HZ=24000000
)(input wire clk,reset,read,write,input wire[1:0] address,
 input wire[7:0] data_in,output reg[7:0] data_out,
 input wire rxd,output wire txd);
 reg[2:0] rx_sync;
 reg[7:0] control,baud;
 reg[13:0] period;
 reg[13:0] baud_counter;
 wire baud_tick=baud_counter==0;
 always @*case(baud[3:0])
  0:period=(CLOCK_HZ+1200)/2400; 1:period=(CLOCK_HZ+2400)/4800;
  2:period=(CLOCK_HZ+4800)/9600; 3:period=(CLOCK_HZ+9600)/19200;
  4:period=(CLOCK_HZ+19200)/38400;5:period=(CLOCK_HZ+38400)/76800;
  6:period=(CLOCK_HZ+76800)/153600;7:period=(CLOCK_HZ+153600)/307200;
  8:period=(CLOCK_HZ+307200)/614400;9:period=(CLOCK_HZ+460800)/921600;
  default:period=(CLOCK_HZ+921600)/1843200;
 endcase
 wire master_reset=write&&address==2&&data_in[1:0]==3;
 wire clear=reset||master_reset;
 // One holding byte and an independently clocked transmit shift register.
 reg[7:0] holding;reg pending;
 reg[11:0] tx_shift;reg[3:0] tx_left;reg[3:0] tx_timer;
 wire take_tx=tx_left==0&&pending&&baud_tick;
 wire put_tx=write&&address==3&&(!pending||take_tx);
 wire seven=control[4:2]<4;
 wire parity_enabled=seven||control[4:3]==3;
 wire two_stops=control[4:2]==0||control[4:2]==1||control[4:2]==4;
 wire parity_bit=(seven?^holding[6:0]:^holding)^control[2];
 wire break_tx=control[6:5]==3;
 assign txd=break_tx?1'b0:tx_shift[0];
 // RX FIFO entries include the framing/parity flags of that particular byte.
 (* syn_ramstyle="distributed" *) reg[9:0] fifo[0:15];
 reg[3:0] head,tail;reg[4:0] count;reg overrun;
 reg[3:0] rx_state;reg[3:0] rx_timer;
 reg[7:0] rx_shift;reg[2:0] rx_format;
 reg rx_parity,rx_bad_parity,rx_bad_stop;
 reg rx_ready;reg[9:0] rx_value;
 wire pop=read&&address==3&&count!=0;
 wire push=rx_ready&&(count<16||pop);
 wire rx_seven=rx_format<4;
 wire rx_has_parity=rx_seven||rx_format[2:1]==3;
 wire rx_two_stops=rx_format==0||rx_format==1||rx_format==4;
 always @*case(address)
  0:data_out=8'h55; // E644 identity 'U'; no write side effects.
  1:data_out={baud[7],1'b0,2'b0,baud[3:0]}; // DSR is asserted, no flow-control wire.
  2:data_out={1'b0,count!=0&&fifo[head][9],overrun,
    count!=0&&fifo[head][8],2'b0,!pending,count!=0};
  3:data_out=count!=0?fifo[head][7:0]:8'hff;
  default:data_out=8'hff;
 endcase
 always @(posedge clk)begin
  rx_sync<={rx_sync[1:0],rxd};rx_ready<=0;
  if(clear)begin
   control<=8'h15;baud<=7;rx_sync<=7;baud_counter<=0;
   pending<=0;holding<=0;tx_shift<=12'hfff;tx_left<=0;tx_timer<=0;
   head<=0;tail<=0;count<=0;overrun<=0;
   rx_state<=0;rx_timer<=0;rx_shift<=0;rx_format<=5;
   rx_parity<=0;rx_bad_parity<=0;rx_bad_stop<=0;rx_value<=0;rx_ready<=0;
  end else begin
   if(baud_tick)baud_counter<=period-1'b1;else baud_counter<=baud_counter-1'b1;
   if(write&&address==2)control<=data_in;
   // Reprogramming a clock halfway through a character would corrupt it.
   if(write&&address==1&&tx_left==0&&!pending&&rx_state==0)begin baud<=data_in;baud_counter<=0;end
   if(put_tx)begin holding<=data_in;pending<=1;end
   else if(take_tx)pending<=0;
   if(take_tx)begin
    if(seven)tx_shift<={3'b111,parity_bit,holding[6:0],1'b0};
    else if(parity_enabled)tx_shift<={2'b11,parity_bit,holding,1'b0};
    else tx_shift<={3'b111,holding,1'b0};
    tx_left<=4'd10+(two_stops?4'd1:4'd0)+(!seven&&parity_enabled?4'd1:4'd0);
    tx_timer<=15;
   end else if(tx_left!=0&&baud_tick)begin
    if(tx_timer!=0)tx_timer<=tx_timer-1'b1;
    else begin tx_shift<={1'b1,tx_shift[11:1]};tx_left<=tx_left-1'b1;tx_timer<=15;end
   end
   // One shared 16x baud clock, independent RX/TX bit phases. The nearest
   // integer divisor differs by at most 0.17% across supported baud rates.
   // Sample the start in its centre, then every data/parity/stop bit centre.
   if(rx_state==0)begin
    if(!rx_sync[2])begin rx_state<=1;rx_timer<=7;rx_format<=control[4:2];end
   end else if(rx_state==13)begin if(rx_sync[2])rx_state<=0;end
   else if(baud_tick)begin
    if(rx_timer!=0)rx_timer<=rx_timer-1'b1;
    else begin
    rx_timer<=15;
    case(rx_state)
     1:if(rx_sync[2])rx_state<=0;
       else begin rx_state<=2;rx_shift<=0;rx_parity<=0;rx_bad_parity<=0;rx_bad_stop<=0;end
     2,3,4,5,6,7,8,9:begin
      rx_shift<={rx_sync[2],rx_shift[7:1]};rx_parity<=rx_parity^rx_sync[2];
      if(rx_state==(rx_seven?8:9))rx_state<=rx_has_parity?10:11;
      else rx_state<=rx_state+1'b1;
     end
     10:begin rx_bad_parity<=(rx_parity^rx_sync[2])!=rx_format[0];rx_state<=11;end
     11:begin
      rx_bad_stop<=!rx_sync[2];
      if(rx_two_stops)rx_state<=12;
      else begin rx_value<={rx_bad_parity,!rx_sync[2],(rx_seven?{1'b0,rx_shift[7:1]}:rx_shift)};rx_ready<=1;rx_state<=13;end
     end
     12:begin rx_value<={rx_bad_parity,rx_bad_stop||!rx_sync[2],(rx_seven?{1'b0,rx_shift[7:1]}:rx_shift)};rx_ready<=1;rx_state<=13;end
     // Wait through the rest of the stop bit. A held break produces one byte.
     13:if(rx_sync[2])rx_state<=0;
     default:rx_state<=0;
    endcase
    end
   end
   if(pop)begin head<=head+1'b1;overrun<=0;end
   if(push)begin fifo[tail]<=rx_value;tail<=tail+1'b1;end
   if(rx_ready&&!push)overrun<=1;
   case({push,pop})2'b10:count<=count+1'b1;2'b01:count<=count-1'b1;endcase
  end
 end
endmodule
