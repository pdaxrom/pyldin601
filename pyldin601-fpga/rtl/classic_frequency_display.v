// hardware-lcd common-anode scanner, adapted from uJ11 HC7000 diagnostics.
// One segment across both digits; commons are off before cathodes change.
module classic_frequency_display #(parameter CLOCK_HZ=24000000)(
 input wire clk,reset,input wire[1:0]speed,input wire boot_mode,
 output wire[8:0]seg_led_h,seg_led_l
);
 localparam DIVISOR=CLOCK_HZ/32000;
 localparam WIDTH=DIVISOR<2?1:$clog2(DIVISOR);
 reg[WIDTH-1:0]divider=0;
 reg[1:0]phase=0;reg[3:0]slot=0;reg[15:0]frame=0;
 reg[8:0]high_digit=9'h0ff,low_digit=9'h0ff;
 // Active-low {g,f,e,d,c,b,a}. No decimal points.
 wire[1:0]shown=boot_mode?2'd2:speed;
 wire[6:0]glyph=shown==0?7'h79:shown==1?7'h24:shown==2?7'h19:7'h00;
 always @(posedge clk)begin
  if(reset)begin divider<=0;phase<=0;slot<=0;frame<=0;high_digit<=9'h0ff;low_digit<=9'h0ff;end
  else begin
   divider<=divider==DIVISOR-1?0:divider+1'b1;
   if(divider==DIVISOR-1)begin
    phase<=phase+1'b1;
    case(phase)
     0:begin high_digit[8]<=0;low_digit[8]<=0;if(slot==0)frame<={1'b0,~glyph,1'b0,~7'h40};end
     1:begin
      high_digit[7:0]<=!slot[3]&&frame[slot]?~(8'b1<<slot[2:0]):8'hff;
      low_digit[7:0]<=slot[3]&&frame[slot]?~(8'b1<<slot[2:0]):8'hff;
     end
     2:begin high_digit[8]<=!slot[3]&&frame[slot];low_digit[8]<=slot[3]&&frame[slot];end
     3:begin high_digit[8]<=0;low_digit[8]<=0;slot<=slot+1'b1;end
    endcase
   end
  end
 end
 assign seg_led_h=high_digit;assign seg_led_l=low_digit;
endmodule
