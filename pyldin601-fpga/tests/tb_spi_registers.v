`timescale 1ns/1ps
module tb_spi_registers;
reg clk=0;always #5 clk=~clk;
reg reset=1,enabled=1,write=0;reg[2:0]address=0;reg[7:0]data=0;
wire[7:0]result,tx,divider,rx;wire busy,cs,start,bb,done,sck,mosi;
boot_spi_registers dut(clk,reset,enabled,write,address,data,result,busy,cs,bb,done,rx,start,tx,divider);
spi_byte_master engine(clk,reset,start,tx,divider,mosi,sck,mosi,bb,done,rx);
task put;input[2:0]a;input[7:0]d;
begin @(negedge clk);address=a;data=d;write=1;@(negedge clk);write=0;end endtask
initial begin
 #22;reset=0;address=2;#1;if(result!=8'ha3||!cs)$fatal(1,"HD reset ABI");
 put(3,0);put(2,8'h21);if(cs)$fatal(1,"CS active low bit1");
 put(1,8'ha6);wait(!busy);address=1;#1;if(result!=8'ha6)$fatal(1,"8-bit transfer");
 put(2,8'h31);put(0,8'h5a);put(1,8'hc3);wait(!busy);
 address=0;#1;if(result!=8'h5a)$fatal(1,"16 high");
 address=1;#1;if(result!=8'hc3)$fatal(1,"16 low got=%x start=%b busy=%b word=%b",result,start,busy,dut.word_pending);
 put(2,8'h23);if(!cs)$fatal(1,"release CS");
 enabled=0;address=2;#1;if(result[7])$fatal(1,"READY while unavailable");
 $display("PASS new Pyldin SPI ABI: reset, CS, READY and 8/16-bit transfers");$finish;
end
initial begin #1000000;$fatal(1,"SPI timeout");end
endmodule
