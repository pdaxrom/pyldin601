/* Verilog netlist generated by SCUBA Diamond (64-bit) 3.9.0.99.2 */
/* Module Version: 2.8 */
/* /opt/diamond/3.9_x64/ispfpga/bin/lin64/scuba -w -n mcu_rom -lang verilog -synth lse -bus_exp 7 -bb -arch xo2c00 -type rom -addr_width 8 -num_rows 256 -data_width 8 -outdata UNREGISTERED -memfile ROM/rom.mem -memformat orca  */
/* Sun Apr 23 14:01:17 2017 */


`timescale 1 ns / 1 ps
module mcu_rom (Address, Q)/* synthesis NGD_DRC_MASK=1 */;
    input wire [7:0] Address;
    output wire [7:0] Q;


    defparam mem_0_7.initval = 256'h55557FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC026DB5B6D9A ;
    ROM256X1A mem_0_7 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(Q[7]));

    defparam mem_0_6.initval = 256'h55557FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC02492524998 ;
    ROM256X1A mem_0_6 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(Q[6]));

    defparam mem_0_5.initval = 256'h7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6DB1B6DC8 ;
    ROM256X1A mem_0_5 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(Q[5]));

    defparam mem_0_4.initval = 256'h55557FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE249092480 ;
    ROM256X1A mem_0_4 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(Q[4]));

    defparam mem_0_3.initval = 256'h7FFD7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC10404129B ;
    ROM256X1A mem_0_3 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(Q[3]));

    defparam mem_0_2.initval = 256'h7D57FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC006DB5B6DDB ;
    ROM256X1A mem_0_2 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(Q[2]));

    defparam mem_0_1.initval = 256'h57D7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEEDB5FFFDB ;
    ROM256X1A mem_0_1 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(Q[1]));

    defparam mem_0_0.initval = 256'h77777FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC20C0830C9 ;
    ROM256X1A mem_0_0 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(Q[0]));



    // exemplar begin
    // exemplar end

endmodule
