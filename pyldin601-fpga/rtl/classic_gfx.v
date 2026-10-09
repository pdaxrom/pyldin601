// Indexed 320x200 extension. All DMA addresses are in 100000..1fffff.
// CPU commands cross as a held bundle plus a toggle, with one outstanding job.
// The 96 MHz engine gives scanline fetches priority over the byte blitter.
module classic_gfx(
 input wire clk,fast,reset,bus_write,input wire[3:0]address,input wire[7:0]bus_data,
 output reg[7:0]bus_result,output reg enabled,
 input wire line_request,input wire[7:0]line_y,input wire vblank,
 input wire[8:0]pixel_x,input wire pixel_bank,output wire[7:0]pixel,
 output wire mem_request,output reg mem_write,mem_word,output reg[20:0]mem_address,
 output reg[15:0]mem_data,input wire mem_ready,mem_done,input wire[15:0]mem_result
);
 reg[7:0]job_command,job_colour,job_height;reg[8:0]job_width;
 reg[3:0]job_source_page,job_destination_page;
 reg[15:0]job_source_offset,job_destination_offset;
 reg token;reg[1:0]done_sync,error_sync,under_sync;reg[7:0]read_byte;
 reg finished,failed,underrun;reg[7:0]fast_read;
 wire busy=token!=done_sync[1];
 reg[3:0]front_page;reg[3:0]front_sync1,front_sync2;
 always @*begin
  bus_result=8'hff;
  case(address)
   0:bus_result={busy,1'b0,under_sync[1],error_sync[1],3'b0,enabled};
   1:bus_result=job_command;2:bus_result={4'b0,front_sync2};3:bus_result=job_colour;
   4:bus_result={4'b0,job_source_page};5:bus_result={4'b0,job_destination_page};
   6:bus_result=job_source_offset[7:0];7:bus_result=job_source_offset[15:8];
   8:bus_result=job_destination_offset[7:0];9:bus_result=job_destination_offset[15:8];
   10:bus_result=job_width[7:0];11:bus_result={7'b0,job_width[8]};12:bus_result=job_height;
   13:bus_result=read_byte;14:bus_result=8'h47;15:bus_result=3;
  endcase
 end
 always @(posedge clk)begin
  done_sync<={done_sync[0],finished};error_sync<={error_sync[0],failed};under_sync<={under_sync[0],underrun};
  front_sync1<=front_page;front_sync2<=front_sync1;
  if(reset)begin
   enabled<=0;token<=0;job_command<=0;job_colour<=0;job_height<=0;job_width<=0;
   job_source_page<=0;job_destination_page<=0;job_source_offset<=0;job_destination_offset<=0;read_byte<=0;
  end else begin
   if(!busy)read_byte<=fast_read;
   if(bus_write)begin
    if(address==0)enabled<=bus_data[0];
    else if(!busy)case(address)
     1:begin job_command<=bus_data;token<=!token;end
     3:job_colour<=bus_data;4:job_source_page<=bus_data[3:0];5:job_destination_page<=bus_data[3:0];
     6:job_source_offset[7:0]<=bus_data;7:job_source_offset[15:8]<=bus_data;
     8:job_destination_offset[7:0]<=bus_data;9:job_destination_offset[15:8]<=bus_data;
     10:job_width[7:0]<=bus_data;11:job_width[8]<=bus_data[0];12:job_height<=bus_data;
    endcase
   end
  end
 end
 // One dual-clock EBR, 2 x 160 words. Port B is read synchronously by video.
 (* syn_ramstyle="block_ram" *) reg[15:0]cache[0:511];
 reg[15:0]pixel_pair;reg pixel_lane,pixel_valid;reg[1:0]valid_sync1,valid_sync2,valid_banks;
 always @(posedge clk)begin
  valid_sync1<=valid_banks;valid_sync2<=valid_sync1;
  pixel_pair<=cache[{pixel_bank,pixel_x[8:1]}];pixel_lane<=pixel_x[0];pixel_valid<=valid_sync2[pixel_bank];
 end
 assign pixel=!pixel_valid?8'd0:pixel_lane?pixel_pair[15:8]:pixel_pair[7:0];
 reg[2:0]reset_sync;reg[3:0]command_sync,line_sync,vblank_sync;reg[1:0]enable_sync;
 always @(posedge fast)begin
  reset_sync<={reset_sync[1:0],reset};command_sync<={command_sync[2:0],token};
  line_sync<={line_sync[2:0],line_request};vblank_sync<={vblank_sync[2:0],vblank};
  enable_sync<={enable_sync[0],enabled};
 end
 reg line_seen,vblank_seen,fetching,fetch_bank,waiting,owner_video,issued,request_video;
 reg[7:0]fetch_column;reg[15:0]fetch_offset;
 reg[3:0]fetch_page;
 reg[15:0]src,dst;
 reg[8:0]remaining;reg[7:0]rows;
 reg reverse;reg[7:0]copy_byte;reg copy_read,skip_write;
 reg[3:0]state;
 localparam IDLE=0,CHECK=1,BLIT=2,READ_ONE=3,FLIP=4,KEY=5;
 wire byte_command=job_command==4||job_command==5;
 wire copy_command=job_command==2||job_command==6;
 wire[7:0]last_row=job_height-1'b1;
 wire[16:0]span=byte_command?17'd0:({1'b0,last_row,8'b0}+{3'b0,last_row,6'b0}+job_width-17'd1);
 wire[16:0]source_end={1'b0,job_source_offset}+span;
 wire[16:0]destination_end={1'b0,job_destination_offset}+span;
 wire bounds=(byte_command||(job_width!=0&&job_width<=320&&job_height!=0&&job_height<=200))
  &&(!copy_command&&job_command!=5||source_end<64000)&&(job_command==5||destination_end<64000);
 wire[15:0]row_step=16'd321-job_width;
 // Pointer calculation settles while the SRAM transaction is in flight.
 // Separate the row-end decoder, adder and completion mux at 96 MHz.
 reg[15:0]advance_step,next_src,next_dst;
 reg last_column,last_pixel;reg[8:0]next_remaining;reg[7:0]next_rows;
 always @(posedge fast)begin
  last_column<=remaining==1;last_pixel<=remaining==1&&rows==1;
  next_remaining<=remaining-1'b1;next_rows<=rows-1'b1;
  advance_step<=reverse?(last_column?-row_step:16'hffff):(last_column?row_step:16'd1);
  next_src<=src+advance_step;next_dst<=dst+advance_step;
 end
 wire job_request=state==BLIT||state==READ_ONE;
 wire pixel_complete=(state==KEY&&skip_write)||
   (waiting&&mem_done&&!owner_video&&state==BLIT&&!copy_read);
 assign mem_request=issued&&!waiting;
 always @(posedge fast)begin
  if(reset_sync[2])begin
   finished<=0;failed<=0;underrun<=0;front_page<=0;fast_read<=0;
   line_seen<=0;vblank_seen<=0;fetching<=0;fetch_bank<=0;fetch_column<=0;
   fetch_offset<=0;fetch_page<=0;valid_banks<=0;waiting<=0;owner_video<=0;issued<=0;request_video<=0;
   mem_write<=0;mem_word<=0;mem_address<=21'h100000;mem_data<=0;
   src<=0;dst<=0;remaining<=0;rows<=0;reverse<=0;copy_byte<=0;copy_read<=0;skip_write<=0;state<=IDLE;
  end else begin
   if(!enable_sync[1])begin valid_banks<=0;underrun<=0;end
   // A flip becomes visible only at the field boundary, before line 0 fetch.
   vblank_seen<=vblank_sync[3];
   if(state==FLIP&&vblank_seen!=vblank_sync[3])begin
    front_page<=job_destination_page;state<=IDLE;finished<=command_sync[3];
   end
   if(line_seen!=line_sync[3])begin
    line_seen<=line_sync[3];
    if(enable_sync[1])begin
     if(fetching)underrun<=1;
     else begin
      fetching<=1;fetch_column<=0;fetch_bank<=line_y[0];fetch_page<=front_page;
      fetch_offset<={line_y,8'b0}+{2'b0,line_y,6'b0};
      valid_banks[line_y[0]]<=0;
     end
    end
   end
   if(state==IDLE&&command_sync[3]!=finished)begin
    failed<=0;src<=job_source_offset;dst<=job_destination_offset;
    remaining<=byte_command?9'd1:job_width;rows<=byte_command?8'd1:job_height;
    copy_read<=copy_command;reverse<=copy_command&&job_source_page==job_destination_page&&job_destination_offset>job_source_offset;
    if(job_command==3)state<=FLIP;
    else if(job_command==1||copy_command||byte_command)state<=CHECK;
    else begin failed<=1;finished<=command_sync[3];end
   end
   if(state==CHECK)begin
    if(!bounds)begin failed<=1;state<=IDLE;finished<=command_sync[3];end
    else begin
     if(reverse)begin src<=source_end[15:0];dst<=destination_end[15:0];end
     state<=job_command==5?READ_ONE:BLIT;
    end
   end
   // Register the comparison on read completion. It must not share the
   // 96 MHz path with the rectangle counters and pointer completion muxes.
   if(state==KEY&&!skip_write)begin copy_read<=0;state<=BLIT;end
   if(!issued&&!waiting&&(fetching||job_request))begin
    issued<=1;request_video<=fetching;mem_word<=fetching;
    mem_write<=!fetching&&state==BLIT&&!copy_read;
    mem_address<=fetching?{1'b1,fetch_page,fetch_offset}:
      copy_read||state==READ_ONE?{1'b1,job_source_page,src}:{1'b1,job_destination_page,dst};
    mem_data<={job_colour,(copy_command?copy_byte:job_colour)};
   end
   if(mem_request&&mem_ready)begin waiting<=1;issued<=0;owner_video<=request_video;end
   if(waiting&&mem_done)begin
    waiting<=0;
    if(owner_video)begin
     cache[{fetch_bank,fetch_column}]<=mem_result;
     fetch_offset<=fetch_offset+16'd2;
     if(fetch_column==159)begin fetching<=0;valid_banks[fetch_bank]<=1;end
     else fetch_column<=fetch_column+1'b1;
    end else if(state==READ_ONE)begin
     fast_read<=mem_result[7:0];finished<=command_sync[3];state<=IDLE;
    end else if(copy_read)begin
     copy_byte<=mem_result[7:0];
     if(job_command==6)begin skip_write<=mem_result[7:0]==job_colour;state<=KEY;end
     else copy_read<=0;
    end
   end
   if(pixel_complete)begin
     // Keyed pixels skip the destination transaction entirely. Both kinds
     // of COPY advance through the same overlap-safe traversal.
     state<=BLIT;
     copy_read<=copy_command;
     if(last_pixel)begin state<=IDLE;finished<=command_sync[3];end
     else if(last_column)begin
      remaining<=job_width;rows<=next_rows;
      src<=next_src;dst<=next_dst;
     end else begin
      remaining<=next_remaining;src<=next_src;dst<=next_dst;
     end
   end
  end
 end
endmodule
