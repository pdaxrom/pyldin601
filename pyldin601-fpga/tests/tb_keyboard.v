`timescale 1ns/1ps
module tb_keyboard;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,capture=0,rd=0,rs=0,wd=0,ws=0;reg[7:0]din=0;
 wire[7:0]data,status;wire irq,consumed;
 classic_keyboard dut(clk,reset,capture,rd,rs,wd,ws,din,data,status,irq,consumed);
 task write_code;input[7:0]b;begin @(negedge clk);din=b;wd=1;@(negedge clk);wd=0;end endtask
 task strobe;input[7:0]b;begin @(negedge clk);din=b;ws=1;@(negedge clk);ws=0;end endtask
 task read_code;begin @(negedge clk);rd=1;@(negedge clk);rd=0;end endtask
 initial begin
  repeat(3)@(negedge clk);reset=0;
  if(data!==8'hff||irq||!consumed)$fatal(1,"reset ports");
  write_code("A");if(data!=="A"||irq||consumed)$fatal(1,"software data latch");
  strobe(8'hbf);if(!irq||status!==8'h80)$fatal(1,"software strobe");
  @(negedge clk);rs=1;@(negedge clk);rs=0;
  if(!irq||status!==0)$fatal(1,"status handshake must not acknowledge IRQ");
  read_code;if(irq||!consumed||data!=="A")$fatal(1,"data acknowledge");
  @(negedge clk);rs=1;@(negedge clk);rs=0;
  if(status!==0)$fatal(1,"native CAPS read rearmed consumed strobe");
  strobe(8'hb7);if(irq)$fatal(1,"native CAPS write rearmed consumed key");
  write_code(8'hff);if(data!==8'hff||irq||!consumed)$fatal(1,"software release");
  write_code("B");strobe(8'hbf);capture=1;repeat(3)@(negedge clk);
  if(irq||status||data!==8'hff||!consumed)$fatal(1,"capture did not clear ports");
  capture=0;write_code("C");strobe(8'hbf);read_code;
  if(irq||!consumed)$fatal(1,"release did not restore ports");
  $display("PASS software keyboard ports: data/strobe/handshake, CAPS writes, capture/reset");$finish;
 end
endmodule
