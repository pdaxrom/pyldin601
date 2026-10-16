// Shared byte transfer engine: legacy rectangles and flat physical DMA.
// CPU descriptors cross as a held bundle plus a toggle. Scanout arbitrates
// ahead of this engine in classic_gfx; CPU slots never depend on DMA BUSY.
module classic_dma(
 input wire clk,fast,reset,io_read,io_write,input wire[1:0]io_address,input wire[7:0]io_data,
 output reg[7:0]io_result,output wire busy,output wire palette_owned,
 input wire legacy_busy,legacy_token,input wire[7:0]legacy_command,legacy_colour,legacy_height,
 input wire[8:0]legacy_width,input wire[3:0]legacy_source_page,legacy_destination_page,
 input wire[15:0]legacy_source_offset,legacy_destination_offset,
 output reg legacy_finished,legacy_failed,output reg[7:0]legacy_read,
 output wire mem_request,mem_write,output wire[20:0]mem_address,output wire[15:0]mem_data,
 input wire mem_ready,mem_done,input wire[15:0]mem_result,
 output wire palette_write,output wire[3:0]palette_register,output wire[7:0]palette_data,
 input wire[5:0]palette_result,input wire palette_read_mode
);
 // E6E0 status, E6E1 cfg_command/ID, E6E2 index, E6E3 data (write increments only).
 // Parameters: SRC24,DST24,WIDTH24,HEIGHT16,SRC_STRIDE24,DST_STRIDE24,MODE,VALUE.
 reg[23:0]cfg_source,cfg_destination,cfg_width,cfg_source_stride,cfg_destination_stride;
 reg[15:0]cfg_height;reg[7:0]cfg_mode,cfg_value,cfg_command;reg[4:0]index;
 reg token;reg finished,failed;reg[1:0]done_sync,error_sync;
 assign busy=token!=done_sync[1];
 assign palette_owned=busy&&|cfg_mode[1:0];
 always @*begin
  io_result=8'hff;
  case(io_address)
   0:io_result={busy||legacy_busy,2'b0,error_sync[1],4'd1};
   1:io_result=8'h44;
   2:io_result={3'b0,index};
   3:case(index)
    0:io_result=cfg_source[7:0];1:io_result=cfg_source[15:8];2:io_result=cfg_source[23:16];
    3:io_result=cfg_destination[7:0];4:io_result=cfg_destination[15:8];5:io_result=cfg_destination[23:16];
    6:io_result=cfg_width[7:0];7:io_result=cfg_width[15:8];8:io_result=cfg_width[23:16];
    9:io_result=cfg_height[7:0];10:io_result=cfg_height[15:8];
    11:io_result=cfg_source_stride[7:0];12:io_result=cfg_source_stride[15:8];13:io_result=cfg_source_stride[23:16];
    14:io_result=cfg_destination_stride[7:0];15:io_result=cfg_destination_stride[15:8];16:io_result=cfg_destination_stride[23:16];
    17:io_result=cfg_mode;18:io_result=cfg_value;
   endcase
  endcase
 end
 always @(posedge clk)begin
  if(reset)begin
   cfg_source<=0;cfg_destination<=0;cfg_width<=0;cfg_height<=1;cfg_source_stride<=0;cfg_destination_stride<=0;
   cfg_mode<=0;cfg_value<=0;cfg_command<=0;index<=0;token<=0;done_sync<=0;error_sync<=0;
  end else begin
   done_sync<={done_sync[0],finished};error_sync<={error_sync[0],failed};
   if(io_write)begin
    if(io_address==2)index<=io_data[4:0];
    else if(!busy&&!legacy_busy)begin
     if(io_address==1)begin cfg_command<=io_data;token<=!token;end
     else if(io_address==3)begin
      index<=index==18?0:index+1'b1;
      case(index)
       0:cfg_source[7:0]<=io_data;1:cfg_source[15:8]<=io_data;2:cfg_source[23:16]<=io_data;
       3:cfg_destination[7:0]<=io_data;4:cfg_destination[15:8]<=io_data;5:cfg_destination[23:16]<=io_data;
       6:cfg_width[7:0]<=io_data;7:cfg_width[15:8]<=io_data;8:cfg_width[23:16]<=io_data;
       9:cfg_height[7:0]<=io_data;10:cfg_height[15:8]<=io_data;
       11:cfg_source_stride[7:0]<=io_data;12:cfg_source_stride[15:8]<=io_data;13:cfg_source_stride[23:16]<=io_data;
       14:cfg_destination_stride[7:0]<=io_data;15:cfg_destination_stride[15:8]<=io_data;16:cfg_destination_stride[23:16]<=io_data;
       17:cfg_mode<=io_data;18:cfg_value<=io_data;
      endcase
     end
    end
   end
  end
 end
 reg[2:0]reset_sync;reg[3:0]new_sync,legacy_sync;
 always @(posedge fast)begin
  reset_sync<={reset_sync[1:0],reset};new_sync<={new_sync[2:0],token};legacy_sync<={legacy_sync[2:0],legacy_token};
 end
 reg owner,job_token;reg[7:0]operation,colour,flags;reg read_only,invalid,reverse;
 reg[21:0]src,dst,src_first,dst_first,bytes,remaining,src_pitch,dst_pitch;
 reg[15:0]lines,rows;
 reg[7:0]copy_byte;
 reg[21:0]source_step,destination_step,source_advance,destination_advance,next_source,next_destination;
 reg[3:0]state;
 localparam IDLE=0,CHECK=1,VALIDATE=2,BEGIN_JOB=3,READ=4,READ_WAIT=5,KEY=6,WRITE=7,WRITE_WAIT=8,ADVANCE=9,FINISH=10,TEST_ROW=11,NEXT_ROW=12,CHECK_DECIDE=13,ROW_DECIDE=14,ROW_ADVANCE=15;
 wire source_used=operation!=1;
 wire source_port=flags[0],destination_port=flags[1];
 wire source_fixed=flags[2]||source_port,destination_fixed=flags[3]||destination_port;
 reg[21:0]source_end,destination_end,next_source_row,next_destination_row;
 reg[15:0]next_rows;
 reg bad_source_address,bad_destination_address,bad_source_port,bad_destination_port;
 reg bad_legacy_source,bad_legacy_destination,protected_destination;
 reg bad_shape,bad_source_stride,bad_destination_stride,bad_row;
 reg last_column,last_pixel;reg[21:0]next_remaining,bytes_last;
 // Compute row adjustments once, then pipeline pointer arithmetic while the
 // byte transaction is in flight. Keep subtract/add chains off the 96-MHz path.
 always @(posedge fast)begin
  source_advance<=last_column?source_step:22'd1;
  destination_advance<=last_column?destination_step:22'd1;
  next_source<=reverse?src-source_advance:src+source_advance;
  next_destination<=reverse?dst-destination_advance:dst+destination_advance;
 end
 always @(posedge fast)begin
  source_end<=src+(source_fixed?22'd1:bytes);
  destination_end<=dst+(destination_fixed?22'd1:bytes);
  next_source_row<=src+src_pitch;next_destination_row<=dst+dst_pitch;
  next_rows<=rows-1'b1;next_remaining<=remaining-1'b1;bytes_last<=bytes-1'b1;
  last_column<=remaining==1;last_pixel<=remaining==1&&rows==1;
 end
 wire[7:0]write_byte=operation==1?colour:copy_byte;
 assign mem_request=(state==READ&&!source_port)||(state==WRITE&&!destination_port);
 assign mem_write=state==WRITE;
 assign mem_address=state==READ?src[20:0]:dst[20:0];
 assign mem_data={8'b0,write_byte};
 // Palette transactions cross to the 24 MHz EBR port with backpressure.
 reg pal_token,pal_writing;reg[7:0]pal_byte;reg[1:0]pal_done_sync;
 reg pal_finished,pal_write_clk;reg[7:0]pal_data_clk;reg[5:0]pal_read;
 reg[2:0]pal_sync;reg[1:0]pal_state;
 always @(posedge clk)begin
  if(reset)begin pal_sync<=0;pal_state<=0;pal_finished<=0;pal_read<=0;pal_write_clk<=0;pal_data_clk<=0;end
  else begin
   pal_sync<={pal_sync[1:0],pal_token};
   case(pal_state)
    0:if(pal_sync[2]!=pal_finished)begin pal_state<=1;pal_write_clk<=pal_writing;pal_data_clk<=pal_byte;end
    1:begin pal_read<=palette_result;pal_finished<=pal_sync[2];pal_state<=0;end
   endcase
  end
 end
 assign palette_write=pal_state==1&&!reset;
 assign palette_register=pal_write_clk?4'd14:4'd15;
 assign palette_data=pal_write_clk?pal_data_clk:{6'b0,1'b1,palette_read_mode};
 always @(posedge fast)begin
  pal_done_sync<={pal_done_sync[0],pal_finished};
  if(reset_sync[2])begin
   state<=IDLE;finished<=0;failed<=0;legacy_finished<=0;legacy_failed<=0;legacy_read<=0;
   owner<=0;job_token<=0;operation<=0;colour<=0;flags<=0;read_only<=0;invalid<=0;reverse<=0;
   src<=0;dst<=0;src_first<=0;dst_first<=0;bytes<=0;remaining<=0;src_pitch<=0;dst_pitch<=0;lines<=0;rows<=0;copy_byte<=0;
   pal_token<=0;pal_writing<=0;pal_byte<=0;pal_done_sync<=0;
  end else case(state)
   IDLE:begin
    if(legacy_sync[3]!=legacy_finished)begin
     owner<=1;job_token<=legacy_sync[3];legacy_failed<=0;
     operation<=legacy_command==4?8'd1:legacy_command;colour<=legacy_colour;flags<=0;read_only<=legacy_command==5;
     src<={1'b0,1'b1,legacy_source_page,legacy_source_offset};src_first<={1'b0,1'b1,legacy_source_page,legacy_source_offset};
     dst<={1'b0,1'b1,legacy_destination_page,legacy_destination_offset};dst_first<={1'b0,1'b1,legacy_destination_page,legacy_destination_offset};
     bytes<=legacy_command==4||legacy_command==5?22'd1:{13'b0,legacy_width};
     lines<=legacy_command==4||legacy_command==5?16'd1:{8'b0,legacy_height};
     src_pitch<=320;dst_pitch<=320;
     // Legacy bounds are checked below without multiplying in the datapath.
     invalid<=!(legacy_command==1||legacy_command==2||legacy_command==4||legacy_command==5||legacy_command==6);
     state<=CHECK;
     if(legacy_command==3)begin legacy_finished<=legacy_sync[3];state<=IDLE;end
    end else if(new_sync[3]!=finished)begin
     owner<=0;job_token<=new_sync[3];failed<=0;operation<=cfg_command;colour<=cfg_value;flags<=cfg_mode;read_only<=0;
     src<={1'b0,cfg_source[20:0]};src_first<={1'b0,cfg_source[20:0]};dst<={1'b0,cfg_destination[20:0]};dst_first<={1'b0,cfg_destination[20:0]};
     bytes<=cfg_width[21:0];lines<=cfg_height;src_pitch<={1'b0,cfg_source_stride[20:0]};dst_pitch<={1'b0,cfg_destination_stride[20:0]};
     invalid<=(|cfg_source[23:21])||(|cfg_destination[23:21])||cfg_width>24'h200000||
       (|cfg_source_stride[23:21])||(|cfg_destination_stride[23:21])||(|cfg_mode[7:4])||cfg_mode[1:0]==3||
       !(cfg_command==1||cfg_command==2||cfg_command==6)||(cfg_command==1&&cfg_mode[0]);
     state<=CHECK;
    end
   end
   CHECK:begin
    reverse<=source_used&&!source_fixed&&!destination_fixed&&!read_only&&dst>src;
    rows<=lines;
    bad_shape<=invalid||(owner&&(bytes>320||bytes==0||lines==0||lines>200));
    bad_source_stride<=lines>1&&source_used&&!source_fixed&&src_pitch<bytes;
    bad_destination_stride<=lines>1&&!read_only&&!destination_fixed&&dst_pitch<bytes;
    state<=CHECK_DECIDE;
   end
   CHECK_DECIDE:begin
    source_step<=src_pitch-bytes_last;destination_step<=dst_pitch-bytes_last;
    if(bad_shape||bad_source_stride||bad_destination_stride)begin
     if(owner)legacy_failed<=1;else failed<=1;
     state<=FINISH;
    end else if(bytes==0||lines==0)state<=FINISH;
    else state<=VALIDATE;
   end
   VALIDATE:state<=TEST_ROW;
   TEST_ROW:begin
    // Separate addition, comparisons and control/counters into clock stages.
    // Every row is still validated before any memory/peripheral transaction.
    bad_source_address<=src>=22'h200000||source_end>22'h200000;
    bad_destination_address<=dst>=22'h200000||destination_end>22'h200000;
    protected_destination<=dst<22'h21800&&destination_end>22'h10000;
    bad_source_port<=src!=22'he65e;bad_destination_port<=dst!=22'he65e;
    bad_legacy_source<=source_end[21:16]!={2'b01,legacy_source_page}||source_end[15:0]>16'd64000;
    bad_legacy_destination<=destination_end[21:16]!={2'b01,legacy_destination_page}||destination_end[15:0]>16'd64000;
    state<=NEXT_ROW;
   end
   NEXT_ROW:begin
    bad_row<=(source_used&&(source_port?bad_source_port:bad_source_address||(owner&&bad_legacy_source)))||
       (!read_only&&(destination_port?bad_destination_port:bad_destination_address||protected_destination||(owner&&bad_legacy_destination)));
    state<=ROW_DECIDE;
   end
   ROW_DECIDE:begin
    if(bad_row)begin
     if(owner)legacy_failed<=1;else failed<=1;
     state<=FINISH;
    end else state<=rows==1?BEGIN_JOB:ROW_ADVANCE;
   end
   ROW_ADVANCE:begin
    if(!source_fixed)src<=next_source_row;
    if(!destination_fixed)dst<=next_destination_row;
    rows<=next_rows;state<=VALIDATE;
   end
   BEGIN_JOB:begin
    src<=reverse?source_end-1'b1:src_first;
    dst<=reverse?destination_end-1'b1:dst_first;
    remaining<=bytes;rows<=lines;
    state<=source_used?READ:WRITE;
   end
   READ:begin
    if(source_port)begin pal_writing<=0;pal_token<=!pal_token;state<=READ_WAIT;end
    else if(mem_ready)state<=READ_WAIT;
   end
   READ_WAIT:if(source_port?(pal_done_sync[1]==pal_token):mem_done)begin
    copy_byte<=source_port?{2'b0,pal_read}:mem_result[7:0];
    if(read_only)begin legacy_read<=mem_result[7:0];state<=FINISH;end
    else state<=KEY;
   end
   KEY:state<=operation==6&&copy_byte==colour?ADVANCE:WRITE;
   WRITE:begin
    if(destination_port)begin pal_writing<=1;pal_byte<=write_byte;pal_token<=!pal_token;state<=WRITE_WAIT;end
    else if(mem_ready)state<=WRITE_WAIT;
   end
   WRITE_WAIT:if(destination_port?(pal_done_sync[1]==pal_token):mem_done)state<=ADVANCE;
   ADVANCE:begin
    if(last_pixel)state<=FINISH;
    else begin
     if(last_column)begin remaining<=bytes;rows<=next_rows;end
     else remaining<=next_remaining;
     if(!source_fixed)src<=next_source;
     if(!destination_fixed)dst<=next_destination;
     state<=source_used?READ:WRITE;
    end
   end
   FINISH:begin
    if(owner)legacy_finished<=job_token;else finished<=job_token;
    state<=IDLE;
   end
   default:state<=IDLE;
  endcase
 end
endmodule
