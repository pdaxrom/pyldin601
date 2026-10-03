// Classic MC6800 core on hardware-lcd, byte SRAM and one SPI shifter.
module classic_system #(parameter BOOT_FILE="build/boot.mem",parameter BOOT_DIV=6,parameter CLASSIC_DIV=24)(
 input wire clk,pll_locked,btn_resetn,
 input wire cpu_rw,cpu_vma,input wire[15:0]cpu_addr,input wire[7:0]cpu_out,
 output wire cpu_clk,cpu_reset,cpu_hold,cpu_irq,output wire[7:0]cpu_in,
 output wire[8:0]seg_led_h,seg_led_l,output wire[2:0]led_rgb,
 input wire rxd,output wire txd,input wire ps2clk,ps2dat,
 output wire mss,msck,mosi,input wire miso,
 output wire[19:0]SRAM_ADDR,inout wire[15:0]SRAM_DATA,
 output wire SRAM_CE,SRAM_OE,SRAM_WE,SRAM_UB,SRAM_LB,
 output wire[5:0]tvout,output wire[1:0]audio,output wire hd6303_en
);
 reg[7:0]power_delay=255;
 always @(posedge clk)if(!pll_locked)power_delay<=255;else if(power_delay!=0)power_delay<=power_delay-1'b1;
 wire cold_reset=power_delay!=0;
 reg[2:0]button_sync=7;
 always @(posedge clk)button_sync<={button_sync[1:0],btn_resetn};
 wire warm_request=!button_sync[2];
 wire raw_owned;
 wire memory_busy,sd_ready,sd_initialized,sd_done,sd_error,raw_busy,raw_cs;
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
 reg[4:0]phase=0;
 wire[4:0]cpu_divisor=boot_mode?BOOT_DIV:CLASSIC_DIV;
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
 (* syn_ramstyle = "block_ram" *) reg[7:0]boot_rom[0:4095];
 reg[7:0]boot_byte;
 initial $readmemh(BOOT_FILE,boot_rom);
 always @(posedge clk)boot_byte<=boot_rom[cpu_addr[11:0]];
 wire cycle;
 wire bus_read=cycle&&cpu_rw,bus_write=cycle&&!cpu_rw;
 wire boot_io=(boot_mode||(cpu_rw&&cpu_addr==16'he6a0))&&cpu_addr[15:4]==12'he6a;
 wire spi_io=cpu_addr>=16'he660&&cpu_addr<=16'he664;
 wire crtc_io=cpu_addr==16'he600||cpu_addr==16'he601||cpu_addr==16'he604||cpu_addr==16'he605;
 wire fdc_io=!boot_mode&&(cpu_addr==16'he6c0||cpu_addr==16'he6d0||cpu_addr==16'he6d1);
 wire keyboard_io=cpu_addr==16'he628||cpu_addr==16'he62a||cpu_addr==16'he62e;
 wire timer_io=cpu_addr==16'he62b;
 wire simple_io=cpu_addr==16'he629||cpu_addr>=16'he680&&cpu_addr<=16'he682
   ||cpu_addr==16'he632||cpu_addr==16'he634||cpu_addr==16'he635;
 wire disk_data_io=cpu_addr==16'he683;
 wire rom_read=boot_mode&&cpu_rw&&cpu_addr>=16'hf000;
 wire peripheral=boot_io||spi_io||crtc_io||fdc_io||keyboard_io||timer_io||simple_io||rom_read;
 reg[7:0]page,mode;reg caps_off,speaker;reg[18:0]ramdisk_address;
 wire[20:0]mapped_address;wire ignored_io;
 classic_memory_map map(cpu_addr,!cpu_rw,page,mapped_address,ignored_io);
 wire[7:0]kbd_data,kbd_status;
 classic_keyboard keyboard(clk,cpu_reset,ps2clk,ps2dat,!mode[0],
  bus_read&&cpu_addr==16'he628,bus_read&&(cpu_addr==16'he62a||cpu_addr==16'he62e),kbd_data,kbd_status,keyboard_irq);
 wire boot_request,boot_write,boot_accept,boot_done;wire[20:0]boot_address;wire[7:0]boot_data,boot_result,boot_debug;
 wire[7:0]memory_read_data;
 wire[31:0]a_start,a_length,b_start,b_length;wire[7:0]aspt,ah,bspt,bh;wire[8:0]ac,bc;
 wire boot_b,sd_mode,model_a;
 classic_boot_ports boot(clk,cold_reset,cpu_reset,bus_read&&boot_io,bus_write&&boot_io,
  cpu_addr[3:0],cpu_out,boot_result,boot_request,boot_write,boot_address,boot_data,boot_accept,boot_done,memory_read_data,
  !raw_busy&&raw_cs,locked,boot_mode,boot_error,boot_debug,sd_mode,
  a_start,a_length,b_start,b_length,aspt,ah,bspt,bh,ac,bc,boot_b,model_a,hd6303_en);
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
 wire memory_request,memory_write,memory_ready,memory_done;wire[20:0]memory_address;
 wire[7:0]memory_data;
 wire font_write=memory_request&&memory_ready&&memory_write&&memory_address>=21'h61000&&memory_address<21'h61800;
 classic_video video(clk,cpu_reset,bus_read&&crtc_io,bus_write&&crtc_io,cpu_addr[0],cpu_out,
  video_result,mode,font_write,memory_address[10:0],memory_data,
  video_request,video_address,video_accept,video_done,memory_read_data,tvout,video_tick,model_a);
 wire[20:0]cpu_mem_address;wire[7:0]cpu_mem_data;wire cpu_mem_write,disk_advance;
 // Clients present persistent requests; the arbiter alone owns scheduling.
 // Each 7-clock slot includes the SRAM setup/access/hold/release and response.
 // CPU: accept 3, complete 9. Video: accept 10/17, complete 16/23.
 // cpu_in is retained separately through both video reads and CPU capture.
 wire cpu_request;
 wire[2:0]accept,completed;
 wire requested_write;
 memory_arbiter #(.RUNTIME_SLOTS(1)) arbiter(clk,cold_reset,{video_request&&!cpu_reset,boot_request,cpu_request},
  {1'b0,boot_write,cpu_mem_write},{video_address,boot_address,cpu_mem_address},{8'b0,boot_data,cpu_mem_data},
  accept,completed,memory_busy,memory_request,requested_write,memory_address,memory_data,memory_ready,memory_done,
  !boot_mode,phase);
 wire guard_locked;
 rom_write_guard guard(clk,cold_reset,locked,requested_write,memory_address,guard_locked,memory_write);
 assign boot_accept=accept[1];assign boot_done=completed[1];
 assign video_accept=accept[2];assign video_done=completed[2];
 sram_byte_controller memory(clk,cold_reset,memory_request,memory_write,memory_address,memory_data,
  memory_ready,memory_done,memory_read_data,SRAM_ADDR,SRAM_DATA,SRAM_CE,SRAM_OE,SRAM_WE,SRAM_LB,SRAM_UB);
 reg[7:0]peripheral_data;
 always @*begin
  peripheral_data=8'hff;
  if(rom_read)peripheral_data=boot_byte;
  else if(boot_io)peripheral_data=boot_result;
  else if(spi_io)peripheral_data=raw_result;
  else if(crtc_io)peripheral_data=video_result;
  else if(fdc_io)peripheral_data=fdc_result;
  else if(keyboard_io)peripheral_data=cpu_addr==16'he628 ? kbd_data:kbd_status|8'h37|(caps_off?8'h08:0);
  else if(timer_io)peripheral_data=8'h37|(tick_pending?8'h80:0)|(speaker?8'h08:0);
  // UniBIOS reads DRB before modifying video or LAT/CYR bits.
  else if(simple_io)peripheral_data=cpu_addr==16'he629 ? mode:cpu_addr==16'he632 ? 8'h80:0;
 end
 classic_cpu_bus cpu_bus(clk,cpu_reset,phase,cpu_vma,cpu_rw,cpu_out,
  peripheral,peripheral_data,disk_data_io?21'h80000+ramdisk_address:mapped_address,disk_data_io,
  cycle,cpu_request,cpu_hold,disk_advance,
  cpu_mem_write,cpu_mem_address,cpu_mem_data,accept[0],completed[0],memory_read_data,cpu_in);
 always @(posedge clk)begin
  if(cpu_reset)begin
   page<=0;mode<=1;caps_off<=1;speaker<=0;ramdisk_address<=0;tick_pending<=0;
  end else begin
   if(video_tick)tick_pending<=1;
   if(bus_read&&timer_io)tick_pending<=0;
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
 assign seg_led_h=9'h0ff;assign seg_led_l=9'h0ff;
 // Active-low cathodes: pin39 red, pin41 green, pin42 blue.
 // Schematic LED_B/LED_G names are swapped; use the actual LED cathodes.
 // Red indication is opposite to the PIA control-register bit 3 readback.
 assign led_rgb={1'b1,mode[0],!caps_off};
endmodule
