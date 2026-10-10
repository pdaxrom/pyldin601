`timescale 1ns/1ps
// Full machine memory path with SRAM-10 delay, board skew, video, ROM lock,
// electronic disk and cycle-by-cycle speed changes. 24/96 MHz PLL ratio.
module tb_turbo_memory #(parameter ADDR_DELAY=10,DATA_DELAY=14.5,CONTROL_DELAY=10,WE_DELAY=6,WE_RISE=WE_DELAY,WE_FALL=WE_DELAY,FAST_OFFSET=0);
 reg clk=0;always #20.832 clk=~clk;
 reg fast=0;initial begin #(FAST_OFFSET);forever #5.208 fast=~fast;end
 reg button=1;
 reg rw=1,vma=0;reg[15:0]address=0;reg[7:0]data=0;
 wire cpu_clk,cpu_reset,cpu_hold;wire[7:0]result;
 wire[19:0]sa,pa;wire[15:0]sd,pd;wire ce,oe,we,ub,lb,pc,po,pw,pu,pl;
 classic_system #(.BUTTON_TICK_DIV(1),.BUTTON_DEBOUNCE_MS(2),.BUTTON_LONG_MS(64),.BUTTON_RELOAD_MS(128)) dut(.clk(clk),.clk_fast(fast),.pll_locked(1'b1),.btn_resetn(button),
  .cpu_rw(rw),.cpu_vma(vma),.cpu_addr(address),.cpu_out(data),.cpu_clk(cpu_clk),.cpu_reset(cpu_reset),.cpu_hold(cpu_hold),.cpu_in(result),
  .ps2clk(1'b1),.ps2dat(1'b1),.rxd(1'b1),.miso(1'b1),
  .SRAM_ADDR(sa),.SRAM_DATA(sd),.SRAM_CE(ce),.SRAM_OE(oe),.SRAM_WE(we),.SRAM_UB(ub),.SRAM_LB(lb));
 reg[15:0]memory[0:1048575];reg[7:0]header[0:63];
 assign #ADDR_DELAY pa=sa;assign #CONTROL_DELAY pc=ce,po=oe,pu=ub,pl=lb;
 assign #(WE_RISE,WE_FALL) pw=we;assign #DATA_DELAY pd=sd;
 // Worst SRAM tAA=10 ns plus 8 ns FPGA input budget; output disable 4 ns.
 assign #(18,18,4) sd=!pc&&!po&&pw?memory[pa]:16'bz;
 real we_start,addr_change,dq_change;integer writes=0,reads=0,video_reads=0,cycles=0;
 reg armed=0;
 always @(pa or pu or pl)begin
  addr_change=$realtime;
  if(armed&&!pw)$fatal(1,"address/lane changed while WE low");
 end
 always @(pd)begin dq_change=$realtime;end
 always @(negedge pw)if(armed)begin
  we_start=$realtime;
  if($realtime-addr_change<0||pc||!po||((pl&&pu)||(!pl&&!pu)))$fatal(1,"bad write setup/lane/control");
 end
 always @(posedge pw)if(!pc)begin
  if(armed&&($realtime-we_start<8||$realtime-dq_change<6))$fatal(1,"write pulse/data setup below SRAM-10 spec");
  if(!pl)begin if(^pd[7:0]===1'bx)$fatal(1,"invalid write DQ");memory[pa][7:0]=pd[7:0];end
  if(!pu)begin if(^pd[15:8]===1'bx)$fatal(1,"invalid write DQ");memory[pa][15:8]=pd[15:8];end
  writes=writes+1;
 end
 always @(posedge fast)if(armed)begin
  if(dut.runtime_memory.grant_cpu&&dut.runtime_memory.active)$fatal(1,"CPU slot collided with video");
  if(dut.runtime_memory.grant_video&&!dut.runtime_memory.active)video_reads=video_reads+1;
 end
 always @(negedge cpu_clk)if(armed)begin if(cpu_hold||cpu_reset)$fatal(1,"runtime stretched/reset CPU");cycles=cycles+1;end
 task put;input[15:0]a;input[7:0]d;
 begin @(negedge cpu_clk);#1;address=a;data=d;rw=0;vma=1;
  @(negedge cpu_clk);#1;vma=0;rw=1;
 end endtask
 task get;input[15:0]a;input[7:0]expected;
 begin @(negedge cpu_clk);#1;address=a;rw=1;vma=1;
  @(negedge cpu_clk);#1;
  if(result!==expected)$fatal(1,"CPU read mismatch speed=%d address=%x got=%x expected=%x",dut.speed,a,result,expected);
  vma=0;reads=reads+1;
 end endtask
 integer i,s,video_before;reg[15:0]a;reg[7:0]d;real before_edge,period;
 initial begin
  for(i=0;i<1048576;i=i+1)memory[i]=16'h5aa5;
  for(i=0;i<64;i=i+1)header[i]=0;
  {header[0],header[1],header[2],header[3],header[4],header[5],header[6],header[7]}="P601BOOT";
  header[8]=2;header[14]=1;header[17]=8'h18;header[18]=1;
  wait(cpu_reset===0);
  // Reset before acceptance and after client ACK, while an AP write drains.
  // No orphaned token or permanently issued boot request may survive reset.
  for(s=0;s<2;s=s+1)begin
   put(16'he6a4,8'h20+s);put(16'he6a5,8'h10);put(16'he6a6,2);
   fork
    put(16'he6a7,8'hd3);
    begin
     if(s==0)wait(dut.boot_pending&&dut.boot_accept_seen!=dut.boot_token);
     else wait(dut.boot.issued&&!dut.boot_done);
     force dut.warm_hold=1;force dut.warm_request=1;
     repeat(4)@(negedge clk);release dut.warm_request;release dut.warm_hold;
     wait(cpu_reset===0);
    end
   join
   if(dut.boot.pending||dut.boot.issued||dut.boot_pending)$fatal(1,"orphaned boot request after reset");
  end
  // Exercise the unified boot aperture and its font mirror before lock.
  put(16'he6a4,0);put(16'he6a5,8'h10);put(16'he6a6,2);
  for(i=0;i<16;i=i+1)put(16'he6a7,i^8'hb6);
  wait(!dut.boot.pending);@(posedge clk);#1;
  for(i=0;i<16;i=i+1)begin
   if((i[0]?memory[(21'h21000+i)>>1][15:8]:memory[(21'h21000+i)>>1][7:0])!==((i^8'hb6)&255))$fatal(1,"boot SRAM write mismatch");
   if(dut.video.font[i]!==((i^8'hb6)&255))$fatal(1,"boot font mirror mismatch index=%d actual=%x expected=%x",i,dut.video.font[i],i^8'hb6);
  end
  put(16'he6a4,0);put(16'he6a5,8'h10);put(16'he6a6,2);
  put(16'he6ab,0);wait(!dut.boot.pending);get(16'he6ab,8'hb6);
  put(16'he6a0,4); // BIOS-selected 2 MHz; ordinary reset must restore this value.
  for(i=0;i<64;i=i+1)put(16'he6a3,header[i]);put(16'he6a0,8'ha5);
  if(!dut.locked)$fatal(1,"fixture lock failed");armed=1;
  put(16'he600,1);put(16'he601,48);put(16'he600,6);put(16'he601,28);
  put(16'he600,12);put(16'he601,8'h08);put(16'he600,13);put(16'he601,0);put(16'he629,8'h20);
  #4000000;
  // Cancel a video token before ACK and drain one after ACK. The first new
  // frame must make progress in both cases, rather than alias a stale token.
  for(s=0;s<2;s=s+1)begin
   if(s==0)wait(dut.video_pending&&dut.video_accept_seen!=dut.video_token);
   else wait(dut.video_pending&&dut.video_accept_seen==dut.video_token&&!dut.video_done);
   armed=0;force dut.warm_hold=1;force dut.warm_request=1;
   repeat(4)@(negedge clk);release dut.warm_request;release dut.warm_hold;
   wait(cpu_reset===0);armed=1;
   put(16'he600,1);put(16'he601,48);put(16'he600,6);put(16'he601,28);
   put(16'he600,12);put(16'he601,8'h08);put(16'he600,13);put(16'he601,0);put(16'he629,8'h20);
   video_before=video_reads;wait(video_reads>=video_before+80);
  end
  for(s=0;s<8;s=s+1)begin
   // Request via the real boundary/drain logic; no forced clock or phase.
   if(s!=0)begin button=0;repeat(12)@(negedge clk);button=1;wait(dut.speed==(s+1)%4);end
   repeat(2)@(negedge cpu_clk);before_edge=$realtime;@(negedge cpu_clk);period=$realtime-before_edge;
   if(period<((1000.0/(1<<((s+1)%4)))-0.1)||period>((1000.0/(1<<((s+1)%4)))+0.1))$fatal(1,"wrong CPU period %f",period);
   for(i=0;i<128;i=i+1)begin a=16'h2000+i;d=i^8'h69;put(a,d);get(a,d);end
   put(16'he680,0);put(16'he681,0);put(16'he682,0);put(16'he683,8'ha5);
   get(16'he683,0); // Removed disk ports cannot access SRAM.

  end
  armed=0;button=0;repeat(80)@(negedge clk);
  if(!cpu_reset)$fatal(1,"long press did not reset");
  button=1;wait(cpu_reset===0);repeat(3)@(negedge cpu_clk);
  if(dut.speed!=1||!dut.locked||dut.video.font[15]!=8'hb9)$fatal(1,"warm reset lost BIOS speed/ROM lock");
  armed=1;get(16'h2000,8'h69);
  put(16'he680,7);put(16'he681,8'hff);put(16'he682,8'hfe);get(16'he683,0);
  if(video_reads<40)$fatal(1,"no concurrent video traffic");
  armed=0;vma=0;button=0;
  wait(dut.restart_reset);
  if(dut.fast_memory_busy)$fatal(1,"BIOS restart aborted a physical SRAM transaction");
  repeat(200)@(negedge clk);
  if(dut.locked||!dut.boot_mode||!cpu_reset||!dut.hd6303_en||!dut.restart_seen)$fatal(1,"10s reset did not return to resident HD6303 BIOS");
  button=1;wait(cpu_reset===0);repeat(4)@(negedge cpu_clk);
  if(dut.locked||!dut.boot_mode||dut.restart_seen||dut.boot_speed!=0)$fatal(1,"BIOS restart repeated/lost defaults on release");
  $display("PASS turbo SRAM-10: 1/2/4/8 MHz, %d reads/%d writes, %d video reads, %d CPU cycles without HOLD; removed disk ports/ROM, BIOS reset frequency and drained 10s restart",reads,writes,video_reads,cycles);$finish;
 end
 initial begin #30000000;$fatal(1,"turbo memory timeout");end
endmodule
