`timescale 1ns/1ps
// Real PS/2 receiver plus production CPU MMIO decode. No BIOS polling is
// needed to observe physical keys, including keys beyond a full native FIFO.
module tb_keyboard_raw;
 reg clk=0;always #5 clk=~clk;
 reg fast=0;always #1.25 fast=~fast;
 reg psclk=1,psdata=1,vma=0,rw=1;reg[15:0]address=0;reg[7:0]out=0;
 wire reset,cpu_clk;wire[7:0]data;
 classic_system dut(.clk(clk),.clk_fast(fast),.pll_locked(1'b1),.btn_resetn(1'b1),
  .cpu_rw(rw),.cpu_vma(vma),.cpu_addr(address),.cpu_out(out),
  .cpu_clk(cpu_clk),.cpu_reset(reset),.cpu_in(data),
  .ps2clk(psclk),.ps2dat(psdata),.rxd(1'b1),.miso(1'b1));
 task send;input[7:0]b;reg[10:0]frame;integer n;
  begin frame={1'b1,~^b,b,1'b0};
   for(n=0;n<11;n=n+1)begin psdata=frame[n];#300;psclk=0;#300;psclk=1;#300;end
   psdata=1;#300;
  end
 endtask
 task bad_parity;input[7:0]b;reg[10:0]frame;integer n;
  begin frame={1'b1,^b,b,1'b0};
   for(n=0;n<11;n=n+1)begin psdata=frame[n];#300;psclk=0;#300;psclk=1;#300;end
   psdata=1;#300;
  end
 endtask
 task event_key;input ext,up;input[7:0]scan;
  begin if(ext)send(8'he0);if(up)send(8'hf0);send(scan);end
 endtask
 task read_register;input[15:0]a;input[7:0]expected;
  begin @(negedge cpu_clk);address=a;vma=1;rw=1;
   @(negedge cpu_clk);#1;if(data!==expected)$fatal(1,"read %h got %h expected %h",a,data,expected);
   vma=0;
  end
 endtask
 task control;input[7:0]bits;
  begin @(negedge cpu_clk);address=16'he6b3;out=bits;vma=1;rw=0;
   @(negedge cpu_clk);vma=0;rw=1;end
 endtask
 task raw_read;input[7:0]expected;
  reg[7:0]old_data,old_status;reg old_irq;reg[3:0]old_count;
  begin
   old_data=dut.kbd_data;old_status=dut.kbd_status;old_irq=dut.keyboard_irq;old_count=dut.keyboard.queue_count;
   read_register(16'he6b2,expected);
   if(dut.kbd_data!==old_data||dut.kbd_status!==old_status||dut.keyboard_irq!==old_irq||dut.keyboard.queue_count!==old_count)
    $fatal(1,"raw read consumed a native keyboard event");
  end
 endtask
 integer k;
 initial begin
  wait(reset===0);force dut.boot_mode=0;
  read_register(16'he6b0,8'h52);read_register(16'he6b1,0);raw_read(8'hff);
  bad_parity(8'h6b);read_register(16'he6b3,0);
  event_key(1,0,8'h6b);event_key(1,1,8'h6b);
  read_register(16'he6b3,5);raw_read(8'he0);raw_read(8'h6b);raw_read(8'he0);raw_read(8'hf0);raw_read(8'h6b);
  send(8'he1);send(8'h14);send(8'h77);send(8'he1);send(8'hf0);send(8'h14);send(8'hf0);send(8'h77);
  read_register(16'he6b3,8);raw_read(8'he1);raw_read(8'h14);raw_read(8'h77);raw_read(8'he1);raw_read(8'hf0);raw_read(8'h14);raw_read(8'hf0);raw_read(8'h77);
  // Fill native FIFO without reading the character or PIA status.
  for(k=0;k<10;k=k+1)begin event_key(0,0,8'h1c+k);event_key(0,1,8'h1c+k);end
  if(dut.keyboard.queue_count!=8)$fatal(1,"native full FIFO fixture missing");
  control(3);event_key(1,0,8'h72);event_key(1,1,8'h72);
  read_register(16'he6b3,5);raw_read(8'he0);raw_read(8'h72);raw_read(8'he0);raw_read(8'hf0);raw_read(8'h72);
  for(k=0;k<65;k=k+1)send(k);read_register(16'he6b3,64);read_register(16'he6b1,8'ha1);
  for(k=0;k<64;k=k+1)raw_read(k);
  read_register(16'he6b1,8'h80);control(3);read_register(16'he6b1,0);
  event_key(0,0,8'h29);read_register(16'he6b3,1);
  force dut.cpu_reset=1;repeat(4)@(negedge clk);release dut.cpu_reset;
  wait(reset===0);read_register(16'he6b3,0);read_register(16'he6b1,0);
  $display("PASS raw PS/2 CPU/MMIO: exact E0/F0/E1 bytes, full native FIFO independence, raw overflow/flush/reset");$finish;
 end
 initial begin #3000000;$fatal(1,"keyboard raw timeout");end
endmodule
