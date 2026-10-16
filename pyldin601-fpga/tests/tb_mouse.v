`timescale 1ns/1ps
// The test host explicitly drives the ordinary PS/2 pins through MMIO.
// There is no FPGA host-command sequencer or automatic initialization.
module tb_mouse;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,read=0,write=0;reg[2:0]address=0;reg[7:0]din=0;
 wire[7:0]dout;wire host_clock_low,host_data_low;
 reg device_clock_low=0,device_data_low=0;
 tri1 mouse_clk,mouse_data;
 assign mouse_clk=host_clock_low||device_clock_low?1'b0:1'bz;
 assign mouse_data=host_data_low||device_data_low?1'b0:1'bz;
 classic_mouse dut(clk,reset,read,write,address,din,dout,
  mouse_clk,mouse_data,host_clock_low,host_data_low);
 task wr;input[2:0]a;input[7:0]b;begin
  @(negedge clk);address=a;din=b;write=1;@(negedge clk);write=0;
 end endtask
 task check;input[2:0]a;input[7:0]b;begin
  address=a;#1;if(dout!==b)$fatal(1,"mouse reg%0d=%h expected%h",a,dout,b);
 end endtask
 task pop;input[7:0]b;begin
  @(negedge clk);check(2,b);read=1;@(negedge clk);read=0;
 end endtask
 task send;input[7:0]b;input bad;reg[10:0]frame;integer i;begin
  frame={1'b1,(~^b)^bad,b,1'b0};
  for(i=0;i<11;i=i+1)begin
   device_data_low=!frame[i];repeat(600)@(negedge clk);
   device_clock_low=1;repeat(900)@(negedge clk);
   device_clock_low=0;repeat(300)@(negedge clk);
  end
  device_data_low=0;repeat(600)@(negedge clk);
 end endtask
 task software_send;input[7:0]b;reg[8:0]bits;integer i;begin
  bits={(~^b),b};wr(4,5);repeat(2600)@(negedge clk);
  wr(4,7);repeat(300)@(negedge clk);wr(4,6);wait(mouse_clk===1);
  for(i=0;i<10;i=i+1)begin
   wait(mouse_clk===0);wr(4,i<9&&!bits[i]?6:4);
   wait(mouse_clk===1);
  end
  wait(mouse_clk===0);repeat(20)@(negedge clk);check(4,4);
  wait(mouse_clk===1);repeat(600)@(negedge clk);wr(4,0);
 end endtask
 task accept_command;input[7:0]expected;integer i,held;reg[8:0]bits;begin
  wait(host_clock_low);held=0;
  while(host_clock_low)begin @(negedge clk);held=held+1;end
  if(held<2400||mouse_data!==0)$fatal(1,"host request-to-send %0d cycles",held);
  repeat(600)@(negedge clk);bits={(~^expected),expected};
  for(i=0;i<10;i=i+1)begin
   device_clock_low=1;repeat(900)@(negedge clk);
   if(mouse_data!==(i==9?1'b1:bits[i]))$fatal(1,"host TX %h bit%0d data%b",expected,i,mouse_data);
   device_clock_low=0;repeat(900)@(negedge clk);
  end
  device_data_low=1;repeat(600)@(negedge clk);
  device_clock_low=1;repeat(900)@(negedge clk);
  device_clock_low=0;repeat(300)@(negedge clk);device_data_low=0;
 end endtask
 integer i;reg[7:0]tick;
 initial begin
  repeat(3)@(negedge clk);reset=0;check(0,8'h4d);check(1,0);pop(8'hff);
  repeat(100000)@(negedge clk);
  if(host_clock_low||host_data_low)$fatal(1,"FPGA must never initialize the mouse automatically");
  address=5;#1;tick=dout;repeat(24*256)@(negedge clk);#1;
  if(dout!==tick)$fatal(1,"1-us software timer wrap");
  send(8'haa,0);send(0,0);pop(8'haa);pop(0);
  fork software_send(8'hf4);accept_command(8'hf4);join
  check(1,0);send(8'hfa,0);pop(8'hfa);
  send(8'h09,0);send(8'h81,0);send(8'hff,0);check(3,3);
  pop(9);pop(8'h81);pop(8'hff);
  send(8'h55,1);check(3,0);check(1,8'h40);wr(3,3);check(1,0);
  for(i=0;i<17;i=i+1)send(i,0);check(1,8'h81);check(3,16);
  for(i=0;i<16;i=i+1)pop(i);check(1,8'h80);wr(3,2);check(1,0);
  // Both low-drive bits are independent, device always wins a released line.
  wr(4,5);repeat(5)@(negedge clk);check(4,6);
  wr(4,6);repeat(5)@(negedge clk);check(4,5);
  wr(4,7);repeat(5)@(negedge clk);check(4,4);
  @(negedge clk);reset=1;@(negedge clk);reset=0;
  if(host_clock_low||host_data_low)$fatal(1,"reset did not release pins");
  wr(5,1);repeat(24*256+5)@(negedge clk);check(4,8'h83);
  if(host_clock_low||host_data_low)$fatal(1,"software timer must not control PS/2 pins");
  wr(5,0);check(4,3);
  $display("PASS ordinary PS/2 mouse: software-only 0/Z command/ACK, no automatic initialization, RX parity/FIFO/overflow, pin readback/reset, microsecond timer/countdown");$finish;
 end
 initial begin #30000000;$fatal(1,"mouse timeout");end
endmodule
