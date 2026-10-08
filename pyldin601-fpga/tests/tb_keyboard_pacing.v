`timescale 1ns/1ps
module tb_keyboard_pacing;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,psclk=1,psdata=1,rd=0,tick=0,runtime=1;
 wire[7:0]data,status;wire irq;
 classic_keyboard dut(clk,reset,psclk,psdata,1'b0,rd,1'b0,data,status,irq,runtime,tick);
 task send;input[7:0]b;reg[10:0]frame;integer n;
  begin
   frame={1'b1,~^b,b,1'b0};
   for(n=0;n<11;n=n+1)begin psdata=frame[n];#300;psclk=0;#300;psclk=1;#300;end
   psdata=1;#300;
  end
 endtask
 task tap;input[7:0]b;
  begin send(b);send(8'hf0);send(b);end
 endtask
 task read_key;
  begin @(negedge clk);rd=1;@(negedge clk);rd=0;repeat(5)@(negedge clk);end
 endtask
 task acknowledge;
  begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(5)@(negedge clk);end
 endtask
 task empty;
  begin if(data!==8'hff||irq)$fatal(1,"debounce exposed a key data=%h irq=%b",data,irq);end
 endtask
 initial begin
  #22;reset=0;
  tap(8'h1c);tap(8'h32);tap(8'h32); // A, B, a second distinct tap of B
  if(data!=="a"||!irq)$fatal(1,"first tap delayed");
  read_key;empty;
  acknowledge;empty;acknowledge;empty;
  acknowledge;empty;
  acknowledge;if(data!=="b"||!irq)$fatal(1,"different tap not presented after 4 timer IRQs");
  read_key;empty;
  acknowledge;empty;acknowledge;empty;acknowledge;empty;acknowledge;empty;
  acknowledge;empty;
  acknowledge;if(data!=="b"||!irq)$fatal(1,"same tap not presented after 6 timer IRQs");
  read_key;empty;
  // A new make during the guard must enter the FIFO even if it was empty.
  tap(8'h21);empty;
  acknowledge;empty;acknowledge;empty;
  acknowledge;empty;
  acknowledge;if(data!=="c"||!irq)$fatal(1,"incoming tap bypassed/lost in guard");
  read_key;empty;
  // Primary BIOS polls directly: it has no native IRQ debounce interval.
  runtime=0;tap(8'h23);if(data!=="d")$fatal(1,"boot tap delayed");
  read_key;tap(8'h23);if(data!=="d")$fatal(1,"boot same tap delayed");
  @(negedge clk);reset=1;@(negedge clk);reset=0;repeat(5)@(negedge clk);empty;
  if(dut.queue_count!=0||dut.quiet_ticks!=6)$fatal(1,"reset did not clear pacing/FIFO");
  $display("PASS BIOS debounce pacing, distinct/repeated/incoming taps, boot bypass and reset");$finish;
 end
endmodule
