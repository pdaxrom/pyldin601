/* Verilog netlist generated by SCUBA Diamond (64-bit) 3.9.0.99.2 */
/* Module Version: 2.8 */
/* /opt/diamond/3.9_x64/ispfpga/bin/lin64/scuba -w -n mcu_rom -lang verilog -synth lse -bus_exp 7 -bb -arch xo2c00 -type rom -addr_width 8 -num_rows 1024 -data_width 8 -outdata REGISTERED -cascade -1 -resetmode SYNC -sync_reset -memfile ROM/rom.mem -memformat orca  */
/* Sun Jun  4 11:35:35 2017 */


`timescale 1 ns / 1 ps
module mcu_rom (Address, OutClock, OutClockEn, Reset, Q)/* synthesis NGD_DRC_MASK=1 */;
    input wire [9:0] Address;
    input wire OutClock;
    input wire OutClockEn;
    input wire Reset;
    output wire [7:0] Q;

    wire qdataout7_ffin;
    wire mdL0_0_3;
    wire mdL0_0_2;
    wire mdL0_0_1;
    wire mdL0_0_0;
    wire qdataout6_ffin;
    wire mdL0_1_3;
    wire mdL0_1_2;
    wire mdL0_1_1;
    wire mdL0_1_0;
    wire qdataout5_ffin;
    wire mdL0_2_3;
    wire mdL0_2_2;
    wire mdL0_2_1;
    wire mdL0_2_0;
    wire qdataout4_ffin;
    wire mdL0_3_3;
    wire mdL0_3_2;
    wire mdL0_3_1;
    wire mdL0_3_0;
    wire qdataout3_ffin;
    wire mdL0_4_3;
    wire mdL0_4_2;
    wire mdL0_4_1;
    wire mdL0_4_0;
    wire qdataout2_ffin;
    wire mdL0_5_3;
    wire mdL0_5_2;
    wire mdL0_5_1;
    wire mdL0_5_0;
    wire qdataout1_ffin;
    wire mdL0_6_3;
    wire mdL0_6_2;
    wire mdL0_6_1;
    wire mdL0_6_0;
    wire qdataout0_ffin;
    wire mdL0_7_3;
    wire mdL0_7_2;
    wire mdL0_7_1;
    wire mdL0_7_0;

    FD1P3DX FF_7 (.D(qdataout7_ffin), .SP(OutClockEn), .CK(OutClock), .CD(Reset), 
        .Q(Q[7]))
             /* synthesis GSR="ENABLED" */;

    FD1P3DX FF_6 (.D(qdataout6_ffin), .SP(OutClockEn), .CK(OutClock), .CD(Reset), 
        .Q(Q[6]))
             /* synthesis GSR="ENABLED" */;

    FD1P3DX FF_5 (.D(qdataout5_ffin), .SP(OutClockEn), .CK(OutClock), .CD(Reset), 
        .Q(Q[5]))
             /* synthesis GSR="ENABLED" */;

    FD1P3DX FF_4 (.D(qdataout4_ffin), .SP(OutClockEn), .CK(OutClock), .CD(Reset), 
        .Q(Q[4]))
             /* synthesis GSR="ENABLED" */;

    FD1P3DX FF_3 (.D(qdataout3_ffin), .SP(OutClockEn), .CK(OutClock), .CD(Reset), 
        .Q(Q[3]))
             /* synthesis GSR="ENABLED" */;

    FD1P3DX FF_2 (.D(qdataout2_ffin), .SP(OutClockEn), .CK(OutClock), .CD(Reset), 
        .Q(Q[2]))
             /* synthesis GSR="ENABLED" */;

    FD1P3DX FF_1 (.D(qdataout1_ffin), .SP(OutClockEn), .CK(OutClock), .CD(Reset), 
        .Q(Q[1]))
             /* synthesis GSR="ENABLED" */;

    FD1P3DX FF_0 (.D(qdataout0_ffin), .SP(OutClockEn), .CK(OutClock), .CD(Reset), 
        .Q(Q[0]))
             /* synthesis GSR="ENABLED" */;

    defparam mem_0_7.initval = 256'hE9DD436D1500902610F3CF3C348D6565B2B2888AF38F5F737FC7EFBFBEFB6DB2 ;
    ROM256X1A mem_0_7 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_0_0));

    defparam mem_0_6.initval = 256'h41B8000800F000244052C50839354022A01111113386BAB33589F71BFEFB36DB ;
    ROM256X1A mem_0_6 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_1_0));

    defparam mem_0_5.initval = 256'h08103E50680E07F49FF9FF9FE227C918E35C62246527B7713DD54B9FAFBE7FFF ;
    ROM256X1A mem_0_5 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_2_0));

    defparam mem_0_4.initval = 256'h0330FED0280E4FE00F307304F2116020B0040505610531182D49F296ABAE3EDF ;
    ROM256X1A mem_0_4 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_3_0));

    defparam mem_0_3.initval = 256'h6559737D2608918E46951910DFAC34EE19B60457B380FCDB442AB422BBCBBFDF ;
    ROM256X1A mem_0_3 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_4_0));

    defparam mem_0_2.initval = 256'hA9794DA603F1FE23DC6AE6AE17ADA5C7D2B3F276F3EB7BB35ED6AD8DB6FFB7DF ;
    ROM256X1A mem_0_2 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_5_0));

    defparam mem_0_1.initval = 256'hC9894CC3C6076E649968E68E102181A3C204B76418B3ABFB58D8B5EF975D9A6D ;
    ROM256X1A mem_0_1 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_6_0));

    defparam mem_0_0.initval = 256'h2050697F720BD503C33B31F29C8D0CEE83A33FAFA96C75912D142A92A3AA8100 ;
    ROM256X1A mem_0_0 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_7_0));

    defparam mem_1_7.initval = 256'hFFFFFFF00000000000000000000000001CE70000000000BB18CEC6EEEEEEEEEE ;
    ROM256X1A mem_1_7 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_0_1));

    defparam mem_1_6.initval = 256'hFFFFFFF0FEEFF0FEEFF0001FFE7C9FDE3DEF06309247771739C0000000000040 ;
    ROM256X1A mem_1_6 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_1_1));

    defparam mem_1_5.initval = 256'hFFFFFFF1FF1FE1FF1FE1FFFDDFFFFDE03DEF19CF6D8000FA52A1314C94C94D0D ;
    ROM256X1A mem_1_5 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_2_1));

    defparam mem_1_4.initval = 256'hFFFFFFF0002160002141EF264B54064A14A506108000363E10BDB00000444000 ;
    ROM256X1A mem_1_4 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_3_1));

    defparam mem_1_3.initval = 256'hFFFFFFF7248A27248A36167A11615A33B5A978C7A4B7413B3DEADA2266266226 ;
    ROM256X1A mem_1_3 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_4_1));

    defparam mem_1_2.initval = 256'hFFFFFFF5E68AD5E68AE51878810018B52D6F58C724A3209B38CE52BFEFAAAAAA ;
    ROM256X1A mem_1_2 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_5_1));

    defparam mem_1_1.initval = 256'hFFFFFFF3142303142323282C0A548C3ABD6B2220025132A1886D24DCCCDCDCCC ;
    ROM256X1A mem_1_1 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_6_1));

    defparam mem_1_0.initval = 256'hFFFFFFF44AC4944AC4959F190E1D993510045AE734E6750A90A2CA2322322232 ;
    ROM256X1A mem_1_0 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_7_1));

    defparam mem_2_7.initval = 256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF ;
    ROM256X1A mem_2_7 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_0_2));

    defparam mem_2_6.initval = 256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF ;
    ROM256X1A mem_2_6 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_1_2));

    defparam mem_2_5.initval = 256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF ;
    ROM256X1A mem_2_5 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_2_2));

    defparam mem_2_4.initval = 256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF ;
    ROM256X1A mem_2_4 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_3_2));

    defparam mem_2_3.initval = 256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF ;
    ROM256X1A mem_2_3 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_4_2));

    defparam mem_2_2.initval = 256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF ;
    ROM256X1A mem_2_2 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_5_2));

    defparam mem_2_1.initval = 256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF ;
    ROM256X1A mem_2_1 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_6_2));

    defparam mem_2_0.initval = 256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF ;
    ROM256X1A mem_2_0 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_7_2));

    defparam mem_3_7.initval = 256'h55FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF ;
    ROM256X1A mem_3_7 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_0_3));

    defparam mem_3_6.initval = 256'h7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF ;
    ROM256X1A mem_3_6 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_1_3));

    defparam mem_3_5.initval = 256'h7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF ;
    ROM256X1A mem_3_5 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_2_3));

    defparam mem_3_4.initval = 256'h7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF ;
    ROM256X1A mem_3_4 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_3_3));

    defparam mem_3_3.initval = 256'hF5FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF ;
    ROM256X1A mem_3_3 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_4_3));

    defparam mem_3_2.initval = 256'hDDFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF ;
    ROM256X1A mem_3_2 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_5_3));

    defparam mem_3_1.initval = 256'hA0FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF ;
    ROM256X1A mem_3_1 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_6_3));

    defparam mem_3_0.initval = 256'h9DFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF ;
    ROM256X1A mem_3_0 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_7_3));

    MUX41 mux_7 (.D0(mdL0_0_0), .D1(mdL0_0_1), .D2(mdL0_0_2), .D3(mdL0_0_3), 
        .SD1(Address[8]), .SD2(Address[9]), .Z(qdataout7_ffin));

    MUX41 mux_6 (.D0(mdL0_1_0), .D1(mdL0_1_1), .D2(mdL0_1_2), .D3(mdL0_1_3), 
        .SD1(Address[8]), .SD2(Address[9]), .Z(qdataout6_ffin));

    MUX41 mux_5 (.D0(mdL0_2_0), .D1(mdL0_2_1), .D2(mdL0_2_2), .D3(mdL0_2_3), 
        .SD1(Address[8]), .SD2(Address[9]), .Z(qdataout5_ffin));

    MUX41 mux_4 (.D0(mdL0_3_0), .D1(mdL0_3_1), .D2(mdL0_3_2), .D3(mdL0_3_3), 
        .SD1(Address[8]), .SD2(Address[9]), .Z(qdataout4_ffin));

    MUX41 mux_3 (.D0(mdL0_4_0), .D1(mdL0_4_1), .D2(mdL0_4_2), .D3(mdL0_4_3), 
        .SD1(Address[8]), .SD2(Address[9]), .Z(qdataout3_ffin));

    MUX41 mux_2 (.D0(mdL0_5_0), .D1(mdL0_5_1), .D2(mdL0_5_2), .D3(mdL0_5_3), 
        .SD1(Address[8]), .SD2(Address[9]), .Z(qdataout2_ffin));

    MUX41 mux_1 (.D0(mdL0_6_0), .D1(mdL0_6_1), .D2(mdL0_6_2), .D3(mdL0_6_3), 
        .SD1(Address[8]), .SD2(Address[9]), .Z(qdataout1_ffin));

    MUX41 mux_0 (.D0(mdL0_7_0), .D1(mdL0_7_1), .D2(mdL0_7_2), .D3(mdL0_7_3), 
        .SD1(Address[8]), .SD2(Address[9]), .Z(qdataout0_ffin));



    // exemplar begin
    // exemplar attribute FF_7 GSR ENABLED
    // exemplar attribute FF_6 GSR ENABLED
    // exemplar attribute FF_5 GSR ENABLED
    // exemplar attribute FF_4 GSR ENABLED
    // exemplar attribute FF_3 GSR ENABLED
    // exemplar attribute FF_2 GSR ENABLED
    // exemplar attribute FF_1 GSR ENABLED
    // exemplar attribute FF_0 GSR ENABLED
    // exemplar end

endmodule
