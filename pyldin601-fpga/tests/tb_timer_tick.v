`timescale 1ns/1ps
// A PAL pulse coincident with the PIA read must remain pending: the CPU
// samples the previous latch value on this edge, so clearing would lose it.
module tb_timer_tick;
 reg clk=0;always #5 clk=~clk;
 reg fast=0;always #1.25 fast=~fast;
 reg button=1,vma=0;reg[15:0]address=16'he62b;
 wire reset,cpu_clk;wire[7:0]data;
 classic_system #(.BUTTON_TICK_DIV(1),.BUTTON_DEBOUNCE_MS(2),.BUTTON_LONG_MS(4),.BUTTON_RELOAD_MS(128)) dut(
  .clk(clk),.clk_fast(fast),.pll_locked(1'b1),.btn_resetn(button),
  .cpu_rw(1'b1),.cpu_vma(vma),.cpu_addr(address),.cpu_out(8'b0),
  .cpu_clk(cpu_clk),.cpu_reset(reset),.cpu_in(data),
  .ps2clk(1'b1),.ps2dat(1'b1),.rxd(1'b1),.miso(1'b1));
 task collision;
  input old_pending;
  begin
   wait(dut.video_tick);@(negedge clk);
   // Arrange the read phase at the real raster pulse. No forced timer latch.
   force dut.phase=1;vma=1;
   @(posedge clk);#1;
   if(data[7]!==old_pending)$fatal(1,"PIA did not return previous tick state");
   if(dut.tick_pending!==1'b1)$fatal(1,"PAL tick lost when PIA read coincides with pulse");
   @(negedge clk);vma=0;release dut.phase;
  end
 endtask
 task consume;
  begin
   @(negedge cpu_clk);vma=1;
   @(negedge cpu_clk);#1;
   if(data[7]!==1'b1||dut.tick_pending!==0)$fatal(1,"pending tick not consumed once");
   vma=0;
  end
 endtask
 initial begin
  wait(reset===0);
  collision(0);consume();
  wait(dut.tick_pending);collision(1);consume();
  button=0;wait(dut.restart_reset);repeat(200)@(negedge clk);
  button=1;wait(reset===0);
  if(dut.tick_pending!==0||!dut.boot_mode)$fatal(1,"BIOS restart did not reset timer latch");
  collision(0);consume();
  $display("PASS PAL tick/read collision with empty and pending latch, and after full BIOS reset");$finish;
 end
 initial begin #25000000;$fatal(1,"timer tick timeout");end
endmodule
