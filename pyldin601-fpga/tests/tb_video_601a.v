`timescale 1ns/1ps
module tb_video_601a;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,wr=0,address=0;reg[7:0]data=0,mode=0;
 wire request;wire[20:0]ma;wire[5:0]tv;
 reg done=0;reg[7:0]memory_data;
 classic_video dut(clk,reset,1'b0,wr,address,data,,mode,
  1'b0,11'b0,8'b0,request,ma,1'b1,done,memory_data,tv,,1'b1,1'b0,8'b0,,,,,);
 reg[7:0]ram[0:65535],reference[0:138239],configuration[0:16];
 reg[3:0]expected;integer checked=0,test_case=0,row,x,height,total=0;
 integer completed=0,fetch_start=0,last_row=-1;reg blink_pass=0;
 always @(posedge clk)begin
  done<=request;if(request)begin
   if(ma>=65536)$fatal(1,"601A video escaped base RAM");
   memory_data<=ram[ma];
  end
  if(!reset&&(dut.divide==1||dut.divide==2))begin
   row=(dut.half_line/2)-(dut.half_line>=625?312:0)-50;
   x=2*(integer'(dut.horizontal)-100)+(dut.divide==2);
   if(row>=0&&row<height&&x>=0&&x<640)begin
    expected=reference[row*640+x];
    if(blink_pass)expected=ram[16'hf000+(row/8)*80+(x/16)*2]&15;
    #1;
    if(dut.held_colour!==expected)$fatal(1,"601A mode case=%d row=%d x=%d colour=%h expected=%h character=%h font=%h",test_case,row,x,dut.held_colour,expected,dut.font_character,dut.font_pixels);
    checked++;total++;
   end
  end
 end
 task put;input a;input[7:0]d;
  begin @(negedge clk);address=a;data=d;wr=1;@(negedge clk);wr=0;end
 endtask
 initial begin
  for(integer n=0;n<12;n++)begin
   @(negedge clk);reset=1;checked=0;blink_pass=0;test_case=n;height=n<6?200:216;
   $readmemh($sformatf("build/601a-%0d-ram.mem",n),ram);
   $readmemh($sformatf("build/601a-%0d-pixels.mem",n),reference,0,height*640-1);
   $readmemh($sformatf("build/601a-%0d-config.mem",n),configuration);
   mode=configuration[0];repeat(3)@(negedge clk);reset=0;
   for(integer j=0;j<16;j++)begin put(0,j);put(1,configuration[j+1]);end
   wait(checked==height*640*2); // both PAL fields, every logical pixel
   if(n==9)begin
    // Let 32 actual PAL ticks turn attribute blinking off; no forced counter.
    wait(dut.blink==32);@(negedge clk);checked=0;blink_pass=1;
    wait(checked==height*640*2);
   end
  end
  $display("PASS %0d 601A pixels in both PAL fields: 640/320/160 graphics, all palettes, 80/40 mono text, all colour attributes, real 50Hz blink, native 80/40-column cursors and underscores",total);$finish;
 end
 initial begin #350000000;$fatal(1,"601A video timeout case=%d pixels=%d",test_case,checked);end
endmodule
