`timescale 1ns/1ps
// Independent raster oracle: integer division from elapsed 24 MHz clocks,
// rather than the RTL's phase accumulators, row banks or pixel counters.
module pal_viewport_reference #(parameter LATENCY=4)(
 input wire clk,reset,model_a,extended,colour,
 input wire [7:0] rows,
 output wire [9:0] x,output wire [8:0] y,
 output wire valid,first,sync,burst,alternate,
 output wire [9:0] held_x,output wire [8:0] held_y,
 output wire held_valid,held_first,held_sync,held_burst,held_alternate
);
 integer cycles=0,frame=0,h,half,line,r,height,px,py,previous_x,previous_y;
 integer canonical,burst_line,burst_frame;
 reg [9:0] xs[0:LATENCY-1];reg [8:0] ys[0:LATENCY-1];
 reg [LATENCY-1:0] vs=0,fs=0,ss=0,bs=0,as=0;
 reg rv,rf,rs,rb,ra;
 always @*begin
  h=cycles%1536;half=cycles/768;line=half/2-(half>=625?312:0);
  r=line-38;height=extended?200:(rows>29?232:rows*8);
  px=(h-288)*(model_a&&!extended?10:5)/18;
  py=r*height/264;
  previous_x=(h-289)*(model_a&&!extended?10:5)/18;
  previous_y=(r-1)*height/264;
  rv=h>=288&&h<1440&&r>=0&&r<264&&height!=0;
  rf=rv&&(h==288||px!=previous_x)&&(r==0||py!=previous_y);
  if(half%625<5||(half%625>=10&&half%625<15))rs=h%768<57;
  else if(half%625<10)rs=h%768<654;
  else rs=h<114;
  canonical=(half+1245)%1250;burst_line=canonical/2;
  burst_frame=(half<5?frame^1:frame);
  rb=h>=135&&h<189&&(burst_frame?
   !(burst_line<5||burst_line>=621||(burst_line>=310&&burst_line<=318)):
   !(burst_line<6||burst_line>=622||(burst_line>=309&&burst_line<=317)));
  ra=((half/2)+frame)&1;
 end
 always @(posedge clk)begin
  if(reset)begin
   cycles<=0;frame<=0;vs<=0;fs<=0;ss<={LATENCY{1'b1}};bs<=0;as<=0;
   for(integer j=0;j<LATENCY;j++)begin xs[j]<=0;ys[j]<=0;end
  end else begin
   if(cycles==959999)begin cycles<=0;frame<=frame^1;end else cycles<=cycles+1;
   xs[0]<=px;ys[0]<=py;
   for(integer j=1;j<LATENCY;j++)begin xs[j]<=xs[j-1];ys[j]<=ys[j-1];end
   vs<={vs[LATENCY-2:0],rv};fs<={fs[LATENCY-2:0],rf};
   ss<={ss[LATENCY-2:0],rs};bs<={bs[LATENCY-2:0],rb};as<={as[LATENCY-2:0],ra};
  end
 end
 assign x=xs[LATENCY-1];assign y=ys[LATENCY-1];assign valid=vs[LATENCY-1];assign first=fs[LATENCY-1];
 assign sync=ss[LATENCY-1];assign burst=bs[LATENCY-1];assign alternate=as[LATENCY-1];
 generate if(LATENCY>=3)begin
  assign held_x=xs[2];assign held_y=ys[2];assign held_valid=vs[2];assign held_first=fs[2];
  assign held_sync=ss[2];assign held_burst=bs[2];assign held_alternate=as[2];
 end else begin
  assign held_x=0;assign held_y=0;assign held_valid=0;assign held_first=0;
  assign held_sync=1;assign held_burst=0;assign held_alternate=0;
 end endgenerate
endmodule
