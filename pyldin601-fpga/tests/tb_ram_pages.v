`timescale 1ns/1ps
module tb_ram_pages;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,runtime=1,write=0,rw=0;
 reg[7:0]data=0,page=0;
 reg[15:0]address=0;
 wire[20:0]legacy,physical;wire io,invalid;wire[7:0]result;
 classic_memory_map map(address,rw,page,legacy,io);
 classic_ram_pages dut(clk,reset,runtime,write,data,address,page,legacy,result,physical,invalid);
 task group;input integer n;
 begin @(negedge clk);data=n;write=1;@(negedge clk);write=0;end endtask
 integer bank,offset,slot,g,rom,w;
 initial begin
  @(negedge clk);reset=0;
  address=16'he6f1;#1;if(result!==0)$fatal(1,"group reset");
  address=16'he6f2;#1;if(result!==8'h52)$fatal(1,"RAM identity");
  address=16'he6f3;#1;if(result!==111)$fatal(1,"RAM capacity");
  // Every byte, both directions, all 111 banks: unique and outside every
  // protected ROM/font/video byte. 8-KiB endpoints are included.
  for(bank=0;bank<111;bank=bank+1)begin
   g=bank/6;slot=bank%6+1;group(g);page=slot;
   for(w=0;w<2;w=w+1)begin
    rw=w;
    for(offset=0;offset<8192;offset=offset+1)begin
     address=16'hc000+offset;#1;
     if(invalid||physical!==21'h22000+bank*8192+offset)
      $fatal(1,"bank=%d offset=%h direction=%d physical=%h",bank,offset,w,physical);
    end
   end
  end
  group(18);
  for(slot=4;slot<=6;slot=slot+1)begin
   page=slot;address=16'hc000;#1;if(!invalid)$fatal(1,"invalid bank aliases graphics");
   address=16'hdfff;#1;if(!invalid)$fatal(1,"invalid bank endpoint");
  end
  for(g=19;g<256;g=g+1)begin
   group(g);address=16'he6f1;#1;if(result!==18)$fatal(1,"invalid group accepted");
  end
  // Pages 0 and 7 are the SAME native RAM, even in the last group.
  for(slot=0;slot<=7;slot=slot+7)begin
   page=slot;
   for(offset=0;offset<8192;offset=offset+1)begin
    address=16'hc000+offset;#1;
    if(invalid||physical!==address)$fatal(1,"main RAM changed");
   end
  end
  for(rom=8;rom<=15;rom=rom+1)begin
   page=rom;
   for(w=0;w<2;w=w+1)begin
    rw=w;
    for(offset=0;offset<8192;offset=offset+1)begin
     address=16'hc000+offset;#1;
     if(invalid||physical!==(w?address:21'h10000+(rom-8)*8192+offset))$fatal(1,"ROM/underlay changed");
    end
   end
  end
  page=1;runtime=0;address=16'hc000;#1;
  if(invalid||physical!==legacy)$fatal(1,"expansion active in bootstrap");
  runtime=1;@(negedge clk);reset=1;@(negedge clk);reset=0;
  address=16'he6f1;#1;if(result!==0)$fatal(1,"warm reset group");
  $display("PASS 111 RAM pages: every byte/read/write, ROM/main RAM isolation, invalid banks, bootstrap and reset");$finish;
 end
endmodule
