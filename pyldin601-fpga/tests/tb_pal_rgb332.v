`timescale 1ns/1ps
// Compare the DAC directly with continuous (unquantized) PAL sine/cosine.
// This reference does not read the waveform ROM or the RTL phase register.
module tb_pal_rgb332;
    reg clk=0;always #20.833333 clk=~clk;
    reg reset=1,sync=0,burst=0,alternate=0;
    reg [7:0] colour=0;
    wire [5:0] dac;
    classic_pal_encoder #(.GFX(1)) dut(clk,reset,sync,burst,alternate,4'b0,dac,1'b1,colour,1'b0,4'd0,8'd0,,);
    real r,g,b,y,u,v,angle,want,delayed=0,output_reference,error,max_error=0;
    real allowed,delayed_allowed=0,output_allowed;
    integer cycles=0,checks=0;
    reg [255:0] seen[0:1];
    always @(posedge clk)begin
        if(reset)begin cycles=0;delayed=0;delayed_allowed=0;end
        else begin
            r=real'(colour[7:5])/7.0;
            g=real'(colour[4:2])/7.0;
            b=real'(colour[1:0])/3.0;
            y=0.299*r+0.587*g+0.114*b;u=0.493*(b-y);v=0.877*(r-y);
            if(burst)begin y=0;u=-(0.3/0.7)/(2.0*$sqrt(2.0));v=-u;end
            if(alternate)v=-v;
            angle=cycles*(4433618.75/24000000.0)*6.283185307179586;
            want=sync?0.0:15.0+34.0*(y+u*$sin(angle)+v*$cos(angle));
            output_reference=delayed;delayed=want;
            // A full-intensity primary has more chroma than the legacy IRGB
            // palette. Derive the phase-bin plus DAC rounding error per colour.
            allowed=sync?0.0:0.5001+68.0*$sqrt(u*u+v*v)*$sin(3.141592653589793/64.0);
            output_allowed=delayed_allowed;delayed_allowed=allowed;
            cycles++;
            #1;
            error=real'(dac)-output_reference;if(error<0)error=-error;
            if(error>max_error)max_error=error;
            // 5.625 degree maximum phase quantization, plus one-half DAC LSB.
            if(error>output_allowed+0.001||(^dac===1'bx))
                $fatal(1,"PAL waveform colour=%h alternate=%b sync=%b burst=%b got=%d expected=%.3f error=%.3f",colour,alternate,sync,burst,dac,output_reference,error);
            if(!burst&&!sync)seen[alternate][colour]=1;
            checks++;
        end
    end
    initial begin
        seen[0]=0;seen[1]=0;
        repeat(3)@(negedge clk);reset=0;
        for(integer a=0;a<2;a++)for(integer c=0;c<256;c++)begin
            colour=c;alternate=a;repeat(256)@(negedge clk);
        end
        // Mode/burst/sync changes must all have the same two-stage delay.
        colour=15;repeat(31)@(negedge clk);sync=1;
        repeat(113)@(negedge clk);sync=0;colour=0;
        repeat(23)@(negedge clk);burst=1;
        repeat(54)@(negedge clk);alternate=0;
        repeat(54)@(negedge clk);burst=0;
        repeat(19)@(negedge clk);reset=1;
        repeat(2)@(negedge clk);reset=0;colour=12;
        repeat(127)@(negedge clk);
        if(seen[0]!={256{1'b1}}||seen[1]!={256{1'b1}})$fatal(1,"missing RGB332 coverage");
        $display("PASS PAL encoder: %0d continuous-phase DAC samples, 256 RGB332 colours, both V signs, burst/sync/reset; maximum error %.3f codes",checks,max_error);
        $finish;
    end
endmodule
