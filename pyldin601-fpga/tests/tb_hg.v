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
  // Continuous 1 MHz TCK; no CPU/USB gap inside a packet.
 end endtask
 initial begin
  repeat(5)@(negedge clk);reset=0;repeat(5)@(negedge clk);
  if(enable)$fatal(1,"TDO driven in idle/JTAG");
  address=3;#1;if(dout!==8'h48)$fatal(1,"HG identity");
  put(2,8'h80);put(0,8'ha5);put(0,8'h3c);put(2,5);
  if(!enable||!tdo)$fatal(1,"HG request missing");
  #200;tms=1;#1000;exchange(8'hff);
  if(received!==8'ha5)$fatal(1,"LSB-first TX %02x",received);
  exchange(0);if(received!==8'h3c)$fatal(1,"second TX");
  #200;address=1;#1;if(dout[7:6]||!dout[3]||dout[0])$fatal(1,"TX empty/RX disabled");
  put(2,3);exchange(8'h52);exchange(8'hc7);get(8'h52);get(8'hc7);
  // CPU pauses across 64 host bytes (interrupts), then drains the EBR FIFO.
  for(i=0;i<64;i=i+1)exchange(i);
  for(i=0;i<64;i=i+1)get(i);
  for(i=0;i<8;i=i+1)begin exchange(i+80);get(i+80);end
  for(i=0;i<65;i=i+1)exchange(i);
  address=1;#1;if(!dout[6])$fatal(1,"RX overflow not latched");
  put(2,0); #200;tms=0;#1000;put(2,8'h80);
  address=1;#1;if(dout[7:6]||dout[0])$fatal(1,"flush did not reset FIFO/errors");
  put(2,5);#200;tms=1;#1000;exchange(0);
  address=1;#1;if(!dout[7])$fatal(1,"TX underrun not latched");
  put(2,0); #200;tms=0;#1000;put(2,8'h80);
  address=1;#1;if(!dout[4])$fatal(1,"packet capability missing");
  put(2,27);#1000;if(tdo)$fatal(1,"status phase incorrectly grants a packet");
  put(2,11);#1000;if(!tdo)$fatal(1,"empty RX must grant 32 bytes");
  exchange(0);if(received!==8'h8b)$fatal(1,"RX query %h",received);
  address=1;#1;if(dout[0])$fatal(1,"credit query polluted RX FIFO");
  // Two complete credits fit even when the CPU is stopped throughout both.
  #200;tms=1;#1000;for(i=0;i<32;i=i+1)exchange(i);
   #200;tms=0;#1000;if(!tdo)$fatal(1,"RX second credit missing");
  #200;tms=1;#1000;for(i=32;i<64;i=i+1)exchange(i);
   #200;tms=0;#1000;if(tdo)$fatal(1,"full RX wrongly grants a burst");
  for(i=0;i<31;i=i+1)get(i);
  #1000;if(tdo)$fatal(1,"RX grant with only 31 free bytes");
  get(31);#1000;if(!tdo)$fatal(1,"RX credit after 32 pops missing");
  for(i=32;i<64;i=i+1)get(i);
  put(2,13);#1000;if(tdo)$fatal(1,"empty TX wrongly grants a burst");
  for(i=0;i<31;i=i+1)put(0,i);
  #1000;if(tdo)$fatal(1,"TX grant with only 31 queued bytes");
  put(0,31);#1000;if(!tdo)$fatal(1,"TX 32-byte grant missing");
  #200;tms=1;#1000;for(i=0;i<32;i=i+1)begin exchange(0);if(received!==i[7:0])$fatal(1,"packet TX byte");end
   #200;tms=0;#1000;if(tdo)$fatal(1,"drained TX grants a packet");
  put(0,8'h12);put(0,8'h34);#1000;if(tdo)$fatal(1,"short TX before final flag");
  put(2,45);#1000;if(!tdo)$fatal(1,"final checksum tail credit missing");
  exchange(0);if(received!==8'had)$fatal(1,"final TX query %h",received);
  #200;tms=1;#1000;exchange(0);if(received!==8'h12)$fatal(1,"tail low");
  exchange(0);if(received!==8'h34)$fatal(1,"tail high");
   #200;tms=0;#1000;address=1;#1;if(dout[7:6])$fatal(1,"packet FIFO errors");
  put(2,25);exchange(0);if(received!==8'h98)$fatal(1,"terminal query %h",received);
  #200;tms=1;#1000;exchange(0);if(received!==8'h98)$fatal(1,"terminal acknowledgment query %h",received);
  reset=1;repeat(4)@(negedge clk);reset=0;
  if(enable)$fatal(1,"warm reset did not release TDO");
  $display("PASS HG v1/v2 pins, framing, FIFO wrap, 32-byte credits, CPU pause, checksum tail, phase direction, errors, reset");$finish;
 end
endmodule
