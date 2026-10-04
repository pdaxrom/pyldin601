`timescale 1ns/1ps
`include "build/runtime-check.vh"
// Real DOS RAM/ROM and real VHDL CPU, restored at the BIOS input loop by RTI.
// Twenty natural PAL timer events exercise runtime CPU/video SRAM slots and
// I/O acknowledgements in production RTL. This is an ISR differential check,
// not a long soak test and not a substitute for the complete disk boot.
module runtime_irq_fixture #(parameter SPEED=0)(
 input cpu_rw,cpu_vma,input[15:0]cpu_addr,input[7:0]cpu_out,
 output cpu_clk,cpu_reset,cpu_hold,cpu_irq,output[7:0]cpu_in
);
 reg button=1;
 reg clk=0;always #21 clk=~clk;
 wire clk_fast;test_fast_clock_physical fast_clock(clk_fast);
 wire[19:0]sa;wire[15:0]sd;wire ce,oe,we,ub,lb;
 classic_system #(.BOOT_FILE("build/runtime-boot.mem"),.BUTTON_TICK_DIV(1),.BUTTON_DEBOUNCE_MS(2),.BUTTON_LONG_MS(64)) dut(
  .clk(clk),.clk_fast(clk_fast),.pll_locked(1'b1),.btn_resetn(button),.cpu_rw(cpu_rw),.cpu_vma(cpu_vma),
  .cpu_addr(cpu_addr),.cpu_out(cpu_out),.cpu_clk(cpu_clk),.cpu_reset(cpu_reset),
  .cpu_hold(cpu_hold),.cpu_irq(cpu_irq),.cpu_in(cpu_in),
  .ps2clk(1'b1),.ps2dat(1'b1),.rxd(1'b1),.miso(1'b1),
  .hd6303_en(),.seg_led_h(),.seg_led_l(),.led_rgb(),.txd(),.mss(),.msck(),.mosi(),.tvout(),.audio(),
  .SRAM_ADDR(sa),.SRAM_DATA(sd),.SRAM_CE(ce),.SRAM_OE(oe),.SRAM_WE(we),.SRAM_UB(ub),.SRAM_LB(lb));
 reg[15:0]memory[0:199679];
 wire[19:0]pin_address;wire pin_ce,pin_oe,pin_we,pin_lb,pin_ub;wire[15:0]pin_data;
 assign #10 pin_address=sa;assign #10 pin_ce=ce;assign #10 pin_oe=oe;
 assign #6 pin_we=we;assign #10 pin_lb=lb;assign #10 pin_ub=ub;assign #15 pin_data=sd;
 assign #18 sd=!pin_ce&&!pin_oe&&pin_we?memory[pin_address]:16'bz;
 always @(posedge pin_we)if(!pin_ce)begin
  if(!pin_lb)memory[pin_address][7:0]=pin_data[7:0];
  if(!pin_ub)memory[pin_address][15:8]=pin_data[15:8];
 end
 integer speed_step;
 initial begin
  wait(dut.locked);
  for(speed_step=1;speed_step<=SPEED;speed_step=speed_step+1)begin
   button=0;repeat(12)@(negedge clk);button=1;
   wait(dut.speed==speed_step);repeat(30)@(posedge clk);
  end
 end
 integer acknowledged=0,returns=0,video_reads=0;
 reg armed=0;reg[7:0]header[0:119];reg[23:0]checks[0:`RUNTIME_CHECKS-1];
 function[7:0]ram;input[15:0]a;begin ram=a[0]?memory[a>>1][15:8]:memory[a>>1][7:0];end endfunction
 integer j;reg[15:0]check_address;reg[7:0]check_byte;
 always @(posedge cpu_clk)begin
  if(dut.locked&&cpu_vma&&cpu_rw&&cpu_addr==16'hf39c)begin
   if(!armed)begin armed=1;end
   else returns=returns+1;
   if(acknowledged>=20)begin
    if(acknowledged!=20)$fatal(1,"IRQ ack mismatch got=%d",acknowledged);
    for(j=0;j<`RUNTIME_CHECKS;j=j+1)begin
     check_address=checks[j][23:8];
     check_byte=ram(check_address);
     if(check_byte!==checks[j][7:0])$fatal(1,"native IRQ RAM mismatch address=%h got=%h expected=%h",check_address,check_byte,checks[j][7:0]);
    end
    if(video_reads<20)$fatal(1,"no concurrent video traffic");
    for(j=0;j<120;j=j+1)
     if(ram(16'hf000+(j/40)*42+(j%40))!==header[j])$fatal(1,"header corrupted in IRQ test index=%d",j);
    $display("PASS actual HDL CPU/native BIOS IRQ: %d MHz, 20 acknowledgements and RTI returns, native RAM changes match, header intact, %d video reads",1<<SPEED,video_reads);$finish;
   end
  end
 end
 always @(posedge clk)if(armed)begin
  if(cpu_reset)$fatal(1,"runtime IRQ reset address=%h",cpu_addr);

  if(dut.bus_read&&cpu_addr==16'he62b&&dut.tick_pending)begin
   acknowledged=acknowledged+1;
  end
  if(dut.bus_write&&cpu_addr>=16'hf000&&cpu_addr<16'hf07e)
   $fatal(1,"IRQ unexpectedly wrote banner RAM address=%h data=%h",cpu_addr,cpu_out);
 end
 always @(posedge clk_fast)if(armed&&dut.runtime_memory.grant_video&&!dut.runtime_memory.active)video_reads=video_reads+1;
 always @(negedge cpu_clk)if(armed&&cpu_hold)$fatal(1,"runtime CPU cycle stretched at IRQ address=%h",cpu_addr);
 initial begin
  $readmemh("build/runtime-sram.mem",memory);
  $readmemh("build/runtime-check.mem",checks);
  for(j=0;j<120;j=j+1)header[j]=ram(16'hf000+(j/40)*42+(j%40));
 end
 initial begin #450000000;$fatal(1,"runtime IRQ timeout address=%h acknowledged=%d returns=%d",cpu_addr,acknowledged,returns);end
endmodule
