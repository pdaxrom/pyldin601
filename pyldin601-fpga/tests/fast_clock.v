`timescale 1ps/1ps
// NVC 1.23 mis-scales real-valued and parameterised delay expressions.
// Literal integer picoseconds give exact 4:1 clocks; test-mixed-clock checks
// both generators independently before the mixed VHDL/Verilog regressions.
module test_fast_clock(output reg clk=0);
 always #1250 clk=~clk;
endmodule
module test_fast_clock_physical(output reg clk=0);
 always #5250 clk=~clk;
endmodule
