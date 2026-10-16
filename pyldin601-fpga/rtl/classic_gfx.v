// Indexed/HAM scanout and legacy frontend for the shared physical DMA engine.
// CPU commands cross as a held bundle plus a toggle, with one outstanding job.
// The 96 MHz engine gives scanline fetches priority over the byte blitter.
module classic_gfx(
 input wire clk,fast,reset,bus_write,input wire[3:0]address,input wire[7:0]bus_data,
 output reg[7:0]bus_result,output reg enabled,
 input wire line_request,input wire[7:0]line_y,input wire vblank,
 input wire[8:0]pixel_x,input wire pixel_bank,output wire[7:0]pixel,
 output wire mem_request,output reg mem_write,mem_word,output reg[20:0]mem_address,
 output reg[15:0]mem_data,input wire mem_ready,mem_done,input wire[15:0]mem_result,
 output wire[17:0]pixel_rgb,
 input wire dma_io_read,dma_io_write,input wire[1:0]dma_io_address,output wire[7:0]dma_result,
 output wire palette_owned,palette_write,output wire[3:0]palette_register,output wire[7:0]palette_data,
 input wire[5:0]palette_result,input wire palette_read_mode
);
 reg[7:0]job_command,job_colour,job_height;reg[8:0]job_width;
 reg format,layered;reg[3:0]background_page;
 reg[3:0]job_source_page,job_destination_page;
 reg[15:0]job_source_offset,job_destination_offset;
 reg token;reg[1:0]done_sync,error_sync,under_sync;reg[7:0]read_byte;
 reg finished,failed,underrun;reg[7:0]fast_read;
 wire legacy_busy=token!=done_sync[1];
 wire dma_busy;wire busy=legacy_busy||dma_busy;
 reg[3:0]front_page;reg[3:0]front_sync1,front_sync2;
 always @*begin
  bus_result=8'hff;
  case(address)
   0:bus_result={busy,1'b0,under_sync[1],error_sync[1],layered,{2{format}},enabled};
   1:bus_result=job_command;2:bus_result={4'b0,front_sync2};3:bus_result=job_colour;
   4:bus_result={4'b0,job_source_page};5:bus_result={4'b0,job_destination_page};
   6:bus_result=job_source_offset[7:0];7:bus_result=job_source_offset[15:8];
   8:bus_result=job_destination_offset[7:0];9:bus_result=job_destination_offset[15:8];
   10:bus_result=job_width[7:0];11:bus_result={7'b0,job_width[8]};12:bus_result=job_height;
   13:bus_result=read_byte;14:bus_result=8'h47;15:bus_result=6;
  endcase
 end
 always @(posedge clk)begin
  done_sync<={done_sync[0],finished};error_sync<={error_sync[0],failed};under_sync<={under_sync[0],underrun};
  front_sync1<=front_page;front_sync2<=front_sync1;
  if(reset)begin
   enabled<=0;format<=0;layered<=0;background_page<=0;token<=0;job_command<=0;job_colour<=0;job_height<=0;job_width<=0;
   job_source_page<=0;job_destination_page<=0;job_source_offset<=0;job_destination_offset<=0;read_byte<=0;
  end else begin
   if(!busy)read_byte<=fast_read;
   if(bus_write)begin
    if(address==0)begin
     enabled<=bus_data[0];format<=bus_data[2:1]==3;
     layered<=bus_data[3]&&bus_data[2:1]==3;
     // Latch the underlay at mode entry; subsequent COPY descriptors are
     // independent of this full, unmodified HAM8 background stream.
     if(bus_data[3]&&bus_data[2:1]==3)background_page<=job_source_page;
    end
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
 // Two dual-clock EBRs, 2 x 160 pairs. Ordinary modes use the low 16 bits;
 // layered HAM8 stores two full RGB666 pixels without colour quantization.
 (* syn_ramstyle="block_ram" *) reg[35:0]cache[0:511];
 reg[35:0]pixel_pair;reg pixel_lane,pixel_valid;reg[1:0]valid_sync1,valid_sync2,valid_banks;
 always @(posedge clk)begin
  valid_sync1<=valid_banks;valid_sync2<=valid_sync1;
  pixel_pair<=cache[{pixel_bank,pixel_x[8:1]}];pixel_lane<=pixel_x[0];pixel_valid<=valid_sync2[pixel_bank];
 end
 assign pixel=!pixel_valid?8'd0:pixel_lane?pixel_pair[15:8]:pixel_pair[7:0];
 assign pixel_rgb=!pixel_valid?18'd0:pixel_lane?pixel_pair[35:18]:pixel_pair[17:0];
 reg[2:0]reset_sync;reg[3:0]command_sync,line_sync,vblank_sync;reg[1:0]enable_sync,layer_sync;
 reg[3:0]background_sync1,background_sync2;
 always @(posedge fast)begin
  reset_sync<={reset_sync[1:0],reset};command_sync<={command_sync[2:0],token};
  line_sync<={line_sync[2:0],line_request};vblank_sync<={vblank_sync[2:0],vblank};
  enable_sync<={enable_sync[0],enabled};
  layer_sync<={layer_sync[0],layered};background_sync1<=background_page;background_sync2<=background_sync1;
 end
 reg line_seen,vblank_seen,fetching,fetch_bank,waiting,owner_video,issued,request_video;
 reg[7:0]fetch_column;reg[15:0]fetch_offset;
 reg[3:0]fetch_page;
 reg fetch_layer,fetch_background;reg[3:0]fetch_background_page;
 reg[15:0]foreground_pair;reg[17:0]background_colour;
 // Decode the entire source, including hidden pixels. RGB222 foreground
 // codes cover it; modifier codes reveal it. Actors cannot change its HAM
 // history, and palette codes in a revealed image retain their exact colour.
 function[17:0]base_colour;
  input[7:0]code;
  begin base_colour={{3{code[5:4]}},{3{code[3:2]}},{3{code[1:0]}}};end
 endfunction
 function[17:0]ham_colour;
  input[17:0]prior;input[7:0]code;
  begin case(code[7:6])
   0:ham_colour=base_colour(code);
   1:ham_colour={prior[17:6],code[5:0]};
   2:ham_colour={code[5:0],prior[11:0]};
   3:ham_colour={prior[17:12],code[5:0],prior[5:0]};
  endcase end
 endfunction
 wire[17:0]background_first=ham_colour(background_colour,mem_result[7:0]);
 wire[17:0]background_second=ham_colour(background_first,mem_result[15:8]);
 wire[17:0]display_first=foreground_pair[7:6]==0?base_colour(foreground_pair[7:0]):background_first;
 wire[17:0]display_second=foreground_pair[15:14]==0?base_colour(foreground_pair[15:8]):background_second;
 // One common transfer engine serves both register interfaces. The scanout
 // cache and HAM decoder above remain independent and have first priority.
 wire transfer_request,transfer_write,transfer_ready,transfer_done;
 wire[20:0]transfer_address;wire[15:0]transfer_data;
 wire transfer_finished,transfer_failed;wire[7:0]transfer_read;
 classic_dma dma(clk,fast,reset,dma_io_read,dma_io_write,dma_io_address,bus_data,dma_result,dma_busy,palette_owned,
  legacy_busy,token,job_command,job_colour,job_height,job_width,job_source_page,job_destination_page,
  job_source_offset,job_destination_offset,transfer_finished,transfer_failed,transfer_read,
  transfer_request,transfer_write,transfer_address,transfer_data,transfer_ready,transfer_done,mem_result,
  palette_write,palette_register,palette_data,palette_result,palette_read_mode);
 reg[3:0]state;
 localparam IDLE=0,TRANSFER=1,FLIP=4;
 assign mem_request=issued&&!waiting;
 assign transfer_ready=mem_request&&mem_ready&&!request_video;
 assign transfer_done=waiting&&mem_done&&!owner_video;
 always @(posedge fast)begin
  if(reset_sync[2])begin
   finished<=0;failed<=0;underrun<=0;front_page<=0;fast_read<=0;state<=IDLE;
   line_seen<=0;vblank_seen<=0;fetching<=0;fetch_bank<=0;fetch_column<=0;
   fetch_offset<=0;fetch_page<=0;valid_banks<=0;waiting<=0;owner_video<=0;issued<=0;request_video<=0;
   fetch_layer<=0;fetch_background<=0;fetch_background_page<=0;foreground_pair<=0;background_colour<=0;
   mem_write<=0;mem_word<=0;mem_address<=21'h100000;mem_data<=0;
  end else begin
   if(!enable_sync[1])begin valid_banks<=0;underrun<=0;end
   vblank_seen<=vblank_sync[3];
   if(state==IDLE&&command_sync[3]!=finished)begin
    failed<=0;state<=job_command==3?FLIP:TRANSFER;
   end
   if(state==FLIP&&vblank_seen!=vblank_sync[3])begin
    front_page<=job_destination_page;state<=IDLE;finished<=command_sync[3];
   end
   if(state==TRANSFER&&transfer_finished==command_sync[3])begin
    failed<=transfer_failed;fast_read<=transfer_read;finished<=command_sync[3];state<=IDLE;
   end
   if(line_seen!=line_sync[3])begin
    line_seen<=line_sync[3];
    if(enable_sync[1])begin
     if(fetching)underrun<=1;
     else begin
      fetching<=1;fetch_column<=0;fetch_bank<=line_y[0];fetch_page<=front_page;
      fetch_layer<=layer_sync[1];fetch_background<=0;fetch_background_page<=background_sync2;background_colour<=0;
      fetch_offset<={line_y,8'b0}+{2'b0,line_y,6'b0};valid_banks[line_y[0]]<=0;
     end
    end
   end
   if(!issued&&!waiting&&(fetching||transfer_request))begin
    issued<=1;request_video<=fetching;mem_word<=fetching;
    mem_write<=!fetching&&transfer_write;
    mem_address<=fetching?{1'b1,(fetch_background?fetch_background_page:fetch_page),fetch_offset}:transfer_address;
    mem_data<=transfer_data;
   end
   if(mem_request&&mem_ready)begin waiting<=1;issued<=0;owner_video<=request_video;end
   if(waiting&&mem_done)begin
    waiting<=0;
    if(owner_video)begin
     if(fetch_layer&&!fetch_background)begin foreground_pair<=mem_result;fetch_background<=1;end
     else begin
      cache[{fetch_bank,fetch_column}]<=fetch_layer?{display_second,display_first}:{20'd0,mem_result};
      if(fetch_layer)background_colour<=background_second;
      fetch_background<=0;fetch_offset<=fetch_offset+16'd2;
      if(fetch_column==159)begin fetching<=0;valid_banks[fetch_bank]<=1;end
      else fetch_column<=fetch_column+1'b1;
     end
    end
   end
  end
 end
endmodule
