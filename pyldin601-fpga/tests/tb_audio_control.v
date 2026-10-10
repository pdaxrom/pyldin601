`timescale 1ns/1ps
module tb_audio_control;
 reg clk=0,fast=0,reset=1,read=0,write=0;
 always #20 clk=~clk;
 always #5 fast=~fast;
 reg[3:0]address=0;reg[7:0]data=0;
 wire[7:0]result,ay_result;wire irq,update,seen,audio;wire[31:0]divider;
 classic_audio_control control(clk,reset,read,write,address,data,result,irq,update,divider,seen);
 classic_ay8910 ay(clk,fast,reset,1'b0,4'b0,8'b0,ay_result,audio,1'b0,update,divider,seen);
`ifdef SYNTHESIS
 GSR GSR_INST(1'b1);PUR PUR_INST(1'b1);
`endif
 integer system_cycles=0,fast_cycles=0,timer_events=0;
 always @(posedge clk)begin
  system_cycles=system_cycles+1;
  if(!reset&&control.event_due)timer_events=timer_events+1;
 end
 always @(posedge fast)begin
  fast_cycles=fast_cycles+1;
  if(!reset&&!ay.initializing&&ay.clock_terminal)
   if(ay.pc!=42||ay.state!=4)$fatal(1,"AY missed a chip tick while engine busy");
 end
 task wr;input integer a,v;begin
  @(negedge clk);address=a;data=v;write=1;
  @(negedge clk);write=0;
 end endtask
 task rd;input integer a;output reg[7:0]v;begin
  @(negedge clk);address=a;read=1;#1;v=result;
  @(negedge clk);read=0;
 end endtask
 task set_period;input[31:0]p;begin
  wr(2,p[31:24]);wr(3,p[23:16]);wr(4,p[15:8]);wr(5,p[7:0]);wr(6,1);
 end endtask
 task set_divider;input[31:0]d;begin
  wr(11,d[31:24]);wr(12,d[23:16]);wr(13,d[15:8]);wr(14,d[7:0]);wr(15,1);
  wait(!control.busy);
 end endtask
 task cadence;input[31:0]d;integer start,last,k,interval;reg[63:0]scaled;begin
  set_divider(d);
  wait(ay.clock_terminal);@(negedge fast);wait(!ay.clock_terminal);
  wait(ay.clock_terminal);@(negedge fast);start=fast_cycles;last=start;
  for(k=0;k<1000;k=k+1)begin
   wait(!ay.clock_terminal);wait(ay.clock_terminal);@(negedge fast);
   interval=fast_cycles-last;last=fast_cycles;
   if(interval!=d[31:16]&&interval!=d[31:16]+1)$fatal(1,"fractional divider interval %d for %h",interval,d);
  end
  scaled=64'd1000*d;
  if(last-start<scaled/65536-1||last-start>scaled/65536+1)$fatal(1,"fractional divider accumulated drift %d",last-start);
 end endtask
 task timer_rate;input integer p;integer start,count;begin
  wr(0,0);set_period(p);wr(0,5);
  start=system_cycles;count=timer_events;
  wait(irq);@(negedge clk);
  if(system_cycles-start!=p||timer_events!=count+1)$fatal(1,"timer first period %d expected %d",system_cycles-start,p);
  wr(0,3);if(irq)$fatal(1,"timer ACK failed");
  wait(irq);@(negedge clk);
  if(system_cycles-start!=2*p)$fatal(1,"timer ACK altered cadence");
  wait(control.overrun);@(negedge clk);
  if(!irq||system_cycles-start!=3*p)$fatal(1,"timer pending/overrun");
  wr(0,3);if(irq||control.overrun)$fatal(1,"ACK did not clear latched flags");
  wr(0,0);
 end endtask
 reg[7:0]v,a,b,c,d;reg[31:0]snap;
 initial begin
  repeat(4)@(negedge clk);reset=0;wait(!ay.initializing);
  if(divider!==32'h01800000||irq||control.enabled)$fatal(1,"audio reset defaults");
  rd(1,v);if(v!=8'h59)$fatal(1,"audio signature");
  cadence(32'h01800000);cadence(32'h03000000);
  cadence(32'h01b11101);cadence(32'h01ad1acd);
  wr(11,3);wr(12,0);wr(13,0);wr(14,0);
  wait(ay.clock_count==0);wr(15,1);
  if(!control.busy)$fatal(1,"divider command did not await fast-domain ACK");
  wr(15,1);if(!control.bad_config)$fatal(1,"busy divider accepted another command");
  wait(!control.busy);wr(0,8);set_divider(32'h01ad1acd);
  wr(11,1);wr(12,128);if(divider!=32'h01ad1acd)$fatal(1,"torn clock divisor");
  set_divider(32'h00010000);if(!control.bad_config||divider!=32'h01ad1acd)$fatal(1,"invalid fast AY clock accepted");
  wr(0,8);set_period(0);if(!control.bad_config||control.period==0)$fatal(1,"zero timer period accepted");
  wr(0,8);timer_rate(480000);timer_rate(400000);timer_rate(240000);
  set_period(17);wr(0,5);
  wait(control.counter==16);@(negedge clk);address=0;data=3;write=1;
  @(negedge clk);write=0;
  if(!irq)$fatal(1,"ACK/compare collision lost new event");
  wr(0,0);set_period(24000000);wr(0,5);
  rd(7,a);snap=control.snapshot;rd(8,b);rd(9,c);rd(10,d);
  if({a,b,c,d}!==snap)$fatal(1,"incoherent multi-byte counter snapshot");
  wr(2,0);wr(3,0);wr(4,0);wr(5,31);
  if(control.period!=24000000)$fatal(1,"torn timer period");
  wr(6,1);if(control.period!=31||control.counter>1||irq)$fatal(1,"timer commit/restart");
  reset=1;repeat(4)@(negedge clk);reset=0;wait(!ay.initializing);
  if(irq||control.enabled||control.counter||divider!=32'h01800000||ay.clock_period!=384)$fatal(1,"warm reset audio state");
  $display("PASS programmable audio: exact 50/60/100-Hz cadence, Q16 AY clocks, atomic commits, held IRQ/overrun/ACK collision, snapshot and reset");$finish;
 end
 initial begin #300000000;$fatal(1,"programmable audio timeout");end
endmodule
