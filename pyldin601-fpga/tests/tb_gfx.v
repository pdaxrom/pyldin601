`timescale 1ns/1ps
// Full machine memory path with SRAM-10 delay, board skew, video, ROM lock,
// electronic disk and cycle-by-cycle speed changes. 24/96 MHz PLL ratio.
module tb_gfx #(parameter ADDR_DELAY=10,DATA_DELAY=14.5,CONTROL_DELAY=10,WE_DELAY=6,WE_RISE=WE_DELAY,WE_FALL=WE_DELAY,FAST_OFFSET=0);
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
 reg[15:0]memory[0:1048575];reg[7:0]header[0:95];
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
  if($realtime-addr_change<0||pc||!po||(pl&&pu))$fatal(1,"bad write setup/lane/control");
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
 integer i,s,checks=0;reg[7:0]got;integer front_seen=0;
 task reg16;input[15:0]a;input[15:0]d;
 begin put(a,d[7:0]);put(a+1,d[15:8]);end endtask
 task configure;input[3:0]sp,dp;input[15:0]so,doff;input[8:0]w;input[7:0]h,c;
 begin
  put(16'he654,sp);put(16'he655,dp);reg16(16'he656,so);reg16(16'he658,doff);
  reg16(16'he65a,w);put(16'he65c,h);put(16'he653,c);
 end endtask
 task command;input[7:0]c;input bad;
 begin
  put(16'he651,c);
  wait(!dut.gfx.busy);repeat(3)@(negedge cpu_clk);
  if(dut.gfx.error_sync[1]!==bad)$fatal(1,"GFX error command %d",c);
 end endtask
 function[7:0]byte_at;input[20:0]a;
 begin byte_at=a[0]?memory[a>>1][15:8]:memory[a>>1][7:0];end endfunction
 task expect_byte;input[20:0]a;input[7:0]b;
 begin if(byte_at(a)!==b)$fatal(1,"GFX SRAM %h got=%h expected=%h",a,byte_at(a),b);end endtask
 always @(posedge fast)if(armed&&dut.runtime_memory.grant_gfx)begin
  if(!dut.gfx_address[20])$fatal(1,"GFX escaped upper SRAM");
  if(dut.runtime_memory.active)$fatal(1,"GFX overlapped active slot");
 end
 always @(posedge clk)if(armed&&dut.gfx_enabled&&dut.video.divide==1)begin
  if(dut.video.horizontal>=100&&dut.video.horizontal<420&&dut.video.field_line>=50&&dut.video.field_line<250)begin
   if(dut.video.rgb_pixel!==((dut.video.y+dut.video.x)&255))
    $fatal(1,"RGB332 raster y=%d x=%d got=%h",dut.video.y,dut.video.x,dut.video.rgb_pixel);
   checks++;
  end
 end
 initial begin
  for(i=0;i<1048576;i=i+1)memory[i]=16'h5aa5;
  for(i=0;i<96;i=i+1)header[i]=0;
  {header[0],header[1],header[2],header[3],header[4],header[5],header[6],header[7]}="P601BOOT";
  header[8]=1;header[14]=1;header[17]=8'h18;header[18]=5;
  header[33]=8'h88;header[36]=8'h40;header[37]=8'h0b;header[40]=18;header[42]=2;header[44]=80;
  header[49]=8'h98;header[52]=8'h40;header[53]=8'h0b;header[56]=18;header[58]=2;header[60]=80;
  header[68]=1;header[73]=8'h88;header[76]=8'h40;header[77]=8'h0b;
  header[84]=1;header[89]=8'h98;header[92]=8'h40;header[93]=8'h0b;
  wait(cpu_reset===0);

  for(i=0;i<96;i=i+1)put(16'he6a3,header[i]);put(16'he6a0,8'ha5);
  if(!dut.locked)$fatal(1,"fixture lock failed");armed=1;
  get(16'he65e,8'h47);get(16'he65f,1);
  for(s=0;s<4;s=s+1)begin
   if(s!=0)begin button=0;repeat(12)@(negedge clk);button=1;wait(dut.speed==s);end
   // Unaligned byte fill, multi-row pitch and both ends of the page.
   configure(0,1,0,1,13,4,8'hb7);command(1,0);
   for(i=0;i<4;i=i+1)begin
    expect_byte(21'h110000+320*i,8'ha5);
    for(integer j=1;j<14;j=j+1)expect_byte(21'h110000+320*i+j,8'hb7);
    expect_byte(21'h110000+320*i+14,8'ha5);
   end
   configure(0,1,0,63999,1,1,8'h8e);command(4,0);expect_byte(21'h11f9ff,8'h8e);
   configure(1,0,63999,0,1,1,0);command(5,0);get(16'he65d,8'h8e);
   // Both overlap directions, odd/even byte lanes, exact row strides.
   for(i=0;i<1024;i=i+1)memory[(21'h120000>>1)+i]=16'(i*2+1)<<8 | ((i*2)&255);
   configure(2,2,0,3,17,3,0);command(2,0);
   for(i=0;i<3;i=i+1)for(integer j=0;j<17;j=j+1)expect_byte(21'h120003+320*i+j,(320*i+j)&255);
   configure(2,2,3,0,17,3,0);command(2,0);
   for(i=0;i<3;i=i+1)for(integer j=0;j<17;j=j+1)expect_byte(21'h120000+320*i+j,(320*i+j)&255);
   configure(2,15,0,63999,2,1,0);command(1,1);
   configure(2,15,64000,0,1,1,0);command(5,1);
   configure(2,15,0,0,0,1,0);command(1,1);
   configure(2,15,0,0,321,1,0);command(1,1);
   configure(2,15,0,0,1,201,0);command(1,1);
   // Independent ramp reference, every pixel in both PAL fields at each speed.
   for(i=0;i<64000;i=i+2)memory[(21'h100000+i)>>1]=(((i/320+i%320+1)&255)<<8)|((i/320+i%320)&255);
   checks=0;put(16'he650,1);
   // CPU RAM read/write, a full-frame fill and word-wide video run together.
   configure(0,3,0,0,320,200,8'h6d);put(16'he651,1);
   while(checks<128000)begin
    for(i=0;i<64;i=i+1)begin put(16'h2400+i,i);get(16'h2400+i,i);end
   end
   wait(!dut.gfx.busy);put(16'he650,0);
   for(i=0;i<64000;i=i+1)expect_byte(21'h130000+i,8'h6d);
   if(dut.gfx.underrun)$fatal(1,"scanline deadline missed speed %d",s);
   // Flip waits for VBL, never alters the displayed page in an active field.
   put(16'he655,1);put(16'he651,3);wait(dut.gfx.state==4);
   if(dut.gfx.front_page!=0)$fatal(1,"early page flip");
   wait(!dut.gfx.busy);get(16'he652,1);
   put(16'he655,0);command(3,0);
   for(i=0;i<64;i=i+1)begin put(16'h2400+i,i);get(16'h2400+i,i);end
  end
  // Reset drains a physical GPU transfer before releasing the CPU.
  configure(0,0,0,0,320,200,8'h55);put(16'he651,1);
  wait(dut.runtime_memory.gfx_owner&&dut.runtime_memory.active);
  armed=0;button=0;repeat(80)@(negedge clk);button=1;wait(cpu_reset===0);
  repeat(8)@(negedge cpu_clk);
  if(dut.gfx.busy||dut.gfx_enabled||!dut.locked)$fatal(1,"warm GFX reset did not drain/cancel");
  $display("PASS GFX 1/2/4/8 MHz: 512000 RGB332 pixels, fills, overlap copies, byte ports, bounds, VBL flip, SRAM-10 slots without HOLD, warm drain");$finish;
 end
`ifdef GFX_TRACE
 initial begin
  for(integer q=0;q<10;q++)begin
   #100000;$display("GFX trace t=%t cmd=%d state=%d issued=%b wait=%b cpu_reset=%b req=%b ack=%b done=%b busy=%b locked=%b",$time,dut.gfx.job_command,dut.gfx.state,dut.gfx.issued,dut.gfx.waiting,cpu_reset,dut.gfx_request,dut.gfx_ready,dut.gfx_done,dut.gfx.busy,dut.locked);
  end
  $finish;
 end
`endif
 initial begin #500000000;$fatal(1,"GFX timeout state=%d checks=%d",dut.gfx.state,checks);end
endmodule
