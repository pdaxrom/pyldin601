`timescale 1ns/1ps
module tb_arbiter;
reg clk=0,reset=1;always #5 clk=~clk;
reg[2:0]req=0;wire[2:0]accepted,completed;wire busy,mreq,mwrite,mready,mdone;
wire[20:0]ma;wire[7:0]data;integer ac[0:2],dc[0:2];
memory_arbiter dut(clk,reset,req,3'b010,{21'd30,21'd20,21'd10},24'h030201,
 accepted,completed,busy,mreq,mwrite,ma,data,mready,mdone,1'b0,5'b0);
sram_byte_controller ram(.clk(clk),.reset(reset),.request(mreq),.write(mwrite),.address(ma),.write_data(data),.ready(mready),.done(mdone));
always @(posedge clk)if(!reset)for(integer n=0;n<3;n=n+1)begin
 if(accepted[n])begin ac[n]<=ac[n]+1;req[n]<=0;end
 if(completed[n])dc[n]<=dc[n]+1;
end
initial begin
 for(integer n=0;n<3;n=n+1)begin ac[n]=0;dc[n]=0;end
 #22;reset=0;req=7;
 repeat(35)@(negedge clk);
 for(integer n=0;n<3;n=n+1)if(ac[n]!=1||dc[n]!=1)$fatal(1,"duplicate/lost transfer owner=%d a=%d d=%d",n,ac[n],dc[n]);
 if(busy)$fatal(1,"stuck");$display("PASS single acceptance/completion and SRAM ownership for three masters");$finish;
end
endmodule
