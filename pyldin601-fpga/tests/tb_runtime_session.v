`timescale 1ns/1ps
// Actual CPU + runtime SRAM slots + PS/2 + i8272 + SD SPI, restored DOS RAM.
// The card model serves the existing image, validates addresses, rejects writes.
module runtime_session_fixture(
 input cpu_rw,cpu_vma,input[15:0]cpu_addr,input[7:0]cpu_out,
 output cpu_clk,cpu_reset,cpu_hold,cpu_irq,output[7:0]cpu_in
);
 reg clk=0;always #21 clk=~clk;
 reg psclk=1,psdat=1;
 wire[19:0]sa;wire[15:0]sd;wire ce,oe,we,ub,lb,cs,sck,mosi;reg miso=1;
 classic_system #(.BOOT_FILE("build/session-boot.mem")) dut(
  .clk(clk),.pll_locked(1'b1),.btn_resetn(1'b1),.cpu_rw(cpu_rw),.cpu_vma(cpu_vma),
  .cpu_addr(cpu_addr),.cpu_out(cpu_out),.cpu_clk(cpu_clk),.cpu_reset(cpu_reset),
  .cpu_hold(cpu_hold),.cpu_irq(cpu_irq),.cpu_in(cpu_in),
  .ps2clk(psclk),.ps2dat(psdat),.rxd(1'b1),.miso(miso),
  .seg_led_h(),.seg_led_l(),.led_rgb(),.txd(),.mss(cs),.msck(sck),.mosi(mosi),.tvout(),.audio(),
  .SRAM_ADDR(sa),.SRAM_DATA(sd),.SRAM_CE(ce),.SRAM_OE(oe),.SRAM_WE(we),.SRAM_UB(ub),.SRAM_LB(lb));
 reg[15:0]memory[0:199679];reg[7:0]expected_screen[0:999];
 wire[19:0]pin_address;wire pin_ce,pin_oe,pin_we,pin_lb,pin_ub;wire[15:0]pin_data;
 assign #15 pin_address=sa;assign #15 pin_ce=ce;assign #15 pin_oe=oe;
 assign #3 pin_we=we;assign #15 pin_lb=lb;assign #15 pin_ub=ub;assign #15 pin_data=sd;
 assign #20 sd=!pin_ce&&!pin_oe&&pin_we?memory[pin_address]:16'bz;
 always @(posedge pin_we)if(!pin_ce)begin
  if(!pin_lb)memory[pin_address][7:0]=pin_data[7:0];
  if(!pin_ub)memory[pin_address][15:8]=pin_data[15:8];
 end
 function[7:0]ram;input[15:0]a;begin ram=a[0]?memory[a>>1][15:8]:memory[a>>1][7:0];end endfunction
 wire[15:0]screen_start=dut.video.start_addr;
 wire[15:0]cursor=dut.video.cursor_addr;
 function prompt;integer gap;reg[15:0]a;begin
  prompt=0;
  if(cpu_vma&&cpu_rw&&cpu_addr==16'hf39c)
   for(gap=4;gap<=8;gap=gap+1)begin
    a=cursor-gap;
    if(ram(a)=="A"&&ram(a+1)==":"&&ram(a+2)=="\\"&&ram(a+3)==">")prompt=1;
   end
 end endfunction
 localparam A_START=34816,A_SECTORS=2880;
 // Restored runtime only reads A. Avoid a 20 MiB initialisation/LLVM array;
 // retain the real card's absolute LBAs and the complete disk-A partition.
 reg[7:0]card[0:A_SECTORS*512-1],fifo[0:1023],command[0:5];
 reg[7:0]incoming=0,current=255;integer fifo_read=0,fifo_write=0,bits=0,cmd_count=0;
 integer reads=0;reg[31:0]argument;reg[15:0]read_crc;
 function[15:0]crc16;input[15:0]old;input[7:0]data;reg[15:0]c;integer k;
  begin c=old^{data,8'b0};for(k=0;k<8;k=k+1)c=c[15]?(c<<1)^16'h1021:c<<1;crc16=c;end
 endfunction
 task enqueue;input[7:0]b;begin fifo[fifo_write]=b;fifo_write=fifo_write+1;end endtask
 task receive_byte;input[7:0]b;integer j;reg[7:0]value;begin
  if(cmd_count!=0||b[7:6]==2'b01)begin
   command[cmd_count]=b;cmd_count=cmd_count+1;
   if(cmd_count==6)begin
    argument={command[1],command[2],command[3],command[4]};cmd_count=0;
    if(command[0][5:0]!=17)$fatal(1,"unexpected SD command %d; DIR must only read",command[0][5:0]);
    if(argument<A_START||argument>=A_START+A_SECTORS)$fatal(1,"SD address outside A %d",argument);
    reads=reads+1;$display("READ %d LBA %d CPU %h at %t",reads,argument,cpu_addr,$time);
    enqueue(0);enqueue(255);enqueue(8'hfe);read_crc=0;
    for(j=0;j<512;j=j+1)begin value=card[(argument-A_START)*512+j];enqueue(value);read_crc=crc16(read_crc,value);end
    enqueue(read_crc[15:8]);enqueue(read_crc[7:0]);
   end
  end
 end endtask
 always @(negedge cs)begin fifo_read=0;fifo_write=0;bits=0;cmd_count=0;incoming=0;current=255;miso=1;end
 always @(posedge cs)miso=1;
 always @(posedge sck)if(!cs)begin
  incoming={incoming[6:0],mosi};bits=bits+1;
  if(bits==8)begin bits=0;receive_byte(incoming);end
 end
 always @(negedge sck)if(!cs)begin
  if(bits==0)begin
   if(fifo_read<fifo_write)begin current=fifo[fifo_read];fifo_read=fifo_read+1;end else current=255;
  end
  miso=current[7-bits];
 end
 task scan;input[7:0]code;reg[10:0]frame;integer bitnum;begin
  frame={1'b1,~^code,code,1'b0};
  for(bitnum=0;bitnum<11;bitnum=bitnum+1)begin
   psdat=frame[bitnum];#15000;psclk=0;#15000;psclk=1;
  end
  psdat=1;#30000;
 end endtask
 // Match the native reference's 100 ms down/up intervals. Its BIOS debounces
 // keys; a shorter interval tested "D" four times rather than the DIR command.
 task key;input[7:0]code;begin scan(code);#100000000;scan(8'hf0);scan(code);#100000000;end endtask
 integer cmd,j,fileout,mismatches;reg[7:0]got;reg armed=0;integer previous_reads;
 always @(negedge cpu_clk)if(armed&&cpu_hold)$fatal(1,"CPU capture stalled PC=%h",cpu_addr);
 always @(posedge clk)if(armed&&cpu_reset)$fatal(1,"runtime reset PC=%h",cpu_addr);
 always @(posedge clk)if(dut.locked&&dut.bus_read&&cpu_addr==16'he628)
  $display("KEY data=%h ready=%b down=%b irq=%b page=%h at %t",dut.kbd_data,dut.keyboard.key_ready,dut.keyboard.active_down,cpu_irq,dut.page,$time);
 initial begin
  $readmemh("build/session-sram.mem",memory);$readmemh("build/session-screen.mem",expected_screen);
  $readmemh("build/session-disk-a.mem",card);
  wait(dut.locked===1'b1);while(!prompt())@(posedge cpu_clk);armed=1;
  for(cmd=0;cmd<4;cmd=cmd+1)begin
   previous_reads=reads;key(8'h23);key(8'h43);key(8'h2d);key(8'h5a);
   while(!prompt())@(posedge cpu_clk);
   if(reads==previous_reads)$fatal(1,"DIR %d did not read card",cmd+1);
   $display("DIR %d complete; reads %d at %t",cmd+1,reads,$time);
  end
  fileout=$fopen("build/monitor-debug/hdl-screen.bin","wb");mismatches=0;
  for(j=0;j<1000;j=j+1)begin
   got=ram(screen_start+(j/40)*42+j%40);
   $fwrite(fileout,"%c",got);
   if(got!==expected_screen[j])begin
    if(mismatches<8)$display("DOS screen mismatch offset %d got %h expected %h",j,got,expected_screen[j]);
    mismatches=mismatches+1;
   end
  end
  $fclose(fileout);
  fileout=$fopen("build/monitor-debug/hdl-ram.bin","wb");
  for(j=0;j<65536;j=j+1)begin got=ram(j);$fwrite(fileout,"%c",got);end
  $fclose(fileout);
  if(mismatches)$fatal(1,"%d DOS screen mismatches; start=%h cursor=%h",mismatches,screen_start,cursor);
  $display("PASS actual VHDL CPU/PS2/i8272/SD: four DIR return to prompt, listing matches native; %d reads",reads);$finish;
 end
 // Preserve a short run's actual screen/RAM rather than interpreting the
 // current bus address alone as a hang. This also distinguishes OS reload
 // and input waits from an unfinished SD request.
 initial begin
  #750000000;
  fileout=$fopen("build/monitor-debug/hdl-short-screen.bin","wb");
  for(j=0;j<1000;j=j+1)begin got=ram(screen_start+(j/40)*42+j%40);$fwrite(fileout,"%c",got);end
  $fclose(fileout);
  fileout=$fopen("build/monitor-debug/hdl-short-ram.bin","wb");
  for(j=0;j<65536;j=j+1)begin got=ram(j);$fwrite(fileout,"%c",got);end
  $fclose(fileout);
  $display("SESSION snapshot CPU=%h start=%h cursor=%h page=%h fdc=%d sd=%d reads=%d",cpu_addr,screen_start,cursor,dut.page,dut.fdc.state,dut.sd.state,reads);
 end
 initial begin #12000000000;$fatal(1,"session timeout CPU=%h fdc=%d sd=%d raw_owned=%b reads=%d",cpu_addr,dut.fdc.state,dut.sd.state,dut.raw_owned,reads);end
endmodule
