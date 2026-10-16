`timescale 1ns/1ps
// Independent raster oracle plus a pointer-free video/PAL instance. Every
// non-sprite DAC sample must remain identical, including HAM history/burst.
module tb_video_pointer;
 reg clk=0;always #5 clk=~clk;
 reg fast=0;always #1.25 fast=~fast;
 reg reset=1,model_a=0,extended=0,wr=0,reg_address=0,pw=0,pa=0,pal_wr=0;
 reg[7:0]mode=8'h20,reg_data=0,pdata=0,pal_data=0;
 reg[3:0]pal_reg=0;
 wire request,base_request;reg done=0,base_done=0;
 wire[5:0]tv,base_tv;wire[20:0]mem_address;
 classic_video #(.GFX(1),.POINTER(1)) dut(
  .clk(clk),.reset(reset),.bus_read(1'b0),.bus_write(wr),.bus_address(reg_address),.bus_data(reg_data),.mode(mode),
  .font_write(1'b0),.font_address(11'd0),.font_data(8'd0),.mem_request(request),.mem_address(mem_address),.mem_ready(1'b1),.mem_done(done),.mem_data(8'd0),
  .tvout(tv),.model_a(model_a),.gfx_enable(extended),.gfx_pixel(8'hff),.fast(fast),.gfx_rgb(18'h12345),
  .palette_write(pal_wr),.palette_register(pal_reg),.palette_data(pal_data),
  .pointer_write(pw),.pointer_address(pa),.pointer_data(pdata));
 classic_video #(.GFX(1)) base(
  .clk(clk),.reset(reset),.bus_read(1'b0),.bus_write(wr),.bus_address(reg_address),.bus_data(reg_data),.mode(mode),
  .font_write(1'b0),.font_address(11'd0),.font_data(8'd0),.mem_request(base_request),.mem_ready(1'b1),.mem_done(base_done),.mem_data(8'd0),
  .tvout(base_tv),.model_a(model_a),.gfx_enable(extended),.gfx_pixel(8'hff),.fast(fast),.gfx_rgb(18'h12345),
  .palette_write(pal_wr),.palette_register(pal_reg),.palette_data(pal_data));
 wire[9:0]rx;wire[8:0]ry;wire valid,first;
 pal_viewport_reference reference(.clk(clk),.reset(reset),.model_a(model_a),.extended(1'b0),.colour(1'b1),.rows(8'd25),.x(rx),.y(ry),.valid(valid),.first(first));
 task vreg;input[7:0]a,b;begin
  @(negedge clk);reg_address=0;reg_data=a;wr=1;
  @(negedge clk);reg_address=1;reg_data=b;
  @(negedge clk);wr=0;
 end endtask
 task pointer;input a;input[7:0]b;begin
  @(negedge clk);pa=a;pdata=b;pw=1;@(negedge clk);pw=0;
 end endtask
 integer kind,i,px,py,code,checks=0,overlay_checks=0;reg[5:0]want;reg checking=0;
 always @(posedge clk)begin
  done<=request;base_done<=base_request;
  #1;if(checking)begin
   px=model_a?rx:rx*2;py=ry;code=0;
   if((mode[5]||extended)&&valid&&px>=193&&px<209&&py>=87&&py<103)code=((px-193)+(py-87))%4;
   want=code==1?15:code==2?49:code==3?32:base_tv;
   if(tv!==want)$fatal(1,"pointer DAC kind%0d x%0d y%0d code%0d got%0d expected%0d baseline%0d",kind,px,py,code,tv,want,base_tv);
   checks++;if(code)overlay_checks++;
  end
 end
 initial begin
  for(kind=0;kind<6;kind=kind+1)begin
   checking=0;reset=1;repeat(5)@(negedge clk);reset=0;
   model_a=kind==1||kind==4||kind==5;extended=kind>=2&&kind!=4;mode=kind==4?8'h01:8'h20;
   vreg(6,25);vreg(10,32);
   if(kind==3)begin @(negedge clk);pal_wr=1;pal_reg=0;pal_data=7;@(negedge clk);pal_wr=0;end
   pointer(0,64);
   for(i=0;i<64;i=i+1)pointer(1,
    (((i/4+i%4*4)%4)<<6)|(((i/4+i%4*4+1)%4)<<4)|(((i/4+i%4*4+2)%4)<<2)|((i/4+i%4*4+3)%4));
   pointer(0,0);pointer(1,193);pointer(1,0);pointer(1,87);pointer(1,0);pointer(0,128);
   checking=1;repeat(300000)@(negedge clk);
  end
  if(overlay_checks<100)$fatal(1,"no sprite overlay coverage");
  $display("PASS video sprite: %0d independent DAC samples, %0d overlays, 601/601A native graphics/indexed/HAM, uploaded shape, text suppression, all other pixels/burst/sync unchanged",checks,overlay_checks);$finish;
 end
endmodule
