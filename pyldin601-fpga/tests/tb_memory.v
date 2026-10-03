`timescale 1ns/1ps
module tb_memory;
    reg clk=0; always #5 clk=~clk;
    reg reset=1;
    reg [15:0] cpu_addr; reg cpu_write; reg [7:0] page;
    wire [20:0] physical; wire io;
    classic_memory_map map(cpu_addr,cpu_write,page,physical,io);
    reg commit=0; reg write_req=0; reg [20:0] address;
    wire locked,allowed;
    rom_write_guard guard(clk,reset,commit,write_req,address,locked,allowed);
    reg [7:0] cylinder,head,sector,spt,heads;
    reg [8:0] cylinders; reg [31:0] start,length;
    wire [31:0] lba; wire valid;
    chs_to_lba chs(cylinder,head,sector,cylinders,heads,spt,start,length,lba,valid);
    task check; input condition; input [511:0] message;
        begin if (!condition) $fatal(1,"%0s",message); end
    endtask
    initial begin
        cpu_addr=16'hf006; cpu_write=0; page=0; address=0;
        cylinder=127;head=1;sector=96;cylinders=128;heads=2;spt=96;
        start=59392;length=24576;
        #12;reset=0;#1;
        check(physical==21'h60006,"BIOS mapping");
        cpu_write=1;#1;check(physical==21'hf006,"RAM under BIOS");
        cpu_addr=16'hc123;cpu_write=0;page=8'h4f;#1;
        check(physical==21'h5e123,"last bank/page mapping");
        cpu_write=1;#1;check(physical==21'hc123,"RAM under bank");
        cpu_write=0;page=0;#1;check(physical==21'hc123,"disabled bank");
        page=8'hff;#1;check(physical==21'h1e123,"bank wraps modulo five like classic emulator");
        cpu_addr=16'he6f0;#1;check(io,"I/O decoding");
        write_req=1;address=21'h60000;#1;check(allowed,"load before lock");
        commit=1;#1;check(!allowed,"commit edge protection");
        @(posedge clk);#1;commit=0;#1;check(locked&&!allowed,"one way lock");
        address=21'h80000;#1;check(allowed,"RAM disk writable");
        address=21'hf006;#1;check(allowed,"underlying RAM writable");
        check(valid&&lba==83967,"12 MiB last CHS sector");
        sector=0;#1;check(!valid,"sector zero rejected");
        sector=97;#1;check(!valid,"sector overflow rejected");
        sector=96;cylinder=128;#1;check(!valid,"cylinder overflow rejected");
        cylinder=127;length=24575;#1;check(!valid,"partition boundary");
        length=24576;start=32'hfffff000;#1;check(!valid,"LBA arithmetic overflow");
        $display("PASS memory overlays, ROM lock and CHS bounds");$finish;
    end
endmodule
