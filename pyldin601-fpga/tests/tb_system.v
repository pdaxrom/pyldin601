`timescale 1ns/1ps
module system_fixture(input cpu_rw,cpu_vma,input[15:0]cpu_addr,input[7:0]cpu_out,output cpu_clk,cpu_reset,cpu_hold,cpu_irq,output[7:0]cpu_in,output hd6303_en);
reg clk=0;always #5 clk=~clk;
 wire clk_fast;test_fast_clock fast_clock(clk_fast);
integer menu_writes=0;always @(posedge clk)if(dut.bus_write&&cpu_addr==16'he6a0)menu_writes=menu_writes+1;
reg resetn=1,psclk=1,psdata=1;wire cs,sck,mosi;reg miso=1;
wire[19:0]sa;wire[15:0]sd;wire ce,oe,we,ub,lb;
wire[5:0]tv;wire[1:0]audio;
classic_system #(
 .BUTTON_TICK_DIV(1),.BUTTON_DEBOUNCE_MS(2),.BUTTON_LONG_MS(4),
 `ifdef HANDOFF_CHECK
 .BOOT_FILE("build/handoff-boot.mem")
 `else
 .BOOT_FILE("build/boot.mem")
 `endif
 ) dut(.clk(clk),.clk_fast(clk_fast),.pll_locked(1'b1),.cpu_rw(cpu_rw),.cpu_vma(cpu_vma),.cpu_addr(cpu_addr),.cpu_out(cpu_out),.cpu_clk(cpu_clk),.cpu_reset(cpu_reset),.cpu_hold(cpu_hold),.cpu_irq(cpu_irq),.cpu_in(cpu_in),.hd6303_en(hd6303_en),.btn_resetn(resetn),.ps2clk(psclk),.ps2dat(psdata),.rxd(1'b1),
 .mss(cs),.msck(sck),.mosi(mosi),.miso(miso),.SRAM_ADDR(sa),.SRAM_DATA(sd),
 .SRAM_CE(ce),.SRAM_OE(oe),.SRAM_WE(we),.SRAM_UB(ub),.SRAM_LB(lb),.tvout(tv),.audio(audio),.seg_led_h(),.seg_led_l(),.led_rgb(),.txd());
task key_byte;input[7:0]b;reg[10:0]frame;integer n;
 begin frame={1'b1,~^b,b,1'b0};
  for(n=0;n<11;n++)begin psdata=frame[n];#300;psclk=0;#300;psclk=1;#300;end
  psdata=1;#300;
 end
