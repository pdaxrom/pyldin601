`timescale 1ns/1ps
// Physical PS/2 plus production MMIO. Translation deliberately requires ROM.
module tb_keyboard_raw;
 reg clk=0;always #5 clk=~clk;
 reg fast=0;always #1.25 fast=~fast;
 reg psclk=1,psdata=1,vma=0,rw=1;reg[15:0]address=0;reg[7:0]out=0;
 wire reset,cpu_clk;wire[7:0]data;
 classic_system dut(.clk(clk),.clk_fast(fast),.pll_locked(1'b1),.btn_resetn(1'b1),
  .cpu_rw(rw),.cpu_vma(vma),.cpu_addr(address),.cpu_out(out),
  .cpu_clk(cpu_clk),.cpu_reset(reset),.cpu_in(data),
  .ps2clk(psclk),.ps2dat(psdata),.rxd(1'b1),.miso(1'b1));
 task send;input[7:0]b;input bad;reg[10:0]frame;integer n;
  begin frame={1'b1,(~^b)^bad,b,1'b0};
   for(n=0;n<11;n=n+1)begin psdata=frame[n];#300;psclk=0;#300;psclk=1;#300;end
   psdata=1;#300;
  end
 endtask
 task read_register;input[15:0]a;input[7:0]expected;
  begin @(negedge cpu_clk);address=a;vma=1;rw=1;
   @(negedge cpu_clk);#1;if(data!==expected)$fatal(1,"read %h got %h expected %h",a,data,expected);vma=0;
  end
 endtask
 task write_register;input[15:0]a;input[7:0]b;
  begin @(negedge cpu_clk);address=a;out=b;vma=1;rw=0;
   @(negedge cpu_clk);vma=0;rw=1;end
 endtask
 integer n;
 initial begin
  wait(reset===0);repeat(5)@(negedge cpu_clk);
  read_register(16'he6b0,8'h52);read_register(16'he6b4,2);read_register(16'he6b1,4);
  send(8'he0,0);send(8'hf0,0);send(8'h6b,0);send(8'h1c,1);
  read_register(16'he6b3,3);read_register(16'he628,8'hff);
  if(dut.kbd_raw_irq||dut.keyboard_irq)$fatal(1,"boot must poll without IRQ");
  write_register(16'he6b3,8'h10);
  if(!dut.kbd_raw_irq)$fatal(1,"nonempty FIFO must hold raw IRQ");
  read_register(16'he6b2,8'he0);if(!dut.kbd_raw_irq)$fatal(1,"prefix IRQ disappeared");
  read_register(16'he6b2,8'hf0);read_register(16'he6b2,8'h6b);
  if(dut.kbd_raw_irq)$fatal(1,"empty FIFO IRQ");
  write_register(16'he628,8'hc1);write_register(16'he62a,8'hbf);
  if(!dut.keyboard_irq)$fatal(1,"software-fed legacy IRQ");
  read_register(16'he628,8'hc1);read_register(16'he6b1,4);
  if(dut.keyboard_irq)$fatal(1,"legacy data did not ACK");
  write_register(16'he6b3,7);send(8'h12,0);send(8'h1c,0);
  read_register(16'he6b1,8'h4d);if(dut.kbd_raw_irq||dut.keyboard_irq)$fatal(1,"capture IRQ");
  read_register(16'he6b2,8'h12);read_register(16'he6b2,8'h1c);
  write_register(16'he650,0);
  if(dut.kbd_capture||!dut.kbd_raw_irq)$fatal(1,"native video must release and request parser reset");
  write_register(16'he6b3,8'h20);if(dut.kbd_raw_irq)$fatal(1,"parser reset ACK");
  for(n=0;n<65;n=n+1)send(n,0);
  read_register(16'he6b1,8'ha5);write_register(16'he6b3,3);
  read_register(16'he6b1,4);if(dut.kbd_raw_irq)$fatal(1,"overflow ACK");
  $display("PASS production raw PS/2: parity, FIFO/level IRQ, software legacy ports, capture/release and overflow");$finish;
 end
endmodule
