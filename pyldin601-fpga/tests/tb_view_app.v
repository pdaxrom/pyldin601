`timescale 1ns/1ps
// Actual VHDL CPU executes the real relocated PGM through production DMA/pads.
module view_app_fixture #(parameter SPEED=0,MODEL_A=0)(
 input cpu_rw,cpu_vma,input[15:0]cpu_addr,input[7:0]cpu_out,
 output cpu_clk,cpu_reset,cpu_hold,cpu_irq,cpu_hd,output[7:0]cpu_in
);
 reg clk=0;always #21 clk=~clk;
 wire fast;test_fast_clock_physical fast_clock(fast);
 wire[19:0]sa,pa;wire[15:0]sd,pd;wire ce,oe,we,ub,lb,pc,po,pw,pu,pl;
 classic_system #(.BOOT_FILE("build/view-app-boot.mem")) dut(
  .clk(clk),.clk_fast(fast),.pll_locked(1'b1),.btn_resetn(1'b1),.cpu_rw(cpu_rw),.cpu_vma(cpu_vma),
  .cpu_addr(cpu_addr),.cpu_out(cpu_out),.cpu_clk(cpu_clk),.cpu_reset(cpu_reset),.cpu_hold(cpu_hold),.cpu_irq(cpu_irq),.cpu_in(cpu_in),.hd6303_en(cpu_hd),
  .ps2clk(1'b1),.ps2dat(1'b1),.rxd(1'b1),.miso(1'b1),.hg_tms(1'b0),.hg_tck(1'b0),.hg_tdi(1'b0),
  .SRAM_ADDR(sa),.SRAM_DATA(sd),.SRAM_CE(ce),.SRAM_OE(oe),.SRAM_WE(we),.SRAM_UB(ub),.SRAM_LB(lb));
 // Only base RAM, the SWI vector and the two framebuffer pages are accessed here.
 // The separate arbitration bench covers the entire physical 2 MiB range.
 reg[15:0]memory[0:32767],graphics[0:65535];integer jobs=0,checks=0,flips=0;
 assign #10 pa=sa;assign #10 pc=ce,po=oe,pu=ub,pl=lb;
 assign #6 pw=we;assign #14.5 pd=sd;
 wire[15:0]read_word=pa[19]?graphics[pa[15:0]]:pa==20'h107fd ? 16'h0001:memory[pa[14:0]];
 always @(negedge oe)if(!ce&&sa>=20'h08000&&sa!=20'h107fd&&!(sa>=20'h80000&&sa<20'h90000))
  $fatal(1,"VIEW PGM unexpected physical read %h",sa);
 assign #18 sd=!pc&&!po&&pw?read_word:16'bz;
 always @(posedge pw)if(!pc)begin
  if(!pl)begin
   if(^pd[7:0]===1'bx)$fatal(1,"VIEW PGM invalid SRAM data");
   if(pa[19])graphics[pa[15:0]][7:0]=pd[7:0];else memory[pa[14:0]][7:0]=pd[7:0];
  end
  if(!pu)begin
   if(^pd[15:8]===1'bx)$fatal(1,"VIEW PGM invalid SRAM data");
   if(pa[19])graphics[pa[15:0]][15:8]=pd[15:8];else memory[pa[14:0]][15:8]=pd[15:8];
  end
 end
 function[7:0]byte_at;input[20:0]a;reg[15:0]w;
 begin w=a[20]?graphics[a[16:1]]:memory[a[15:1]];byte_at=a[0]?w[15:8]:w[7:0];end endfunction
 reg[7:0]expected[0:63999];
 reg[5:0]expected_palette[0:8191],original_palette[0:8191];integer palette_checks=0,delta;
 initial begin
  $readmemh("build/view-app-sram.mem",memory);
  $readmemh("build/view-app-expected.mem",expected);
  $readmemh("build/view-app-palette.mem",expected_palette);
  $readmemh("rtl/pal_rgb332.mem",original_palette);
  while(byte_at(21'h0381)!==1)begin
   @(posedge clk);
   if(byte_at(21'h0380)===8'ha5)$fatal(1,"VIEW exited before displaying, jobs=%d",jobs);
  end
  if(!dut.gfx_enabled||dut.gfx.front_page!=1||jobs<3)$fatal(1,"real VIEW setup jobs=%d",jobs);
  for(integer p=0;p<64000;p++)begin
   if(byte_at(21'h110000+p)!==expected[p])$fatal(1,"VIEW pixel %d: expected %h",p,expected[p]);
   checks++;
  end
  if(palette_checks!=8192||dut.palette_read_mode)$fatal(1,"VIEW palette upload incomplete");
  memory[16'h0382>>1][7:0]=1; // The SWI console may now deliver ESC.
  while(byte_at(21'h0380)!==8'ha5)@(posedge clk);
  if(dut.gfx_enabled||dut.gfx.busy||dut.gfx.underrun||flips!=1)
   $fatal(1,"VIEW exit/flip failed flips=%d status=%b/%b",flips,dut.gfx_enabled,dut.gfx.busy);
  if(palette_checks!=16384||dut.palette_read_mode)$fatal(1,"VIEW palette restore incomplete");
  $display("PASS actual HD6303 VIEW.PGM 601A=%0d %0dMHz: %0d jobs, %0d independently checked pixels, PCX RLE/palette/padding/centering, VBL flip and ESC",MODEL_A,1<<SPEED,jobs,checks);$finish;
 end
 always @(posedge clk)if(dut.bus_write&&cpu_addr==16'he65e)begin
  if(palette_checks<8192)begin
   delta=cpu_out;delta=delta-expected_palette[palette_checks];
   if(delta < -1 || delta > 1 || ^cpu_out===1'bx)
    $fatal(1,"real CPU palette sample %d expected %d got %d",palette_checks,expected_palette[palette_checks],cpu_out);
  end else if(palette_checks>=16384||cpu_out!=={2'b0,original_palette[palette_checks-8192]})
   $fatal(1,"VIEW readback/restore failed sample %d",palette_checks);
  palette_checks++;
 end
 always @(posedge clk)if(dut.bus_write&&cpu_addr==16'he651)begin jobs++;
  if(cpu_out==3)flips++;
  if(jobs<5||jobs%64==0)$display("VIEW PGM job %0d opcode %0d at %0t",jobs,cpu_out,$time);
 end
 initial begin #1000000;$display("VIEW bootstrap address=%h lock=%b jobs=%0d",cpu_addr,dut.locked,jobs);end
 always @(negedge cpu_clk)if(dut.locked&&cpu_hold)$fatal(1,"VIEW PGM stalled CPU");
 initial begin #8000000000;$fatal(1,"VIEW PGM timeout PC=%h jobs=%d",cpu_addr,jobs);end
endmodule
