`timescale 1ns/1ps
`include "build/game-perf/labels.vh"
// Production CPU, system clocks, PAL, blitter and SRAM slots. The established
// physical clock fixture uses 42 ns / 10.5 ns; reports count 24-MHz system
// clocks, rather than treating those rounded simulation delays as board time.
module game_perf_fixture #(parameter SPEED=0,FRAMES=12,MUSIC=1,STRESS=0)(
 input cpu_rw,cpu_vma,input[15:0]cpu_addr,input[7:0]cpu_out,
 input[71:0]debug_state,input[7:0]debug_opcode,input debug_decode,
 output cpu_clk,cpu_reset,cpu_hold,cpu_irq,hd,output[7:0]cpu_in
);
 reg clk=0;always #21 clk=~clk;
 reg psclk=1,psdata=1;
 wire fast;test_fast_clock_physical clock_fast(fast);
 wire[19:0]sa;wire[15:0]sd;wire ce,oe,we,ub,lb;
 classic_system #(.BOOT_FILE("build/game-perf/boot.mem")) dut(
 .clk(clk),.clk_fast(fast),.pll_locked(1'b1),.btn_resetn(1'b1),
 .cpu_rw(cpu_rw),.cpu_vma(cpu_vma),.cpu_addr(cpu_addr),.cpu_out(cpu_out),
 .cpu_clk(cpu_clk),.cpu_reset(cpu_reset),.cpu_hold(cpu_hold),.cpu_irq(cpu_irq),.cpu_in(cpu_in),
 .ps2clk(psclk),.ps2dat(psdata),.rxd(1'b1),.miso(1'b1),.hd6303_en(hd),
 .hg_tms(1'b1),.hg_tck(1'b1),.hg_tdi(1'b1),.hg_tdo(),.hg_tdo_enable(),
 .seg_led_h(),.seg_led_l(),.led_rgb(),.txd(),.mss(),.msck(),.mosi(),.tvout(),.audio(),
 .SRAM_ADDR(sa),.SRAM_DATA(sd),.SRAM_CE(ce),.SRAM_OE(oe),.SRAM_WE(we),.SRAM_UB(ub),.SRAM_LB(lb));
 // Compact backing store: native RAM+ROM and the four game framebuffer pages.
 reg[15:0]memory[0:199679];reg epoch=0;reg[15:0]read_word;
 function integer index;input[19:0]a;begin index=a>=20'h80000 ? 20'h10c00+a-20'h80000 : a;end endfunction
 wire[19:0]pa;wire pc,po,pw,pl,pu;wire[15:0]pd;
 assign #10 pa=sa;assign #10 pc=ce;assign #10 po=oe;assign #6 pw=we;
 assign #10 pl=lb;assign #10 pu=ub;assign #15 pd=sd;
 always @(pc or po or pw or pa or epoch)read_word=!pc&&!po&&pw?memory[index(pa)]:16'bz;
 assign #18 sd=read_word;
 always @(posedge pw)if(!pc)begin
  if(index(pa)<0||index(pa)>199679)$fatal(1,"unmapped SRAM %h",pa);
  if(!pl)memory[index(pa)][7:0]=pd[7:0];if(!pu)memory[index(pa)][15:8]=pd[15:8];epoch<=!epoch;
 end
 function[7:0]ram;input[15:0]a;begin ram=a[0]?memory[a>>1][15:8]:memory[a>>1][7:0];end endfunction
 integer ticks=0,frames=0,start_tick=0,last_request=0,flip_request=0,irq_count=0,irq_clocks=0;
 integer app_clocks=0,bios_clocks=0,blit_wait=0,flip_wait=0,input_clocks=0,refill_clocks=0,other_clocks=0;
 integer instruction_pc=0;reg armed=0,in_irq=0;reg[7:0]failure_op;
 wire[15:0]decoded_pc=debug_state[71:56];
 wire[7:0]rom_page=dut.page;
 always @(posedge cpu_clk)begin
  if(armed&&cpu_hold)$fatal(1,"CPU stretched during game at %h",cpu_addr);
  if(debug_decode)begin
   instruction_pc=decoded_pc;
   if(armed&&decoded_pc==`PERF_FAILED)begin
    failure_op=ram(`PERF_OP);
    $fatal(1,"GAMEBIOS failed op=%h status=%h",failure_op,debug_state[23:16]);
   end
   if(rom_page[3:0]==14&&decoded_pc==`PERF_GAME_IRQ)begin in_irq=1;irq_count=irq_count+1;end
   if(in_irq&&debug_opcode==8'h3b)in_irq=0;
   if(decoded_pc==`PERF_LOOP)begin
    if(armed)begin
     $display("PERF frame=%0d ticks=%0d app=%0d bios=%0d input=%0d refill=%0d blit_wait=%0d flip_wait=%0d irq=%0d other=%0d requests=%0d",frames,ticks-start_tick,app_clocks,bios_clocks,input_clocks,refill_clocks,blit_wait,flip_wait,irq_clocks,other_clocks,flip_request);
     frames=frames+1;
     if(frames==FRAMES)begin
      if(MUSIC&&irq_count<2)$fatal(1,"music IRQ not exercised");
      if(dut.gfx.underrun||dut.audio_control.overrun)$fatal(1,"video/audio underrun");
      $display("PASS production ARKANOID performance model_a=%0d MHz=%0d music=%0d frames=%0d music_irq=%0d",dut.model_a,1<<SPEED,MUSIC,frames,irq_count);$finish;
     end
    end
    if(!dut.locked||dut.speed!=SPEED||!hd)$fatal(1,"wrong restored CPU setting");
    armed=1;start_tick=ticks;app_clocks=0;bios_clocks=0;input_clocks=0;refill_clocks=0;blit_wait=0;flip_wait=0;irq_clocks=0;other_clocks=0;flip_request=0;
   end
  end
 end
 always @(posedge clk)begin
  ticks=ticks+1;
  if(armed)begin
   if(cpu_reset)$fatal(1,"game reset");
   if(!dut.kbd_capture||dut.keyboard_irq||dut.keyboard.key_ready||dut.keyboard.queue_count)
    $fatal(1,"game lost exclusive keyboard capture or delivered native key");
   if(in_irq)irq_clocks=irq_clocks+1;
   else if(dut.gfx.state==4)flip_wait=flip_wait+1;
   else if(dut.gfx.busy)blit_wait=blit_wait+1;
   else if(instruction_pc>=`PERF_INPUT&&instruction_pc<`PERF_INPUT_END)input_clocks=input_clocks+1;
   else if(instruction_pc>=`PERF_REFILL&&instruction_pc<`PERF_REFILL_END)refill_clocks=refill_clocks+1;
   else if(instruction_pc>=`PERF_APP&&instruction_pc<`PERF_APP_END)app_clocks=app_clocks+1;
   else if(rom_page[3]&&instruction_pc>=16'hc000&&instruction_pc<16'he000)bios_clocks=bios_clocks+1;
   else other_clocks=other_clocks+1;
   if(dut.bus_write&&cpu_addr==16'he651&&cpu_out==3)flip_request=flip_request+1;
  end
 end
 initial $readmemh("build/game-perf/sram.mem",memory);
 task ps2_byte;input[7:0]b;reg[10:0]f;integer k;
  begin f={1'b1,~^b,b,1'b0};
   for(k=0;k<11;k=k+1)begin psdata=f[k];#20000;psclk=0;#20000;psclk=1;#20000;end
   psdata=1;#20000;
  end
 endtask
 initial if(STRESS)begin
  wait(armed);ps2_byte(8'he0);ps2_byte(8'h6b);
  forever begin
   // Physical typematic at roughly 30 Hz, including the long loss-of-life
   // text operation. Prefix/modifier make/break must remain live in capture.
   repeat(8)begin #32000000;ps2_byte(8'he0);ps2_byte(8'h6b);end
   ps2_byte(8'h12);ps2_byte(8'h14);
   ps2_byte(8'hf0);ps2_byte(8'h12);ps2_byte(8'hf0);ps2_byte(8'h14);
   ps2_byte(8'he0);ps2_byte(8'hf0);ps2_byte(8'h6b);
   #20000000;ps2_byte(8'he0);ps2_byte(8'h6b);
  end
 end
 initial begin #2000000;if(!dut.locked)$fatal(1,"snapshot bootstrap did not commit");end
 initial begin #2000000000;$fatal(1,"game performance timeout PC=%h frames=%0d",decoded_pc,frames);end
endmodule
