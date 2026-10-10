// E690-E69F: independent 24-MHz music timer and atomic AY divider control.
// No generated clock: AY consumes enables in the existing 96-MHz domain.
module classic_audio_control(
 input wire clk,reset,read,write,input wire[3:0]address,input wire[7:0]data,
 output reg[7:0]result,output wire irq,
 output reg divider_update,output reg[31:0]divider_value,input wire divider_seen
);
 reg enabled,pending,overrun,bad_config;
 reg[31:0]period,period_shadow,counter,snapshot,divider_shadow;
 reg[1:0]seen_sync;
 wire busy=divider_update!=seen_sync[1];
 wire control=write&&address==0;
 wire ack=control&&data[1];
 wire restart=control&&data[2];
 wire event_due=enabled&&counter==period-1'b1;
 assign irq=enabled&&pending;
 always @*begin
  result=8'hff;
  case(address)
   0:result={pending,overrun,busy,bad_config,3'b0,enabled};
   1:result=8'h59;
   2:result=period[31:24];3:result=period[23:16];
   4:result=period[15:8];5:result=period[7:0];
   6:result=0;
   7:result=counter[31:24];8:result=snapshot[23:16];
   9:result=snapshot[15:8];10:result=snapshot[7:0];
   11:result=divider_value[31:24];12:result=divider_value[23:16];
   13:result=divider_value[15:8];14:result=divider_value[7:0];
   15:result={7'b0,busy};
  endcase
 end
 always @(posedge clk)begin
  seen_sync<={seen_sync[0],divider_seen};
  if(reset)begin
   enabled<=0;pending<=0;overrun<=0;bad_config<=0;counter<=0;snapshot<=0;
   period<=480000;period_shadow<=480000;
   divider_update<=0;seen_sync<=0;divider_value<=32'h01800000;divider_shadow<=32'h01800000;
  end else begin
   if(read&&address==7)snapshot<=counter;
   if(control)begin
    enabled<=data[0];
    if(data[1])begin pending<=0;overrun<=0;end
    if(data[3])bad_config<=0;
   end
   if(enabled)counter<=event_due?0:counter+1'b1;
   if(event_due)begin
    pending<=1;
    if(pending&&!ack)overrun<=1;
   end
   // Stop/restart intentionally cancel the previous event. Otherwise an ACK
   // coincident with compare leaves the NEW event pending, just like PAL IRQ.
   if(control&&(!data[0]||restart))begin counter<=0;pending<=0;overrun<=0;end
   if(write)case(address)
    2:period_shadow[31:24]<=data;3:period_shadow[23:16]<=data;
    4:period_shadow[15:8]<=data;5:period_shadow[7:0]<=data;
    6:if(data[0])begin
     if(period_shadow==0)bad_config<=1;
     else begin period<=period_shadow;counter<=0;pending<=0;overrun<=0;end
    end
    11:divider_shadow[31:24]<=data;12:divider_shadow[23:16]<=data;
    13:divider_shadow[15:8]<=data;14:divider_shadow[7:0]<=data;
    15:if(data[0])begin
     // A full engine pass needs 215 fast clocks. Limit the chip to 2 MHz;
     // Q16 periods 384..65534 also leave a spare bit for fractional carry.
     if(busy||divider_shadow<32'h01800000||divider_shadow>32'hfffeffff)bad_config<=1;
     else begin divider_value<=divider_shadow;divider_update<=!divider_update;end
    end
   endcase
  end
 end
endmodule
