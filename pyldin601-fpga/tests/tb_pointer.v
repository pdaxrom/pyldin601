`timescale 1ns/1ps
module tb_pointer;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,write=0,address=0,active=0;
 reg[7:0]din=0;wire[7:0]dout;reg[9:0]sx=0;reg[8:0]sy=0;wire[1:0]pixel;
 classic_pointer dut(clk,reset,write,address,din,dout,sx,sy,active,pixel);
 reg[7:0]expected[0:63];integer i,xx,yy,mode,checks=0;reg[1:0]want;
 task wr;input a;input[7:0]b;begin
  @(negedge clk);address=a;din=b;write=1;@(negedge clk);write=0;
 end endtask
 task locate;input integer x,y;input on;begin
  wr(0,0);wr(1,x&255);wr(1,(x>>8)&3);wr(1,y&255);wr(1,(y>>8)&1);
  wr(0,on?128:0);
 end endtask
 task sample;input integer x,y;input on;input[1:0]expected_pixel;begin
  @(negedge clk);sx=x;sy=y;active=on;@(posedge clk);#1;
  if(pixel!==expected_pixel)$fatal(1,"sprite at%0d,%0d got%0d expected%0d",x,y,pixel,expected_pixel);
  checks++;
 end endtask
 initial begin
  repeat(3)@(negedge clk);reset=0;sample(0,0,1,0);
  for(mode=0;mode<2;mode=mode+1)begin
   wr(0,64);
   for(i=0;i<64;i=i+1)begin expected[i]=mode?(i*137+51):(i*19+7);wr(1,expected[i]);end
   // CPU data reads do not advance the index (including a CLR/RMW read).
   for(i=0;i<64;i=i+1)begin
    wr(0,64+i);address=1;repeat(2)@(posedge clk);#1;
    if(dout!==expected[i])$fatal(1,"sprite CPU read %0d",i);
    repeat(2)@(posedge clk);#1;if(dout!==expected[i])$fatal(1,"sprite CPU read advanced index");
   end
   locate(300,90,1);
   for(yy=0;yy<232;yy=yy+1)for(xx=0;xx<640;xx=xx+1)begin
    want=0;if(xx>=300&&xx<316&&yy>=90&&yy<106)want=expected[(yy-90)*4+(xx-300)/4]>>(6-2*((xx-300)%4));
    sample(xx,yy,1,want);
   end
   sample(300,90,0,0);locate(300,90,0);sample(300,90,1,0);
  end
  // Signed coordinates clip a hotspot at the top/left without wrap artifacts.
  locate(-8,-8,1);
  for(yy=0;yy<20;yy=yy+1)for(xx=0;xx<20;xx=xx+1)begin
   want=0;if(xx<8&&yy<8)want=expected[(yy+8)*4+(xx+8)/4]>>(6-2*((xx+8)%4));
   sample(xx,yy,1,want);
  end
  locate(639,199,1);sample(639,199,1,expected[0]>>6);sample(0,199,1,0);
  @(negedge clk);reset=1;@(negedge clk);reset=0;sample(639,199,1,0);
  locate(0,0,1);sample(0,0,1,expected[0]>>6);
  $display("PASS loaded sprite: %0d independent pixel checks, two uploaded shapes, transparency/3 levels, 640x232 bounds, signed clipping, indexed reads/wrap, reset retention/disable",checks);$finish;
 end
endmodule
