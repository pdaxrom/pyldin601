`timescale 1ns/1ps
// Real PS/2 decoder and production VHDL CPU, paired native BIOS/RAM.
// PAL/audio MMIO are clocked reference models; full-system coverage is separate.
// A burst is checked at the BIOS typeahead buffer, before DOS consumes it.
module keyboard_bios_fixture #(parameter SPEED=0)(
 input cpu_rw,cpu_vma,input[15:0]cpu_addr,input[7:0]cpu_out,
 output cpu_clk,cpu_reset,cpu_hold,cpu_irq,output[7:0]cpu_in
);
 wire clk;
 keyboard_test_cpu_clock #(.SPEED(SPEED)) clock(clk);
 assign cpu_clk=clk;
 reg reset=1,psclk=1,psdata=1;
 initial begin #2200;reset=0;end
 assign cpu_reset=reset;assign cpu_hold=0;
 reg[15:0]memory[0:68607];
 reg[7:0]page=0,group=0,mode=1;reg caps_off=1,speaker=0;
 wire[20:0]physical;wire unused;
 classic_memory_map map(cpu_addr,!cpu_rw,page,physical,unused);
 reg pal_pending=0,music_pending=0,music_enabled=0;
 integer cycles=0,music_counter=0;
 wire[7:0]kbd_data,kbd_status,raw_result,raw_scan;wire keyboard_irq,raw_irq,raw_valid,captured,consumed;
 reg io_latched=0;reg[15:0]io_address;reg[7:0]io_data;
 wire bus_read=cpu_vma&&cpu_rw&&(!io_latched||io_address!=cpu_addr);
 wire bus_write=cpu_vma&&!cpu_rw;
 wire raw_io=cpu_addr[15:3]==13'h1cd6;
 ps2_byte_receiver receiver(clk,reset,psclk,psdata,raw_valid,raw_scan,);
 classic_keyboard keyboard(clk,reset,captured,
  bus_read&&cpu_addr==16'he628,bus_read&&(cpu_addr==16'he62a||cpu_addr==16'he62e),
  bus_write&&cpu_addr==16'he628,bus_write&&(cpu_addr==16'he62a||cpu_addr==16'he62e),
  cpu_out,kbd_data,kbd_status,keyboard_irq,consumed);
 classic_ps2_raw raw_fifo(clk,reset,raw_valid,raw_scan,bus_read&&raw_io,bus_write&&raw_io,
  cpu_addr[2:0],cpu_out,raw_result,1'b0,captured,consumed,raw_irq);
 assign cpu_irq=keyboard_irq||raw_irq||pal_pending||music_pending;
 reg[7:0]byte_in;reg memory_epoch=0;
 // Explicit write epoch avoids a whole-array sensitivity subscription in
 // mixed-language simulators while retaining asynchronous memory reads.
 always @(physical or cpu_addr or memory_epoch or kbd_data or kbd_status
          or caps_off or pal_pending or speaker or mode or page or group
          or music_enabled or music_pending or raw_result)begin
  byte_in=physical[0]?memory[physical>>1][15:8]:memory[physical>>1][7:0];
  if(raw_io)byte_in=raw_result;
  case(cpu_addr)
   16'he628:byte_in=kbd_data;
   16'he62a,16'he62e:byte_in=kbd_status|8'h37|(caps_off?8'h08:0);
   16'he62b:byte_in=8'h37|(pal_pending?8'h80:0)|(speaker?8'h08:0);
   16'he629:byte_in=mode;
   16'he6f0:byte_in=page;
   16'he6f1:byte_in=group;
   16'he691:byte_in=8'h59;
   16'he690:byte_in=(music_enabled?8'h01:0)|(music_pending?8'h80:0);
  endcase
 end
 assign cpu_in=io_latched&&io_address==cpu_addr?io_data:byte_in;
 always @(posedge clk)begin
  cycles<=cycles+1;
  if(io_address!=cpu_addr||!cpu_vma||!cpu_rw)io_latched<=0;
  if(bus_read&&cpu_addr[15:8]==8'he6)begin
   io_latched<=1;io_address<=cpu_addr;io_data<=byte_in;
   if(cpu_addr==16'he62b)pal_pending<=0;
  end
  if(bus_write)begin
   case(cpu_addr)
    16'he628,16'he6b0,16'he6b1,16'he6b2,16'he6b3,16'he6b4:begin end
    16'he6f0:page<=cpu_out;
    16'he6f1:group<=cpu_out;
    16'he629:mode<=cpu_out;
    16'he62a,16'he62e:caps_off<=cpu_out[3];
    16'he62b:speaker<=cpu_out[3];
    16'he690:begin
     music_enabled<=cpu_out[0];
     if(cpu_out[1]||!cpu_out[0]||cpu_out[2])music_pending<=0;
     if(!cpu_out[0]||cpu_out[2])music_counter<=0;
    end
    default:if(cpu_addr[15:8]!=8'he6)begin
     if(cpu_addr[0])memory[cpu_addr>>1][15:8]=cpu_out;
     else memory[cpu_addr>>1][7:0]=cpu_out;
     memory_epoch<=!memory_epoch;
    end
   endcase
  end
  if(!reset)begin
   if(cycles%(20000<<SPEED)==0)pal_pending<=1;
   if(music_enabled)begin
    if(music_counter==(10000<<SPEED)-1)begin
     if(music_pending)$fatal(1,"music IRQ was not acknowledged");
     music_counter<=0;music_pending<=1;
    end else music_counter<=music_counter+1;
   end
  end
 end
 task send;input[7:0]b;reg[10:0]frame;integer bit_index;
  begin
   frame={1'b1,~^b,b,1'b0};
   for(bit_index=0;bit_index<11;bit_index=bit_index+1)begin
    psdata=frame[bit_index];#10000;psclk=0;#30000;psclk=1;#30000;
   end
   psdata=1;#10000;
  end
 endtask
 integer key_index,accepted=0,released_count;reg armed=0,holding=0;
 integer first_held,last_held;
 reg[7:0]scan[0:7],expected[0:7];
 wire[7:0]timer0=memory[16'hed09>>1][15:8],timer1=memory[16'hed0a>>1][7:0],timer2=memory[16'hed0b>>1][15:8];
 initial begin
  $readmemh("build/keyboard-sram.mem",memory);
  memory[20'h20ffe>>1]=16'h00e0; // SRAM word lanes hold the big-endian vector bytes E0,00.
  scan[0]=8'h16;scan[1]=8'h1e;scan[2]=8'h26;scan[3]=8'h26;
  scan[4]=8'h25;scan[5]=8'h2e;scan[6]=8'h36;scan[7]=8'h3d;
  expected[0]="1";expected[1]="2";expected[2]="3";expected[3]="3";
  expected[4]="4";expected[5]="5";expected[6]="6";expected[7]="7";
  wait(cpu_reset===0);
  #30000000;armed=1;
  for(key_index=0;key_index<8;key_index=key_index+1)begin
   send(scan[key_index]);#2000000;send(8'hf0);send(scan[key_index]);
   #20000000;
  end
  wait(accepted==8);#20000000;
  if(raw_fifo.count!=0||keyboard.data!=8'hff)$fatal(1,"keyboard did not drain");
  #160000000;holding=1;
  send(8'h3e); // Hold 8; BIOS owns the initial repeat delay and rate.
  #200000000;
  if(accepted!=9)$fatal(1,"premature held repeat accepted=%0d",accepted);
  send(8'h3e);send(8'h3e); // PS/2 typematic duplicates must not enqueue taps.
  #700000000;
  if(accepted<12)$fatal(1,"native BIOS autorepeat missing accepted=%0d",accepted);
  send(8'hf0);send(8'h3e);
  #100000000;released_count=accepted;
  #200000000;
  if(accepted!=released_count||raw_fifo.count!=0||keyboard.data!=8'hff)
   $fatal(1,"autorepeat continued after release");
  if({memory[16'he180>>1][7:0],memory[16'he180>>1][15:8]}<100)
   $fatal(1,"shared 100-Hz music IRQ did not run");
  $display("PASS actual HDL CPU/native BIOS core: 8 fast taps, held BIOS repeat/delay/rate, typematic/break and 100-Hz audio IRQ at %0d MHz",1<<SPEED);
  $finish;
 end
 always @(negedge clk)if(armed&&bus_write&&cpu_addr>=16'hbff0&&cpu_addr<16'hc000)begin
  $display("BIOS key %0d = %h at %0t",accepted,cpu_out,$time);
  if(!holding)begin
   if(accepted>=8||cpu_out!==expected[accepted])$fatal(1,"BIOS key order got=%h expected[%0d]=%h",cpu_out,accepted,expected[accepted]);
  end else begin
   if(cpu_out!=="8")$fatal(1,"held BIOS key changed: %h",cpu_out);
   if(accepted==8)first_held=cycles;
   else if(accepted==9)begin
    if(cycles-first_held<(560000<<SPEED)||cycles-first_held>(760000<<SPEED))
     $fatal(1,"native initial repeat delay %0d CPU clocks",cycles-first_held);
   end else if(cycles-last_held<(40000<<SPEED)||cycles-last_held>(100000<<SPEED))
    $fatal(1,"native repeat interval %0d CPU clocks",cycles-last_held);
   last_held=cycles;
  end
  accepted=accepted+1;
 end
 initial begin #3000000000;$fatal(1,"BIOS keyboard timeout PC=%h accepted=%0d",cpu_addr,accepted);end
endmodule

`timescale 1ps/1ps
module keyboard_test_cpu_clock #(parameter SPEED=0)(output reg clk=0);
 generate
  if(SPEED==0)always #500000 clk=~clk;
  else if(SPEED==1)always #250000 clk=~clk;
  else if(SPEED==2)always #125000 clk=~clk;
  else always #62500 clk=~clk;
 endgenerate
endmodule
