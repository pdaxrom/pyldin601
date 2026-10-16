`timescale 1ns/1ps
module tb_uart;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,read=0,write=0,rxd=1;reg[1:0]address=0;reg[7:0]din=0;
 wire[7:0]dout;wire txd;
 // Keep the real 24-MHz integer divisors; simulation clock units are scaled.
 classic_uart dut(clk,reset,read,write,address,din,dout,rxd,txd);
 task wr;input[1:0]a;input[7:0]b;begin
  @(negedge clk);address=a;din=b;write=1;@(negedge clk);write=0;
 end endtask
 task check;input[1:0]a;input[7:0]b;begin
  address=a;#1;if(dout!==b)$fatal(1,"UART reg%0d=%h expected%h",a,dout,b);
 end endtask
 task pop;input[7:0]b;begin
  @(negedge clk);check(3,b);read=1;@(negedge clk);read=0;
 end endtask
 task bit_rx;input value;input integer ticks;begin
  rxd=value;repeat(ticks)@(negedge clk);
 end endtask
 task receive_byte;input[7:0]value;input integer format,ticks;input bad_parity,bad_stop;
  integer i,bits;reg parity;begin
   bits=format<4?7:8;parity=format&1;
   bit_rx(0,ticks);
   for(i=0;i<bits;i=i+1)begin bit_rx(value[i],ticks);parity=parity^value[i];end
   if(format<4||format>=6)bit_rx(parity^bad_parity,ticks);
   bit_rx(!bad_stop,ticks);
   if(format==0||format==1||format==4)bit_rx(!bad_stop,ticks);
   rxd=1;
  end
 endtask
 task transmit_byte;input[7:0]value;input integer format,ticks;
  integer i,bits;reg parity;begin
   bits=format<4?7:8;parity=format&1;
   wait(txd===0);repeat(ticks/2)@(negedge clk);
   if(txd!==0)$fatal(1,"TX start");
   for(i=0;i<bits;i=i+1)begin
    repeat(ticks)@(negedge clk);
    if(txd!==value[i])$fatal(1,"TX format%0d bit%0d",format,i);
    parity=parity^value[i];
   end
   if(format<4||format>=6)begin
    repeat(ticks)@(negedge clk);if(txd!==parity)$fatal(1,"TX parity format%0d",format);
   end
   repeat(ticks)@(negedge clk);if(txd!==1)$fatal(1,"TX stop1");
   if(format==0||format==1||format==4)begin
    repeat(ticks)@(negedge clk);if(txd!==1)$fatal(1,"TX stop2");
   end
  end
 endtask
 integer format,rate,ticks,i;reg[7:0]value;
 initial begin
  repeat(3)@(negedge clk);reset=0;check(0,8'h55);check(2,2);check(1,7);
  for(rate=0;rate<=10;rate=rate+1)begin
   wr(1,rate);
   case(rate)
    0:ticks=24000000/150;1:ticks=24000000/300;2:ticks=24000000/600;
    3:ticks=24000000/1200;4:ticks=24000000/2400;5:ticks=24000000/4800;
    6:ticks=24000000/9600;7:ticks=24000000/19200;8:ticks=24000000/38400;
    9:ticks=24000000/57600;10:ticks=24000000/115200;
   endcase
   for(format=0;format<8;format=format+1)begin
    wr(2,(format<<2)|1);value=8'ha5^format;
    fork
     begin wr(3,value);end
     transmit_byte(value,format,ticks);
     receive_byte(value,format,ticks,0,0);
    join
    repeat(ticks)@(negedge clk);
    check(2,3);pop(format<4?value&127:value);check(2,2);
   end
  end
  wr(2,8'h15);wr(1,10);ticks=24000000/115200;
  // A false start shorter than half a bit must not enqueue anything.
  bit_rx(0,ticks/4);bit_rx(1,ticks);check(2,2);
  // Back-to-back bytes, no idle gap; then FIFO overflow keeps the oldest 16.
  for(i=0;i<17;i=i+1)receive_byte(i,5,ticks,0,0);
  repeat(ticks)@(negedge clk);check(2,8'h23);
  for(i=0;i<16;i=i+1)pop(i);check(2,2);pop(8'hff);
  wr(2,8'h19);receive_byte(8'h3c,6,ticks,1,0);
  repeat(ticks)@(negedge clk);check(2,8'h43);pop(8'h3c);
  receive_byte(8'h81,6,ticks,0,1);repeat(ticks)@(negedge clk);
  check(2,8'h13);pop(8'h81);check(2,2);
  // Held break is one framing-error byte, never an unbounded stream.
  wr(2,8'h15);bit_rx(0,ticks*40);check(2,8'h13);pop(0);check(2,2);
  bit_rx(1,ticks*2);receive_byte(8'hff,5,ticks,0,0);
  repeat(ticks)@(negedge clk);pop(8'hff);
  // Holding register capacity and reset abort during active transmission.
  wr(3,8'h55);repeat(3)@(negedge clk);wr(3,8'haa);check(2,0);
  wr(3,8'h99);if(dut.holding!==8'haa)$fatal(1,"full holding overwrite");
  wr(2,3);check(2,2);if(txd!==1)$fatal(1,"reset TX idle");
  wr(2,8'h75);if(txd!==0)$fatal(1,"TX break");wr(2,8'h15);
  $display("PASS UART: 11 baud rates, 8 formats, independent full duplex, back-to-back/FIFO/overflow, parity/framing/break, TX holding/reset");
  $finish;
 end
 initial begin #3000000000;$fatal(1,"UART timeout");end
endmodule
