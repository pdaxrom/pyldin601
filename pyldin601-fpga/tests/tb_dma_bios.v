`timescale 1ps/1ps
// Actual VHDL CPU executes the real relocated PGM through production DMA/pads.
module dma_bios_fixture #(parameter SPEED=0,MODEL_A=0,HD=1)(
 input cpu_rw,cpu_vma,input[15:0]cpu_addr,input[7:0]cpu_out,cpu_cc,
 output cpu_clk,cpu_reset,cpu_hold,cpu_irq,output[7:0]cpu_in,output hd6303_en
);
 reg clk=0;always #21000 clk=~clk;
 wire fast;test_fast_clock_physical fast_clock(fast);
 wire[19:0]sa,pa;wire[15:0]sd,pd;wire ce,oe,we,ub,lb,pc,po,pw,pu,pl;
 classic_system #(.BOOT_FILE("build/dma-bios/boot.mem")) dut(
  .clk(clk),.clk_fast(fast),.pll_locked(1'b1),.btn_resetn(1'b1),.cpu_rw(cpu_rw),.cpu_vma(cpu_vma),
  .cpu_addr(cpu_addr),.cpu_out(cpu_out),.cpu_clk(cpu_clk),.cpu_reset(cpu_reset),.cpu_hold(cpu_hold),.cpu_irq(cpu_irq),.cpu_in(cpu_in),.hd6303_en(hd6303_en),
  .ps2clk(1'b1),.ps2dat(1'b1),.rxd(1'b1),.miso(1'b1),.hg_tms(1'b0),.hg_tck(1'b0),.hg_tdi(1'b0),
  .SRAM_ADDR(sa),.SRAM_DATA(sd),.SRAM_CE(ce),.SRAM_OE(oe),.SRAM_WE(we),.SRAM_UB(ub),.SRAM_LB(lb));

 reg[15:0]ram[0:32767],rom[0:35839],banks[0:8191];
 wire[15:0]read_word=pa<20'h08000 ? ram[pa[14:0]]:
   pa>=20'h08000&&pa<20'h10c00 ? rom[pa-20'h08000]:
   pa>=20'h11000&&pa<20'h12000 ? banks[{1'b0,pa[11:0]}]:
   pa>=20'h7f000&&pa<20'h80000 ? banks[{1'b1,pa[11:0]}]:16'hffff;
 assign #10000 pa=sa;assign #10000 pc=ce,po=oe,pu=ub,pl=lb;
 assign #6000 pw=we;assign #14500 pd=sd;
 assign #18000 sd=!pc&&!po&&pw?read_word:16'bz;
 task store_byte;input[19:0]a;input lane;input[7:0]b;
 begin
  if(a<20'h08000)begin if(lane)ram[a][15:8]=b;else ram[a][7:0]=b;end
  else if(a>=20'h11000&&a<20'h12000)begin if(lane)banks[{1'b0,a[11:0]}][15:8]=b;else banks[{1'b0,a[11:0]}][7:0]=b;end
  else if(a>=20'h7f000&&a<20'h80000)begin if(lane)banks[{1'b1,a[11:0]}][15:8]=b;else banks[{1'b1,a[11:0]}][7:0]=b;end
  else $fatal(1,"native DMA unexpected physical write %h",{a,lane});
 end endtask
 always @(posedge pw)if(!pc)begin
  if(!pl)begin if(^pd[7:0]===1'bx)$fatal(1,"invalid native DMA SRAM byte");store_byte(pa,0,pd[7:0]);end
  if(!pu)begin if(^pd[15:8]===1'bx)$fatal(1,"invalid native DMA SRAM byte");store_byte(pa,1,pd[15:8]);end
 end
 integer direct_jobs=0,native_jobs=0,irq_count=0,masked_waits=0;
 reg[15:0]wait_address[0:0];
 always @(negedge cpu_clk)if(cpu_vma&&cpu_addr==wait_address[0]&&ram[16'h0386][7:0]==1)begin
  if(!cpu_cc[4])$fatal(1,"INT E8 ignored caller SEI during DMA wait");
  masked_waits++;
 end
 always @(posedge clk)if(dut.bus_write&&cpu_addr==16'he6e1)begin
  if(cpu_addr==16'he6e1&&dut.cpu_out==2&&cpu_vma)native_jobs++;
  direct_jobs++;
 end
 always @(negedge cpu_clk)if(dut.locked&&cpu_hold)$fatal(1,"native DMA held CPU");
 initial begin
  $readmemh("build/dma-bios/wait.mem",wait_address);
  $readmemh("build/dma-bios/ram.mem",ram);$readmemh("build/dma-bios/rom.mem",rom);
  for(integer k=0;k<8192;k++)banks[k]=16'h5aa5;
  wait(ram[16'h0387][15:8]!=0);
  if(ram[16'h0387][15:8]!=8'ha5)$fatal(1,"native BIOS DMA failed PC=%h marker=%h",cpu_addr,ram[16'h0387]);
  begin
   for(integer k=0;k<4096;k++)if(banks[4096+k]!==16'h1515)$fatal(1,"native BIOS PAL bank %d",k);
   if(ram[16'h3080][7:0]!=8'h76||ram[16'h0386][15:8]!=0)$fatal(1,"reentrant IRQ transfer");
   if(native_jobs<7||dut.palette_read_mode)$fatal(1,"native BIOS failed to use/restore DMA/PAL");
  end
  if(masked_waits==0)$fatal(1,"caller SEI DMA wait was not exercised");
  if(!ram[16'h0387][7:0]||dut.gfx.busy||dut.gfx.dma_busy)$fatal(1,"DMA IRQ/completion");
  $display("PASS actual HDL CPU/BIOS/shared DMA 601A=%0d HD=%0d %0dMHz: flat bank DMA, INT E8 ABI, overlap/PAL, reentrant IRQ, SRAM-10, no HOLD (%0d jobs/%0d IRQ)",MODEL_A,HD,1<<SPEED,direct_jobs,ram[16'h0387][7:0]);$finish;
 end
 initial begin #200000000000;$fatal(1,"native DMA timeout address=%h marker=%h state=%d",cpu_addr,ram[16'h0387],dut.gfx.dma.state);end
endmodule
