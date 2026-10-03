`timescale 1ns/1ps
module tb_unread_key;
    reg clk=0;always #5 clk=~clk;
    reg reset=1,psclk=1,psdata=1,cyr=0,rd=0,rs=0;
    wire[7:0]data,status;
    classic_keyboard dut(clk,reset,psclk,psdata,cyr,rd,rs,data,status);
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
        #22;reset=0;send(8'h1c,0);
        send(8'hf0,0);send(8'h1c,0);
        if(data!=8'hff)$fatal(1,"unexpected data %x",data);
        $display("CONFIRMED: unread key disappears on break; consumed flag does not protect it");
        $finish;
    end
endmodule
