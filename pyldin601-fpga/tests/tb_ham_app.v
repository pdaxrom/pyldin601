`timescale 1ns/1ps
// Real HD6303 PGM, production blitter/arbitration and SRAM-10 delayed pads.
module ham_app_fixture #(parameter SPEED=0,MODEL_A=0)(
 input cpu_rw,cpu_vma,input[15:0]cpu_addr,input[7:0]cpu_out,
 output cpu_clk,cpu_reset,cpu_hold,cpu_irq,cpu_hd,output[7:0]cpu_in
);
 reg clk=0;always #21 clk=~clk;
 wire fast;test_fast_clock_physical fast_clock(fast);
 wire[19:0]sa,pa;wire[15:0]sd,pd;wire ce,oe,we,ub,lb,pc,po,pw,pu,pl;
 classic_system #(.BOOT_FILE("build/ham-app-boot.mem")) dut(
  .clk(clk),.clk_fast(fast),.pll_locked(1'b1),.btn_resetn(1'b1),.cpu_rw(cpu_rw),.cpu_vma(cpu_vma),
  .cpu_addr(cpu_addr),.cpu_out(cpu_out),.cpu_clk(cpu_clk),.cpu_reset(cpu_reset),.cpu_hold(cpu_hold),.cpu_irq(cpu_irq),.hd6303_en(cpu_hd),.cpu_in(cpu_in),
  .ps2clk(1'b1),.ps2dat(1'b1),.rxd(1'b1),.miso(1'b1),.hg_tms(1'b0),.hg_tck(1'b0),.hg_tdi(1'b0),
  .SRAM_ADDR(sa),.SRAM_DATA(sd),.SRAM_CE(ce),.SRAM_OE(oe),.SRAM_WE(we),.SRAM_UB(ub),.SRAM_LB(lb));
 reg[15:0]memory[0:32767],graphics[0:131071];
 integer jobs=0,checks=0,enables=0,palette_writes=0;reg was_enabled=0;
 reg[5:0]components[0:6143],original[0:8191];
 assign #10 pa=sa;assign #10 pc=ce,po=oe,pu=ub,pl=lb;
 assign #6 pw=we;assign #14.5 pd=sd;
 wire[15:0]read_word=pa[19]?graphics[pa[16:0]]:pa==20'h307fd ? 16'h0001:memory[pa[14:0]];
 always @(negedge oe)if(!ce&&sa>=20'h08000&&sa!=20'h307fd&&!(sa>=20'h80000&&sa<20'ha0000))
  $fatal(1,"HAM unexpected physical read %h",sa);
 assign #18 sd=!pc&&!po&&pw?read_word:16'bz;
 always @(posedge pw)if(!pc)begin
  if(^pd===1'bx)$fatal(1,"HAM invalid SRAM write");
  if(!pl)begin if(pa[19])graphics[pa[16:0]][7:0]=pd[7:0];else memory[pa[14:0]][7:0]=pd[7:0];end
  if(!pu)begin if(pa[19])graphics[pa[16:0]][15:8]=pd[15:8];else memory[pa[14:0]][15:8]=pd[15:8];end
 end
 function[7:0]byte_at;input[20:0]a;reg[15:0]w;
 begin w=a[20]?graphics[a[17:1]]:memory[a[15:1]];byte_at=a[0]?w[15:8]:w[7:0];end endfunction
 function[7:0]expected_pixel;input integer page,x,y;integer row,col,sub;
 begin
  row=y/3;col=x/5;sub=x%5;
  if(y>=192)expected_pixel=0;
  else expected_pixel=sub==0?8'h80+col:sub==1?8'hc0+row:8'h40+((row+col)&63);
 end endfunction
 task check_images;
 reg[7:0]actual,want;
 begin
  if(palette_writes!=6144)$fatal(1,"HAM native table upload incomplete %d",palette_writes);
  for(integer page=0;page<1;page++)for(integer y=0;y<200;y++)for(integer x=0;x<320;x++)begin
   actual=byte_at(21'h100000+page*65536+y*320+x);want=expected_pixel(page,x,y);
   if(actual!==want)$fatal(1,"HAM page=%d pixel=%d,%d got=%h expected=%h",page,x,y,actual,want);
   checks++;
  end
 end endtask
 always @(posedge clk)begin
  #1;
  if(dut.gfx_enabled&&!was_enabled)begin
   enables++;check_images();
   if(dut.gfx.format!==1'b1||dut.gfx.front_page!==4'd0)$fatal(1,"HAM wrong mode/page");
   memory[16'h01c1][7:0]=27;
  end
  was_enabled=dut.gfx_enabled;
 end
 always @(posedge clk)if(dut.bus_write&&cpu_addr==16'he65e)begin
  if(palette_writes<6144)begin
   if(cpu_out!=={2'b0,components[palette_writes]})$fatal(1,"HAM native MUL component mismatch %d got=%d expected=%d",palette_writes,cpu_out,components[palette_writes]);
  end else if(palette_writes>=14336||cpu_out!=={2'b0,original[palette_writes-6144]})$fatal(1,"HAM native palette readback/restore mismatch %d",palette_writes);
  palette_writes++;
 end
 always @(posedge clk)if(dut.bus_write&&cpu_addr==16'he651)jobs++;
 always @(negedge cpu_clk)if(dut.locked&&cpu_hold)$fatal(1,"HAM stalled CPU");
 initial begin
  $readmemh("build/ham-app-sram.mem",memory);
  $readmemh("build/ham/components.mem",components);
  $readmemh("rtl/pal_rgb332.mem",original);
  while(byte_at(21'h0380)!==8'ha5)@(posedge clk);
  if(enables!=1||dut.gfx_enabled||dut.gfx.busy||dut.gfx.underrun)$fatal(1,"HAM bad exit enables=%d",enables);
  if(palette_writes!=14336||dut.palette_read_mode)$fatal(1,"HAM native palette restore incomplete %d",palette_writes);
  $display("PASS actual HD6303 HAM.PGM 601A=%0d %0dMHz: %0d FILL/VBL jobs, %0d page bytes, 6144 native MUL samples, HAM8/ESC, 8192 palette restore, SRAM-10 without HOLD",MODEL_A,1<<SPEED,jobs,checks);$finish;
 end
 initial begin #15000000000;$fatal(1,"HAM timeout PC=%h jobs=%d enables=%d",cpu_addr,jobs,enables);end
endmodule
