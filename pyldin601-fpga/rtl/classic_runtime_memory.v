// One SRAM sequencer for bootstrap, CPU and video on the 96 MHz PLL output.
// Six-clock slots (62.5 ns); CPU slots repeat every 96/48/24/12 clocks.
// CPU read OE starts at launch, capture at +3 clocks (31.25 ns). Other reads
// start OE at +1, capture at +5. SRAM-10 budget: 6 ns pad + 10 ns access +
// 4 ns PCB + 8 ns FPGA input = 28 ns. CPU result has a separate 27 ns bound.
// Write: DQ/WE-low at +1, WE-high at +3, DQ-off at +4. With pad bounds DQ10.5,
// WE6 and <=4 ns board skew: tAS/tDH >=0.417 ns, tSD >=6.333 ns. Two clocks
// between DQ-off and the next early read prevent bus contention. No HOLD.
module classic_runtime_memory #(parameter GFX=0)(
 input wire clk,reset,locked,cpu_reset,input wire prepare,
 input wire cpu_vma,cpu_rw,peripheral,input wire[20:0]cpu_address,input wire[7:0]cpu_data,
 input wire video_request,input wire[20:0]video_address,input wire pause_video,
 input wire boot_request,boot_write,input wire[20:0]boot_address,input wire[7:0]boot_data,
 output reg boot_accept,boot_done,output reg[7:0]boot_result,
 output reg video_accept,video_done,output reg[7:0]video_data,cpu_result,
 output wire busy,output reg[19:0]SRAM_ADDR,inout wire[15:0]SRAM_DATA,
 output reg SRAM_CE,SRAM_OE,SRAM_WE,SRAM_LB,SRAM_UB,
 input wire gfx_request,gfx_write,gfx_word,input wire[20:0]gfx_address,input wire[15:0]gfx_data,
 output reg gfx_ready,gfx_done,output reg[15:0]gfx_result /* synthesis syn_useioff=0 */
);
 reg phase_one,aligned;reg grant_cpu,grant_boot,grant_video,grant_gfx;
 reg[1:0]prepare_sync=0,locked_sync=0,reset_sync=3,cpu_reset_sync=3,pause_sync=0;
 always @(posedge clk)begin
  prepare_sync<={prepare_sync[0],prepare};locked_sync<={locked_sync[0],locked};
  reset_sync<={reset_sync[0],reset};cpu_reset_sync<={cpu_reset_sync[0],cpu_reset};
  pause_sync<={pause_sync[0],pause_video};
 end
 reg[2:0]slot,count;
 reg active,writing,lane,video_owner,boot_owner,gfx_owner,gfx_wide,drive;reg[7:0]held_data;
 // Bundled video address is stable before its four-stage request arrives.
 reg[3:0]video_sync,boot_sync;
 wire cpu_event=prepare_sync[1]&&!phase_one;
 wire slot_event=aligned&&slot==0;
 wire cpu_memory=cpu_event&&!cpu_reset_sync[1]&&cpu_vma&&!peripheral;
 wire boot_memory=slot_event&&!cpu_event&&!cpu_reset_sync[1]&&!locked_sync[1]&&(boot_sync[3]!=boot_accept);
 wire video_memory=slot_event&&!cpu_event&&!boot_memory&&!cpu_reset_sync[1]&&!pause_sync[1]&&(video_sync[3]!=video_accept);
 wire gfx_memory=GFX&&slot_event&&!cpu_event&&!boot_memory&&!video_memory&&!cpu_reset_sync[1]&&!pause_sync[1]&&gfx_request;
 wire[20:0]chosen_address=grant_cpu?cpu_address:grant_boot?boot_address:grant_video?video_address:gfx_address;
 // All ROM pages, BIOS and font stay locked throughout warm resets.
 wire protected_address=cpu_address>=21'h10000&&cpu_address<21'h21800;
 assign busy=active;
 // Both lanes carry the same byte; exactly one byte-enable permits writing.
 assign SRAM_DATA=drive?{held_data,held_data}:16'bz;
 always @(posedge clk)begin
  if(reset_sync[1])begin
   phase_one<=0;aligned<=0;grant_cpu<=0;grant_boot<=0;grant_video<=0;grant_gfx<=0;slot<=0;count<=0;active<=0;
   gfx_owner<=0;gfx_wide<=0;gfx_ready<=0;gfx_done<=0;gfx_result<=0;
   writing<=0;lane<=0;video_owner<=0;boot_owner<=0;drive<=0;held_data<=0;video_sync<=0;boot_sync<=0;boot_accept<=0;boot_done<=0;boot_result<=0;
   video_accept<=0;video_done<=0;video_data<=0;cpu_result<=8'hff;
   SRAM_ADDR<=0;SRAM_CE<=1;SRAM_OE<=1;SRAM_WE<=1;SRAM_LB<=1;SRAM_UB<=1;
  end else begin
   gfx_ready<=0;gfx_done<=0;
   phase_one<=prepare_sync[1];
   // Choose the next slot one fast edge before the pad registers launch it.
   grant_cpu<=cpu_memory;grant_boot<=boot_memory;grant_video<=video_memory;grant_gfx<=gfx_memory;
   // Source prepare is a registered 24 MHz pulse, never a decoded multi-bit
   // counter crossing. Two synchronizer stages precede the snapshot.
   video_sync<={video_sync[2:0],video_request};boot_sync<={boot_sync[2:0],boot_request};
   if(cpu_event)begin aligned<=1;slot<=5;end
   else if(aligned)slot<=slot==0?5:slot-1'b1;
   if(active)begin
    count<=count+1'b1;
    case(count)
     1:begin SRAM_OE<=writing;drive<=writing;if(writing)SRAM_WE<=0;end
     3:begin
      SRAM_WE<=1;
      if(!writing&&!boot_owner&&!video_owner&&!gfx_owner)begin
       cpu_result<=lane?SRAM_DATA[15:8]:SRAM_DATA[7:0];SRAM_OE<=1;
      end
     end
     4:drive<=0;
     5:begin
      if(!writing)begin
       if(gfx_owner)gfx_result<=gfx_wide?SRAM_DATA:{8'b0,lane?SRAM_DATA[15:8]:SRAM_DATA[7:0]};
       else if(boot_owner)boot_result<=lane?SRAM_DATA[15:8]:SRAM_DATA[7:0];
       else if(video_owner)begin video_data<=lane?SRAM_DATA[15:8]:SRAM_DATA[7:0];video_done<=video_accept;end

      end
      drive<=0;SRAM_OE<=1;active<=0;if(boot_owner)boot_done<=boot_accept;if(gfx_owner)gfx_done<=1;
      if(!writing)begin SRAM_CE<=1;SRAM_LB<=1;SRAM_UB<=1;end
     end
    endcase
   end else if(grant_cpu||grant_boot||grant_video||grant_gfx)begin
    active<=1;count<=1;video_owner<=grant_video;boot_owner<=grant_boot;gfx_owner<=grant_gfx;gfx_wide<=gfx_word;
    writing<=(grant_cpu&&!cpu_rw&&!(locked_sync[1]&&protected_address))||(grant_boot&&boot_write)||(grant_gfx&&gfx_write);
    drive<=0;
    held_data<=grant_boot?boot_data:grant_gfx?gfx_data[7:0]:cpu_data;lane<=chosen_address[0];SRAM_ADDR<=chosen_address[20:1];
    SRAM_CE<=0;
    // Previous write released DQ two clocks before this early CPU read.
    SRAM_OE<=!(grant_cpu&&cpu_rw);SRAM_WE<=1;
    SRAM_LB<=grant_gfx&&gfx_word?1'b0:chosen_address[0];SRAM_UB<=grant_gfx&&gfx_word?1'b0:!chosen_address[0];
    if(grant_gfx)gfx_ready<=1;
    if(grant_video)begin video_accept<=video_sync[3];end
    if(grant_boot)begin boot_accept<=boot_sync[3];end
   end else begin drive<=0;SRAM_CE<=1;SRAM_OE<=1;SRAM_LB<=1;SRAM_UB<=1;end
  end
 end
endmodule
