/* Verilog netlist generated by SCUBA Diamond (64-bit) 3.9.0.99.2 */
/* Module Version: 2.8 */
/* /opt/diamond/3.9_x64/ispfpga/bin/lin64/scuba -w -n vrom -lang verilog -synth lse -bus_exp 7 -bb -arch xo2c00 -type rom -addr_width 8 -num_rows 2048 -data_width 8 -outdata UNREGISTERED -cascade -1 -resetmode SYNC -sync_reset -memfile ROM/vrom.mem -memformat orca  */
/* Mon Jun 19 06:17:40 2017 */


`timescale 1 ns / 1 ps
module vrom (Address, Q)/* synthesis NGD_DRC_MASK=1 */;
    input wire [10:0] Address;
    output wire [7:0] Q;

    wire mdL0_0_7;
    wire mdL0_0_6;
    wire mdL0_0_5;
    wire mdL0_0_4;
    wire mdL0_0_3;
    wire mdL0_0_2;
    wire mdL0_0_1;
    wire mdL0_0_0;
    wire mdL0_1_7;
    wire mdL0_1_6;
    wire mdL0_1_5;
    wire mdL0_1_4;
    wire mdL0_1_3;
    wire mdL0_1_2;
    wire mdL0_1_1;
    wire mdL0_1_0;
    wire mdL0_2_7;
    wire mdL0_2_6;
    wire mdL0_2_5;
    wire mdL0_2_4;
    wire mdL0_2_3;
    wire mdL0_2_2;
    wire mdL0_2_1;
    wire mdL0_2_0;
    wire mdL0_3_7;
    wire mdL0_3_6;
    wire mdL0_3_5;
    wire mdL0_3_4;
    wire mdL0_3_3;
    wire mdL0_3_2;
    wire mdL0_3_1;
    wire mdL0_3_0;
    wire mdL0_4_7;
    wire mdL0_4_6;
    wire mdL0_4_5;
    wire mdL0_4_4;
    wire mdL0_4_3;
    wire mdL0_4_2;
    wire mdL0_4_1;
    wire mdL0_4_0;
    wire mdL0_5_7;
    wire mdL0_5_6;
    wire mdL0_5_5;
    wire mdL0_5_4;
    wire mdL0_5_3;
    wire mdL0_5_2;
    wire mdL0_5_1;
    wire mdL0_5_0;
    wire mdL0_6_7;
    wire mdL0_6_6;
    wire mdL0_6_5;
    wire mdL0_6_4;
    wire mdL0_6_3;
    wire mdL0_6_2;
    wire mdL0_6_1;
    wire mdL0_6_0;
    wire mdL0_7_7;
    wire mdL0_7_6;
    wire mdL0_7_5;
    wire mdL0_7_4;
    wire mdL0_7_3;
    wire mdL0_7_2;
    wire mdL0_7_1;
    wire mdL0_7_0;

    defparam mem_0_7.initval = 256'h0000000000000000000000FF000000FF00000000000000000000000000000000 ;
    ROM256X1A mem_0_7 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_0_0));

    defparam mem_0_6.initval = 256'h000800C000000000003000C3003C00FF0000611800380008000E007E007E0000 ;
    ROM256X1A mem_0_6 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_1_0));

    defparam mem_0_5.initval = 256'h7F2A3EC07F607F0640487F997F667FE74118123C7F38C01C7F1F7FFF7F817C00 ;
    ROM256X1A mem_0_5 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_2_0));

    defparam mem_0_4.initval = 256'h011C417F086002293E4808BD104210C3493C0CBE49967F3E013F49EB49951200 ;
    ROM256X1A mem_0_4 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_3_0));

    defparam mem_0_3.initval = 256'h01774105083F0C79013914BD094208C3493C7FFF49FF417F017E49CF49B11100 ;
    ROM256X1A mem_0_3 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_4_0));

    defparam mem_0_2.initval = 256'h011C41650805022901052299046604E749180CBE4196413E013F49EB49951200 ;
    ROM256X1A mem_0_2 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_5_0));

    defparam mem_0_1.initval = 256'h7F2A3E657F057F067F0341C37F3C7FFF3600123C41387F1C011F36FF31817C00 ;
    ROM256X1A mem_0_1 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_6_0));

    defparam mem_0_0.initval = 256'h0008003F00070000000F00FF000000FF000061180038C008000E007E007E0000 ;
    ROM256X1A mem_0_0 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_7_0));

    defparam mem_1_7.initval = 256'h00000000000000000000000800000000000000F0000000000000000000000000 ;
    ROM256X1A mem_1_7 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_0_1));

    defparam mem_1_6.initval = 256'h001000080008001E0008000800000000008000F000001C060000000000000000 ;
    ROM256X1A mem_1_6 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_1_1));

    defparam mem_1_5.initval = 256'h46307F0C221C7F107F1C01087F207F0407947FF0631A2209470001143E087F00 ;
    ROM256X1A mem_1_5 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_2_1));

    defparam mem_1_4.initval = 256'h2970080E493E4810483E7F084060400608B640F014A52201484F0136411C097F ;
    ROM256X1A mem_1_4 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_3_1));

    defparam mem_1_3.initval = 256'h19F03E0F490848104808483E7FFF7FFF08FF40F008A57F7F48007F7F413E093E ;
    ROM256X1A mem_1_3 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_4_1));

    defparam mem_1_2.initval = 256'h0970410E493E48103008481C4060400608B67FF014A52201484F0136417F091C ;
    ROM256X1A mem_1_2 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_5_1));

    defparam mem_1_1.initval = 256'h7F30410C3E1C3010000848087F207F047F94C0F0635822013F00011422000608 ;
    ROM256X1A mem_1_1 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_6_1));

    defparam mem_1_0.initval = 256'h00103E08000800107F083000C0000000008000F000001C7F0000000000000000 ;
    ROM256X1A mem_1_0 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_7_1));

    defparam mem_2_7.initval = 256'h0000000000000000000000000000000000000000000000000000000000000000 ;
    ROM256X1A mem_2_7 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_0_2));

    defparam mem_2_6.initval = 256'h0000000000000000000000000000000000000000000000000000000000000000 ;
    ROM256X1A mem_2_6 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_1_2));

    defparam mem_2_5.initval = 256'h7C4038007C087C0040087C247C007C00440044363846C0247C147C003E002000 ;
    ROM256X1A mem_2_5 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_2_2));

    defparam mem_2_4.initval = 256'h0420440010080880780810182041201C440028495426642A047F540345005400 ;
    ROM256X1A mem_2_4 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_3_2));

    defparam mem_2_3.initval = 256'h0410444010081060043E187E1222102254037C4954105C7F04145400455F5400 ;
    ROM256X1A mem_2_3 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_4_2));

    defparam mem_2_2.initval = 256'h040844001008080004082418081C0841540028565408442A047F540345005400 ;
    ROM256X1A mem_2_2 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_5_2));

    defparam mem_2_1.initval = 256'h7C0438007C087C007C0844247C007C002800442058647C120014280039007800 ;
    ROM256X1A mem_2_1 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_6_2));

    defparam mem_2_0.initval = 256'h00020000000000000000000000000000000000500062C0000000000000004000 ;
    ROM256X1A mem_2_0 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_7_2));

    defparam mem_3_7.initval = 256'h0000000000000000000000000000000000000000000000000000000000000000 ;
    ROM256X1A mem_3_7 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_0_3));

    defparam mem_3_6.initval = 256'h0000000000000000000000000000000000000000000000000000000000000000 ;
    ROM256X1A mem_3_6 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_1_3));

    defparam mem_3_5.initval = 256'h48027C0028147C007C0004007C467C360C017C3C442738189C2104623800FC3E ;
    ROM256X1A mem_3_5 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_2_3));

    defparam mem_3_4.initval = 256'h540110414414500850407C00404940491071404A28454414A041045144422451 ;
    ROM256X1A mem_3_4 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_3_3));

    defparam mem_3_3.initval = 256'h3451382254145014503450147C497C49100940491045FE12A0497C49447F2449 ;
    ROM256X1A mem_3_3 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_4_3));

    defparam mem_3_2.initval = 256'h1409441454145022200050004029404910057C492845447FA04D044944402445 ;
    ROM256X1A mem_3_2 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_5_3));

    defparam mem_3_1.initval = 256'h7C06440838142041000050007C1E7C367C03C031443938107C3304464400183E ;
    ROM256X1A mem_3_1 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_6_3));

    defparam mem_3_0.initval = 256'h00003800000000007C002000C000000000000000000000000000000000000000 ;
    ROM256X1A mem_3_0 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_7_3));

    defparam mem_4_7.initval = 256'h0800140014000000140014000000000000001400080008000000080008000000 ;
    ROM256X1A mem_4_7 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_0_4));

    defparam mem_4_6.initval = 256'h0800140014000000140014000000000000001400080008000000080008000000 ;
    ROM256X1A mem_4_6 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_1_4));

    defparam mem_4_5.initval = 256'h083E147F147F007F147F14200000007F003E147F087F087F003E087F087C003E ;
    ROM256X1A mem_4_5 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_2_4));

    defparam mem_4_4.initval = 256'h0841F7041402FF40F4081740FC411F08FF41F709084908410041084908120041 ;
    ROM256X1A mem_4_4 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_3_4));

    defparam mem_4_3.initval = 256'hF8410008140C004004141040047F100800410009FF490841FF41F8490F110F5D ;
    ROM256X1A mem_4_3 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_4_4));

    defparam mem_4_2.initval = 256'h0041F7101402F740F4221740F4411708FF49FF09084908410841084908120859 ;
    ROM256X1A mem_4_2 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_5_4));

    defparam mem_4_1.initval = 256'h003E147F147F14401441143F1400147F007900010841083E08220836087C084E ;
    ROM256X1A mem_4_1 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_6_4));

    defparam mem_4_0.initval = 256'h0000140014001400140014001400140000000000080008000800080008000800 ;
    ROM256X1A mem_4_0 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_7_4));

    defparam mem_5_7.initval = 256'h0F800000FF00F000FF0000000800140014003C007F0008000000FF00AA000000 ;
    ROM256X1A mem_5_7 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_0_5));

    defparam mem_5_6.initval = 256'h0F800000FF00F000FF0000000800140014004200040008000000AA005500AA00 ;
    ROM256X1A mem_5_6 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_1_5));

    defparam mem_5_5.initval = 256'h0F800010FF41F002FF7F006108031463147F991F083F08010026FF7FAA3E007F ;
    ROM256X1A mem_5_5 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_2_5));

    defparam mem_5_4.initval = 256'h0F800008FF41F004FF7F005108041714F420A520104008010049550955415509 ;
    ROM256X1A mem_5_4 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_3_5));

    defparam mem_5_3.initval = 256'h0F80FF040041F008FF41F8490F7810080418A5407F40FF7FFF49FF19AA510009 ;
    ROM256X1A mem_5_3 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_4_5));

    defparam mem_5_2.initval = 256'h0F80FF08007FF010FF41084500041F14FC208120024000010049AA295521AA09 ;
    ROM256X1A mem_5_2 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_5_5));

    defparam mem_5_1.initval = 256'h0F80FF10007FF020FF41084300030063007F421F153F00010032FF46AA5E0006 ;
    ROM256X1A mem_5_1 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_6_5));

    defparam mem_5_0.initval = 256'h0F80FF000000F000FF0008000000000000003C00120000000000550055005500 ;
    ROM256X1A mem_5_0 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_7_5));

    defparam mem_6_7.initval = 256'h0000000000000000000000000000000000000000000000000000000000000000 ;
    ROM256X1A mem_6_7 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_0_6));

    defparam mem_6_6.initval = 256'h000000005C003000000000000000810000008000000041000800000000003000 ;
    ROM256X1A mem_6_6 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_1_6));

    defparam mem_6_5.initval = 256'h7E381C7C227C4800767F5C001C00997F01187E083838633804387F7FFE204800 ;
    ROM256X1A mem_6_5 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_2_6));

    defparam mem_6_4.initval = 256'h01442A0451044841891062402244A504F2A4087E445455447C44014401544801 ;
    ROM256X1A mem_6_4 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_3_6));

    defparam mem_6_3.initval = 256'h014449044978307F92100280497DE704FCA41009445449440444014449543002 ;
    ROM256X1A mem_6_3 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_4_6));

    defparam mem_6_2.initval = 256'h0144490445044840642862844940A50402A408013C5441440444014436545C04 ;
    ROM256X1A mem_6_2 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_5_6));

    defparam mem_6_1.initval = 256'h7E384978227C480000445C7D2200997802781E020458637F3C44033800784200 ;
    ROM256X1A mem_6_1 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_6_6));

    defparam mem_6_0.initval = 256'h000000001D003000000000001C00810004002000040000004400000000000000 ;
    ROM256X1A mem_6_0 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_7_6));

    defparam mem_7_7.initval = 256'hFF00000000000000000000000000000000000000000000000000000000000000 ;
    ROM256X1A mem_7_7 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_0_7));

    defparam mem_7_6.initval = 256'h81C0000012001F00100000000000000048000800400000004400510000002A00 ;
    ROM256X1A mem_7_6 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_1_7));

    defparam mem_7_5.initval = 256'h81B03C021941010020080044001C0244247C081C803C00044448517C44182AFC ;
    ROM256X1A mem_7_5 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_2_7));

    defparam mem_7_4.initval = 256'h818C3C0115410100403E086418A0052824406B208040003F4A544A0844242A24 ;
    ROM256X1A mem_7_4 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_3_7));

    defparam mem_7_3.initval = 256'h81833C0312771E77FF77085418A0051048306B407F40FE444A544A045F242A24 ;
    ROM256X1A mem_7_3 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_4_7));

    defparam mem_7_2.initval = 256'h818C3C02003E00000141004C00A0022848400820002001405154440444242A24 ;
    ROM256X1A mem_7_2 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_5_7));

    defparam mem_7_1.initval = 256'h81B000010008000001410044007C0044247C081C007C01205124440444FC2A18 ;
    ROM256X1A mem_7_1 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_6_7));

    defparam mem_7_0.initval = 256'hFFC0000000000000010000000000000000000000000002000000000000000000 ;
    ROM256X1A mem_7_0 (.AD7(Address[7]), .AD6(Address[6]), .AD5(Address[5]), 
        .AD4(Address[4]), .AD3(Address[3]), .AD2(Address[2]), .AD1(Address[1]), 
        .AD0(Address[0]), .DO0(mdL0_7_7));

    MUX81 mux_7 (.D0(mdL0_0_0), .D1(mdL0_0_1), .D2(mdL0_0_2), .D3(mdL0_0_3), 
        .D4(mdL0_0_4), .D5(mdL0_0_5), .D6(mdL0_0_6), .D7(mdL0_0_7), .SD1(Address[8]), 
        .SD2(Address[9]), .SD3(Address[10]), .Z(Q[7]));

    MUX81 mux_6 (.D0(mdL0_1_0), .D1(mdL0_1_1), .D2(mdL0_1_2), .D3(mdL0_1_3), 
        .D4(mdL0_1_4), .D5(mdL0_1_5), .D6(mdL0_1_6), .D7(mdL0_1_7), .SD1(Address[8]), 
        .SD2(Address[9]), .SD3(Address[10]), .Z(Q[6]));

    MUX81 mux_5 (.D0(mdL0_2_0), .D1(mdL0_2_1), .D2(mdL0_2_2), .D3(mdL0_2_3), 
        .D4(mdL0_2_4), .D5(mdL0_2_5), .D6(mdL0_2_6), .D7(mdL0_2_7), .SD1(Address[8]), 
        .SD2(Address[9]), .SD3(Address[10]), .Z(Q[5]));

    MUX81 mux_4 (.D0(mdL0_3_0), .D1(mdL0_3_1), .D2(mdL0_3_2), .D3(mdL0_3_3), 
        .D4(mdL0_3_4), .D5(mdL0_3_5), .D6(mdL0_3_6), .D7(mdL0_3_7), .SD1(Address[8]), 
        .SD2(Address[9]), .SD3(Address[10]), .Z(Q[4]));

    MUX81 mux_3 (.D0(mdL0_4_0), .D1(mdL0_4_1), .D2(mdL0_4_2), .D3(mdL0_4_3), 
        .D4(mdL0_4_4), .D5(mdL0_4_5), .D6(mdL0_4_6), .D7(mdL0_4_7), .SD1(Address[8]), 
        .SD2(Address[9]), .SD3(Address[10]), .Z(Q[3]));

    MUX81 mux_2 (.D0(mdL0_5_0), .D1(mdL0_5_1), .D2(mdL0_5_2), .D3(mdL0_5_3), 
        .D4(mdL0_5_4), .D5(mdL0_5_5), .D6(mdL0_5_6), .D7(mdL0_5_7), .SD1(Address[8]), 
        .SD2(Address[9]), .SD3(Address[10]), .Z(Q[2]));

    MUX81 mux_1 (.D0(mdL0_6_0), .D1(mdL0_6_1), .D2(mdL0_6_2), .D3(mdL0_6_3), 
        .D4(mdL0_6_4), .D5(mdL0_6_5), .D6(mdL0_6_6), .D7(mdL0_6_7), .SD1(Address[8]), 
        .SD2(Address[9]), .SD3(Address[10]), .Z(Q[1]));

    MUX81 mux_0 (.D0(mdL0_7_0), .D1(mdL0_7_1), .D2(mdL0_7_2), .D3(mdL0_7_3), 
        .D4(mdL0_7_4), .D5(mdL0_7_5), .D6(mdL0_7_6), .D7(mdL0_7_7), .SD1(Address[8]), 
        .SD2(Address[9]), .SD3(Address[10]), .Z(Q[0]));



    // exemplar begin
    // exemplar end

endmodule
