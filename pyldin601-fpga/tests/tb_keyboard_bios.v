`timescale 1ns/1ps
// Real PS/2 wire, production system, original DOS/BIOS RAM and VHDL CPU.
// A burst is checked at the BIOS typeahead buffer, before DOS consumes it.
module keyboard_bios_fixture #(parameter SPEED=0)(
 input cpu_rw,cpu_vma,input[15:0]cpu_addr,input[7:0]cpu_out,
 output cpu_clk,cpu_reset,cpu_hold,cpu_irq,output[7:0]cpu_in
);
 reg button=1,psclk=1,psdata=1;
 reg clk=0;always #21 clk=~clk;
 wire clk_fast;test_fast_clock_physical fast_clock(clk_fast);
 wire[19:0]sa;wire[15:0]sd;wire ce,oe,we,ub,lb;
 classic_system #(.BOOT_FILE("build/keyboard-boot.mem"),.BUTTON_TICK_DIV(1),.BUTTON_DEBOUNCE_MS(2),.BUTTON_LONG_MS(64)) dut(
  .clk(clk),.clk_fast(clk_fast),.pll_locked(1'b1),.btn_resetn(button),.cpu_rw(cpu_rw),.cpu_vma(cpu_vma),
  .cpu_addr(cpu_addr),.cpu_out(cpu_out),.cpu_clk(cpu_clk),.cpu_reset(cpu_reset),
  .cpu_hold(cpu_hold),.cpu_irq(cpu_irq),.cpu_in(cpu_in),
  .ps2clk(psclk),.ps2dat(psdata),.rxd(1'b1),.miso(1'b1),
  .hd6303_en(),.seg_led_h(),.seg_led_l(),.led_rgb(),.txd(),.mss(),.msck(),.mosi(),.tvout(),.audio(),
  .SRAM_ADDR(sa),.SRAM_DATA(sd),.SRAM_CE(ce),.SRAM_OE(oe),.SRAM_WE(we),.SRAM_UB(ub),.SRAM_LB(lb));
 reg[15:0]memory[0:199679];
 wire[19:0]pin_address;wire pin_ce,pin_oe,pin_we,pin_lb,pin_ub;wire[15:0]pin_data;
 assign #10 pin_address=sa;assign #10 pin_ce=ce;assign #10 pin_oe=oe;
 assign #6 pin_we=we;assign #10 pin_lb=lb;assign #10 pin_ub=ub;assign #15 pin_data=sd;
 reg[15:0]read_word;reg memory_epoch=0;
 // Retain the 18-ns SRAM access delay without subscribing the simulator
 // to an entire 199680-word array on every pin/address transition.
 always @(pin_ce or pin_oe or pin_we or pin_address or memory_epoch)
  read_word=!pin_ce&&!pin_oe&&pin_we?memory[pin_address]:16'bz;
 assign #18 sd=read_word;
 always @(posedge pin_we)if(!pin_ce)begin
  if(!pin_lb)memory[pin_address][7:0]=pin_data[7:0];
  if(!pin_ub)memory[pin_address][15:8]=pin_data[15:8];
  memory_epoch<=!memory_epoch;
 end
 task send;input[7:0]b;reg[10:0]frame;integer bit_index;
  begin
   frame={1'b1,~^b,b,1'b0};
   for(bit_index=0;bit_index<11;bit_index=bit_index+1)begin
    psdata=frame[bit_index];#10000;psclk=0;#30000;psclk=1;#30000;
   end
   psdata=1;#10000;
  end
 endtask
 integer key_index,accepted=0,released_count;reg armed=0,holding=0;
 integer test_cycles=0,first_held,last_held;
 always @(posedge clk)test_cycles=test_cycles+1;
 reg[7:0]scan[0:7],expected[0:7];
 wire[7:0]timer0=memory[16'hed09>>1][15:8],timer1=memory[16'hed0a>>1][7:0],timer2=memory[16'hed0b>>1][15:8];
 initial begin
  $readmemh("build/keyboard-sram.mem",memory);
  scan[0]=8'h16;scan[1]=8'h1e;scan[2]=8'h26;scan[3]=8'h26;
  scan[4]=8'h25;scan[5]=8'h2e;scan[6]=8'h36;scan[7]=8'h3d;
  expected[0]="1";expected[1]="2";expected[2]="3";expected[3]="3";
  expected[4]="4";expected[5]="5";expected[6]="6";expected[7]="7";
  wait(dut.locked);wait(cpu_reset===0);
  wait(dut.speed==SPEED);
  #30000000;armed=1;
  for(key_index=0;key_index<8;key_index=key_index+1)begin
   send(scan[key_index]);#2000000;send(8'hf0);send(scan[key_index]);
   #20000000;
  end
  wait(accepted==8);#20000000;
  if(dut.keyboard.queue_count!=0||dut.keyboard.data!=8'hff)$fatal(1,"keyboard did not drain");
  #160000000;holding=1;
  send(8'h3e); // Hold 8; BIOS owns the initial repeat delay and rate.
  #200000000;
  if(accepted!=9)$fatal(1,"premature held repeat accepted=%0d",accepted);
  send(8'h3e);send(8'h3e); // PS/2 typematic duplicates must not enqueue taps.
  #700000000;
  if(accepted<12)$fatal(1,"native BIOS autorepeat missing accepted=%0d",accepted);
  send(8'hf0);send(8'h3e);
  #100000000;released_count=accepted;
  #200000000;
  if(accepted!=released_count||dut.keyboard.queue_count!=0||dut.keyboard.data!=8'hff)
   $fatal(1,"autorepeat continued after release");
  if({memory[16'he180>>1][7:0],memory[16'he180>>1][15:8]}<100)
   $fatal(1,"shared 100-Hz music IRQ did not run");
  $display("PASS actual HDL CPU/native BIOS model_a=%0d: 8 fast taps, held BIOS repeat/delay/rate, typematic/break and 100-Hz audio IRQ at %0d MHz",dut.model_a,1<<SPEED);
  $finish;
 end
 always @(posedge clk)if(armed&&dut.bus_write&&cpu_addr>=16'hbff0&&cpu_addr<16'hc000)begin
  $display("BIOS key %0d = %h at %0t",accepted,cpu_out,$time);
  if(!holding)begin
   if(accepted>=8||cpu_out!==expected[accepted])$fatal(1,"BIOS key order got=%h expected[%0d]=%h",cpu_out,accepted,expected[accepted]);
  end else begin
   if(cpu_out!=="8")$fatal(1,"held BIOS key changed: %h",cpu_out);
   if(accepted==8)first_held=test_cycles;
   else if(accepted==9)begin
    if(test_cycles-first_held<560000000/42||test_cycles-first_held>760000000/42)
     $fatal(1,"native initial repeat delay %0d ns",(test_cycles-first_held)*42);
   end else if(test_cycles-last_held<40000000/42||test_cycles-last_held>100000000/42)
    $fatal(1,"native repeat interval %0d ns",(test_cycles-last_held)*42);
   last_held=test_cycles;
  end
  accepted=accepted+1;
 end
 always @(posedge clk)if(armed&&dut.bus_read)begin
  if(cpu_addr==16'he628&&dut.kbd_data!=8'hff)
   $display("KBD read %h qt=%0d timer=%0d/%0d/%0d fifo=%0d at %0t",dut.kbd_data,dut.keyboard.quiet_ticks,timer0,timer1,timer2,dut.keyboard.queue_count,$time);
  if(cpu_addr==16'he62b&&dut.tick_pending)
   $display("Timer ack qt=%0d timer=%0d/%0d/%0d at %0t",dut.keyboard.quiet_ticks,timer0,timer1,timer2,$time);
 end
 initial begin #3000000000;$fatal(1,"BIOS keyboard timeout PC=%h accepted=%0d",cpu_addr,accepted);end
endmodule
