`timescale 1ns/1ps
module tb_boot_header;
 reg clk=0;always #5 clk=~clk;
 reg cold=1,wr=0;reg[3:0]address=0;reg[7:0]data=0;
 wire locked,error;
 classic_boot_ports dut(.clk(clk),.cold_reset(cold),.warm_reset(1'b0),.bus_read(1'b0),
 .bus_write(wr),.address(address),.bus_data(data),.mem_ready(1'b1),.mem_done(1'b0),
 .mem_read_data(8'b0),.spi_idle(1'b1),.locked(locked),.error(error));
 reg[7:0]header[0:63];integer cases=0;
 task put;input[3:0]a;input[7:0]d;
 begin @(negedge clk);address=a;data=d;wr=1;@(negedge clk);wr=0;end endtask
 task base;
 begin
 for(integer j=0;j<64;j++)header[j]=0;
 {header[0],header[1],header[2],header[3],header[4],header[5],header[6],header[7]}="P601BOOT";
 header[8]=2;header[14]=1;header[17]=8'h18;header[18]=1;
 end endtask
 task check;input expected;
 begin
 cold=1;repeat(2)@(negedge clk);cold=0;put(0,header[25]);
 for(integer j=0;j<64;j++)put(3,header[j]);put(0,8'ha5);#1;
 if(locked!==expected||error===expected)$fatal(1,"compact header case %0d",cases);
 cases++;
 end endtask
 initial begin
 for(integer model=0;model<2;model++)begin
 base;header[25]=model;check(1);
 for(integer j=0;j<64;j++)begin
 base;header[25]=model;header[j]=header[j]^8'h80;check(0);
 end
 end
 base;check(1);put(14,7);if(dut.boot_partition!=0)$fatal(1,"partition changed after lock");
 cold=1;repeat(2)@(negedge clk);cold=0;put(14,37);if(!error)$fatal(1,"invalid partition accepted");
 $display("PASS %0d compact boot headers: every byte corrupted, model/CRC/size, partition bounds and lock",cases);$finish;
 end
endmodule
