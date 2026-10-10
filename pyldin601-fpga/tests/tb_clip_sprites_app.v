`timescale 1ns/1ps
// Real HD6303 PGM, production blitter/arbitration and SRAM-10 delayed pads.
module clip_sprites_app_fixture #(parameter SPEED=0,MODEL_A=0)(
 input cpu_rw,cpu_vma,input[15:0]cpu_addr,input[7:0]cpu_out,
 output cpu_clk,cpu_reset,cpu_hold,cpu_irq,cpu_hd,output[7:0]cpu_in
);
 reg clk=0;always #21 clk=~clk;
 wire fast;test_fast_clock_physical fast_clock(fast);
 wire[19:0]sa,pa;wire[15:0]sd,pd;wire ce,oe,we,ub,lb,pc,po,pw,pu,pl;
 classic_system #(.BOOT_FILE("build/clip-sprites-app-boot.mem")) dut(
  .clk(clk),.clk_fast(fast),.pll_locked(1'b1),.btn_resetn(1'b1),.cpu_rw(cpu_rw),.cpu_vma(cpu_vma),
  .cpu_addr(cpu_addr),.cpu_out(cpu_out),.cpu_clk(cpu_clk),.cpu_reset(cpu_reset),.cpu_hold(cpu_hold),.cpu_irq(cpu_irq),.hd6303_en(cpu_hd),.cpu_in(cpu_in),
  .ps2clk(1'b1),.ps2dat(1'b1),.rxd(1'b1),.miso(1'b1),.hg_tms(1'b0),.hg_tck(1'b0),.hg_tdi(1'b0),
  .SRAM_ADDR(sa),.SRAM_DATA(sd),.SRAM_CE(ce),.SRAM_OE(oe),.SRAM_WE(we),.SRAM_UB(ub),.SRAM_LB(lb));
 reg[15:0]memory[0:32767],graphics[0:131071];
 integer jobs=0,frames=0,checks=0,opaque=0,keyed=0;
 // NVC 1.20 treats integer-array selections as unsigned; cast signed X/Y
 // explicitly, as verified by a standalone negative-coordinate reproducer.
 integer px[0:2],py[0:2],dx[0:2],dy[0:2],valid[0:1],old_visible[0:1];
 reg[3:0]seen_page=0;
 assign #10 pa=sa;assign #10 pc=ce,po=oe,pu=ub,pl=lb;
 assign #6 pw=we;assign #14.5 pd=sd;
 wire[15:0]read_word=pa[19]?graphics[pa[16:0]]:pa==20'h107fd ? 16'h0001:memory[pa[14:0]];
 always @(negedge oe)if(!ce&&sa>=20'h08000&&sa!=20'h107fd&&!(sa>=20'h80000&&sa<20'ha0000))
  $fatal(1,"CLIPSPR unexpected physical read %h",sa);
 assign #18 sd=!pc&&!po&&pw?read_word:16'bz;
 always @(posedge pw)if(!pc)begin
  if(^pd===1'bx)$fatal(1,"CLIPSPR invalid SRAM write");
  if(!pl)begin if(pa[19])graphics[pa[16:0]][7:0]=pd[7:0];else memory[pa[14:0]][7:0]=pd[7:0];end
  if(!pu)begin if(pa[19])graphics[pa[16:0]][15:8]=pd[15:8];else memory[pa[14:0]][15:8]=pd[15:8];end
 end
 function[7:0]byte_at;input[20:0]a;reg[15:0]w;
 begin w=a[20]?graphics[a[17:1]]:memory[a[15:1]];byte_at=a[0]?w[15:8]:w[7:0];end endfunction
 function[7:0]background;input integer x,y;
 begin background=((x/20+y/20)&1)?8'h4a:8'h25;end endfunction
 function integer inset;input integer y;
 begin
  case(y)
   0,31:inset=12;1,30:inset=10;2,29:inset=8;3,28:inset=6;
   4,27:inset=5;5,26:inset=4;6,25:inset=3;7,8,23,24:inset=2;
   9,10,11,20,21,22:inset=1;default:inset=0;
  endcase
 end endfunction
 function[7:0]sprite;input integer x,y,b;
 begin
  if(x<inset(y)||x>=32-inset(y))sprite=0;
  else if(x>=8&&x<12&&y>=8&&y<12)sprite=255;
  else sprite=b==0?8'he0:b==1?8'h1c:8'h03;
 end endfunction
 task check_frame;input integer page;
 integer x,y,b,sx,sy,visible;reg[7:0]expected,c,actual;
 begin
  visible=0;
  for(b=0;b<3;b=b+1)if($signed(px[b])<320&&px[b]+32>0&&$signed(py[b])<200&&py[b]+32>0)visible++;
  if(keyed!=visible||opaque!=(valid[page]?old_visible[page]:0))$fatal(1,"CLIPSPR wrong dirty rectangles frame=%d page=%d opaque=%d keyed=%d visible=%d valid=%d old=%d xy=%d,%d / %d,%d / %d,%d",frames,page,opaque,keyed,visible,valid[page],old_visible[page],px[0],py[0],px[1],py[1],px[2],py[2]);
  for(y=0;y<200;y=y+1)for(x=0;x<320;x=x+1)begin
   expected=background(x,y);
   for(b=0;b<3;b=b+1)begin
    sx=x-px[b];sy=y-py[b];
    if(sx>=0&&sx<32&&sy>=0&&sy<32)begin c=sprite(sx,sy,b);if(c!=0)expected=c;end
   end
   actual=byte_at(21'h100000+page*65536+y*320+x);
   if(actual!==expected)
    $fatal(1,"CLIPSPR frame %d page %d pixel %d,%d got %h expected %h",frames,page,x,y,actual,expected);
   if(byte_at(21'h130000+y*320+x)!==background(x,y))$fatal(1,"CLIPSPR background damaged");
   checks++;
  end
  for(b=0;b<3;b=b+1)for(y=0;y<32;y=y+1)for(x=0;x<32;x=x+1)
   if(byte_at(21'h120000+y*320+b*32+x)!==sprite(x,y,b))$fatal(1,"CLIPSPR atlas damaged");
  for(b=0;b<3;b=b+1)begin
   px[b]+=dx[b];py[b]+=dy[b];
   if($signed(px[b])< -32)begin px[b]=-32;dx[b]=-dx[b];end
   if($signed(px[b])>320)begin px[b]=320;dx[b]=-dx[b];end
   if($signed(py[b])< -32)begin py[b]=-32;dy[b]=-dy[b];end
   if($signed(py[b])>200)begin py[b]=200;dy[b]=-dy[b];end
  end
  valid[page]=1;old_visible[page]=visible;frames++;opaque=0;keyed=0;
  if(frames==8)memory[16'h01c1][7:0]=27;
 end endtask
 always @(posedge clk)begin
  #1;
  if(dut.gfx_enabled&&dut.gfx.front_page!=seen_page)begin
   seen_page=dut.gfx.front_page;
   check_frame(seen_page);
  end
 end
 always @(posedge clk)if(dut.bus_write&&cpu_addr==16'he651)begin
  jobs++;
  if(dut.gfx_enabled)begin
   if(cpu_out==2)opaque++;
   if(cpu_out==6)keyed++;
   if(cpu_out==2||cpu_out==6)begin
    if(dut.gfx.job_width>32||dut.gfx.job_height>32||dut.gfx.job_destination_offset%320+dut.gfx.job_width>320||dut.gfx.job_source_offset%320+dut.gfx.job_width>320)$fatal(1,"CLIPSPR full-frame copy during animation");
    if(dut.gfx.job_destination_page==dut.gfx.front_page)$fatal(1,"CLIPSPR writes displayed page");
   end
  end
 end
 always @(negedge cpu_clk)if(dut.locked&&cpu_hold)$fatal(1,"CLIPSPR stalled CPU");
 initial begin
  $readmemh("build/clip-sprites-app-sram.mem",memory);
  px[0]=-16;py[0]=-16;dx[0]=2;dy[0]=1;
  px[1]=304;py[1]=184;dx[1]=-3;dy[1]=-2;
  px[2]=140;py[2]=85;dx[2]=-4;dy[2]=3;valid[0]=0;valid[1]=0;
  while(byte_at(21'h0380)!==8'ha5)@(posedge clk);
  if(frames!=8||dut.gfx_enabled||dut.gfx.busy||dut.gfx.underrun)$fatal(1,"CLIPSPR bad exit frames=%d",frames);
  $display("PASS actual HD6303 CLIPSPR.PGM 601A=%0d %0dMHz: %0d jobs, %0d full-frame pixels, signed coordinates/four-edge clipping/transparent overlap/dirty rectangles, 8 VBL flips, ESC, SRAM-10 without HOLD",MODEL_A,1<<SPEED,jobs,checks);$finish;
 end
 initial begin #2000000000;$fatal(1,"CLIPSPR timeout PC=%h jobs=%d frames=%d",cpu_addr,jobs,frames);end
endmodule
