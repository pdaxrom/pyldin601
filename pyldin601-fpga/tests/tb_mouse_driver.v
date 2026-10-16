`timescale 1ps/1ps
// Real CPU, production system/MMIO, actual software driver and independent mouse.
module mouse_driver_fixture #(parameter SPEED=0,MODEL_A=0,HD=0,FAILURE=0)(
 input cpu_rw,cpu_vma,input[15:0]cpu_addr,input[7:0]cpu_out,
 output cpu_clk,cpu_reset,cpu_hold,cpu_irq,output[7:0]cpu_in,output hd6303_en);
 reg clk=0;always #21000 clk=~clk;
 wire fast;test_fast_clock_physical fast_clock(fast);
 wire[19:0]sa,pa;wire[15:0]sd,pd;wire ce,oe,we,ub,lb,pc,po,pw,pu,pl;
 wire mouse_clk,mouse_data;
 wire host_clock_low,host_data_low;reg device_clock_low=0,device_data_low=0;
 assign mouse_clk=host_clock_low||device_clock_low?1'b0:1'b1;
 assign mouse_data=host_data_low||device_data_low?1'b0:1'b1;
 classic_system #(.BOOT_FILE("build/mouse-driver/boot.mem")) dut(
  .clk(clk),.clk_fast(fast),.pll_locked(1'b1),.btn_resetn(1'b1),.cpu_rw(cpu_rw),.cpu_vma(cpu_vma),
  .cpu_addr(cpu_addr),.cpu_out(cpu_out),.cpu_clk(cpu_clk),.cpu_reset(cpu_reset),.cpu_hold(cpu_hold),.cpu_irq(cpu_irq),.cpu_in(cpu_in),.hd6303_en(hd6303_en),
  .ps2clk(1'b1),.ps2dat(1'b1),.mouseclk(mouse_clk),.mousedat(mouse_data),.mouse_clock_low(host_clock_low),.mouse_data_low(host_data_low),
  .rxd(1'b1),.miso(1'b1),.hg_tms(1'b0),.hg_tck(1'b0),.hg_tdi(1'b0),
  .SRAM_ADDR(sa),.SRAM_DATA(sd),.SRAM_CE(ce),.SRAM_OE(oe),.SRAM_WE(we),.SRAM_UB(ub),.SRAM_LB(lb));
 reg[15:0]ram[0:32767];
 assign #10000 pa=sa;assign #10000 pc=ce,po=oe,pu=ub,pl=lb;
 assign #6000 pw=we;assign #14500 pd=sd;
 assign #18000 sd=!pc&&!po&&pw ? (pa<20'h08000 ? ram[pa[14:0]]:16'hffff):16'bz;
 always @(posedge pw)if(!pc)begin
  if(pa>=20'h08000)$fatal(1,"mouse driver escaped ordinary RAM %h",pa);
  if(!pl)ram[pa][7:0]=pd[7:0];if(!pu)ram[pa][15:8]=pd[15:8];
 end
 always @(negedge cpu_clk)if(dut.locked&&cpu_hold)$fatal(1,"mouse driver held CPU");
 task accept;input[7:0]expected;input nack;integer i;reg[8:0]bits;time started;begin
  wait(host_clock_low);started=$time;
  wait(!host_clock_low);
  if($time-started<100000000||mouse_data!==0)$fatal(1,"software inhibit/setup timing");
  #100000000;bits={(~^expected),expected};
  for(i=0;i<10;i=i+1)begin
   device_clock_low=1;#30000000;
   if(mouse_data!==(i==9?1'b1:bits[i]))$fatal(1,"software command %h bit%0d data%b at%h speed%0d",expected,i,mouse_data,cpu_addr,SPEED);
   device_clock_low=0;#30000000;
  end
  device_data_low=!nack;#6000000;device_clock_low=1;#30000000;
  device_clock_low=0;#6000000;device_data_low=0;#60000000;
 end endtask
 task send;input[7:0]b;reg[10:0]frame;integer i;begin
  frame={1'b1,(~^b),b,1'b0};
  for(i=0;i<11;i=i+1)begin
   device_data_low=!frame[i];#10000000;device_clock_low=1;#30000000;
   device_clock_low=0;#20000000;
  end
  device_data_low=0;#60000000;
 end endtask
 wire[7:0]initialized=ram['h380][7:0],event_count=ram['h380][15:8],marker=ram['h387][15:8];
 wire[15:0]result_x={ram['h382][7:0],ram['h382][15:8]},result_y={ram['h383][7:0],ram['h383][15:8]};
 wire[7:0]buttons_got=ram['h384][7:0],pressed_got=ram['h384][15:8],released_got=ram['h385][7:0];
 task packet;input[7:0]header,dx,dy;input integer n,x,y,buttons,pressed,released;
 begin
  send(header);send(dx);send(dy);while(event_count!==n)#1000000;#2000000;
  if(result_x!==x||result_y!==y||
    buttons_got!==buttons||pressed_got!==pressed||released_got!==released)
   $fatal(1,"software packet%0d got x%0d y%0d buttons%0d/%0d/%0d",n,result_x,result_y,buttons_got,pressed_got,released_got);
 end endtask
 initial begin
  $readmemh("build/mouse-driver/ram.mem",ram);
  if(FAILURE!=0)begin
   wait(marker!==8'd0&&^marker!==1'bx);
   if(marker!=1||host_clock_low||host_data_low||dut.video.cursor.sprite.enabled)
    $fatal(1,"absent/NACK mouse did not fail cleanly marker%h",marker);
   $display("PASS actual HDL CPU software PS/2 mouse failure=%0d HD=%0d %0dMHz: bounded timeout/NACK, pins/receiver/pointer released",FAILURE,HD,1<<SPEED);$finish;
  end
  wait(initialized===8'd1);
  packet(8'h09,8'hff,5,1,575,95,1,1,0);
  packet(8'h28,8'hff,1,2,639,199,0,0,1);
  packet(8'h18,0,8'hff,3,383,0,0,0,0);
  packet(8'hf8,0,0,4,128,199,0,0,0);
  // Closing the driver begins as soon as the last event has been consumed.
  packet(8'h0a,8'hff,0,5,383,199,2,2,0);
  wait(marker!==8'd0&&^marker!==1'bx);
  if(marker!=8'ha5||host_clock_low||host_data_low||dut.video.cursor.sprite.enabled)
   $fatal(1,"software mouse cleanup marker%h",marker);
  $display("PASS actual HDL CPU software PS/2 mouse 601A=%0d HD=%0d %0dMHz: F6/F4/F5 bit-bang, shortest clocks, ACK, signed9/overflow/clamps/buttons, uploaded sprite, cleanup/no HOLD",MODEL_A,HD,1<<SPEED);$finish;
 end
 initial begin
  #1000000;wait(cpu_reset===1'b0);
  if(FAILURE!=1)begin
   accept(8'hf6,FAILURE==2);
   if(FAILURE==0)begin send(8'hfa);accept(8'hf4,0);send(8'hfa);accept(8'hf5,0);send(8'hfa);end
  end
 end
 initial begin #200000000000;$fatal(1,"software mouse timeout PC%h marker%h",cpu_addr,marker);end
endmodule
