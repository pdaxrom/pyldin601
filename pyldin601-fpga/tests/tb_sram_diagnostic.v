`timescale 1ns/1ps
module sram_diagnostic_fixture(
 input cpu_rw,cpu_vma,input[15:0]cpu_addr,input[7:0]cpu_out,
 output cpu_clk,cpu_reset,cpu_hold,cpu_irq,output[7:0]cpu_in
);
 reg clk=0;always #21 clk=~clk; // 24 MHz rounded to the simulator's ns time unit
 wire[19:0]sa;wire[15:0]sd;wire ce,oe,we,ub,lb;
 classic_system #(.BOOT_FILE("build/sram-smoke.mem")) dut(
  .clk(clk),.pll_locked(1'b1),.btn_resetn(1'b1),.cpu_rw(cpu_rw),.cpu_vma(cpu_vma),
  .cpu_addr(cpu_addr),.cpu_out(cpu_out),.cpu_clk(cpu_clk),.cpu_reset(cpu_reset),
  .cpu_hold(cpu_hold),.cpu_irq(cpu_irq),.cpu_in(cpu_in),
  .ps2clk(1'b1),.ps2dat(1'b1),.rxd(1'b1),.miso(1'b1),
  .seg_led_h(),.seg_led_l(),.led_rgb(),.txd(),.mss(),.msck(),.mosi(),.tvout(),.audio(),
  .SRAM_ADDR(sa),.SRAM_DATA(sd),.SRAM_CE(ce),.SRAM_OE(oe),.SRAM_WE(we),.SRAM_UB(ub),.SRAM_LB(lb));
 // This shortened fixture only accesses the bottom 16 KiB. Keeping the array
 // small avoids NVC's expensive sensitivity list for a million-word model.
 reg[15:0]memory[0:8191];
 wire[19:0]pin_address;wire pin_ce,pin_oe,pin_we,pin_lb,pin_ub;wire[15:0]pin_data;
 assign #15 pin_address=sa;assign #15 pin_ce=ce;assign #15 pin_oe=oe;
 assign #3 pin_we=we;assign #15 pin_lb=lb;assign #15 pin_ub=ub;assign #15 pin_data=sd;
 // NVC currently accepts one continuous-assignment delay; use 20 ns for
 // release as well, conservatively slower than the 8 ns Icarus model.
 assign #20 sd=!pin_ce&&!pin_oe&&pin_we?memory[pin_address]:16'bz;
 always @(posedge pin_we)if(!pin_ce)begin
  if(!pin_lb)memory[pin_address][7:0]=pin_data[7:0];
  if(!pin_ub)memory[pin_address][15:8]=pin_data[15:8];
 end
 integer i,writes=0,reads=0;reg injected=0;
 always @(posedge clk)begin
  if(dut.boot_request&&dut.boot_accept)begin
   if(dut.boot_address<21'h2000||dut.boot_address>=21'h2100)$fatal(1,"diagnostic escaped shortened range");
   if(dut.boot_write)writes=writes+1;
   else begin
    reads=reads+1;
    `ifdef SRAM_DIAGNOSTIC_FAULT
    if(!injected)begin memory[20'h1018][15:8]=8'hd5;injected=1;end
    `endif
   end
  end
  if(dut.boot_debug==8'hee)begin
   `ifdef SRAM_DIAGNOSTIC_FAULT
   if(!injected||writes!=256||reads!=50||memory[20'h31c]!=16'h3030
      ||memory[20'h31d]!=16'h3032||memory[20'h31e]!=16'h3133)
    $fatal(1,"wrong diagnostic failure writes=%d reads=%d",writes,reads);
   $display("PASS actual HDL MC6800 diagnostic detects delayed SRAM corruption at 002031");$finish;
   `else
   $fatal(1,"real HDL CPU diagnostic failed at address=%h",cpu_addr);
   `endif
  end
  if(dut.boot_debug==8'hd1)begin
   if(writes!=1280||reads!=1280)$fatal(1,"missing diagnostic pattern writes=%d reads=%d",writes,reads);
   for(i=4096;i<4224;i=i+1)if(memory[i]!==16'b0)$fatal(1,"diagnostic final memory mismatch");
   $display("PASS actual HDL MC6800 executes all five SRAM patterns with pad/access delays, 1280 writes + 1280 reads");$finish;
  end
 end
 initial begin #120000000;$fatal(1,"HDL diagnostic timeout pc=%h writes=%d reads=%d",cpu_addr,writes,reads);end
endmodule
