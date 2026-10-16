// Software-loaded 16x16 cursor, 2 bits/pixel, independent of video RAM/palette.
// Pixel codes 00 transparent, 01 black, 10 white, 11 grey. Graphics only.
// E6BE: bit7 enable, bits6:0 index. E6BF: data; writes advance the index.
// 0..3: X lo/hi, Y lo/hi; 64..127: bitmap, row-major, MSB pixel first.
module classic_pointer(input wire clk,reset,write,address,input wire[7:0]data_in,
 output reg[7:0]data_out,input wire[9:0]scan_x,input wire[8:0]scan_y,
 input wire active,output wire[1:0]pixel);
 reg enabled;reg[6:0]index;
 reg[9:0]x;reg[8:0]y;
 (* syn_ramstyle="block_ram" *) reg[7:0]bitmap[0:63];
 wire[9:0]dx=scan_x-x;wire[8:0]dy=scan_y-y;
 reg[7:0]shape,cpu_byte;reg[1:0]subpixel;reg visible;
 // Scan coordinates arrive one clock before the PAL input's normal tuple.
 always @(posedge clk)begin
  shape<=bitmap[{dy[3:0],dx[3:2]}];cpu_byte<=bitmap[index[5:0]];
  subpixel<=dx[1:0];visible<=!reset&&enabled&&active&&dx<16&&dy<16;
 end
 wire[1:0]dot=shape>>{~subpixel,1'b0};
 assign pixel=visible?dot:2'b0;
 always @*begin
  if(!address)data_out={enabled,index};
  else if(index[6])data_out=cpu_byte;
  else case(index)
   0:data_out=x[7:0];1:data_out={6'b0,x[9:8]};
   2:data_out=y[7:0];3:data_out={7'b0,y[8]};default:data_out=0;
  endcase
 end
 always @(posedge clk)begin
  if(reset)begin enabled<=0;index<=0;x<=0;y<=0;end
  else if(write)begin
   if(!address)begin enabled<=data_in[7];index<=data_in[6:0];end
   else begin
    index<=index+1'b1;
    if(index[6])bitmap[index[5:0]]<=data_in;
    else case(index)
     0:x[7:0]<=data_in;1:x[9:8]<=data_in[1:0];
     2:y[7:0]<=data_in;3:y[8]<=data_in[0];
    endcase
   end
  end
 end
endmodule
