`timescale 1ns/1ps
module tb_frequency_controls;
 reg clk=0;always #5 clk=~clk;
 reg cold=1,button=1,boot=0;wire tap,warm;integer taps=0,resets=0,i,j;
 classic_reset_button #(.TICK_DIV(4),.DEBOUNCE_MS(2),.LONG_MS(12)) button_dut(clk,cold,button,tap,warm);
 reg[1:0]speed=0;wire[8:0]h,l;
 classic_frequency_display #(.CLOCK_HZ(32000)) display(clk,cold,speed,boot,h,l);
 reg[7:0]seen_h=0,seen_l=0;reg[8:0]old_h=9'h0ff,old_l=9'h0ff;
 reg old_warm=0;
 always @(posedge clk)begin
  if(tap)taps=taps+1;
  if(warm&&!old_warm)resets=resets+1;
  old_warm=warm;
  #1;
  if(h[8]&&l[8])$fatal(1,"both display commons enabled");
  if(h[8])begin
   if($countones(~h[7:0])!=1||!(&l[7:0]))$fatal(1,"more than one segment enabled");seen_h=seen_h|~h[7:0];
  end
  if(l[8])begin
   if($countones(~l[7:0])!=1||!(&h[7:0]))$fatal(1,"more than one segment enabled");seen_l=seen_l|~l[7:0];
  end
  if(h[7:0]!=old_h[7:0]&&(h[8]||old_h[8]||l[8]||old_l[8]))$fatal(1,"cathodes changed with live common");
  if(l[7:0]!=old_l[7:0]&&(h[8]||old_h[8]||l[8]||old_l[8]))$fatal(1,"cathodes changed with live common");
  old_h=h;old_l=l;
 end
 task wait_ticks;input integer n;begin repeat(n)@(negedge clk);end endtask
 reg[7:0]expected;
 initial begin
  wait_ticks(10);cold=0;
  // Sub-debounce pulses cannot change speed or reset.
  repeat(6)begin button=0;wait_ticks(3);button=1;wait_ticks(12);end
  if(taps||warm)$fatal(1,"button bounce produced an event");
  button=0;wait_ticks(32);if(taps||warm)$fatal(1,"short press acted before release");
  button=1;wait_ticks(32);if(taps!=1||resets)$fatal(1,"short press did not produce exactly one tap");
  button=0;wait_ticks(96);if(!warm||resets!=1)$fatal(1,"long press did not reset");
  wait_ticks(100);button=1;wait_ticks(32);if(warm||taps!=1||resets!=1)$fatal(1,"long release produced a tap");
  for(i=0;i<5;i=i+1)begin
   speed=i;boot=i==4;wait_ticks(128);seen_h=0;seen_l=0;wait_ticks(64);
   case(i)0:expected=8'h06;1:expected=8'h5b;2:expected=8'h66;3:expected=8'h7f;4:expected=8'h66;endcase
   if(seen_h!==8'h3f||seen_l!==expected)$fatal(1,"frequency glyph mismatch mode=%d h=%x l=%x expected=%x",i,seen_h,seen_l,expected);
  end
  $display("PASS reset debounce/one-shot/long hold, uJ11 single-segment scanner, 01/02/04/08 and boot 04");$finish;
 end
 initial begin #100000;$fatal(1,"frequency controls timeout");end
endmodule
