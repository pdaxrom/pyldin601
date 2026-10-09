`timescale 1ns/1ps
// Independent command decoder, DDS counter and floating matrix coefficients.
// Includes variable pixel lengths, both V signs, line restart and native return.
module tb_pal_ham #(parameter FAST_OFFSET=0, parameter FULL=1);
 reg clk=0;always #20.832 clk=~clk;
 reg fast=0;initial begin #(FAST_OFFSET);forever #5.208 fast=~fast;end
 reg reset=1,wr=0,sync=0,burst=0,alternate=0,extended=0;
 reg[3:0]address=0;reg[7:0]data=0,code=0;
 wire[5:0]dac,result;wire read_mode;
 classic_pal_encoder #(.GFX(1)) dut(clk,reset,sync,burst,alternate,4'd0,dac,
  extended,code,wr,address,data,read_mode,result,fast);
 reg[5:0]components[0:6143],indexed[0:8191],legacy[0:1023];
 reg[31:0]phase=0;integer format=0,r=0,g=0,b=0,p,c,v,want,previous=0,previous2=0;
 integer checks=0,ham8_colours=0;reg checking=0;
 function integer round_signed;input real x;
 begin round_signed=x<0?$rtoi(x-0.5):$rtoi(x+0.5);end endfunction
 function integer contribution;input integer ch,level,ph;
 real a,y,u,vv;integer gain,rgb;
 begin
  case(ch)
   0:begin y=0.299;u=-0.493*0.299;vv=0.877*(1-0.299);end
   1:begin y=0.587;u=-0.493*0.587;vv=-0.877*0.587;end
   2:begin y=0.114;u=0.493*(1-0.114);vv=-0.877*0.114;end
  endcase
  a=(ph+0.5)*6.283185307179586/32;
  gain=round_signed(34.0*512.0/255.0*(y+u*$sin(a)+vv*$cos(a)));
  rgb=4*level+level/16;
  contribution=$floor((gain*rgb+256)/512.0);
 end endfunction
 always @(posedge clk)begin
  if(reset)begin phase=0;r=0;g=0;b=0;format=0;previous=0;previous2=0;end
  else begin
   p=phase[31:27];if(alternate)p=(15-p)&31;
   if(!extended)begin r=0;g=0;b=0;end
   else if(format!=0)begin
    c=code>>6;
    v=code&63;
    case(c)
     0:begin
      r=((code>>4)&3)*21;g=((code>>2)&3)*21;b=(code&3)*21;
     end
     1:b=v;2:r=v;3:g=v;
    endcase
   end
   want=sync?0:burst?legacy[512+p]:!extended?15:format==0?indexed[code*32+p]:
    15+contribution(0,r,p)+contribution(1,g,p)+contribution(2,b,p);
   if(wr&&address==0)format=(data>>1)&3;
   phase=phase+32'd793426981;
   #1;if(checking&&dac!==previous2)$fatal(1,"HAM mismatch offset=%f format=%d code=%h RGB=%d/%d/%d phase=%d DAC=%d expected=%d",FAST_OFFSET,format,code,r,g,b,p,dac,previous2);
   previous2=previous;previous=want;if(checking)checks++;
  end
 end
 task put;input[3:0]a;input[7:0]d;
 begin @(negedge clk);wr=1;address=a;data=d;@(negedge clk);wr=0;end endtask
 task pixel;input[7:0]d;input integer n;
 begin code=d;repeat(n)@(negedge clk);end endtask
 integer limit,step,scale;
 initial begin
  $readmemh("build/ham/components.mem",components);$readmemh("rtl/pal_rgb332.mem",indexed);$readmemh("rtl/pal_waveform.mem",legacy);
  repeat(4)@(negedge clk);reset=0;
  put(2,0);put(13,0);for(integer a=0;a<6144;a++)put(14,components[a]);
  put(2,0);put(13,0);put(15,1);
  for(integer a=0;a<6144;a++)begin repeat(2)@(negedge clk);if(result!==components[a])$fatal(1,"HAM table readback %d",a);put(15,3);end
  put(15,0);
  checking=1;
  for(integer f=0;f<1;f++)begin
   put(0,7);extended=1;
   limit=64;step=FULL?1:7;scale=64;
   for(integer sign=0;sign<2;sign++)begin
    alternate=sign;
    // All fixed base colours and all component values.
    for(integer base=0;base<scale;base++)pixel(base,3+(base%2));
    for(integer rr=0;rr<limit;rr=rr+step)begin
     pixel(2*scale+rr,4);
     for(integer gg=0;gg<limit;gg=gg+step)begin
      pixel(3*scale+gg,3);
      for(integer bb=0;bb<limit;bb=bb+step)begin
       pixel(scale+bb,3+(bb%2));
       ham8_colours++;
      end
     end
    end
    // Blanking resets history: the first pixel may modify black directly.
    extended=0;repeat(7)@(negedge clk);extended=1;pixel(scale+limit-1,4);
    burst=1;repeat(13)@(negedge clk);burst=0;sync=1;repeat(11)@(negedge clk);sync=0;
   end
   extended=0;repeat(5)@(negedge clk);
  end
  put(0,0);reset=1;repeat(4)@(negedge clk);reset=0;repeat(7)@(negedge clk);
  checking=0;put(2,0);put(13,0);for(integer a=0;a<8192;a++)put(14,indexed[a]);
  checking=1;extended=1;
  for(integer n=0;n<256;n++)pixel(n,4);
  extended=0;repeat(7)@(negedge clk);
  $display("PASS HAM8 offset=%f: %d colour states, %d independently decoded DAC samples, 6144 CPU writes/readbacks, both V signs, line reset, sync/burst and indexed restore",FAST_OFFSET,ham8_colours,checks);$finish;
 end
 initial begin #200000000;$fatal(1,"HAM test timeout");end
endmodule
