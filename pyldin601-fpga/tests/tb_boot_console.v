`timescale 1ns/1ps
// Render actual bootstrap screen dumps through two complete systems.
// ROM choice differs; the PAL output below the model-specific title must agree.
module boot_console_fixture #(parameter MODEL_A=0)(
 input clk,fast,output[5:0]tv,output configured,output locked,
 output[8:0]y,output active,output native_a
);
 reg rw=1,vma=0;reg[15:0]address=0;reg[7:0]data=0;
 wire reset;wire[19:0]sa;wire[15:0]sd;wire ce,oe,we,lb,ub;
 reg finished=0;
 classic_system dut(.clk(clk),.clk_fast(fast),.pll_locked(1'b1),.btn_resetn(1'b1),
  .cpu_rw(rw),.cpu_vma(vma),.cpu_addr(address),.cpu_out(data),.cpu_reset(reset),
  .rxd(1'b1),.ps2clk(1'b1),.ps2dat(1'b1),.miso(1'b1),
  .SRAM_ADDR(sa),.SRAM_DATA(sd),.SRAM_CE(ce),.SRAM_OE(oe),.SRAM_WE(we),.SRAM_LB(lb),.SRAM_UB(ub),
  .tvout(tv),.hg_tms(1'b0),.hg_tck(1'b0),.hg_tdi(1'b0));
 assign configured=finished;assign locked=dut.locked;
 assign y=dut.video.pixel_y;assign active=dut.video.active;
 assign native_a=dut.video_model_a;
 reg[15:0]memory[0:8191];integer k;
 wire[19:0]pin_address;wire pin_ce,pin_oe,pin_we;
 assign #10 pin_address=sa;assign #10 pin_ce=ce;assign #10 pin_oe=oe;assign #6 pin_we=we;
 assign #18 sd=!pin_ce&&!pin_oe&&pin_we?memory[pin_address]:16'bz;
 initial begin
  for(k=0;k<8192;k=k+1)memory[k]=0;
  if(MODEL_A)$readmemh("build/boot-console-a.mem",memory,512,991);
  else $readmemh("build/boot-console-601.mem",memory,512,991);
 end
 task put;input[15:0]a;input[7:0]d;
  begin
   @(negedge clk);while(dut.phase!=1)@(negedge clk);
   address=a;data=d;rw=0;vma=1;
   @(negedge clk);vma=0;rw=1;
   while(dut.phase!=0)@(negedge clk);
  end
 endtask
 task commit;
  reg[7:0]b;integer n;
  begin
   for(n=0;n<64;n=n+1)begin
    b=0;
    case(n)
     0:b="P";1:b="6";2:b="0";3:b="1";
     4:b="B";5:b="O";6:b="O";7:b="T";
     8:b=2;14,18:b=1;17:b=8'h18;25:b=MODEL_A;
    endcase
    put(16'he6a3,b);
   end
   put(16'he6a0,8'ha5);
  end
 endtask
 initial begin
  wait(!reset);
  put(16'he6a0,MODEL_A);put(16'he629,1);
  put(16'he600,1);put(16'he601,40);
  put(16'he600,6);put(16'he601,24);
  put(16'he600,10);put(16'he601,8'h20);
  put(16'he600,12);put(16'he601,4);
  put(16'he600,13);put(16'he601,0);
  if(dut.model_a!==MODEL_A||native_a!==0)$fatal(1,"bootstrap changed selected ROM or console model");
  finished=1;
 end
endmodule

module tb_boot_console;
 reg clk=0,fast=0;always #20.833 clk=~clk;always #5.208 fast=~fast;
 wire[5:0]tv0,tv1;wire done0,done1,lock0,lock1,a0,a1,active0,active1;
 wire[8:0]y0,y1;
 boot_console_fixture #(.MODEL_A(0)) classic(clk,fast,tv0,done0,lock0,y0,active0,a0);
 boot_console_fixture #(.MODEL_A(1)) model_a(clk,fast,tv1,done1,lock1,y1,active1,a1);
 integer checked=0,lit=0;
 initial begin
  wait(done0&&done1);
  // Let both scanline banks fill, then compare both interlaced fields.
  wait(classic.dut.video.tick50);@(negedge clk);
  repeat(960000)begin
   @(negedge clk);
   if(active0&&y0>=8)begin
    if(!active1||y0!==y1||tv0!==tv1)$fatal(1,"model changed boot pixels: y=%d DAC=%d/%d",y0,tv0,tv1);
    checked=checked+1;if(tv0!=15)lit=lit+1;
   end
  end
  if(checked<400000||lit<1000)$fatal(1,"missing real text coverage %d/%d",checked,lit);
  fork classic.commit();model_a.commit();join
  if(!lock0||!lock1||a0!==0||a1!==1)$fatal(1,"selected native video model not restored at handoff");
  $display("PASS complete systems: identical 40x24 boot PAL pixels (%0d, %0d lit); 601A restored at native handoff",checked,lit);$finish;
 end
 initial begin #70000000;$fatal(1,"boot console timeout");end
endmodule
