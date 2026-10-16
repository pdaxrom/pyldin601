// Ordinary PS/2 pins plus a receive FIFO. All host commands, timing, ACKs,
// initialization and packet interpretation are performed by software.
module classic_mouse #(
 parameter CLOCK_HZ=24000000
)(input wire clk,reset,read,write,input wire[2:0]address,
 input wire[7:0]data_in,output reg[7:0]data_out,
 input wire mouse_clk,mouse_data,output wire clock_low,output wire data_low);
 reg[2:0]clock_sync,data_sync;
 reg[2:0]lines; // bit2 suppresses RX while software sends; bits1:0 drive 0/Z.
 reg[4:0]micro_divider;reg[7:0]microseconds;
 reg[7:0]watchdog;reg expired;
 reg overflow,frame_error;
 assign clock_low=lines[0];assign data_low=lines[1];
 wire received,receive_error;wire[7:0]rx_byte;
 ps2_byte_receiver receiver(clk,reset||lines[2],mouse_clk,mouse_data,received,rx_byte,receive_error);
 (* syn_ramstyle="distributed" *) reg[7:0]fifo[0:15];
 reg[3:0]head,tail;reg[4:0]count;
 wire pop=read&&address==2&&count!=0;
 wire push=received&&(count<16||pop);
 wire flush=write&&address==3&&data_in[0];
 always @*case(address)
  0:data_out=8'h4d;
  1:data_out={overflow,frame_error,3'b0,lines[2],1'b0,count!=0};
  2:data_out=count!=0?fifo[head]:8'hff;
  3:data_out={3'b0,count};
  4:data_out={expired,4'b0,lines[2],data_sync[2],clock_sync[2]};
  5:data_out=microseconds;
  default:data_out=8'hff;
 endcase
 always @(posedge clk)begin
  clock_sync<={clock_sync[1:0],mouse_clk};data_sync<={data_sync[1:0],mouse_data};
  if(reset)begin
   clock_sync<=7;data_sync<=7;lines<=0;micro_divider<=0;microseconds<=0;watchdog<=0;expired<=0;
   head<=0;tail<=0;count<=0;overflow<=0;frame_error<=0;
  end else begin
   if(micro_divider==CLOCK_HZ/1000000-1)begin
    micro_divider<=0;microseconds<=microseconds+1'b1;
    if(microseconds==255&&watchdog!=0)begin
     watchdog<=watchdog-1'b1;if(watchdog==1)expired<=1;
    end
   end else micro_divider<=micro_divider+1'b1;
   if(write&&address==4)lines<=data_in[2:0];
   if(write&&address==5)begin watchdog<=data_in;expired<=0;end
   if(write&&address==3&&data_in[1])begin overflow<=0;frame_error<=0;end
   if(receive_error)frame_error<=1;
   if(received&&!push&&!flush)overflow<=1;
   if(flush)begin head<=0;tail<=0;count<=0;end
   else begin
    if(push)begin fifo[tail]<=rx_byte;tail<=tail+1'b1;end
    if(pop)head<=head+1'b1;
    case({push,pop})2'b10:count<=count+1'b1;2'b01:count<=count-1'b1;endcase
   end

  end
 end
endmodule
