`timescale 1ns/1ps
// Check physical geometry and every repeated sample with an independent
// clock-count raster. Uniform white makes the actual DAC edges measurable.
module tb_video_viewport;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,wr=0,address=0,model_a=0;reg[7:0]data=0,rows=25;
 wire request,tick;wire[20:0]ma;wire[5:0]tv;reg done=0;
 classic_video dut(clk,reset,1'b0,wr,address,data,,8'h20,
  1'b0,11'd0,8'd0,request,ma,1'b1,done,8'hff,tv,tick,model_a,1'b0,8'd0,,,,,,1'b0,4'd0,8'd0,,,1'b0);
 wire[9:0]rx;wire[8:0]ry;wire rv,rf,rs,rb;
 pal_viewport_reference reference(.clk(clk),.reset(reset),.model_a(model_a),.extended(1'b0),.colour(1'b0),
  .rows(rows),.x(rx),.y(ry),.valid(rv),.first(rf),.sync(rs),.burst(rb));
 integer clocks=0,fields=0,lines=0,width=0,logical_pixels=0,previous_tick=-1;
 integer fetch_rows=0,last_fetch=-1,expected_row;
 reg last_valid=0;reg[5:0]want;
 always @(posedge clk)begin
  done<=request;
  if(reset)begin clocks=0;fields=0;lines=0;width=0;logical_pixels=0;previous_tick=-1;last_valid=0;fetch_rows=0;last_fetch=-1;end
  else begin
   if(request&&dut.dma_column==0)begin
    expected_row=dut.field_line==37?0:((dut.field_line-37)*rows*8)/264;
    if(expected_row==last_fetch)$fatal(1,"repeated logical row refetched into displayed bank");
    last_fetch=expected_row;fetch_rows++;
   end
   #1;
   want=rs?0:rv?49:15;
   // The separate mode-switch test checks every swinging-burst sample.
   if(!rb&&tv!==want)$fatal(1,"physical viewport model=%0d rows=%0d clock=%0d x=%0d y=%0d DAC=%0d expected=%0d",model_a,rows,clocks,rx,ry,tv,want);
   if(rv)begin width++;if(rf)logical_pixels++;end
   if(last_valid&&!rv)begin
    if(width!=1152)$fatal(1,"picture width=%0d system clocks, expected 1152 / 48 us",width);
    width=0;lines++;
   end
   last_valid=rv;
   if(tick)begin
    if(previous_tick>=0&&clocks-previous_tick!=480000)$fatal(1,"PAL field period changed");
    if(lines!=264||logical_pixels!=rows*8*(model_a?640:320))
     $fatal(1,"field coverage lines=%0d pixels=%0d",lines,logical_pixels);
    if(fetch_rows!=rows*8)$fatal(1,"DMA fetched %0d rows instead of %0d",fetch_rows,rows*8);
    lines=0;logical_pixels=0;fetch_rows=0;last_fetch=-1;previous_tick=clocks;fields++;
   end
   clocks++;
  end
 end
 task put;input a;input[7:0]d;
  begin @(negedge clk);address=a;data=d;wr=1;@(negedge clk);wr=0;end
 endtask
 initial begin
  for(integer m=0;m<2;m++)for(integer n=0;n<4;n++)begin
   @(negedge clk);reset=1;model_a=m;rows=n==0?24:n==1?25:n==2?27:29;
   repeat(3)@(negedge clk);reset=0;
   put(0,1);put(1,model_a?80:40);put(0,6);put(1,rows);put(0,10);put(1,8'h20);
   put(0,12);put(1,8'h08);put(0,13);put(1,0);
   wait(fields==4);
  end
  $display("PASS PAL viewport: 32 fields, 48 us x 264 lines, 601/601A 192/200/216/232 logical rows, every DAC sample, exact 50 Hz, no repeated-row DMA");$finish;
 end
 initial begin #170000000;$fatal(1,"viewport timeout");end
endmodule
