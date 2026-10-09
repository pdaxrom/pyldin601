`timescale 1ns/1ps
// A PAL receiver must see the same sync, blanking and swinging burst during
// boot, native monochrome/colour, RGB332 and return to the native console.
// Switch at arbitrary points, including sync/burst, rather than only VBL.
module tb_video_mode_switch;
 reg fast=0;always #1.25 fast=~fast;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,wr=0,address=0,model_a=0,extended=0,check_return=0;
 reg[7:0]data=0,mode=1,rows=24;
 wire request,base_request,tick;reg done=0,base_done=0;
 wire[5:0]tv,base_tv;wire[20:0]ma,base_ma;
 reg palette_write=0;reg[3:0]palette_register=0;reg[7:0]palette_data=0;
 classic_video #(.GFX(1)) dut(clk,reset,1'b0,wr,address,data,,mode,
  1'b0,11'd0,8'd0,request,ma,1'b1,done,8'hff,tv,tick,model_a,extended,8'hff,,,,,,palette_write,palette_register,palette_data,,,fast);
 // Native console stays running while the DUT enters/leaves graphics.
 classic_video #(.GFX(1)) base(clk,reset,1'b0,wr,address,data,,8'h01,
  1'b0,11'd0,8'd0,base_request,base_ma,1'b1,base_done,8'hff,base_tv,,model_a,1'b0,8'hff,,,,,,1'b0,4'd0,8'd0,,,fast);
 wire[9:0]rx;wire[8:0]ry;wire rv,rf,rs,rb;
 pal_viewport_reference reference(.clk(clk),.reset(reset),.model_a(model_a),
  .extended(extended),.colour(1'b1),.rows(rows),.x(rx),.y(ry),
  .valid(rv),.first(rf),.sync(rs),.burst(rb));
 integer cycles=0,porch_checks=0,burst_checks=0,transitions=0,fields=0;
 integer return_checks=0;
 reg[31:0]phase=0,phase1=0,phase2=0,phase3=0;
 reg[5:0]waveform[0:1023];integer p;reg[5:0]expected;
 always @(posedge clk)begin
  done<=request;base_done<=base_request;
  if(reset)begin cycles=0;fields=0;phase=0;phase1=0;phase2=0;phase3=0;end
  else begin
   phase3=phase2;phase2=phase1;phase1=phase;phase=phase+32'd793426981;
   #1;
   if(!rv)begin
    if(tv!==base_tv)$fatal(1,"mode changed PAL envelope: clock=%0d mode=%h extended=%b DAC=%0d reference=%0d",cycles,mode,extended,tv,base_tv);
    // The ROM phase at DAC is three clocks old, independent of video mode.
    p=phase3[31:27];if(reference.alternate)p=(15-p)&31;
    expected=rs?0:rb?waveform[512+p]:15;
    if(tv!==expected)$fatal(1,"invalid PAL envelope clock=%0d sync=%b burst=%b DAC=%0d expected=%0d",cycles,rs,rb,tv,expected);
    porch_checks++;if(rb)burst_checks++;
   end
   if(check_return&&rv)begin
    if(tv!==base_tv)$fatal(1,"native console changed after graphics at x=%0d y=%0d DAC=%0d reference=%0d",rx,ry,tv,base_tv);
    if(rf)return_checks++;
   end
   if(tick)fields++;
   cycles++;
  end
 end
 task put;input a;input[7:0]d;
  begin @(negedge clk);address=a;data=d;wr=1;@(negedge clk);wr=0;end
 endtask
 initial begin
  $readmemh("rtl/pal_waveform.mem",waveform);
  for(integer m=0;m<2;m++)begin
   @(negedge clk);reset=1;model_a=m;extended=0;mode=1;rows=24;check_return=0;
   repeat(3)@(negedge clk);reset=0;
   // A custom non-black index 0 must never colour the PAL border/porches.
   for(integer a=0;a<8192;a++)begin
    @(negedge clk);palette_write=1;palette_register=14;palette_data=49;
    @(negedge clk);palette_write=0;
   end
   put(0,1);put(1,m?80:40);put(0,6);put(1,24);
   put(0,10);put(1,8'h20);put(0,12);put(1,4);put(0,13);put(1,0);
   // Bootstrap's 24 rows and UniDOS's 25 rows keep the same PAL envelope.
   wait(fields==1);rows=25;put(0,6);put(1,25);
   for(integer n=0;n<14;n++)begin
    repeat(37777+n*131)@(negedge clk);
    extended=!extended;mode=n%3==0?8'h24:8'h01;transitions++;
   end
   extended=0;mode=1;wait(fields==3);check_return=1;wait(fields==4);check_return=0;
  end
  if(burst_checks<10000)$fatal(1,"incomplete four-field burst coverage");
  if(return_checks!=192000)$fatal(1,"native return coverage=%0d",return_checks);
  $display("PASS 601/601A PAL envelope: boot 24 rows, UniDOS 25 rows, 28 arbitrary graphics/colour transitions, %0d porch and %0d burst samples, %0d native return pixels, unchanged sync/black/DDS",porch_checks,burst_checks,return_checks);$finish;
 end
 initial begin #50000000;$fatal(1,"mode switch timeout");end
endmodule
