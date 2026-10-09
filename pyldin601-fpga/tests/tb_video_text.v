`timescale 1ns/1ps
module tb_video_text;
    reg clk=0;always #5 clk=~clk;
    reg reset=1,wr=0,address=0,font_write=0;
    reg[7:0]data=0,font_data=0;reg[10:0]font_address=0;
    wire request,tick;wire[20:0]ma;wire[5:0]tv;
    reg done=0;reg[7:0]memory_data;
    classic_video dut(clk,reset,1'b0,wr,address,data,,8'b0,
        font_write,font_address,font_data,request,ma,1'b1,done,memory_data,tv,tick,1'b0,1'b0,8'b0,,,,,,1'b0,4'd0,8'd0,,);
    wire[9:0]rx;wire[8:0]ry;wire rv,rf;
    pal_viewport_reference refview(.clk(clk),.reset(reset),.model_a(1'b0),.extended(1'b0),.colour(1'b0),.rows(8'd24),.x(rx),.y(ry),.valid(rv),.first(rf));
    reg[7:0]font_reference[0:2047];integer checked=0,pass=0,row,pixel;reg valid;
    always @(posedge clk)begin
        done<=request;
        if(request)begin
            if(ma<21'h400||ma>=21'h7c0)$fatal(1,"boot text DMA escaped screen");
            memory_data<=ma==21'h400 ? 8'h41 : 8'h20;
        end
        #1;
        row=ry;pixel=rx;
        if(!reset&&rv&&row<8&&pixel<16)begin
            if(tv!==((pixel<8&&(pass==1||font_reference[11'h410+row]&(8'h80>>pixel)))?6'd49:6'd15))
                $fatal(1,"text pixel row=%d x=%d value=%d",row,pixel,tv);
            if(rf)checked=checked+1;
        end
    end
    task put;input a;input[7:0]d;
        begin @(negedge clk);address=a;data=d;wr=1;@(negedge clk);wr=0;end
    endtask
    task initialize_crtc;
        begin put(0,1);put(1,40);put(0,6);put(1,24);put(0,10);put(1,8'h20);
            put(0,12);put(1,4);put(0,13);put(1,0);end
    endtask
    initial begin
        $readmemh("rtl/font_boot.mem",font_reference);
        #22;reset=0;initialize_crtc;
        wait(checked==128);@(negedge clk);
        // The loader can replace font bytes; warm reset must retain them.
        for(integer n=0;n<8;n=n+1)begin font_address=11'h410+n;font_data=255;font_write=1;@(negedge clk);end
        font_write=0;reset=1;repeat(2)@(negedge clk);reset=0;
        pass=1;checked=0;initialize_crtc;
        wait(checked==128);
        $display("PASS text PAL pixels, initialized classic font EBR, SD font replacement and warm retention");$finish;
    end
    initial begin #3000000;$fatal(1,"text video timeout checked=%d",checked);end
endmodule
