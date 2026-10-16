`timescale 1ns/1ps
// Replay actual native Paint RAM/CRTC snapshots through production video RTL.
module tb_paint_dialog_video;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,wr=0,address=0,model_a=0;
 reg[7:0]data=0,mode=0;
 wire request;wire[20:0]ma;reg done=0;reg[7:0]memory_data;
 classic_video dut(clk,reset,1'b0,wr,address,data,,mode,
  1'b0,11'b0,8'b0,request,ma,1'b1,done,memory_data,,,model_a,
  1'b0,8'b0,,,,,,1'b0,4'd0,8'd0,,,1'b0,18'd0,1'b0,1'b0,8'd0,);
 wire[9:0]rx;wire[8:0]ry;wire rv,rf;
 pal_viewport_reference #(.LATENCY(3)) refview(.clk(clk),.reset(reset),
  .model_a(model_a),.extended(1'b0),.colour(1'b0),.rows(configuration[8]),
  .x(rx),.y(ry),.valid(rv),.first(rf));
 reg[7:0]ram[0:65535],reference[0:127999],configuration[0:19];
 integer checked=0,test_case=0,width=320,total=0;
 always @(posedge clk)begin
  done<=request;
  if(request)begin
   if(ma>=65536)$fatal(1,"Paint native dialog escaped ordinary RAM");
   memory_data<=ram[ma];
  end
  #1;
  if(!reset&&rv)begin
   if(dut.held_colour!==reference[ry*width+rx][3:0])
    $fatal(1,"Paint dialog case%0d raster x%0d y%0d got%h expected%h",test_case,rx,ry,dut.held_colour,reference[ry*width+rx]);
   if(rf)begin checked++;total++;end
  end
 end
 task put;input a;input[7:0]d;
  begin @(negedge clk);address=a;data=d;wr=1;@(negedge clk);wr=0;end
 endtask
 initial begin
  for(integer n=0;n<4;n++)begin
   @(negedge clk);reset=1;checked=0;test_case=n;
   $readmemh($sformatf("build/paint/dialog-%0d-ram.mem",n),ram);
   $readmemh($sformatf("build/paint/dialog-%0d-config.mem",n),configuration);
   model_a=configuration[0];mode=configuration[1];width=model_a?640:320;
   $readmemh($sformatf("build/paint/dialog-%0d-pixels.mem",n),reference,0,width*200-1);
   repeat(3)@(negedge clk);reset=0;
   for(integer j=0;j<16;j++)begin put(0,j);put(1,configuration[j+2]);end
   wait(checked==width*200*2);
  end
  $display("PASS Paint F5/Escape dialogs: %0d actual video RTL pixels, both PAL fields, 601 and 601A",total);$finish;
 end
 initial begin #120000000;$fatal(1,"Paint dialog video timeout case%0d pixels%0d",test_case,checked);end
endmodule