endtask
`ifndef HANDOFF_CHECK
initial begin
 // Wait for the real menu's timer read, then enter using physical PS/2.
 wait(dut.bus_read&&cpu_addr==16'he62b);
 `ifdef BOOT_MODEL_A
 key_byte(8'h1e);
 `else
 key_byte(8'h5a);
 `endif
 // Hold the first selection across the whole redraw and into the second
 // menu: it must not count as a fresh CPU choice.
 wait(menu_writes>=1);
 wait(dut.bus_read&&cpu_addr==16'he62b);
 #500000;
 if(menu_writes!=1)$fatal(1,"held model key also selected CPU");
 key_byte(8'hf0);
 `ifdef BOOT_MODEL_A
 key_byte(8'h1e);
 `else
 key_byte(8'h5a);
 `endif
 #100000;
 `ifdef BOOT_HD6303
 key_byte(8'h1e);key_byte(8'hf0);key_byte(8'h1e);
 `else
 key_byte(8'h5a);key_byte(8'hf0);key_byte(8'h5a);
 `endif
end
`endif
reg[15:0]memory[0:1048575];
assign sd=!ce&&!oe&&we?memory[sa]:16'bz;
always @(posedge we)if(!ce)begin
 if(dut.locked&&sa>=20'h08000&&sa<20'h30c00)$fatal(1,"ROM write after lock");
 if(!lb)memory[sa][7:0]=sd[7:0];if(!ub)memory[sa][15:8]=sd[15:8];
end
reg[7:0]expected_rom[0:333823];
reg[7:0]sd_image[0:4194303];
integer image_byte,sectors=0;reg[31:0]sector_lba;reg[1023:0]image_path;
integer boot_text_pixels=0;
always @(posedge clk)if(!dut.locked&&tv==49)boot_text_pixels=boot_text_pixels+1;
    reg [7:0] fifo[0:2047],command[0:5],incoming=0,current=8'hff;
    integer rd=0,wr=0,bits=0,cmd_count=0,write_phase=0,write_count=0,i;
    reg [15:0] read_crc=0,write_crc=0,received_crc=0;
    reg high_capacity;
    reg [31:0] argument;
    function [15:0] crc16;
        input [15:0] old;input [7:0] data;reg[15:0]c;integer k;
        begin c=old^{data,8'b0};for(k=0;k<8;k=k+1)c=c[15]?(c<<1)^16'h1021:c<<1;crc16=c;end
    endfunction
    task put;input[7:0]b;begin fifo[wr]=b;wr=wr+1;end endtask
    task receive_byte;input[7:0]b;integer j;
        begin
            if(write_phase==1)begin
                if(b==8'hfe)begin write_phase=2;write_count=0;write_crc=0;end
            end else if(write_phase==2)begin
                $fatal(1,"unexpected disk write during ROM boot");
                write_crc=crc16(write_crc,b);write_count=write_count+1;
                if(write_count==512)write_phase=3;
            end else if(write_phase==3)begin received_crc[15:8]=b;write_phase=4;end
            else if(write_phase==4)begin
                received_crc[7:0]=b;if(received_crc!=write_crc)$fatal(1,"write CRC");
                put(8'h05);put(0);put(0);put(8'hff);write_phase=0;
            end else if(cmd_count!=0||b[7:6]==2'b01)begin
                command[cmd_count]=b;cmd_count=cmd_count+1;
                if(cmd_count==6)begin
                    argument={command[1],command[2],command[3],command[4]};
                    cmd_count=0;
                    case(command[0][5:0])
                        0:begin
                            if(menu_writes!=2)$fatal(1,"SD started before both selections");
 `ifdef BOOT_HD6303
                            if(!hd6303_en)$fatal(1,"HD6303 menu did not enable CPU input");
 `else
                            if(hd6303_en)$fatal(1,"MC6800 menu enabled extended ISA");
 `endif
                            if(dut.video.stride!==
 `ifdef BOOT_MODEL_A
 8'd80
 `else
 8'd40
 `endif||dut.video.start_addr!==16'h400

 `ifdef BOOT_MODEL_A
 ||!dut.model_a||memory[20'h200]!==16'h5000||memory[20'h201]!==16'h5900)
 `else
 ||dut.model_a||memory[20'h200]!==16'h5950||memory[20'h201]!==16'h444c)
 `endif
                                $fatal(1,"actual CPU did not initialize text before SD");
                            put(1);
                        end
                        8:if(high_capacity)begin put(1);put(0);put(0);put(1);put(8'haa);end else put(5);
                        55:put(1);
                        41:put(0);
                        58:begin put(0);put(high_capacity?8'hc0:8'h80);put(8'hff);put(8'h80);put(0);end
                        16:begin if(argument!=512)$fatal(1,"CMD16");put(0);end
                        17:begin
                            sector_lba=high_capacity?argument:argument>>9;
                            if(sector_lba>=8192)$fatal(1,"test fixture SD bounds");
                            sectors=sectors+1;
                            put(0);put(8'hff);put(8'hfe);read_crc=0;
                            for(j=0;j<512;j=j+1)begin image_byte=sd_image[sector_lba*512+j];put(image_byte[7:0]);read_crc=crc16(read_crc,image_byte[7:0]);end
                            put(read_crc[15:8]);put(read_crc[7:0]^8'h00);
                        end
                        24:begin
                            sector_lba=high_capacity?argument:argument>>9;
                            put(0);write_phase=1;
                        end
                        default:$fatal(1,"unexpected command %0d",command[0][5:0]);
                    endcase
                end
            end
        end
    endtask
    always @(negedge cs)begin rd=0;wr=0;bits=0;cmd_count=0;incoming=0;current=8'hff;miso=1;end
    always @(posedge cs)begin miso=1;if(write_phase!=0)$fatal(1,"CS broke write transaction");end
    always @(posedge sck)if(!cs)begin
        incoming={incoming[6:0],mosi};bits=bits+1;
        if(bits==8)begin bits=0;receive_byte(incoming);end
    end
    always @(negedge sck)if(!cs)begin
        if(bits==0)begin
            if(rd<wr)begin current=fifo[rd];rd=rd+1;end else current=8'hff;
        end
        miso=current[7-bits];
    end
    initial begin
        high_capacity=1;
        image_path="build/test-sd.img";
        `ifndef HANDOFF_CHECK
        $readmemh("build/boot-sd.mem",sd_image);
        `endif
        `ifdef BOOT_MODEL_A
        $readmemh("build/rom-a-payload.mem",expected_rom);
        `else
        $readmemh("build/rom-payload.mem",expected_rom);
        `endif
        `ifdef HANDOFF_CHECK
        for(i=0;i<333824;i=i+1)begin
            if(i%2==0)memory[(65536+i)/2][7:0]=expected_rom[i];else memory[(65536+i)/2][15:8]=expected_rom[i];
        end
        memory[20'h07000]=16'ha586;memory[20'h07001]=16'he6b7;memory[20'h07002]=16'hb6a0;
        memory[20'h07003]=16'ha0e6;memory[20'h07004]=16'h022b;memory[20'h07005]=16'hfe20;
        memory[20'h07006]=16'hfffe;memory[20'h07007]=16'h6efe;memory[20'h07008]=16'h0000;
        `else
        wait(dut.cpu_addr==16'h2000&&dut.boot_mode);
        if(boot_text_pixels<20)$fatal(1,"boot text produced no visible PAL pixels");
        `ifdef BOOT_MODEL_A
        if(memory[20'h228]!==16'h5300||memory[20'h230]!==16'h2000)
        `else
        if(memory[20'h228]!==16'h5453||memory[20'h22c]!==16'h4c20)
        `endif
            $fatal(1,"actual CPU did not display loader stage");
        $display("MILESTONE actual HDL CPU loaded LOADER.BIN over SD SPI (%0d sectors)",sectors);
        $display("PASS actual HDL CPU text initialization and PAL boot status (%0d bright pixels)",boot_text_pixels);
        `endif
        `ifndef FULL_SYSTEM
        $finish;
        `endif
        wait(dut.locked===1'b1);
        for(i=0;i<333824;i=i+1)begin
            if((i%2==0?memory[(65536+i)/2][7:0]:memory[(65536+i)/2][15:8])!==expected_rom[i])$fatal(1,"physical ROM mismatch byte %0d",i);
        end
        $display("MILESTONE ROM initialized and locked (%0d SD sectors)",sectors);
        wait(dut.cpu_addr===16'hf006);repeat(5000)@(negedge clk);
        memory[20'h4091a]=16'h5a3c;
        resetn=0;repeat(80)@(negedge clk);resetn=1;
        wait(dut.cpu_reset===1'b0);repeat(2000)@(negedge clk);
        if(
        `ifdef BOOT_MODEL_A
        !dut.model_a||
        `endif
        !dut.locked||memory[20'h4091a]!=16'h5a3c)$fatal(1,"warm reset lost retained state locked=%b marker=%h cold=%b cpu_reset=%b",dut.locked,memory[20'h4091a],dut.cold_reset,dut.cpu_reset);
        if(sectors!=
        `ifdef HANDOFF_CHECK
        0
        `else
        1310
        `endif
        )$fatal(1,"warm reset reloaded SD sectors=%0d",sectors);
        `ifdef HANDOFF_CHECK
        $display("PASS actual HDL CPU handoff/ROM lock/warm reset with preloaded SRAM fixture");
        `else
        $display("PASS actual HDL CPU+SRAM+SPI boot, BIOS handoff and warm reset");
        `endif
        $finish;
    end
    always @(posedge clk)if(dut.boot_debug==8'hee)$fatal(1,"CPU boot error address=%x sectors=%0d",dut.cpu_addr,sectors);
    initial begin #1000000000000;$fatal(1,"system timeout");end
endmodule
