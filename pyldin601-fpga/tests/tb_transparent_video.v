`timescale 1ns/1ps
// Worst-case runtime bus load: a SRAM transaction on every 1 MHz CPU cycle,
// while PAL video fetches all 40 bytes of every displayed line.
module tb_transparent_video;
    reg clk=0;always #5 clk=~clk;
    reg rw=1,vma=0;reg[15:0]address=0;reg[7:0]data=0;
    wire cpu_clk,cpu_reset,cpu_hold;wire[7:0]result;
    wire[19:0]sa;wire[15:0]sd;wire ce,oe,we,ub,lb;
    classic_system dut(.clk(clk),.pll_locked(1'b1),.btn_resetn(1'b1),
        .cpu_rw(rw),.cpu_vma(vma),.cpu_addr(address),.cpu_out(data),
        .cpu_clk(cpu_clk),.cpu_reset(cpu_reset),.cpu_hold(cpu_hold),.cpu_in(result),
        .ps2clk(1'b1),.ps2dat(1'b1),.rxd(1'b1),.miso(1'b1),
        .SRAM_ADDR(sa),.SRAM_DATA(sd),.SRAM_CE(ce),.SRAM_OE(oe),.SRAM_WE(we),.SRAM_UB(ub),.SRAM_LB(lb));
    reg[15:0]memory[0:1048575];reg[7:0]header[0:95];
    assign sd=!ce&&!oe&&we?memory[sa]:16'bz;
    always @(posedge we)if(!ce)begin
        if(!lb)memory[sa][7:0]=sd[7:0];if(!ub)memory[sa][15:8]=sd[15:8];
    end
    task put;input[15:0]a;input[7:0]d;
        begin @(negedge cpu_clk);address=a;data=d;rw=0;vma=1;
            @(negedge cpu_clk);vma=0;rw=1;
        end
    endtask
    integer i,cycles=0,fetches=0,lines=0;reg stress=0;
    always @(negedge cpu_clk)if(stress)begin
        if(cpu_reset||cpu_hold)$fatal(1,"video stretched classic CPU cycle phase=%d",dut.phase);
        cycles=cycles+1;
    end
    always @(posedge clk)if(stress)begin
        if(dut.accept[0]&&dut.phase!=3)$fatal(1,"CPU escaped its SRAM slot");
        if(dut.accept[2])begin
            if(dut.phase!=10&&dut.phase!=17)$fatal(1,"video escaped its SRAM slots");
            fetches=fetches+1;
        end
        if(dut.video.divide==2&&dut.video.horizontal==100&&dut.video.field_line>=50
            &&dut.video.y<224)begin
            if(dut.video.dma_state!=0)$fatal(1,"video fetch missed visible-line deadline");
            lines=lines+1;
        end
    end
    initial begin
        for(i=0;i<32768;i=i+1)memory[i]=16'hff00;
        for(i=0;i<96;i=i+1)header[i]=0;
        {header[0],header[1],header[2],header[3],header[4],header[5],header[6],header[7]}="P601BOOT";
        header[8]=1;header[14]=1;header[17]=8'h18;header[18]=5;
        header[33]=8'h88;header[36]=8'h40;header[37]=8'h0b;
        header[40]=18;header[42]=2;header[44]=80;
        header[49]=8'h98;header[52]=8'h40;header[53]=8'h0b;
        header[56]=18;header[58]=2;header[60]=80;
        header[68]=1;header[73]=8'h88;header[76]=8'h40;header[77]=8'h0b;
        header[84]=1;header[89]=8'h98;header[92]=8'h40;header[93]=8'h0b;
        wait(cpu_reset===1'b0);
        for(i=0;i<96;i=i+1)put(16'he6a3,header[i]);
        put(16'he6a0,8'ha5);if(!dut.locked)$fatal(1,"fixture commit failed");
        put(16'he600,1);put(16'he601,48);
        put(16'he600,6);put(16'he601,28);
        put(16'he600,12);put(16'he601,8'h08);
        put(16'he600,13);put(16'he601,0);
        put(16'he629,8'h20); // graphics, 48-byte stride, maximum scanline traffic
        address=16'h8000;rw=1;vma=1;stress=1;
        for(i=0;i<40000;i=i+1)begin
            @(negedge cpu_clk);#1;
            if(rw&&result!==(i==0?8'h00:8'ha5))$fatal(1,"CPU data lost under video load cycle=%d got=%x",i,result);
            address=16'h8000;rw=i[0];data=8'ha5;
        end
        if(fetches<10000||lines<200)$fatal(1,"insufficient video traffic fetches=%d lines=%d",fetches,lines);
        $display("PASS transparent SRAM slots: %d CPU cycles without hold, %d video fetches, %d lines before deadline",cycles,fetches,lines);$finish;
    end
    initial begin #12000000;$fatal(1,"transparent video timeout");end
endmodule
