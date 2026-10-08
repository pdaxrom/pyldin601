`timescale 1ns/1ps
// Real PS/2 wire, production system, original DOS/BIOS RAM and VHDL CPU.
// A burst is checked at the BIOS typeahead buffer, before DOS consumes it.
module hg_bios_fixture #(parameter SPEED=0)(
 input cpu_rw,cpu_vma,input[15:0]cpu_addr,input[7:0]cpu_out,
 output cpu_clk,cpu_reset,cpu_hold,cpu_irq,output[7:0]cpu_in
);
 reg button=1,tms=0,tck=0,tdi=0;wire tdo,enable;
 reg clk=0;always #21 clk=~clk;
 wire clk_fast;test_fast_clock_physical fast_clock(clk_fast);
 wire[19:0]sa;wire[15:0]sd;wire ce,oe,we,ub,lb;
 classic_system #(.BOOT_FILE("build/hgdisk-boot.mem"),.BUTTON_TICK_DIV(1),.BUTTON_DEBOUNCE_MS(2),.BUTTON_LONG_MS(64)) dut(
  .clk(clk),.clk_fast(clk_fast),.pll_locked(1'b1),.btn_resetn(button),.cpu_rw(cpu_rw),.cpu_vma(cpu_vma),
  .cpu_addr(cpu_addr),.cpu_out(cpu_out),.cpu_clk(cpu_clk),.cpu_reset(cpu_reset),
  .cpu_hold(cpu_hold),.cpu_irq(cpu_irq),.cpu_in(cpu_in),
  .ps2clk(1'b1),.ps2dat(1'b1),.rxd(1'b1),.miso(1'b1),
  .hg_tms(tms),.hg_tck(tck),.hg_tdi(tdi),.hg_tdo(tdo),.hg_tdo_enable(enable),
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
 reg[7:0]head[0:9],payload[0:5],dummy,got;integer n,transaction,sum,xor_sum,irqs=0,video_reads=0;
 reg armed=0;reg[7:0]failed_stage,failed_a,failed_day,failed_month,failed_year_hi,failed_year_lo,failed_hour,failed_minute;
 task exchange;input[7:0]data;integer n;begin
  for(n=0;n<8;n=n+1)begin
   tdi=data[n];#5000;tck=1;#100;got[n]=tdo;#4900;tck=0;
  end
  #140000; // completed USB byte pacing, with a CPU interrupt gap
 end endtask
 function[7:0]ram;input[15:0]a;begin ram=a[0]?memory[a>>1][15:8]:memory[a>>1][7:0];end endfunction
 task host_request;begin
  wait(enable&&tdo&&!tms);tms=1;#2000000;
  xor_sum=0;
  for(n=0;n<10;n=n+1)begin exchange(0);head[n]=got;if(n<9)xor_sum=xor_sum^got;end
  if(head[0]!=="H"||head[1]!=="G"||head[2]!==1||head[4]!==0||head[9]!==xor_sum[7:0])$fatal(1,"HDL CPU HG header/XOR");
  if(head[3]!==transaction+1)$fatal(1,"HG operation got %h",head[3]);
  if(transaction<2&&(head[5]!==8'hdf||head[6]!==8'h7f||head[7]!==0||head[8]!==2))$fatal(1,"last-sector header mismatch");
  if(transaction==2&&(head[5]!==50||head[6]!==0||head[7]!==6||head[8]!==0))$fatal(1,"TIME header mismatch");
  #500000;exchange(0);#500000;sum=0;
  if(transaction==0)begin
   for(n=0;n<512;n=n+1)begin exchange(n[7:0]^8'ha5);sum=sum+(n[7:0]^8'ha5);end
   exchange(sum[7:0]);exchange(sum[15:8]);
  end else if(transaction==1)begin
   for(n=0;n<512;n=n+1)begin
    exchange(0);if(got!==(n[7:0]^8'ha5))$fatal(1,"HDL WRITE byte %d got %h",n,got);sum=sum+got;
   end
   exchange(0);if(got!==sum[7:0])$fatal(1,"HDL WRITE checksum low");
   exchange(0);if(got!==sum[15:8])$fatal(1,"HDL WRITE checksum high");
   #500000;exchange(0);
  end else begin
   for(n=0;n<6;n=n+1)begin exchange(payload[n]);sum=sum+payload[n];end
   exchange(sum[7:0]);exchange(sum[15:8]);
  end
  #500000;tms=0;#100000;
 end endtask
 initial begin
  $readmemh("build/hgdisk-sram.mem",memory);
  payload[0]=8'h16;payload[1]=8'h69;payload[2]=8'h34;payload[3]=0;payload[4]=8'h68;payload[5]=8'hd8;
  // 2026-10-08 19:14:25.44 -> 3463272 ticks = 0034:d868
  wait(dut.locked);wait(cpu_reset===0);wait(dut.speed==SPEED);armed=1;
  for(transaction=0;transaction<3;transaction=transaction+1)host_request();
  while(ram(16'h0380)==0)@(posedge clk);#100000;
  if(ram(16'h0380)!==8'ha5)$fatal(1,"native HG subroutine failed");
  if(ram(16'h001c)!==8||ram(16'h001d)!==10||ram(16'h001e)!==7||ram(16'h001f)!==8'hea||ram(16'h001b)!==19||ram(16'h001a)!==14)$fatal(1,"HDL TIME conversion mismatch");
  if(irqs==0||video_reads<20)$fatal(1,"no concurrent IRQ/video traffic");
  if(dut.host_link.overflow||dut.host_link.underflow)$fatal(1,"HG FIFO error");
  $display("PASS actual HDL CPU/native resident HG.PGM model_a=%0d %0dMHz: FTDI pins, last-sector read/write/checksum, TIME, %0d IRQ acknowledgements, %0d concurrent video reads",dut.model_a,1<<SPEED,irqs,video_reads);$finish;
 end
 always @(posedge clk)if(armed)begin
  if(dut.bus_read&&cpu_addr==16'he62b&&dut.tick_pending)irqs=irqs+1;
  if(cpu_reset)$fatal(1,"HG unexpectedly reset CPU");
  if(dut.bus_write&&cpu_addr==16'h0380&&cpu_out==8'hee)begin
   failed_stage=ram(16'h0381);failed_a=ram(16'h0006);failed_day=ram(16'h001c);failed_month=ram(16'h001d);
   failed_year_hi=ram(16'h001e);failed_year_lo=ram(16'h001f);failed_hour=ram(16'h001b);failed_minute=ram(16'h001a);
   $fatal(1,"HG failed PC=%h stage=%h SWIA=%h date=%h/%h/%h%h time=%h:%h FIFO=%b/%b",cpu_addr,failed_stage,failed_a,failed_day,failed_month,failed_year_hi,failed_year_lo,failed_hour,failed_minute,dut.host_link.overflow,dut.host_link.underflow);
  end
 end
 always @(posedge clk_fast)if(armed&&dut.runtime_memory.grant_video&&!dut.runtime_memory.active)video_reads=video_reads+1;
 always @(negedge cpu_clk)if(armed&&cpu_hold)$fatal(1,"HG stretched CPU/SRAM cycle");
 initial begin #1000000000;$fatal(1,"HG BIOS timeout PC=%h ctrl=%h status=%h",cpu_addr,dut.host_link.request,dut.host_link.data_out);end
endmodule
