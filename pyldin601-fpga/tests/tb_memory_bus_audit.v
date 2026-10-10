`timescale 1ns/1ps
// Independent physical-memory scoreboard for CPU/video arbitration. Checks
// every accepted/completed read, every physical write, all ROM banks, BIOS
// overlays, RAM underneath ROM, electronic disk, and warm-reset draining.
module tb_memory_bus_audit #(
 parameter ADDR_DELAY=12,DATA_DELAY=14.5,CONTROL_DELAY=12,WE_DELAY=6,ACCESS_DELAY=18
);
 reg clk=0;always #20.832 clk=~clk;
 reg clk_fast=0;always #5.208 clk_fast=~clk_fast;
 reg rw=1,vma=0,button=1;reg[15:0]address=0;reg[7:0]data=0;
 wire cpu_clk,cpu_reset,cpu_hold;wire[7:0]result;
 wire[19:0]sa;wire[15:0]dq;wire ce,oe,we,lb,ub;
 classic_system #(.BUTTON_TICK_DIV(1),.BUTTON_DEBOUNCE_MS(2),.BUTTON_LONG_MS(4)) dut(.clk(clk),.clk_fast(clk_fast),.pll_locked(1'b1),.btn_resetn(button),
  .cpu_rw(rw),.cpu_vma(vma),.cpu_addr(address),.cpu_out(data),
  .cpu_clk(cpu_clk),.cpu_reset(cpu_reset),.cpu_hold(cpu_hold),.cpu_in(result),
  .rxd(1'b1),.ps2clk(1'b1),.ps2dat(1'b1),.miso(1'b1),
  .SRAM_ADDR(sa),.SRAM_DATA(dq),.SRAM_CE(ce),.SRAM_OE(oe),.SRAM_WE(we),.SRAM_LB(lb),.SRAM_UB(ub));
 reg[15:0]memory[0:524287];reg[7:0]shadow[0:1048575],header[0:63];
 wire[19:0]pa;wire pce,poe,pwe,plb,pub;wire[15:0]pd;
 assign #(ADDR_DELAY)pa=sa;
 assign #(CONTROL_DELAY)pce=ce;assign #(CONTROL_DELAY)poe=oe;
 assign #(CONTROL_DELAY)plb=lb;assign #(CONTROL_DELAY)pub=ub;
 assign #(WE_DELAY)pwe=we;assign #(DATA_DELAY)pd=dq;
 assign #(ACCESS_DELAY,ACCESS_DELAY,4)dq=!pce&&!poe&&pwe?memory[pa]:16'bz;
 integer owner=-1,age=0,grants=0,cpu_grants=0,video_grants=0,writes=0,captures=0,resets=0;
 reg[20:0]held_address;reg[7:0]held_data,expected_read,cpu_expected;
 reg held_write,held_disk,physical_write,cpu_check=0,armed=0;
 reg[7:0]reference_page=0;
 reg[18:0]reference_disk=0;
 integer disk_reads=0,disk_writes=0,disk_advances=0;
 reg[31:0]rng=32'h60168000;
 function[20:0]physical;input[15:0]a;input wr;reg[3:0]bank;begin
  bank=reference_page[7:4]%5;
  physical=a;
  if(!wr&&a>=16'hf000)physical=21'h20000+a-16'hf000;
  else if(!wr&&a>=16'hc000&&a<16'he000&&reference_page[3])
   physical=21'h10000+reference_page[2:0]*8192+(a&16'h1fff);
 end endfunction
 real write_start,write_end,address_changed,lane_changed,data_changed;
 always @(pa)begin
  if(armed&&!pwe)$fatal(1,"address changed while WE low");address_changed=$realtime;
 end
 always @(plb or pub)begin
  if(armed&&!pwe)$fatal(1,"lanes changed while WE low");lane_changed=$realtime;
 end
 always @(pd)begin
  data_changed=$realtime;
 end
 always @(negedge pwe)if(armed)begin
  write_start=$realtime;
  if(!poe||pce||owner<0||!held_write)$fatal(1,"unowned write/contention");
  if(write_start-address_changed<0||write_start-lane_changed<0)
   $fatal(1,"insufficient write setup");
 end
 always @(posedge pwe)if(!pce&&armed)begin
  write_end=$realtime;
  if(write_end-write_start<8||write_end-data_changed<6)$fatal(1,"WE pulse lacks skew margin");
  if(pa!==held_address[20:1]||{pub,plb}!=={!held_address[0],held_address[0]})$fatal(1,"wrong physical write address/lane");
  if((held_address[0]?pd[15:8]:pd[7:0])!==held_data)$fatal(1,"wrong physical write byte");
  if(physical_write)$fatal(1,"duplicate physical write");
  physical_write=1;writes=writes+1;
  if(!plb)memory[pa][7:0]=pd[7:0];
  if(!pub)memory[pa][15:8]=pd[15:8];
 end
 always @(posedge clk)if(armed)begin
  if(dut.cycle&&!rw)case(address)
   16'he6f0:reference_page=data;
  endcase
  if(cpu_reset)begin reference_page=0;reference_disk=0;cpu_check=0;end
  if(dut.cycle&&address>=16'he680&&address<=16'he683&&rw)begin
   cpu_expected=0;cpu_check=1;
  end
 end
 always @(posedge clk_fast)if(armed)begin
  if(owner>=0)begin
   age=age+1;
   if(dut.runtime_memory.count==5)begin
    if(age!=5)$fatal(1,"bad response latency %d",age);
    if(!held_write&&(owner==0?dut.runtime_memory.cpu_result:(held_address[0]?dq[15:8]:dq[7:0]))!==expected_read)
     $fatal(1,"read owner=%d physical=%h expected=%h",owner,held_address,expected_read);

    owner=-1;
   end
  end
  if(!dut.runtime_memory.active&&(dut.runtime_memory.grant_cpu||dut.runtime_memory.grant_video))begin
   if(owner>=0)$fatal(1,"two outstanding owners");
   owner=dut.runtime_memory.grant_cpu?0:2;grants=grants+1;age=0;physical_write=0;
   held_address=dut.runtime_memory.chosen_address;
   held_data=data;held_write=owner==0&&!rw&&!dut.runtime_memory.protected_address;
   held_disk=owner==0&&address==16'he683;
   if(owner==0)begin
    cpu_grants=cpu_grants+1;
    if(held_disk)begin if(rw)disk_reads=disk_reads+1;else disk_writes=disk_writes+1;end
    if(held_address!==physical(address,!rw))$fatal(1,"wrong CPU physical mapping");
   end else begin
    video_grants=video_grants+1;
    if(held_write||held_address[20:16]!=0)$fatal(1,"video escaped base RAM");
   end
   expected_read=shadow[held_address];
   if(held_write)shadow[held_address]=held_data;
   if(owner==0&&rw)begin cpu_expected=expected_read;cpu_check=1;end
  end
 end
 always @(posedge clk_fast)if(armed&&dut.runtime_memory.active&&dut.runtime_memory.count==5&&held_write)begin
  #2; // Physical write must have ended before releasing the held payload.
  if(!physical_write)$fatal(1,"write did not reach its pad before hold ended");
 end
 always @(negedge cpu_clk)if(armed&&!cpu_reset)begin
  if(cpu_hold)$fatal(1,"CPU held at capture");
  if(cpu_check&&result!==cpu_expected)$fatal(1,"CPU latch overwritten by video addr=%h got=%h expected=%h",address,result,cpu_expected);
  cpu_check=0;captures=captures+1;
 end
 task put;input[15:0]a;input[7:0]d;begin
  @(negedge cpu_clk);#1;address=a;data=d;rw=0;vma=1;
  @(negedge cpu_clk);#1;vma=0;rw=1;
 end endtask
 task get;input[15:0]a;begin
  @(negedge cpu_clk);#1;address=a;rw=1;vma=1;
  @(negedge cpu_clk);#1;vma=0;
 end endtask
 task video_setup;begin
  put(16'he600,1);put(16'he601,42);
  put(16'he600,6);put(16'he601,28);
  put(16'he600,12);put(16'he601,8'hf0);
  put(16'he600,13);put(16'he601,0);
 end endtask
 integer i,j,reset_phase;reg[20:0]a;reg[7:0]b;
 initial begin
  for(i=0;i<1048576;i=i+1)begin
   b=(i^(i>>8)^(i>>16)^8'h5a)&255;shadow[i]=b;
   if(i[0])memory[i>>1][15:8]=b;else memory[i>>1][7:0]=b;
  end
  for(i=0;i<64;i=i+1)header[i]=0;
  {header[0],header[1],header[2],header[3],header[4],header[5],header[6],header[7]}="P601BOOT";
  header[8]=2;header[14]=1;header[17]=8'h18;header[18]=1;
  wait(!cpu_reset);
  for(i=0;i<64;i=i+1)put(16'he6a3,header[i]);
  put(16'he6a0,8'ha5);if(!dut.locked)$fatal(1,"fixture commit");
  armed=1;video_setup;
  put(16'he680,7);put(16'he681,8'hff);put(16'he682,8'hf0);
  for(i=0;i<32;i=i+1)put(16'he683,i^8'ha5);
  put(16'he680,7);put(16'he681,8'hff);put(16'he682,8'hf0);
  for(i=0;i<32;i=i+1)get(16'he683);
  // Alternating screen modes and all 16 bank-select values (including modulo
  // aliases), with random reads/writes crossing page and byte-lane boundaries.
  @(negedge cpu_clk);#1;vma=1;
  for(i=0;i<150000;i=i+1)begin
   rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
   rw=rng[25];data=rng[23:16];
   case(i%128)
    0:begin address=16'he6f0;rw=0;data=((i/128)%16)*16+8+rng[2:0];end
    1:begin address=16'he629;rw=0;data=i[9]?8'h20:0;end
    2,3,4,5,6,7:address=16'hc000|rng[12:0];
    8,9,10,11:address=16'hf000|rng[11:0];
    12:begin address=16'he680;rw=0;end
    13:begin address=16'he681;rw=0;end
    14:begin address=16'he682;rw=0;end
    15:address=16'he683;
    default:begin address=rng[15:0];if(address[15:8]==8'he6)address[15:8]=8'he5;end
   endcase
   @(negedge cpu_clk);#1;
  end
  vma=0;
  // Assert reset at each of the 24 phases while a CPU write and video are
  // active. Accepted writes must finish; cancelled responses must not leak.
  for(reset_phase=0;reset_phase<24;reset_phase=reset_phase+1)begin
   video_setup;
   @(negedge cpu_clk);#1;vma=1;rw=0;address=16'h4000+reset_phase;data=reset_phase^8'ha5;
   wait(dut.phase==reset_phase);@(negedge clk);button=0;
   repeat(48)@(negedge clk);
   button=1;vma=0;rw=1;
   wait(!cpu_reset);resets=resets+1;
  end
  repeat(3)@(negedge cpu_clk);
  for(i=0;i<1048576;i=i+1)
   if((i[0]?memory[i>>1][15:8]:memory[i>>1][7:0])!==shadow[i])$fatal(1,"unexpected physical modification %h",i);
  if(owner>=0||cpu_grants<100000||video_grants<30000||resets!=24||disk_reads||disk_writes)$fatal(1,"incomplete audit");
  $display("PASS SRAM bus audit: %d CPU, %d video reads, %d physical writes, %d captures; electronic disk %d reads/%d writes, single completion increment and 512KiB wrap, all ROM banks/underlays, 24 warm-reset phases, full 1MiB integrity",cpu_grants,video_grants,writes,captures,disk_reads,disk_writes);$finish;
 end
 initial begin #180000000;$fatal(1,"bus audit timeout");end
endmodule
