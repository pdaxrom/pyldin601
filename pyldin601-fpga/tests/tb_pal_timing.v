`timescale 1ns/1ps
// Check pulse widths at the DAC against PAL timing, not the RTL counters.
// ITU-R BT.470/1700: H=64 us, equalizing=2.35 us, H sync=4.7 us,
// broad sync=27.3 us, broad gap=4.7 us; five pulses per vertical sequence.
module tb_pal_timing;
 reg fast=0;always #1.25 fast=~fast;
 reg clk=0;always #5 clk=~clk;
 reg reset=1;wire[5:0]tv;wire tick;
 classic_video #(.GFX(1)) dut(.clk(clk),.reset(reset),
  .bus_read(1'b0),.bus_write(1'b0),.bus_address(1'b0),.bus_data(8'd0),.mode(8'd1),
  .font_write(1'b0),.font_address(11'd0),.font_data(8'd0),
  .mem_ready(1'b0),.mem_done(1'b0),.mem_data(8'd0),.tvout(tv),.tick50(tick),
  .model_a(1'b0),.gfx_enable(1'b0),.gfx_pixel(8'd0),.fast(fast));
 integer cycles=0,start=0,width=0,previous_end=0,previous_width=0;
 integer short_count=0,normal_count=0,broad_count=0,fields=0,last_tick=-1;
 reg previous_sync=1,first_pulse=1;
 always @(posedge clk)begin
  if(reset)begin cycles=0;start=0;width=0;previous_sync=1;first_pulse=1;end
  else begin
   #1;
   if(^tv===1'bx)$fatal(1,"undefined composite DAC");
   if(tv==0)begin
    if(!previous_sync)begin
     start=cycles;
     if(previous_width==654&&cycles-previous_end!=114)
      $fatal(1,"broad sync gap %0d clocks, expected 114 / 4.75 us",cycles-previous_end);
    end
    width++;
   end else if(previous_sync)begin
    // Initial reset assertion begins before the measured first sample.
    if(!first_pulse)case(width)
     57:short_count++;   // 2.375 us, within 2.35 +/- 0.1
     114:normal_count++;// 4.750 us, within 4.7 +/- 0.2
     654:broad_count++; // 27.25 us, complementary 4.75 us gap
     default:$fatal(1,"PAL sync pulse %0d clocks / %0.3f us at %0d, expected 57, 114 or 654 clocks",width,width/24.0,start);
    endcase
    first_pulse=0;previous_end=cycles;previous_width=width;width=0;
   end
   previous_sync=tv==0;
   if(tick)begin
    if(last_tick>=0&&cycles-last_tick!=480000)$fatal(1,"incorrect PAL field period");
    last_tick=cycles;fields++;
   end
   cycles++;
  end
 end
 initial begin
  repeat(3)@(negedge clk);reset=0;
  wait(cycles==1920004);
  if(short_count!=39||normal_count!=1220||broad_count!=20||fields!=4)
   $fatal(1,"PAL vertical sequence counts short=%0d normal=%0d broad=%0d fields=%0d",short_count,normal_count,broad_count,fields);
  $display("PASS actual PAL DAC over four fields: 64 us lines, 50 Hz fields, 2.375/4.75/27.25 us sync pulses, 4.75 us broad gaps, five-pulse pre/broad/post sequences");$finish;
 end
 initial begin #25000000;$fatal(1,"PAL timing timeout");end
endmodule
