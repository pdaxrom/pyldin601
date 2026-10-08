`timescale 1ns/1ps
// Actual VHDL CPU executes the real relocated PGM through production DMA/pads.
module gfx_app_fixture #(parameter SPEED=0,MODEL_A=0)(
 input cpu_rw,cpu_vma,input[15:0]cpu_addr,input[7:0]cpu_out,
 output cpu_clk,cpu_reset,cpu_hold,cpu_irq,output[7:0]cpu_in
);
 reg clk=0;always #21 clk=~clk;
 wire fast;test_fast_clock_physical fast_clock(fast);
 wire[19:0]sa,pa;wire[15:0]sd,pd;wire ce,oe,we,ub,lb,pc,po,pw,pu,pl;
 classic_system #(.BOOT_FILE("build/gfx-app-boot.mem")) dut(
  .clk(clk),.clk_fast(fast),.pll_locked(1'b1),.btn_resetn(1'b1),.cpu_rw(cpu_rw),.cpu_vma(cpu_vma),
  .cpu_addr(cpu_addr),.cpu_out(cpu_out),.cpu_clk(cpu_clk),.cpu_reset(cpu_reset),.cpu_hold(cpu_hold),.cpu_irq(cpu_irq),.cpu_in(cpu_in),
  .ps2clk(1'b1),.ps2dat(1'b1),.rxd(1'b1),.miso(1'b1),.hg_tms(1'b0),.hg_tck(1'b0),.hg_tdi(1'b0),
  .SRAM_ADDR(sa),.SRAM_DATA(sd),.SRAM_CE(ce),.SRAM_OE(oe),.SRAM_WE(we),.SRAM_UB(ub),.SRAM_LB(lb));
 // Only base RAM, the SWI vector and the two demo pages are accessed here.
 // The separate arbitration bench covers the entire physical 2 MiB range.
 reg[15:0]memory[0:32767],graphics[0:65535];integer jobs=0,checks=0,flips=0;
 assign #10 pa=sa;assign #10 pc=ce,po=oe,pu=ub,pl=lb;
 assign #6 pw=we;assign #14.5 pd=sd;
 wire[15:0]read_word=pa[19]?graphics[pa[15:0]]:pa==20'h307fd ? 16'h0001:memory[pa[14:0]];
 always @(negedge oe)if(!ce&&sa>=20'h08000&&sa!=20'h307fd&&!(sa>=20'h80000&&sa<20'h90000))
  $fatal(1,"GFX PGM unexpected physical read %h",sa);
 assign #18 sd=!pc&&!po&&pw?read_word:16'bz;
 always @(posedge pw)if(!pc)begin
  if(!pl)begin
   if(^pd[7:0]===1'bx)$fatal(1,"GFX PGM invalid SRAM data");
   if(pa[19])graphics[pa[15:0]][7:0]=pd[7:0];else memory[pa[14:0]][7:0]=pd[7:0];
  end
  if(!pu)begin
   if(^pd[15:8]===1'bx)$fatal(1,"GFX PGM invalid SRAM data");
   if(pa[19])graphics[pa[15:0]][15:8]=pd[15:8];else memory[pa[14:0]][15:8]=pd[15:8];
  end
 end
 function[7:0]byte_at;input[20:0]a;reg[15:0]w;
 begin w=a[20]?graphics[a[16:1]]:memory[a[15:1]];byte_at=a[0]?w[15:8]:w[7:0];end endfunction
 function[7:0]palette;input integer x,y;begin palette=y>=192?0:(y/12)*16+x/20;end endfunction
 initial begin
  $readmemh("build/gfx-app-sram.mem",memory);
  while(byte_at(21'h0381)!==1)@(posedge clk);
  if(!dut.gfx_enabled||dut.gfx.front_page!=0||jobs!=261)$fatal(1,"real PGM setup jobs=%d",jobs);
  for(integer y=0;y<200;y++)for(integer x=0;x<320;x++)begin
   if(byte_at(21'h100000+y*320+x)!==palette(x,y))$fatal(1,"PGM palette x=%d y=%d",x,y);
   if(x>=80&&x<240&&y>=52&&y<148)begin
    if(byte_at(21'h110000+y*320+x)!==palette(x-80,y-52))$fatal(1,"PGM rectangular copy");
   end else if(x>=64&&x<256&&y>=40&&y<160)begin
    if(byte_at(21'h110000+y*320+x)!==255)$fatal(1,"PGM white border");
   end else if(byte_at(21'h110000+y*320+x)!==palette(x,y))$fatal(1,"PGM full-frame copy");
   checks++;
  end
  while(byte_at(21'h0380)!==8'ha5)@(posedge clk);
  if(dut.gfx_enabled||dut.gfx.busy||dut.gfx.underrun||flips!=3||byte_at(21'h0381)!=3)
   $fatal(1,"PGM exit/flip failed flips=%d status=%b/%b",flips,dut.gfx_enabled,dut.gfx.busy);
  $display("PASS actual MC6800 GFX.PGM 601A=%0d %0dMHz: %0d jobs, %0d independently checked pixels, 3 VBL flips, SPACE/ESC SWI ABI",MODEL_A,1<<SPEED,jobs,checks);$finish;
 end
 always @(posedge clk)if(dut.bus_write&&cpu_addr==16'he651)begin jobs++;
  if(cpu_out==3)flips++;
  if(jobs<5||jobs%64==0)$display("GFX PGM job %0d opcode %0d at %0t",jobs,cpu_out,$time);
 end
 always @(negedge cpu_clk)if(dut.locked&&cpu_hold)$fatal(1,"GFX PGM stalled CPU");
 initial begin #2000000000;$fatal(1,"GFX PGM timeout PC=%h jobs=%d",cpu_addr,jobs);end
endmodule
