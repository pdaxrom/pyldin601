`timescale 1ns/1ps
// Exercise every port-B address, wrap/masks, retention and port-A scanout.
// The phase reference is a separate clock counter; no DUT RAM/phase probes.
module tb_pal_palette;
 reg fast=0;always #1.25 fast=~fast;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,wr=0,sync=0,burst=0,alternate=0,extended=1;
 reg[3:0]address=0;reg[7:0]data=0,index=0;
 wire[5:0]dac,result;wire read_mode;
 classic_pal_encoder #(.GFX(1)) dut(clk,reset,sync,burst,alternate,4'd0,dac,
  extended,index,wr,address,data,read_mode,result,fast);
 reg[5:0]custom[0:8191],legacy[0:1023];
 reg[31:0]phase=0;reg[5:0]previous=0,previous2=0,want;integer p,checks=0;reg checking=0;
 always @(posedge clk)begin
  if(reset)begin phase=0;previous=0;previous2=0;end
  else begin
   p=phase[31:27];if(alternate)p=(15-p)&31;
   want=sync?0:burst?legacy[512+p]:extended?custom[index*32+p]:15;
   phase=phase+32'd793426981;
   #1;if(checking&&dac!==previous2)$fatal(1,"programmable DAC index=%h phase=%d got=%d expected=%d",index,p,dac,previous2);
   previous2=previous;previous=want;if(checking)checks++;
  end
 end
 task put;input[3:0]a;input[7:0]d;
 begin @(negedge clk);wr=1;address=a;data=d;@(negedge clk);wr=0;end endtask
 initial begin
  $readmemh("build/view-app-palette.mem",custom);$readmemh("rtl/pal_waveform.mem",legacy);
  repeat(3)@(negedge clk);reset=0;
  // Upper address bits and data bits are masked. Increment wraps at 8192.
  put(2,255);put(13,255);put(14,255);put(14,17);
  put(2,255);put(13,31);put(15,1);repeat(2)@(negedge clk);
  if(!read_mode||result!==63)$fatal(1,"palette masks/address 8191 failed");
  put(15,3);repeat(2)@(negedge clk);
  if(result!==17)$fatal(1,"palette read increment/wrap failed");
  put(2,0);put(13,0);
  for(integer a=0;a<8192;a++)put(14,custom[a]);
  for(integer a=0;a<8192;a++)begin
   repeat(2)@(negedge clk);
   if(result!==custom[a])$fatal(1,"palette port-B readback address=%d got=%d",a,result);
   put(15,3);
  end
  reset=1;repeat(3)@(negedge clk);reset=0;repeat(3)@(negedge clk);
  if(read_mode||result!==custom[0])$fatal(1,"reset port state/retention failed");
  checking=1;
  for(integer sign=0;sign<2;sign++)for(integer c=0;c<256;c++)begin
   index=c;alternate=sign;repeat(128)@(negedge clk);
  end
  extended=0;repeat(61)@(negedge clk);burst=1;repeat(131)@(negedge clk);
  sync=1;repeat(97)@(negedge clk);sync=0;burst=0;extended=1;repeat(93)@(negedge clk);
  $display("PASS programmable PAL: 8192 writes/readbacks, address/data masks/wrap, retained reset, %0d DAC samples, all 256 indices/both V signs, native black/burst/sync",checks);$finish;
 end
endmodule
