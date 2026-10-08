`timescale 1ns/1ps
// Exhaustive legal CHS geometry and adversarial streamed header validation.
module tb_boot_header;
 reg clk=0;always #5 clk=~clk;
 reg cold=1,wr=0;reg[3:0]address=0;reg[7:0]data=0;
 wire locked,error;wire[8:0]ac,bc;
 classic_boot_ports dut(.clk(clk),.cold_reset(cold),.warm_reset(1'b0),.bus_read(1'b0),
  .bus_write(wr),.address(address),.bus_data(data),.mem_ready(1'b1),.mem_done(1'b0),
  .mem_read_data(8'b0),.spi_idle(1'b1),.locked(locked),.error(error),.a_cylinders(ac),.b_cylinders(bc));
 reg[7:0]header[0:95];integer cases=0,capacity;
 task put;input[3:0]a;input[7:0]d;
 begin @(negedge clk);address=a;data=d;wr=1;@(negedge clk);wr=0;end endtask
 task u32;input integer offset;input[31:0]value;
 begin for(integer j=0;j<4;j++)header[offset+j]=value>>(j*8);end endtask
 task base;
 begin
  for(integer j=0;j<96;j++)header[j]=0;
  {header[0],header[1],header[2],header[3],header[4],header[5],header[6],header[7]}="P601BOOT";
  header[8]=1;header[14]=1;header[17]=8'h18;header[18]=5;
  u32(32,34816);u32(36,2880);header[40]=18;header[42]=2;header[44]=80;
  u32(48,38912);u32(52,2880);header[56]=18;header[58]=2;header[60]=80;
  header[68]=1;u32(72,34816);u32(76,2880);
  header[84]=1;u32(88,38912);u32(92,2880);
 end endtask
 task check;input expected;
 begin
  cold=1;repeat(2)@(negedge clk);cold=0;
  put(0,header[25]);
  for(integer j=0;j<96;j++)put(3,header[j]);
  put(0,8'ha5);#1;
  if(locked!==expected||error===expected)$fatal(1,"streamed header case %0d expected %b lock/error=%b/%b",cases,expected,locked,error);
  cases++;
 end endtask
 initial begin
  for(integer s=1;s<=18;s++)for(integer h=1;h<=2;h++)for(integer c=1;c<=80;c++)begin
   base;capacity=s*h*c;
   header[40]=s;header[42]=h;header[44]=c;
   // Different B CHS verifies that the shared serial multiplier is banked.
   header[56]=19-s;header[58]=3-h;header[60]=81-c;
   u32(36,capacity);u32(52,(19-s)*(3-h)*(81-c));
   header[25]=c&1;header[24]=h&1;check(1);
   if(dut.a_capacity!=capacity||dut.b_capacity!=(19-s)*(3-h)*(81-c)||ac!=c||bc!=81-c)
    $fatal(1,"serial geometry capacity or narrowing");
   u32(36,capacity+1);check(0);
  end
  for(integer j=0;j<96;j++)begin
   if(j<=19||j==41||j==43||j==45||j==57||j==59||j==61||j==68||j==84)begin
    base;header[j]=header[j]^8'h80;check(0);
   end
  end
  for(integer disk=0;disk<2;disk++)begin
   base;header[40+16*disk]=0;check(0);
   base;header[40+16*disk]=19;check(0);
   base;header[42+16*disk]=0;check(0);
   base;header[42+16*disk]=3;check(0);
   base;header[44+16*disk]=0;check(0);
   base;header[44+16*disk]=81;check(0);
   base;u32(36+16*disk,0);check(0);
   base;u32(36+16*disk,2881);check(0);
   base;u32(36+16*disk,32'h10000000);check(0);
   base;u32(76+16*disk,2879);check(0);
   base;u32(72+16*disk,30000);check(0);
  end
  base;header[20]=1;check(0); // empty stream CRC is zero
  base;header[24]=2;check(0);
  base;header[25]=2;check(0);
  base;u32(32,0);u32(72,0);check(0);
  base;u32(76,5000);check(0); // A overlaps B
  base;u32(48,32'hfffffff0);u32(88,32'hfffffff0);check(0); // B overflow
  base;check(1);
  $display("PASS %0d streamed boot headers: exhaustive CHS capacities, model, fixed bytes, CRC, MBR bounds and overflow",cases);$finish;
 end
endmodule
