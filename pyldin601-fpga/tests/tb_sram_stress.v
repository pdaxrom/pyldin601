`timescale 1ns/1ps
// Worst-case runtime bus load: a SRAM transaction on every 1 MHz CPU cycle,
// while PAL video fetches all 40 bytes of every displayed line.
module tb_sram_stress #(parameter SPEED=0);
    reg clk=0;always #20.832 clk=~clk;
 reg clk_fast=0;always #5.208 clk_fast=~clk_fast;
    reg rw=1,vma=0;reg[15:0]address=0;reg[7:0]data=0;
    wire cpu_clk,cpu_reset,cpu_hold;wire[7:0]result;
    wire[19:0]sa;wire[15:0]sd;wire ce,oe,we,ub,lb;
    classic_system dut(.clk(clk),.clk_fast(clk_fast),.pll_locked(1'b1),.btn_resetn(1'b1),
        .cpu_rw(rw),.cpu_vma(vma),.cpu_addr(address),.cpu_out(data),
        .cpu_clk(cpu_clk),.cpu_reset(cpu_reset),.cpu_hold(cpu_hold),.cpu_in(result),
        .ps2clk(1'b1),.ps2dat(1'b1),.rxd(1'b1),.miso(1'b1),
        .SRAM_ADDR(sa),.SRAM_DATA(sd),.SRAM_CE(ce),.SRAM_OE(oe),.SRAM_WE(we),.SRAM_UB(ub),.SRAM_LB(lb));
    reg[15:0]memory[0:1048575];reg[7:0]header[0:95],expected[0:65535];
    // Exercise unequal FPGA pad delays and SRAM-10 data access, rather than
    // a zero-delay RAM. Data/control remain within the documented LPF budget.
    wire[19:0]pin_address;wire pin_ce,pin_oe,pin_we,pin_lb,pin_ub;
    wire[15:0]pin_write_data;
    assign #12 pin_address=sa;
    assign #12 pin_ce=ce;assign #12 pin_oe=oe;
    assign #6 pin_we=we;assign #12 pin_lb=lb;assign #12 pin_ub=ub;
    assign #14 pin_write_data=sd;
    assign #(18,18,4) sd=!pin_ce&&!pin_oe&&pin_we?memory[pin_address]:16'bz;
    real write_start;
    always @(negedge pin_we)begin
        write_start=$realtime;
        if(!pin_oe)$fatal(1,"SRAM write with output enabled");
    end
    always @(posedge pin_we)if(!pin_ce)begin
        if($realtime-write_start<8)$fatal(1,"SRAM WE pulse too short");
        if(!pin_lb)memory[pin_address][7:0]=pin_write_data[7:0];
        if(!pin_ub)memory[pin_address][15:8]=pin_write_data[15:8];
    end
    // Output-enable must be a retained register spanning every FSM transition
    // of the write. This cannot prove pad glitches in a zero-delay RTL model,
    // but prevents accidentally reintroducing a combinational state decode.
    real write_end;
    always @(posedge we)if(!ce)write_end=$realtime;
    always @(negedge dut.runtime_memory.drive)if(stress&&!dut.cold_reset)begin
        if(!we||$realtime-write_end<10)$fatal(1,"SRAM data released before write hold completed");
    end
    task put;input[15:0]a;input[7:0]d;
        begin @(negedge cpu_clk);address=a;data=d;rw=0;vma=1;
            @(negedge cpu_clk);vma=0;rw=1;
        end
    endtask
    integer i,cycles=0,fetches=0,lines=0;reg stress=0;reg[31:0]rng=32'h68001234;
    always @(negedge cpu_clk)if(stress)begin
        if(cpu_reset||cpu_hold)$fatal(1,"video stretched classic CPU cycle phase=%d",dut.phase);
        cycles=cycles+1;
    end
    always @(posedge clk)if(stress)begin
        if(dut.video.divide==2&&dut.video.horizontal==100&&dut.video.field_line>=50
            &&dut.video.y<224)begin
            if(dut.video.dma_state!=0)$fatal(1,"video fetch missed visible-line deadline");
            lines=lines+1;
        end
    end
    always @(posedge clk_fast)if(stress&&dut.runtime_memory.grant_video&&!dut.runtime_memory.active)fetches=fetches+1;
    initial begin
        for(i=0;i<65536;i=i+1)begin
            expected[i]=(i^(i>>8)^8'h5a)&255;
            if(i%2==0)memory[i/2][7:0]=expected[i];else memory[i/2][15:8]=expected[i];
        end
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
        put(16'he6a0,8'ha5);force dut.speed=SPEED;if(!dut.locked)$fatal(1,"fixture commit failed");
        put(16'he600,1);put(16'he601,48);
        put(16'he600,6);put(16'he601,28);
        put(16'he600,12);put(16'he601,8'h08);
        put(16'he600,13);put(16'he601,0);
        put(16'he629,8'h20); // graphics, 48-byte stride, maximum scanline traffic
        address=16'h8000;rw=1;vma=1;stress=1;
        for(i=0;i<100000;i=i+1)begin
            @(negedge cpu_clk);#1;
            if(rw&&result!==expected[address])$fatal(1,"SRAM mismatch cycle=%d address=%h got=%h expected=%h",i,address,result,expected[address]);
            if(!rw)expected[address]=data;
            rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
            address=rng[15:0]%16'he000;rw=rng[25];data=rng[23:16];
        end
        vma=0;stress=0;
        for(i=0;i<65536;i=i+1)
            if((i%2==0?memory[i/2][7:0]:memory[i/2][15:8])!==expected[i])
                $fatal(1,"unexpected SRAM modification address=%h",i);
        if(fetches<10000||lines<200)$fatal(1,"insufficient video traffic fetches=%d lines=%d",fetches,lines);
        $display("PASS delayed SRAM random addresses/data and full 64K integrity: %d CPU cycles without hold, %d video fetches, %d lines before deadline",cycles,fetches,lines);$finish;
    end
    initial begin #160000000;$fatal(1,"transparent video timeout");end
endmodule
