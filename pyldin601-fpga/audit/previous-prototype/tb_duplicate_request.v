`timescale 1ns/1ps
// Reproduces the current top-level CPU request/completion equations unchanged.
module tb_duplicate_request;
reg clk=0,reset=1,pending=0,complete=0;
always #5 clk=~clk;
wire ready,done;
wire request=pending&&!complete;
integer accepts=0;
sram_byte_controller dut(.clk(clk),.reset(reset),.request(request),.write(1'b0),
 .address(21'b0),.write_data(8'b0),.ready(ready),.done(done));
always @(posedge clk)if(!reset)begin
 if(request&&ready)accepts<=accepts+1;
 if(done&&pending&&!complete)complete<=1;
end
initial begin
 #22;reset=0;pending=1;
 repeat(15)@(negedge clk);
 if(accepts!=2)$fatal(1,"unexpected accepts %0d",accepts);
 $display("CONFIRMED: one CPU transaction accepted by SRAM twice (%0d)",accepts);
 $finish;
end
endmodule
