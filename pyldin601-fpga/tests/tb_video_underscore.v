`timescale 1ns/1ps
// Native font row 7 contains the underscore. Match the raster to full PAL
// horizontal lines, independent of the half-line offset of the second field.
module tb_video_underscore;
    reg clk=0;always #5 clk=~clk;
    reg reset=1,wr=0,address=0;reg[7:0]data=0;
    wire request;wire[20:0]ma;wire[5:0]tv;
    reg done=0;reg[7:0]memory_data;
    classic_video dut(clk,reset,1'b0,wr,address,data,,8'b0,
        1'b0,11'b0,8'b0,request,ma,1'b1,done,memory_data,tv,,1'b0,1'b0,8'b0,,,,,,1'b0,4'd0,8'd0,,,1'b0);
    wire[9:0]rx;wire[8:0]ry;wire rv,rf;
    pal_viewport_reference refview(.clk(clk),.reset(reset),.model_a(1'b0),.extended(1'b0),.colour(1'b0),.rows(8'd25),.x(rx),.y(ry),.valid(rv),.first(rf));
    reg[7:0]font[0:2047];
    integer raster_line,row,x,char_column,checked[0:1],field;
    reg valid;reg[7:0]character,expected_bits;
    reg[255:0]seen_characters=0;
    // Alternate rows of all 256 character codes, with underscores at both
    // edges and across the middle of the visible horizontal line.
    function[7:0]screen;
        input integer offset;
        integer line,col;
        begin
            line=offset/42;col=offset%42;
            if(line==0||line==2||line==24)screen=col[0]?8'h20:8'h5f;
            else screen=(line*40+col)&255;
        end
    endfunction
    always @(posedge clk)begin
        done<=request;if(request)memory_data<=screen(ma-21'h400);
        #1;
        field=dut.half_line>=625;row=ry;x=rx;char_column=x>>3;
        if(!reset&&rv)begin
            character=screen((row>>3)*42+char_column);
            seen_characters[character]=1;
            expected_bits=font[{character[6:0],character[7],row[2:0]}];
            if(tv!==(expected_bits[7-(x&7)]?6'd49:6'd15))
                $fatal(1,"PAL text field=%d row=%d x=%d char=%h got=%d expected=%h",field,row,x,character,tv,expected_bits);
            if(rf)checked[field]=checked[field]+1;
        end
    end
    task put;input a;input[7:0]d;
        begin @(negedge clk);address=a;data=d;wr=1;@(negedge clk);wr=0;end
    endtask
    initial begin
        checked[0]=0;checked[1]=0;$readmemh("rtl/font_boot.mem",font);
        #22;reset=0;
        put(0,1);put(1,42);put(0,6);put(1,25);put(0,10);put(1,8'h20);
        put(0,12);put(1,4);put(0,13);put(1,0);
        wait(checked[0]==64000&&checked[1]==64000);
        if(!(&seen_characters))$fatal(1,"incomplete character coverage %h",seen_characters);
        $display("PASS both PAL text fields: 128000 pixels, underscores and all font codes on full scanlines");$finish;
    end
    initial begin #10000000;$fatal(1,"PAL text field timeout %d %d",checked[0],checked[1]);end
endmodule
