// Classic MC6800 core on hardware-lcd, byte SRAM and one SPI shifter.
module classic_system #(parameter BOOT_FILE="build/boot.mem",parameter BOOT_DIV=6,parameter CLASSIC_DIV=24,parameter BUTTON_TICK_DIV=24000,parameter BUTTON_DEBOUNCE_MS=20,parameter BUTTON_LONG_MS=2000,parameter BUTTON_RELOAD_MS=10000)(
 input wire clk,clk_fast,pll_locked,btn_resetn,
 input wire cpu_rw,cpu_vma,input wire[15:0]cpu_addr,input wire[7:0]cpu_out,
 output wire cpu_clk,cpu_reset,cpu_hold,cpu_irq,output wire[7:0]cpu_in,
 output wire[8:0]seg_led_h,seg_led_l,output wire[2:0]led_rgb,
 input wire rxd,output wire txd,input wire ps2clk,ps2dat,
 output wire mss,msck,mosi,input wire miso,
 output wire[19:0]SRAM_ADDR,inout wire[15:0]SRAM_DATA,
 output wire SRAM_CE,SRAM_OE,SRAM_WE,SRAM_UB,SRAM_LB,
 output wire[5:0]tvout,output wire[1:0]audio,output wire hd6303_en,
 input wire hg_tms,hg_tck,hg_tdi,output wire hg_tdo,hg_tdo_enable
);
 reg[7:0]power_delay=255;
 always @(posedge clk)if(!pll_locked)power_delay<=255;else if(power_delay!=0)power_delay<=power_delay-1'b1;
 wire power_reset=power_delay!=0;reg restart_reset=0,restart_seen=0;
 wire cold_reset=power_reset||restart_reset;
 wire warm_request,speed_tap,reload_request;
 classic_reset_button #(.TICK_DIV(BUTTON_TICK_DIV),.DEBOUNCE_MS(BUTTON_DEBOUNCE_MS),.LONG_MS(BUTTON_LONG_MS),.RELOAD_MS(BUTTON_RELOAD_MS))
  button(clk,power_reset,btn_resetn,speed_tap,warm_request,reload_request);
 reg[1:0]speed=0;reg speed_pending=0;wire[1:0]boot_speed;
 wire raw_owned;
 wire fast_memory_busy;reg memory_busy=1;
 // Sample the related fast-domain busy on the falling 24 MHz edge. It is
 // then stable for half a system period before reset/speed decisions.
 always @(negedge clk)if(cold_reset)memory_busy<=1;else memory_busy<=fast_memory_busy;
 wire sd_ready,sd_initialized,sd_done,sd_error,raw_busy,raw_cs;
 wire locked,boot_mode,boot_error;
 // Stop new requests immediately, drain accepted SRAM/SD writes, then reset CPU.
 reg warm_hold;reg[5:0]reset_tail;
 always @(posedge clk)begin
  if(cold_reset)begin warm_hold<=1;reset_tail<=32;end
  else if(warm_request)begin warm_hold<=1;reset_tail<=32;end
  else if(warm_hold)begin
   if(!memory_busy&&(boot_mode||sd_ready||sd_error))begin
    if(reset_tail!=0)reset_tail<=reset_tail-1'b1;else warm_hold<=0;
   end
  end
 end
 assign cpu_reset=cold_reset||warm_hold;
 // At 10 s the CPU has already been held by the 2 s reset. Drain accepted
 // memory/backend transfers before clearing ROM lock and starting bootstrap.
 // The button counter uses power_reset, so holding it cannot restart repeatedly.
 always @(posedge clk)begin
  restart_reset<=0;
  if(power_reset)restart_seen<=0;
  else begin
   if(!reload_request)restart_seen<=0;
   else if(!restart_seen&&warm_hold&&!memory_busy&&!raw_busy&&(boot_mode||sd_ready||sd_error))begin
    restart_reset<=1;restart_seen<=1;
   end
  end
 end
 reg[4:0]phase=0;
 reg[4:0]cpu_divisor=BOOT_DIV;
 wire[1:0]next_speed=speed+1'b1;
 // Commit may choose 8 MHz in the middle of a bootstrap bus cycle. Keep
 // that cycle's divisor until its falling edge; latch the next divisor at 0.
 always @(posedge clk)begin
  if(cold_reset)cpu_divisor<=BOOT_DIV;
  else if(phase==0)begin
   if(boot_mode)cpu_divisor<=BOOT_DIV;
   else if(cpu_reset)cpu_divisor<=CLASSIC_DIV>>boot_speed;
   else if(speed_pending&&!memory_busy)cpu_divisor<=CLASSIC_DIV>>next_speed;
   else cpu_divisor<=CLASSIC_DIV>>speed;
  end
 end
 always @(posedge clk)begin
  if(cold_reset)begin speed<=0;speed_pending<=0;end
  else begin
   if(speed_tap&&!boot_mode&&!cpu_reset)speed_pending<=1;
   // Change only AFTER the previous falling CPU edge and after SRAM drains.
   if(phase==0&&!memory_busy)begin
    if(cpu_reset)begin speed<=boot_speed;speed_pending<=0;end
    else if(boot_mode)begin speed<=boot_speed;speed_pending<=0;end
    else if(speed_pending)begin speed<=speed+1'b1;speed_pending<=0;end
   end
  end
 end
 // Clock is a flip-flop output, never a combinational decode of counter bits.
 (* syn_keep = 1 *) reg cpu_clock=0;
 always @(posedge clk)begin
  if(cold_reset)phase<=0;
  else if(phase==cpu_divisor-1)phase<=0;
  else phase<=phase+1'b1;
 end
 // CPU samples on a falling CPU edge, halfway between SRAM/bus clock edges.
 // Data and hold therefore settle for half a system cycle before CPU capture.
 always @(negedge clk)begin
  if(cold_reset||phase==0)cpu_clock<=0;
  else if(phase==cpu_divisor/2)cpu_clock<=1;
 end
 assign cpu_clk=cpu_clock;
 reg tick_pending;
 wire keyboard_irq;
 assign cpu_irq=(tick_pending||keyboard_irq)&&!boot_mode;
 (* syn_ramstyle = "block_ram" *) reg[7:0]boot_rom[0:8191];
 reg[7:0]boot_byte;
 initial $readmemh(BOOT_FILE,boot_rom);
 always @(posedge clk)boot_byte<=boot_rom[{~cpu_addr[13],cpu_addr[11:0]}];
 wire cycle=phase==1&&!cpu_reset&&cpu_vma;
 wire bus_read=cycle&&cpu_rw,bus_write=cycle&&!cpu_rw;
 wire boot_io=(boot_mode||(cpu_rw&&cpu_addr==16'he6a0))&&cpu_addr[15:4]==12'he6a;
 wire spi_io=cpu_addr>=16'he660&&cpu_addr<=16'he664;
 wire hg_io=cpu_addr[15:2]==14'h399c;
 wire gfx_io=cpu_addr[15:4]==12'he65;
 wire crtc_io=cpu_addr==16'he600||cpu_addr==16'he601||cpu_addr==16'he604||cpu_addr==16'he605;
 wire fdc_io=!boot_mode&&(cpu_addr==16'he6c0||cpu_addr==16'he6d0||cpu_addr==16'he6d1);
 wire keyboard_io=cpu_addr==16'he628||cpu_addr==16'he62a||cpu_addr==16'he62e;
 wire timer_io=cpu_addr==16'he62b;
 wire simple_io=cpu_addr==16'he629||cpu_addr>=16'he680&&cpu_addr<=16'he682
   ||cpu_addr==16'he632||cpu_addr==16'he634||cpu_addr==16'he635;
 wire disk_data_io=cpu_addr==16'he683;
 wire rom_read=boot_mode&&cpu_rw&&(cpu_addr[15:12]==4'hd||cpu_addr[15:12]==4'hf);
 wire peripheral=boot_io||spi_io||hg_io||gfx_io||crtc_io||fdc_io||keyboard_io||timer_io||simple_io||rom_read;
 reg[7:0]page,mode;reg caps_off,speaker;reg[18:0]ramdisk_address;
 wire[20:0]mapped_address;wire ignored_io;
 classic_memory_map map(cpu_addr,!cpu_rw,page,mapped_address,ignored_io);
 wire[7:0]kbd_data,kbd_status;
 classic_keyboard keyboard(clk,cpu_reset,ps2clk,ps2dat,!mode[0],
  bus_read&&cpu_addr==16'he628,bus_read&&(cpu_addr==16'he62a||cpu_addr==16'he62e),kbd_data,kbd_status,keyboard_irq,
  !boot_mode,bus_read&&timer_io&&tick_pending);
 wire[7:0]hg_result;
 classic_hg host_link(clk,cpu_reset,bus_read&&hg_io,bus_write&&hg_io,
  cpu_addr[1:0],cpu_out,hg_result,hg_tms,hg_tck,hg_tdi,hg_tdo,hg_tdo_enable);
 wire boot_request,boot_write,boot_accept,boot_done;wire[20:0]boot_address;wire[7:0]boot_data,boot_result,boot_debug;
 wire[7:0]memory_read_data;wire[7:0]runtime_video_data,runtime_cpu_data;
 wire[31:0]a_start,a_length,b_start,b_length;wire[7:0]aspt,ah,bspt,bh;wire[8:0]ac,bc;
 wire boot_b,sd_mode,model_a,configured_hd;
 // Resident firmware uses HD6303; the selected runtime ISA takes effect at lock.
 assign hd6303_en=boot_mode||configured_hd;
 classic_boot_ports boot(clk,cold_reset,cpu_reset,bus_read&&boot_io,bus_write&&boot_io,
  cpu_addr[3:0],cpu_out,boot_result,boot_request,boot_write,boot_address,boot_data,boot_accept,boot_done,memory_read_data,
  !raw_busy&&raw_cs,locked,boot_mode,boot_error,boot_debug,sd_mode,
  a_start,a_length,b_start,b_length,aspt,ah,bspt,bh,ac,bc,boot_b,model_a,configured_hd,boot_speed);
 wire fdc_request,fdc_write,fdc_buffer_write,fdc_active;wire[31:0]fdc_lba;
 wire[8:0]fdc_buffer_address;wire[7:0]fdc_buffer_data,fdc_result,sd_buffer_result;
 classic_fdc fdc(clk,cpu_reset,bus_read&&fdc_io,bus_write&&fdc_io,cpu_addr[4:0],cpu_out,
  fdc_result,boot_b,a_start,a_length,b_start,b_length,aspt,ah,bspt,bh,ac,bc,
  fdc_request,fdc_write,fdc_lba,sd_ready&&!raw_owned&&!warm_hold,sd_done,sd_error,
  fdc_buffer_address,fdc_buffer_write,fdc_buffer_data,sd_buffer_result,fdc_active);
 wire raw_start,host_start,byte_busy,byte_done;wire[7:0]raw_tx,raw_div,host_tx,host_div,byte_rx,raw_result;
 reg raw_used_runtime,raw_selected_last,byte_owner_raw;
 assign raw_owned=!raw_cs||raw_busy;
 // A raw runtime session invalidates backend SD state. Re-init on its release.
 always @(posedge clk)begin
  if(cold_reset)begin raw_used_runtime<=0;raw_selected_last<=0;end
  else begin
   raw_selected_last<=raw_owned;
   if(locked&&raw_owned)raw_used_runtime<=1;
  end
 end
 wire raw_enabled=boot_mode||(!fdc_active&&sd_ready)||raw_owned;
 boot_spi_registers raw_spi(clk,cold_reset||(cpu_reset&&(!locked||!byte_busy)),raw_enabled,
  bus_write&&spi_io,cpu_addr[2:0],cpu_out,raw_result,raw_busy,raw_cs,
  byte_busy&&byte_owner_raw,byte_done&&byte_owner_raw,byte_rx,raw_start,raw_tx,raw_div);
 always @(posedge clk)begin
  if(cold_reset)byte_owner_raw<=0;
  else if(!byte_busy&&(raw_start||host_start))byte_owner_raw<=raw_owned;
 end
 wire block_cs;
 wire host_reset=cold_reset||(locked&&raw_owned);
 sd_spi_block #(.EXTERNAL_INIT(1)) sd(clk,host_reset,fdc_request&&!raw_owned&&!warm_hold,
  fdc_write,fdc_lba,sd_ready,sd_initialized,sd_done,sd_error,
  fdc_buffer_address,fdc_buffer_write,fdc_buffer_data,sd_buffer_result,block_cs,
  locked,sd_mode,!raw_used_runtime,host_start,host_tx,host_div,
  byte_busy&&!byte_owner_raw,byte_done&&!byte_owner_raw,byte_rx);
 spi_byte_master shifter(clk,cold_reset||(cpu_reset&&boot_mode),raw_owned?raw_start:host_start,
  raw_owned?raw_tx:host_tx,raw_owned?raw_div:host_div,miso,msck,mosi,byte_busy,byte_done,byte_rx);
 assign mss=raw_owned?raw_cs:block_cs;
 wire video_request,video_accept,video_done,video_tick;wire[20:0]video_address;wire[7:0]video_result;
 wire font_write=boot_accept&&boot_write&&boot_address>=21'h61000&&boot_address<21'h61800;
 wire gfx_enabled,gfx_line_request,gfx_vblank,gfx_pixel_bank;wire[7:0]gfx_line_y,gfx_pixel,gfx_result;
 wire[8:0]gfx_pixel_x;wire gfx_request,gfx_write,gfx_word,gfx_ready,gfx_done;
 wire[20:0]gfx_address;wire[15:0]gfx_data,gfx_memory_result;
 wire palette_read_mode;wire[5:0]palette_result;
 classic_gfx gfx(clk,clk_fast,cpu_reset,bus_write&&gfx_io,cpu_addr[3:0],cpu_out,gfx_result,gfx_enabled,
  gfx_line_request,gfx_line_y,gfx_vblank,gfx_pixel_x,gfx_pixel_bank,gfx_pixel,
  gfx_request,gfx_write,gfx_word,gfx_address,gfx_data,gfx_ready,gfx_done,gfx_memory_result);
 classic_video #(.GFX(1)) video(clk,cpu_reset,bus_read&&crtc_io,bus_write&&crtc_io,cpu_addr[0],cpu_out,
  video_result,mode,font_write,boot_address[10:0],boot_data,
  video_request,video_address,video_accept,video_done,runtime_video_data,tvout,video_tick,model_a,
  gfx_enabled,gfx_pixel,gfx_line_request,gfx_vblank,gfx_line_y,gfx_pixel_x,gfx_pixel_bank,
  bus_write&&gfx_io,cpu_addr[3:0],cpu_out,palette_read_mode,palette_result);
 // One optimized physical SRAM sequencer for bootstrap, CPU and video.
 // Registered requests cross to 96 MHz; completions remain until consumed.
 wire disk_advance;
 wire fast_video_accept,fast_video_done,fast_boot_accept,fast_boot_done;
 reg runtime_prepare=0;
 always @(posedge clk)runtime_prepare<=phase==0;
 reg[1:0]video_accept_sync=0,video_done_sync=0,boot_accept_sync=0,boot_done_sync=0;
 reg video_token=0,boot_token=0,video_pending=0,boot_pending=0;
 reg video_accept_seen=0,video_done_seen=0,boot_accept_seen=0,boot_done_seen=0;
 always @(posedge clk)begin
  video_accept_sync<={video_accept_sync[0],fast_video_accept};video_done_sync<={video_done_sync[0],fast_video_done};
  boot_accept_sync<={boot_accept_sync[0],fast_boot_accept};boot_done_sync<={boot_done_sync[0],fast_boot_done};
  if(cold_reset)begin
   video_token<=0;boot_token<=0;video_pending<=0;boot_pending<=0;
   video_accept_seen<=0;video_done_seen<=0;boot_accept_seen<=0;boot_done_seen<=0;
  end else if(cpu_reset)begin
   // Cancel unaccepted requests by realigning their toggle to the last ACK.
   // A boot request already ACKed to its client must still deliver DONE:
   // classic_boot_ports drains an issued write before restarting bootstrap.
   video_token<=video_accept_sync[1];boot_token<=boot_accept_sync[1];
   video_pending<=0;
   video_accept_seen<=video_accept_sync[1];video_done_seen<=video_done_sync[1];
   if(boot_pending&&boot_accept_seen==boot_token)begin
    if(boot_done)begin boot_pending<=0;boot_done_seen<=boot_done_sync[1];end
   end else begin
    boot_pending<=0;boot_accept_seen<=boot_accept_sync[1];boot_done_seen<=boot_done_sync[1];
   end
  end else begin
   if(video_request&&!video_pending)begin video_token<=!video_token;video_pending<=1;end
   if(boot_request&&!boot_pending)begin boot_token<=!boot_token;boot_pending<=1;end
   if(video_accept&&video_request)video_accept_seen<=video_accept_sync[1];
   if(boot_accept&&boot_request)boot_accept_seen<=boot_accept_sync[1];
   if(video_done&&!video_request)begin video_done_seen<=video_done_sync[1];video_pending<=0;end
   if(boot_done&&!boot_request)begin boot_done_seen<=boot_done_sync[1];boot_pending<=0;end
  end
 end
 assign video_accept=video_pending&&(video_accept_sync[1]!=video_accept_seen);
 assign video_done=video_pending&&(video_done_sync[1]!=video_done_seen);
 assign boot_accept=boot_pending&&(boot_accept_sync[1]!=boot_accept_seen);
 assign boot_done=boot_pending&&(boot_done_sync[1]!=boot_done_seen);
 classic_runtime_memory #(.GFX(1)) runtime_memory(clk_fast,cold_reset,locked,cpu_reset,runtime_prepare,
  cpu_vma,cpu_rw,peripheral,disk_data_io?21'h80000+ramdisk_address:mapped_address,cpu_out,
  video_token,video_address,speed_pending,
  boot_token,boot_write,boot_address,boot_data,fast_boot_accept,fast_boot_done,memory_read_data,
  fast_video_accept,fast_video_done,runtime_video_data,runtime_cpu_data,fast_memory_busy,
  SRAM_ADDR,SRAM_DATA,SRAM_CE,SRAM_OE,SRAM_WE,SRAM_LB,SRAM_UB,
  gfx_request,gfx_write,gfx_word,gfx_address,gfx_data,gfx_ready,gfx_done,gfx_memory_result);
 reg[7:0]peripheral_data;
 always @*begin
  peripheral_data=8'hff;
  if(rom_read)peripheral_data=boot_byte;
  else if(boot_io)peripheral_data=boot_result;
  else if(spi_io)peripheral_data=raw_result;
  else if(hg_io)peripheral_data=hg_result;
  else if(gfx_io)peripheral_data=cpu_addr[3:0]==14&&palette_read_mode?{2'b0,palette_result}:gfx_result;
  else if(crtc_io)peripheral_data=video_result;
  else if(fdc_io)peripheral_data=fdc_result;
  else if(keyboard_io)peripheral_data=cpu_addr==16'he628 ? kbd_data:kbd_status|8'h37|(caps_off?8'h08:0);
  else if(timer_io)peripheral_data=8'h37|(tick_pending?8'h80:0)|(speaker?8'h08:0);
  // UniBIOS reads DRB before modifying video or LAT/CYR bits.
  else if(simple_io)peripheral_data=cpu_addr==16'he629 ? mode:cpu_addr==16'he632 ? 8'h80:0;
 end
 reg[7:0]runtime_peripheral_data;reg runtime_memory_read;
 assign cpu_hold=1'b0;
 assign cpu_in=runtime_memory_read?runtime_cpu_data:runtime_peripheral_data;
 assign disk_advance=cycle&&disk_data_io;
 always @(posedge clk)begin
  if(cpu_reset)begin runtime_peripheral_data<=8'hff;runtime_memory_read<=0;end
  else if(cycle)begin runtime_memory_read<=!peripheral;if(peripheral)runtime_peripheral_data<=peripheral_data;end
 end
 always @(posedge clk)begin
  if(cpu_reset)begin
   page<=0;mode<=1;caps_off<=1;speaker<=0;ramdisk_address<=0;tick_pending<=0;
  end else begin
   if(bus_read&&timer_io)tick_pending<=0;
   // A read captures the OLD pending bit. Preserve a PAL pulse arriving on
   // that same edge, otherwise a phase-aligned polling loop loses every tick.
   if(video_tick)tick_pending<=1;
   if(disk_advance)ramdisk_address<=ramdisk_address+1'b1;
   if(bus_write)case(cpu_addr)
    16'he6f0:page<=cpu_out;16'he629:mode<=cpu_out;
    16'he62a,16'he62e:caps_off<=cpu_out[3];16'he62b:speaker<=cpu_out[3];
    16'he680:ramdisk_address[18:16]<=cpu_out[2:0];16'he681:ramdisk_address[15:8]<=cpu_out;
    16'he682:ramdisk_address[7:0]<=cpu_out;
   endcase
  end
 end
 // UART is unused in the normal machine; keep the board TX pin idle.
 assign txd=1'b1;
 assign audio={2{speaker}};
 classic_frequency_display display(clk,cold_reset,speed,boot_mode,seg_led_h,seg_led_l);
 // Active-low cathodes: pin39 red, pin41 green, pin42 blue.
 // Schematic LED_B/LED_G names are swapped; use the actual LED cathodes.
 // Red indication is opposite to the PIA control-register bit 3 readback.
 assign led_rgb={1'b1,mode[0],!caps_off};
endmodule
