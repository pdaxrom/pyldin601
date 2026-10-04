`timescale 1ns/1ps
module tb_fast_clock;
 wire a,b;integer na=0,nb=0;
 test_fast_clock ca(a);test_fast_clock_physical cb(b);
 always @(posedge a)na=na+1;always @(posedge b)nb=nb+1;
 initial begin
  #1000;
  if(na!=400||nb!=95)$fatal(1,"wrong mixed HDL clock periods: %d %d",na,nb);
  $display("PASS mixed HDL clocks: literal 1250 ps and 5250 ps half-periods");$finish;
 end
endmodule
