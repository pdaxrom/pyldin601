`timescale 1ns/1ps
module tb_video_cursor;
    reg clk=0;always #5 clk=~clk;
    reg reset=1,wr=0,address=0,graphics=0;reg[7:0]data=0;
    wire request,tick;wire[20:0]ma;wire[5:0]tv;reg done=0;reg[7:0]memory_data;
    classic_video dut(clk,reset,1'b0,wr,address,data,,{2'b0,graphics,5'b0},
        1'b0,11'b0,8'b0,request,ma,1'b1,done,memory_data,tv,tick,1'b0);
    reg[7:0]ram[0:65535],reference[0:63999];integer checked=0,row,pixel,test_case=0,field,raster_line;reg valid;
    always @(posedge clk)begin
        done<=request;if(request)memory_data<=ram[ma];
        // Derive the expected raster independently from complete horizontal
        // lines; the second PAL field begins on an odd half-line.
        field=dut.half_line>=625;
        raster_line=(dut.half_line>>1)-(field?312:0);
        row=raster_line-50;pixel=dut.horizontal-100;
        valid=!reset&&dut.divide==2&&row>=0&&row<200&&pixel>=0&&pixel<320;
        if(valid)begin #1;
            if(tv!==reference[row*320+pixel])$fatal(1,"cursor case=%d mode=%d field=%d row=%d x=%d got=%d expected=%d",test_case,graphics,field,row,pixel,tv,reference[row*320+pixel]);
            checked=checked+1;
        end
    end
    task put;input a;input[7:0]d;
        begin @(negedge clk);address=a;data=d;wr=1;@(negedge clk);wr=0;end
    endtask
    task init;input[15:0]start,cursor;input[7:0]stride;
        begin put(0,1);put(1,stride);put(0,6);put(1,25);put(0,10);put(1,6);put(0,11);put(1,7);
            put(0,12);put(1,start[15:8]);put(0,13);put(1,start[7:0]);
            put(0,14);put(1,cursor[15:8]);put(0,15);put(1,cursor[7:0]);end
    endtask
    initial begin
        $readmemh("build/cursor-text.mem",reference);$readmemh("build/cursor-text-ram.mem",ram);
        #22;reset=0;init(16'hf100,16'hf22c,42);
        wait(checked==128000);@(negedge clk);reset=1;
        $readmemh("build/cursor-graphics.mem",reference);$readmemh("build/cursor-graphics-ram.mem",ram);
        graphics=1;test_case=1;checked=0;repeat(2)@(negedge clk);reset=0;init(16'h400,16'h555,48);
        wait(checked==128000);
        @(negedge clk);reset=1;
        $readmemh("build/cursor-text-wrap.mem",reference);$readmemh("build/cursor-text-wrap-ram.mem",ram);
        graphics=0;test_case=2;checked=0;repeat(2)@(negedge clk);reset=0;init(16'hff00,16'hf02d,42);
        wait(checked==128000);@(negedge clk);reset=1;
        $readmemh("build/cursor-graphics-wrap.mem",reference);$readmemh("build/cursor-graphics-wrap-ram.mem",ram);
        graphics=1;test_case=3;checked=0;repeat(2)@(negedge clk);reset=0;init(16'h1ff0,16'h146,48);
        wait(checked==128000);
        @(negedge clk);reset=1;
        $readmemh("build/cursor-text-end.mem",reference);$readmemh("build/cursor-text-end-ram.mem",ram);
        graphics=0;test_case=4;checked=0;repeat(2)@(negedge clk);reset=0;init(16'hffff,16'hf12b,42);
        wait(checked==128000);@(negedge clk);reset=1;
        $readmemh("build/cursor-graphics-end.mem",reference);$readmemh("build/cursor-graphics-end-ram.mem",ram);
        graphics=1;test_case=5;checked=0;repeat(2)@(negedge clk);reset=0;init(16'h1fff,16'h155,48);
        wait(checked==128000);
        $display("PASS 768000 PAL text/graphics pixels in both fields, address wrapping and cursor positioning against original MC6845 emulator");$finish;
    end
    initial begin #60000000;$fatal(1,"cursor pixel timeout checked=%d",checked);end
endmodule
