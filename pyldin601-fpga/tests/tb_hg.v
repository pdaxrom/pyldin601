`timescale 1ns/1ps
module tb_hg;
 reg clk=0,reset=1,rd=0,wr=0,tms=0,tck=0,tdi=0;
 reg[1:0]address=0;reg[7:0]din=0;wire[7:0]dout;wire tdo,enable;
 reg[7:0]received;integer i;
 always #20 clk=~clk;
 classic_hg dut(clk,reset,rd,wr,address,din,dout,tms,tck,tdi,tdo,enable);
 task put;input[1:0]a;input[7:0]d;begin
  @(negedge clk);address=a;din=d;wr=1;
  @(negedge clk);wr=0;repeat(4)@(negedge clk);
 end endtask
 task get;input[7:0]expected;begin
  @(negedge clk);address=0;rd=1;
  #1;
  if(dout!==expected)$fatal(1,"HG RX: got %02x expected %02x",dout,expected);
  @(negedge clk);rd=0;repeat(4)@(negedge clk);
 end endtask
 task exchange;input[7:0]data;integer bitn;begin
  for(bitn=0;bitn<8;bitn=bitn+1)begin
   tdi=data[bitn];#500;received[bitn]=tdo;tck=1;#500;tck=0;
  end
  #1000; // 1 MHz TCK; positive-edge sample, negative-edge change
 end endtask
 initial begin
  repeat(5)@(negedge clk);reset=0;repeat(5)@(negedge clk);
  if(enable)$fatal(1,"TDO driven in idle/JTAG");
  address=3;#1;if(dout!==8'h48)$fatal(1,"HG identity");
  put(2,8'h80);put(0,8'ha5);put(0,8'h3c);put(2,5);
  if(!enable||!tdo)$fatal(1,"HG request missing");
  tms=1;#1000;exchange(8'hff);
  if(received!==8'ha5)$fatal(1,"LSB-first TX %02x",received);
  exchange(0);if(received!==8'h3c)$fatal(1,"second TX");
  address=1;#1;if(dout[7:6]||!dout[3]||dout[0])$fatal(1,"TX empty/RX disabled");
  put(2,3);exchange(8'h52);exchange(8'hc7);get(8'h52);get(8'hc7);
  // CPU pauses across 64 host bytes (interrupts), then drains the EBR FIFO.
  for(i=0;i<64;i=i+1)exchange(i);
  for(i=0;i<64;i=i+1)get(i);
  for(i=0;i<8;i=i+1)begin exchange(i+80);get(i+80);end
  for(i=0;i<65;i=i+1)exchange(i);
  address=1;#1;if(!dout[6])$fatal(1,"RX overflow not latched");
  put(2,0);tms=0;#1000;put(2,8'h80);
  address=1;#1;if(dout[7:6]||dout[0])$fatal(1,"flush did not reset FIFO/errors");
  put(2,5);tms=1;#1000;exchange(0);
  address=1;#1;if(!dout[7])$fatal(1,"TX underrun not latched");
  reset=1;repeat(4)@(negedge clk);reset=0;
  if(enable)$fatal(1,"warm reset did not release TDO");
  $display("PASS HG pins, LSB framing, EBR FIFO wrap/pause, phase direction, overflow, underrun, reset");$finish;
 end
endmodule
