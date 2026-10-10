// AY-3-8910 generators, using the BK's digital behaviour and volume curve.
// Default 2 MHz master; programmable Q16 divisor for the master/8 tick.
// One nine-bit ALU, two-byte counters and one EBR serve all five generators;
// neither the CPU nor the video SRAM participates in sound generation.
module classic_ay8910 # (parameter MEMORY_FILE="rtl/ay8910.mem")(
 input wire clk,fast,reset,write,
 input wire[3:0]register_address,input wire[7:0]data,
 output wire[7:0]result,output wire audio,input wire beeper,
 input wire divider_update,input wire[31:0]divider_value,output reg divider_seen
);
 (* syn_keep=1 *) wire[8:0]cpu_value;
 wire[8:0]word;
 reg[3:0]write_address;
 reg[7:0]write_data;
 reg write_token,write_seen,env_dirty;
 wire[7:0]masked_data=(register_address==1||register_address==3||register_address==5||register_address==13)?data&8'h0f:
  (register_address==6||register_address==8||register_address==9||register_address==10)?data&8'h1f:data;
 always @(posedge clk)begin
  if(reset)begin write_token<=0;write_address<=0;write_data<=0;end
  else if(write)begin write_address<=register_address;write_data<=masked_data;write_token<=!write_token;end
 end
 // Unconnected GPIO pins read high; their output latches are retained.
 assign result=register_address[3:1]==7?8'hff:cpu_value[7:0];
 reg initializing;reg[4:0]init_address;
 reg[2:0]state;
 reg[5:0]pc;
 reg[8:0]instruction;
 reg[15:0]clock_count,clock_period,clock_fraction;
 reg[15:0]clock_before_last;
 reg[31:0]clock_divider;
 reg[1:0]divider_sync;
 reg[1:0]fast_reset_sync;
 // Reset originates in the 24-MHz domain. Register it locally instead of
 // driving the fast engine through the system's high-fanout reset decode.
 always @(posedge fast)fast_reset_sync<={fast_reset_sync[0],reset};
 wire fast_reset=fast_reset_sync[1];
 reg[16:0]fraction_sum;
 reg clock_terminal;
 reg[7:0]period_low,count_low;
 reg[8:0]period_high,count_high;
 reg carry,terminal;
 reg[2:0]tone;
 reg noise_prescale;
 reg[16:0]noise_lfsr;
 reg[3:0]env_step;
 reg env_attack,env_holding;
 reg[5:0]mixer;
 reg[3:0]volume;
 reg[8:0]mix,sample;
 wire[3:0]operation=instruction[8:5];
 wire[1:0]channel=instruction[1:0];
 reg[8:0]operand,incremented;
 wire expired=incremented>period_high||(incremented==period_high&&count_low>=period_low);
 wire[3:0]env_level=env_step^{4{env_attack}};
 wire gate=(tone[channel]||mixer[channel])&&(noise_lfsr[0]||mixer[{1'b0,channel}+3'd3]);
 // Related PLL clocks: one outstanding CPU command, serviced within five
 // fast cycles. The fastest CPU bus writes are twelve fast cycles apart.
 wire service_write=!initializing&&write_token!=write_seen&&(state==0||state==4&&operation==13&&!clock_terminal);
 wire[9:0]engine_address=service_write?{6'b0,write_address}:initializing?{5'b0,init_address}:
  state<2?{4'b1000,pc}:
  operation==12?{6'b000010,volume}:{5'b0,instruction[4:0]};
 wire engine_write=service_write||initializing||(state==4&&(operation==4||operation==5));
 wire[8:0]engine_data=service_write?{1'b0,write_data}:initializing||terminal?9'b0:
  operation==5?count_high:{1'b0,count_low};
`ifdef SYNTHESIS
 // Explicit TDP avoids Synplify replicating the CPU read port into a
 // second EBR. Both physical ports are checked with Lattice's RAM model.
 // In x9 mode ADA0 is the byte-write enable, not an address bit.
 wire[12:0]aa={engine_address,2'b0,1'b1},ab={6'b0,register_address,3'b0};
 DP8KC #(
  .DATA_WIDTH_A(9),.DATA_WIDTH_B(9),.REGMODE_A("NOREG"),.REGMODE_B("NOREG"),
  .WRITEMODE_A("READBEFOREWRITE"),.WRITEMODE_B("READBEFOREWRITE"),
  `include "rtl/ay8910_init.vh"
 ) ram(
  .CLKA(fast),.CEA(1'b1),.OCEA(1'b1),.WEA(engine_write&&!fast_reset),.RSTA(1'b0),
  .CLKB(clk),.CEB(1'b1),.OCEB(1'b1),.WEB(1'b0),.RSTB(1'b0),
  .CSA0(1'b0),.CSA1(1'b0),.CSA2(1'b0),.CSB0(1'b0),.CSB1(1'b0),.CSB2(1'b0),
  .ADA0(aa[0]),.ADA1(aa[1]),.ADA2(aa[2]),.ADA3(aa[3]),.ADA4(aa[4]),.ADA5(aa[5]),.ADA6(aa[6]),
  .ADA7(aa[7]),.ADA8(aa[8]),.ADA9(aa[9]),.ADA10(aa[10]),.ADA11(aa[11]),.ADA12(aa[12]),
  .ADB0(ab[0]),.ADB1(ab[1]),.ADB2(ab[2]),.ADB3(ab[3]),.ADB4(ab[4]),.ADB5(ab[5]),.ADB6(ab[6]),
  .ADB7(ab[7]),.ADB8(ab[8]),.ADB9(ab[9]),.ADB10(ab[10]),.ADB11(ab[11]),.ADB12(ab[12]),
  .DIA0(engine_data[0]),.DIA1(engine_data[1]),.DIA2(engine_data[2]),.DIA3(engine_data[3]),.DIA4(engine_data[4]),
  .DIA5(engine_data[5]),.DIA6(engine_data[6]),.DIA7(engine_data[7]),.DIA8(engine_data[8]),
  .DIB0(1'b0),.DIB1(1'b0),.DIB2(1'b0),.DIB3(1'b0),.DIB4(1'b0),.DIB5(1'b0),.DIB6(1'b0),.DIB7(1'b0),.DIB8(1'b0),
  .DOA0(word[0]),.DOA1(word[1]),.DOA2(word[2]),.DOA3(word[3]),.DOA4(word[4]),.DOA5(word[5]),
  .DOA6(word[6]),.DOA7(word[7]),.DOA8(word[8]),.DOB0(cpu_value[0]),.DOB1(cpu_value[1]),.DOB2(cpu_value[2]),
  .DOB3(cpu_value[3]),.DOB4(cpu_value[4]),.DOB5(cpu_value[5]),.DOB6(cpu_value[6]),.DOB7(cpu_value[7]),.DOB8(cpu_value[8])
 );
`else
 reg[8:0]memory[1023:0];reg[8:0]engine_read,cpu_read;
 initial $readmemh(MEMORY_FILE,memory,0,1023);
 always @(posedge fast)begin
  engine_read<=memory[engine_address];
  if(engine_write&&!fast_reset)memory[engine_address]<=engine_data;
 end
 always @(posedge clk)cpu_read<=memory[{6'b0,register_address}];
 assign word=engine_read;assign cpu_value=cpu_read;
`endif
 always @(posedge fast)begin
  divider_sync<={divider_sync[0],divider_update};
  if(fast_reset)begin
   initializing<=1;init_address<=0;state<=0;pc<=0;clock_count<=0;clock_terminal<=0;
   period_low<=0;period_high<=0;count_low<=0;count_high<=0;carry<=0;terminal<=0;operand<=0;incremented<=0;
   tone<=0;noise_prescale<=0;noise_lfsr<=1;write_seen<=0;env_dirty<=0;
   clock_divider<=32'h01800000;clock_period<=384;clock_before_last<=382;clock_fraction<=0;fraction_sum<=0;divider_seen<=0;divider_sync<=0;
   env_step<=0;env_attack<=0;env_holding<=1;mixer<=0;mix<=0;sample<=0;instruction<=0;volume<=0;
  end else if(initializing)begin
   if(init_address==25)begin initializing<=0;clock_count<=0;end
   else init_address<=init_address+1'b1;
  end else begin
   // Period/fraction change only at chip ticks, at least 384 clocks apart.
   // Pipeline arithmetic before the comparator to meet the 96-MHz engine.
   clock_before_last<=clock_period-2;
   fraction_sum<={1'b0,clock_fraction}+{1'b0,clock_divider[15:0]};
   if(clock_terminal)begin
    clock_count<=0;
    if(divider_sync[1]!=divider_seen)begin
     clock_divider<=divider_value;clock_period<=divider_value[31:16];clock_fraction<=0;
     divider_seen<=divider_sync[1];
    end else begin
     clock_fraction<=fraction_sum[15:0];
     clock_period<=clock_divider[31:16]+fraction_sum[16];
    end
   end else begin
    // Independent nibble counters keep the initialization enable out of a
    // sixteen-bit ripple chain. Carries come from the previous count.
    clock_count[3:0]<=clock_count[3:0]+1'b1;
    clock_count[7:4]<=clock_count[7:4]+(&clock_count[3:0]);
    clock_count[11:8]<=clock_count[11:8]+(&clock_count[7:0]);
    clock_count[15:12]<=clock_count[15:12]+(&clock_count[11:0]);
   end
   // Look ahead by one fast edge: this flag is true exactly when count is
   // The divider is applied only at a chip-tick boundary. Period writes do
   // not restart tone/noise/envelope or form a shortened chip tick.
   clock_terminal<=clock_count==clock_before_last;
   if(service_write)begin
    write_seen<=write_token;
    if(write_address==13)env_dirty<=1;
   end else case(state)
    0:state<=1;
    1:begin instruction<=word;state<=2;end
    2:state<=3;
    // Separate the EBR's clock-to-output and increment from the comparison.
    // 43 instructions take 215 clocks, leaving room for CPU register writes
    // within the same fixed 384-clock sound tick.
    3:begin operand<=word;incremented<=word+(operation==2?!(instruction[3]&&env_holding):carry);state<=4;end
    4:begin
     if(operation!=13)begin state<=0;pc<=pc+1'b1;end
     else if(clock_terminal)begin state<=0;pc<=0;end
     case(operation)
      0:begin period_low<=operand[7:0];period_high<=0;end
      1:period_high<={1'b0,operand[7:0]};
      2:begin count_low<=incremented[7:0];carry<=incremented[8];end
      3:begin count_high<=incremented;terminal<=expired;end
      6:if(terminal)tone[channel]<=!tone[channel];
      7:if(terminal)begin
       noise_prescale<=!noise_prescale;
       if(noise_prescale)noise_lfsr<={noise_lfsr[0]^noise_lfsr[3],noise_lfsr[16:1]};
      end
      8:begin
       if(env_dirty)begin
        terminal<=1;env_dirty<=0;env_step<=15;env_attack<=operand[2];env_holding<=0;
       end else if(terminal&&!env_holding)begin
        if(env_step!=0)env_step<=env_step-1'b1;
        else if(!operand[3])begin env_step<=0;env_attack<=0;env_holding<=1;end
        else if(operand[0])begin env_step<=0;env_holding<=1;if(operand[1])env_attack<=!env_attack;end
        else begin env_step<=15;if(operand[1])env_attack<=!env_attack;end
       end
      end
      9:mixer<=operand[5:0];
      10:volume<=gate?(operand[4]?env_level:operand[3:0]):4'b0;
      11:mix<=0;
      12:mix<=mix+operand;
      13:sample<=mix;
      14:begin period_low<={operand[6:0],1'b0};carry<=operand[7];end
      15:period_high<={operand[7:0],carry};
     endcase
    end
   endcase
  end
 end
 reg[8:0]mixed;reg[9:0]sigma;
 always @(posedge clk)begin
  if(reset)begin mixed<=0;sigma<=0;end
  else begin
   mixed<=sample+(beeper?9'd128:9'd0);
   sigma<={1'b0,sigma[8:0]}+{1'b0,mixed};
  end
 end
 // Sigma is cleared synchronously above. Drive the pad from its flip-flop
 // without placing the system reset decode in the audio output path.
 assign audio=sigma[9];
endmodule
