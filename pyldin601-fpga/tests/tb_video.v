`timescale 1ns/1ps
module tb_video;
reg clk=0,reset=1,wr=0;always #5 clk=~clk;
reg address=0,graphics=0;reg[7:0]data=0;wire[7:0]result;wire request,tick;
wire[20:0]ma;wire[5:0]tv;reg ready=1,done=0;
classic_video dut(clk,reset,1'b0,wr,address,data,result,{2'b0,graphics,5'b0},1'b0,11'b0,8'b0,request,ma,ready,done,8'hff,tv,tick,1'b0,1'b0,8'b0,,,,,,1'b0,4'd0,8'd0,,);
integer ticks=0,count=0,last_tick=0;
always @(posedge clk)if(!reset)begin
 count<=count+1;
 if(tick)begin if(ticks>0&&count-last_tick!=480000)$fatal(1,"50 Hz period");ticks<=ticks+1;last_tick<=count;end
 done<=request&&ready;
 if(request&&ready&&ma[20:16]!=0)$fatal(1,"video escaped base RAM");
end
task put;input a;input[7:0]d;
begin @(negedge clk);address=a;data=d;wr=1;@(negedge clk);wr=0;end endtask
initial begin
 #22;reset=0;
 put(0,1);put(1,48);put(0,6);put(1,28);put(0,12);put(1,8'hff);put(0,13);put(1,8'hf0);
 graphics=1;#1;if(dut.stride!=48)$fatal(1,"graphics stride");
 wait(ticks==3);#1;
 if(dut.half_line>1249)$fatal(1,"625-line frame");
 $display("PASS PAL frame/field periods, graphics stride48 and base RAM addressing");$finish;
end
initial begin #20000000;$fatal(1,"video timeout");end
endmodule
