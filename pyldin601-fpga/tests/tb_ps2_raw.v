`timescale 1ns/1ps
module tb_ps2_raw;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,received=0,read=0,write=0;reg[7:0]scan=0,din=0;reg[1:0]address=0;
 wire[7:0]dout;
 classic_ps2_raw dut(clk,reset,received,scan,read,write,address,din,dout,1'b0,);
 task push;input[7:0]b;begin @(negedge clk);received=1;scan=b;@(negedge clk);received=0;end endtask
 task check;input[1:0]a;input[7:0]expected;
  begin address=a;#1;if(dout!==expected)$fatal(1,"raw reg%0d=%h expected%h",a,dout,expected);end endtask
 task pop;input[7:0]expected;begin @(negedge clk);check(2,expected);read=1;@(negedge clk);read=0;end endtask
 task control;input[7:0]bits;begin @(negedge clk);address=3;din=bits;write=1;@(negedge clk);write=0;end endtask
 integer k;
 initial begin
  repeat(3)@(negedge clk);reset=0;check(0,8'h52);check(1,0);check(3,0);pop(8'hff);
  // Read while empty plus push retains the newly arriving byte.
  @(negedge clk);address=2;read=1;received=1;scan=8'he0;check(2,8'hff);
  @(negedge clk);read=0;received=0;check(3,1);pop(8'he0);
  for(k=0;k<64;k=k+1)push(k);check(3,64);check(1,8'h21);
  // Full simultaneous pop/push must accept and preserve FIFO order.
  @(negedge clk);check(2,0);read=1;received=1;scan=8'hf0;
  @(negedge clk);read=0;received=0;check(3,64);check(1,8'h21);
  push(8'hff);check(1,8'ha1); // drop newest; sticky overflow
  for(k=1;k<64;k=k+1)pop(k);pop(8'hf0);check(3,0);check(1,8'h80);
  control(2);check(1,0);
  repeat(3)begin for(k=0;k<47;k=k+1)push(k+64);for(k=0;k<47;k=k+1)pop(k+64);end
  for(k=0;k<65;k=k+1)push(k);control(1);check(3,0);check(1,8'h80);
  control(3);check(1,0);push(8'he1);
  @(negedge clk);reset=1;@(negedge clk);reset=0;check(3,0);check(1,0);
  $display("PASS raw FIFO: empty/full simultaneous push/pop, ordering/wrap, 64-byte capacity, overflow, flush/reset");$finish;
 end
endmodule
