`timescale 1ns/1ps
// Full machine memory path with SRAM-10 delay, board skew, video, ROM lock,
// electronic disk and cycle-by-cycle speed changes. 24/96 MHz PLL ratio.
module tb_dma #(parameter ADDR_DELAY=10,DATA_DELAY=14.5,CONTROL_DELAY=10,WE_DELAY=6,WE_RISE=WE_DELAY,WE_FALL=WE_DELAY,FAST_OFFSET=0);
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

 task set_byte;input[20:0]a;input[7:0]b;
 begin if(a[0])memory[a>>1][15:8]=b;else memory[a>>1][7:0]=b;end endtask
 task param24;input[23:0]d;
 begin put(16'he6e3,d[7:0]);put(16'he6e3,d[15:8]);put(16'he6e3,d[23:16]);end endtask
 task dma_config;input[23:0]src,dst,w;input[15:0]h;input[23:0]ss,ds;input[7:0]flags,val;
 begin
  put(16'he6e2,0);param24(src);param24(dst);param24(w);put(16'he6e3,h[7:0]);put(16'he6e3,h[15:8]);
  param24(ss);param24(ds);put(16'he6e3,flags);put(16'he6e3,val);
 end endtask
 task dma_wait;input bad;
 begin
  wait(!dut.gfx.dma_busy);repeat(3)@(negedge cpu_clk);
  get(16'he6e0,bad?8'h11:8'h01);
 end endtask
 task dma_command;input[7:0]c;input bad;
 begin put(16'he6e1,c);dma_wait(bad);end endtask
 reg[7:0]expected[0:131071];integer jobs=0,total=0;
 task rectangle;input[20:0]src,dst;input integer w,h,ss,ds;input[7:0]op,flags,val;
 integer x,y,k,n;reg[7:0]b;
 begin
  // Independent snapshot oracle, including gaps and neighbouring guard bytes.
  n=ds*h+w+2;
  for(k=0;k<n;k++)expected[k]=byte_at(dst+k);
  for(y=0;y<h;y++)for(x=0;x<w;x++)begin
   b=op==1?val:byte_at(src+(flags[2]?0:y*ss+x));
   if(op!=6||b!=val)expected[flags[3]?0:y*ds+x]=b;
  end
  dma_config(src,dst,w,h,ss,ds,flags,val);put(16'he6e1,op);
  // Both interfaces are locked immediately, including the CDC launch interval.
  get(16'he650,8'h80);put(16'he651,4);put(16'he6e1,255);put(16'he6e3,99);
  while(dut.gfx.dma_busy)begin
   put(16'h2501,8'hf3);get(16'h2501,8'hf3);
   put(16'he6f1,18);put(16'he6f0,3);put(16'he6f0,7);
  end
  dma_wait(0);
  for(k=0;k<n;k++)expect_byte(dst+k,expected[k]);
  jobs++;total+=w*h;
 end endtask
 wire[9:0]raster_x;wire[8:0]raster_y;wire raster_valid,raster_first;
 reg check_raster=0;integer pixel_checks=0;
 pal_viewport_reference #(.LATENCY(2)) reference_view(.clk(clk),.reset(cpu_reset),.model_a(1'b0),.extended(dut.gfx_enabled),.colour(1'b0),.rows(8'd25),.x(raster_x),.y(raster_y),.valid(raster_valid),.first(raster_first));
 always @(posedge clk)begin
  #1;
  if(armed&&check_raster&&raster_valid)begin
   if(dut.video.rgb_pixel!==((raster_x+raster_y)&255))$fatal(1,"flat DMA corrupted scanout x=%d y=%d",raster_x,raster_y);
   pixel_checks++;
  end
 end
 task tap_speed;input[1:0]target;
 begin button=0;repeat(12)@(negedge clk);button=1;wait(dut.speed==target);end endtask
 integer x,y,k,before_writes;reg[7:0]palcopy[0:8191];
 initial begin
  for(i=0;i<1048576;i++)memory[i]=16'h5aa5;
  for(i=0;i<64;i++)header[i]=0;
  {header[0],header[1],header[2],header[3],header[4],header[5],header[6],header[7]}="P601BOOT";
  header[8]=2;header[14]=1;header[17]=8'h18;header[18]=1;
  wait(cpu_reset===0);
  for(i=0;i<64;i++)put(16'he6a3,header[i]);put(16'he6a0,8'ha5);
  if(!dut.locked)$fatal(1,"fixture lock failed");armed=1;
  get(16'he6e0,1);get(16'he6e1,8'h44);
  put(16'he6e2,6);get(16'he6e3,0);get(16'he6e2,6);put(16'he6e3,0);get(16'he6e2,7);
  for(s=0;s<4;s++)begin
   if(s!=0)begin button=0;repeat(12)@(negedge clk);button=1;wait(dut.speed==s);end
   for(i=0;i<131072;i++)begin set_byte(21'h40000+i,(i*17+i/31+3)&255);set_byte(21'h80000+i,(i*7)&255);end
   rectangle(21'h41ff9,21'h81ffd,8193,1,0,0,2,0,0);
   rectangle(21'h42001,21'h42006,8193,1,0,0,2,0,0);
   rectangle(21'h42006,21'h42001,8193,1,0,0,2,0,0);
   rectangle(21'h40001,21'h80003,127,17,159,193,2,0,0);
   rectangle(21'h40001,21'h40004,131,11,320,320,6,0,0);
   rectangle(21'h40004,21'h40001,131,11,320,320,6,0,255);
   rectangle(21'h40000,21'h80001,65537,1,0,0,1,0,8'hd3);
   rectangle(21'h40000,21'h80001,2049,1,0,0,2,4,0);
   rectangle(21'h40000,21'h80001,2049,1,0,0,2,8,0);
   // Final physical byte and crossing legacy GPU pages are valid flat RAM.
   dma_config(24'h40000,24'h1fffff,1,1,0,0,0,8'h71);dma_command(1,0);expect_byte(21'h1fffff,8'h71);
   dma_config(24'h40000,24'h10fff9,31,1,0,0,0,8'h81);dma_command(2,0);
   for(i=0;i<31;i++)expect_byte(21'h10fff9+i,byte_at(21'h40000+i));
   // Physical E6xx is underlying SRAM, never a peripheral access.
   dma_config(0,24'he6e0,1,1,0,0,0,8'hab);dma_command(1,0);expect_byte(21'he6e0,8'hab);get(16'he6e0,1);
   before_writes=writes;
   dma_config(24'h1fffff,24'h80000,2,1,0,0,0,0);dma_command(2,1);
   dma_config(24'h40000,24'h1fffff,2,1,0,0,0,0);dma_command(2,1);
   dma_config(24'h200000,24'h80000,1,1,0,0,0,0);dma_command(2,1);
   dma_config(24'h40000,24'h10000,1,1,0,0,0,0);dma_command(2,1);
   dma_config(24'h40000,24'hffff,2,1,0,0,0,0);dma_command(2,1);
   // Later-row faults reject the entire operation before its first write.
   dma_config(24'h40000,24'hff00,1,2,1,256,0,0);dma_command(2,1);
   dma_config(24'h1ff000,24'h80000,1,2,4096,1,0,0);dma_command(2,1);
   dma_config(24'h40000,24'he6e0,1,1,0,0,2,0);dma_command(2,1);
   dma_config(24'h40000,24'h80000,4,2,3,4,0,0);dma_command(2,1);
   dma_config(24'h40000,24'h80000,1,1,0,0,16,0);dma_command(2,1);
   dma_config(24'h40000,24'h80000,1,1,0,0,0,0);dma_command(255,1);
   dma_config(24'h40000,24'h80000,0,1,0,0,0,0);dma_command(2,0);
   dma_config(24'h40000,24'h80000,1,0,0,0,0,0);dma_command(2,0);
   if(writes!=before_writes)$fatal(1,"invalid/empty DMA changed SRAM");
   // Palette write/read round-trip, auto-increment and ownership against CPU.
   for(i=0;i<8192;i++)set_byte(21'h44000+i,(i*13+i/19)&255);
   put(16'he652,0);put(16'he65d,0);put(16'he65f,0);
   dma_config(24'h44000,24'he65e,8192,1,0,0,2,0);put(16'he6e1,2);
   put(16'he652,57);put(16'he65d,17);put(16'he65e,0);put(16'he65f,3);
   dma_wait(0);
   if(dut.video.encoder.rgb.palette_address!=0||dut.palette_read_mode)$fatal(1,"palette write ownership/address/mode");
   for(i=0;i<8192;i++)if(dut.video.encoder.rgb.table_rgb[i]!==((i*13+i/19)&63))$fatal(1,"palette DMA byte %d",i);
   dma_config(24'he65e,24'h48000,8192,1,0,0,1,0);put(16'he6e1,2);
   put(16'he652,55);put(16'he65e,8'h3f);dma_wait(0);
   for(i=0;i<8192;i++)expect_byte(21'h48000+i,(i*13+i/19)&63);
   if(dut.video.encoder.rgb.palette_address!=0||dut.palette_read_mode)$fatal(1,"palette read address/mode");
   // Nonzero PAL start, modulo wrap, readback-mode preservation.
   put(16'he652,255);put(16'he65d,31);put(16'he65f,1);
   dma_config(24'he65e,24'h50000,3,1,0,0,1,0);dma_command(2,0);
   expect_byte(21'h50000,(8191*13+8191/19)&63);expect_byte(21'h50001,0);expect_byte(21'h50002,13);
   if(dut.video.encoder.rgb.palette_address!=2||!dut.palette_read_mode)$fatal(1,"PAL offset/wrap/read mode");
   put(16'he65f,0);
   // Scanout, common DMA and ordinary CPU RAM traffic at every CPU speed.
   for(i=0;i<64000;i+=2)memory[(21'h100000+i)>>1]=(((i/320+i%320+1)&255)<<8)|((i/320+i%320)&255);
   @(dut.gfx_vblank);put(16'he650,1);check_raster=1;pixel_checks=0;
   dma_config(24'h40000,24'h80000,65537,1,0,0,0,0);put(16'he6e1,2);
   if(s==0)begin wait(pixel_checks>=512);tap_speed(1);tap_speed(2);tap_speed(3);tap_speed(0);end
   while(dut.gfx.dma_busy)begin put(16'h2501,8'hf3);get(16'h2501,8'hf3);end
   dma_wait(0);if(dut.gfx.underrun||pixel_checks<512)$fatal(1,"DMA scanout deadline/pixels");put(16'he650,0);check_raster=0;
   for(i=0;i<65537;i++)expect_byte(21'h80000+i,byte_at(21'h40000+i));
   // Legacy jobs also block the new frontend.
   configure(0,3,0,0,320,200,8'h31);put(16'he651,1);get(16'he6e0,8'h81);put(16'he6e1,2);
   wait(!dut.gfx.busy);repeat(3)@(negedge cpu_clk);get(16'he6e0,1);
   for(i=0;i<64000;i++)expect_byte(21'h130000+i,8'h31);
  end
  dma_config(24'h40000,24'h80000,131072,1,0,0,0,0);put(16'he6e1,2);
  wait(dut.runtime_memory.gfx_owner&&dut.runtime_memory.active);
  armed=0;button=0;repeat(80)@(negedge clk);button=1;wait(cpu_reset===0);
  repeat(8)@(negedge cpu_clk);
  if(dut.gfx.busy||dut.gfx.dma_busy||!dut.locked)$fatal(1,"DMA warm reset drain");
  armed=1;
  dma_config(24'h44000,24'he65e,8192,1,0,0,2,0);put(16'he6e1,2);
  wait(dut.dma_palette_write);armed=0;button=0;repeat(80)@(negedge clk);button=1;wait(cpu_reset===0);
  repeat(8)@(negedge cpu_clk);
  if(dut.gfx.busy||dut.palette_owned||dut.video.encoder.rgb.palette_address!=0||dut.palette_read_mode)$fatal(1,"palette DMA reset/cancel");
  $display("PASS flat/shared DMA 1/2/4/8 MHz: %d snapshot jobs/%d bytes, bank/page boundaries, 24-bit length, strides/fixed/key/fill/memmove, atomic invalid ranges, palette roundtrip/ownership, CPU/scanout, no HOLD, warm reset",jobs,total);$finish;
 end
 always @(posedge fast)if(armed&&dut.runtime_memory.grant_cpu&&dut.runtime_memory.active)$fatal(1,"DMA stole CPU slot");
 initial begin #500000000;$fatal(1,"DMA timeout state %d",dut.gfx.dma.state);end
endmodule
