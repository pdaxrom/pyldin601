`timescale 1ns/1ps
module tb_keyboard;
    reg clk=0;always #5 clk=~clk;
    reg reset=1,psclk=1,psdata=1,cyr=0,rd=0,rs=0;
    wire[7:0]data,status;wire irq;
    classic_keyboard dut(clk,reset,psclk,psdata,cyr,rd,rs,data,status,irq);
    task send;
        input[7:0]b;input badparity;
        reg[10:0]frame;integer i;
        begin
            frame={1'b1,(~^b)^badparity,b,1'b0};
            for(i=0;i<11;i=i+1)begin
                psdata=frame[i];#300;psclk=0;#300;psclk=1;#300;
            end
            psdata=1;#300;
        end
    endtask
    initial begin
        #22;reset=0;send(8'h1c,0); // A
        if(status!=128||!irq)$fatal(1,"make status/IRQ");
        if(data!="a")$fatal(1,"set2 'a' translation %x",data);
        @(negedge clk);rs=1;@(negedge clk);rs=0;#1;
        if(status!=0)$fatal(1,"classic ready trigger");
        @(negedge clk);rd=1;@(negedge clk);rd=0;#1;
        if(status!=0||data!="a")$fatal(1,"held key data");
        send(8'hf0,0);send(8'h1c,0);if(data!=8'hff)$fatal(1,"break handling");
        send(8'h12,0);send(8'h1c,0);if(data!="A")$fatal(1,"shift");
        @(negedge clk);rd=1;@(negedge clk);rd=0;
        send(8'hf0,0);send(8'h1c,0);send(8'hf0,0);send(8'h12,0);
        send(8'h1c,1);if(data!=8'hff)$fatal(1,"parity error accepted");
        cyr=1;send(8'h1c,0);if(data!=8'hb4)$fatal(1,"Cyrillic mapping %x",data);
        $display("PASS PS/2 frames, parity, make/break, Shift and Cyrillic");$finish;
    end
endmodule
