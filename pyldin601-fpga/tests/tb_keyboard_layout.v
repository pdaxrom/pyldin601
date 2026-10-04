`timescale 1ns/1ps
module tb_keyboard_layout;
    reg clk=0;always #5 clk=~clk;
 reg clk_fast=0;always #1.25 clk_fast=~clk_fast;
    reg rw=1,vma=0,psclk=1,psdata=1,resetn=1;
    reg[15:0]address=0;reg[7:0]data=0;
    wire cpu_clk,cpu_reset;wire[7:0]result;wire[2:0]led;
    classic_system #(.BUTTON_TICK_DIV(1),.BUTTON_DEBOUNCE_MS(2),.BUTTON_LONG_MS(4)) dut(.clk(clk),.clk_fast(clk_fast),.pll_locked(1'b1),.btn_resetn(resetn),
        .cpu_rw(rw),.cpu_vma(vma),.cpu_addr(address),.cpu_out(data),
        .cpu_clk(cpu_clk),.cpu_reset(cpu_reset),.cpu_in(result),.led_rgb(led),
        .ps2clk(psclk),.ps2dat(psdata),.rxd(1'b1),.miso(1'b1));
    task put;input[15:0]a;input[7:0]d;
        begin @(negedge cpu_clk);address=a;data=d;rw=0;vma=1;
            @(negedge cpu_clk);vma=0;rw=1;end
    endtask
    task get;input[15:0]a;input[7:0]expected;
        begin @(negedge cpu_clk);address=a;rw=1;vma=1;
            @(negedge cpu_clk);#1;if(result!==expected)$fatal(1,"read %x got %x expected %x",a,result,expected);
            vma=0;end
    endtask
    task send;input[7:0]b;reg[10:0]frame;integer i;
        begin frame={1'b1,~^b,b,1'b0};
            for(i=0;i<11;i=i+1)begin psdata=frame[i];#300;psclk=0;#300;psclk=1;#300;end
            psdata=1;#300;end
    endtask
    task win;input[7:0]scan;
        begin send(8'he0);send(scan);get(16'he628,8'hfb);
            send(8'he0);send(scan); // held make is not another toggle event
            if(dut.keyboard.queue_count!=0)$fatal(1,"Win repeat queued another toggle");
            send(8'he0);send(8'hf0);send(scan);get(16'he628,8'hff);end
    endtask
    initial begin
        wait(cpu_reset===0);get(16'he629,1);
        if(led!==3'b110)$fatal(1,"initial Latin/control-bit LEDs");
        put(16'he629,8'h21);get(16'he629,8'h21);
        put(16'he629,8'h01);get(16'he629,8'h01); // BIOS video read/modify/write retains LAT
        send(8'h1c);get(16'he628,"a");send(8'hf0);send(8'h1c);
        win(8'h1f);win(8'h27);
        put(16'he629,8'h20);get(16'he629,8'h20);
        if(led!==3'b100)$fatal(1,"Cyrillic green cathode");
        send(8'h1c);get(16'he628,8'hb4);send(8'hf0);send(8'h1c);
        send(8'h58);get(16'he628,8'hfc);send(8'hf0);send(8'h58);
        put(16'he62a,8'h37);if(led!==3'b101)$fatal(1,"control bit 3 clear: red off + Cyrillic green");
        put(16'he62a,8'h3f);if(led!==3'b100)$fatal(1,"control bit 3 set: red on + Cyrillic green");
        put(16'he629,8'h21);if(led!==3'b110)$fatal(1,"Latin green off");
        put(16'he629,8'h20);resetn=0;wait(cpu_reset);repeat(80)@(negedge clk);resetn=1;
        wait(cpu_reset===0);get(16'he629,1);
        if(led!==3'b110)$fatal(1,"warm reset layout/LEDs");
        $display("PASS DRB readback, Latin reset, both Win FB keys, repeat/break, Caps FC and physical RGB cathodes");$finish;
    end
    initial begin #1000000;$fatal(1,"keyboard layout timeout");end
endmodule
