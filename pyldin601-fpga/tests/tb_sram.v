`timescale 1ns/1ps
module tb_sram;
reg clk=0,reset=1,request=0,write=0;always #5 clk=~clk;
reg[20:0]address=0;reg[7:0]data=0;wire ready,done;wire[7:0]result;
wire[19:0]sa;wire[15:0]dq;wire ce,oe,we,lb,ub;reg[15:0]mem[0:31];
sram_byte_controller dut(clk,reset,request,write,address,data,ready,done,result,sa,dq,ce,oe,we,lb,ub);
assign dq=!ce&&!oe&&we?mem[sa]:16'bz;
always @(negedge we)if(!oe)$fatal(1,"SRAM write while OE active");
always @(posedge we)if(!ce)begin if(!lb)mem[sa][7:0]=dq[7:0];if(!ub)mem[sa][15:8]=dq[15:8];end
task transfer;input w;input[20:0]a;input[7:0]d;
begin wait(ready);@(negedge clk);request=1;write=w;address=a;data=d;@(negedge clk);request=0;wait(done);@(negedge clk);end endtask
initial begin
 for(integer n=0;n<32;n=n+1)mem[n]=16'h3c5a;
 #22;reset=0;
 transfer(1,0,8'ha1);if(mem[0]!=16'h3ca1)$fatal(1,"low lane");
 transfer(1,1,8'hb2);if(mem[0]!=16'hb2a1)$fatal(1,"high lane");
 transfer(0,0,0);if(result!=8'ha1)$fatal(1,"read low");
 transfer(0,1,0);if(result!=8'hb2)$fatal(1,"read high");
 transfer(1,62,8'h07);if(mem[31]!=16'h3c07)$fatal(1,"word address");
 reset=1;@(negedge clk);if(!ce||!oe||!we||dq!==16'bz)$fatal(1,"idle/reset bus");
 $display("PASS SRAM byte lanes, word addressing, read/write turnaround and reset release");$finish;
end
endmodule
