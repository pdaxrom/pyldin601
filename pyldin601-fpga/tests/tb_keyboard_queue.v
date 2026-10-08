`timescale 1ns/1ps
module tb_keyboard_queue;
    reg clk=0;always #5 clk=~clk;
    reg reset=1,psclk=1,psdata=1,cyr=0,rd=0,rs=0;
    wire[7:0]data,status;wire irq;
    classic_keyboard dut(clk,reset,psclk,psdata,cyr,rd,rs,data,status,irq,1'b0,1'b0);
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
        #22;reset=0;send(8'h1c,0);send(8'hf0,0);send(8'h1c,0);
        if(data!="a"||!irq)$fatal(1,"unread release lost");
        send(8'h32,0);send(8'hf0,0);send(8'h32,0);
        if(data!="a")$fatal(1,"queued key overwrote unread key");
        @(negedge clk);rd=1;@(negedge clk);rd=0;repeat(5)@(negedge clk);
        if(data!="b"||!irq)$fatal(1,"queue did not advance");
        @(negedge clk);rd=1;@(negedge clk);rd=0;repeat(5)@(negedge clk);
        if(data!=255||irq)$fatal(1,"released consumed key stuck");
        // Two separate taps of the same key must remain two queue events.
        send(8'h1c,0);send(8'hf0,0);send(8'h1c,0);
        send(8'h1c,0);send(8'hf0,0);send(8'h1c,0);
        @(negedge clk);rd=1;@(negedge clk);rd=0;repeat(5)@(negedge clk);
        if(data!="a"||!irq)$fatal(1,"second same-key tap lost");
        @(negedge clk);rd=1;@(negedge clk);rd=0;repeat(5)@(negedge clk);
        if(data!=255)$fatal(1,"same-key tap stuck");
        send(8'he1,0);send(8'h14,0);send(8'h77,0);send(8'he1,0);
        send(8'hf0,0);send(8'h14,0);send(8'hf0,0);send(8'h77,0);
        if(dut.ctrl_l||dut.ctrl_r||data!=255)$fatal(1,"Pause affected modifiers");
        $display("PASS unread key retention, queued fast taps, IRQ and Pause sequence");$finish;
    end
endmodule
