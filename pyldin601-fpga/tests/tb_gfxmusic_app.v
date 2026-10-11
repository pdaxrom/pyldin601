`timescale 1ns/1ps
// Real HD6303 PGM, production blitter/arbitration and SRAM-10 delayed pads.
module gfxmusic_app_fixture #(parameter SPEED=0,MODEL_A=0,RETURN_PC=0,APP=0,UNDERRUNS=0,SAVED_PAGE=0,SAVED_GROUP=0,ORIGINAL_IRQ=0)(
 input cpu_rw,cpu_vma,input[15:0]cpu_addr,input[7:0]cpu_out,
 output cpu_clk,cpu_reset,cpu_hold,cpu_irq,cpu_hd,output[7:0]cpu_in
);
 reg clk=0,psclk=1,psdata=1;always #21 clk=~clk;
 wire fast;test_fast_clock_physical fast_clock(fast);
 wire[19:0]sa,pa;wire[15:0]sd,pd;wire ce,oe,we,ub,lb,pc,po,pw,pu,pl;
 classic_system #(.BOOT_FILE("build/gfxmusic/rtl-boot.mem")) dut(
  .clk(clk),.clk_fast(fast),.pll_locked(1'b1),.btn_resetn(1'b1),.cpu_rw(cpu_rw),.cpu_vma(cpu_vma),
  .cpu_addr(cpu_addr),.cpu_out(cpu_out),.cpu_clk(cpu_clk),.cpu_reset(cpu_reset),.cpu_hold(cpu_hold),.cpu_irq(cpu_irq),.hd6303_en(cpu_hd),.cpu_in(cpu_in),
  .ps2clk(psclk),.ps2dat(psdata),.rxd(1'b1),.miso(1'b1),.hg_tms(1'b0),.hg_tck(1'b0),.hg_tdi(1'b0),
  .SRAM_ADDR(sa),.SRAM_DATA(sd),.SRAM_CE(ce),.SRAM_OE(oe),.SRAM_WE(we),.SRAM_UB(ub),.SRAM_LB(lb));
 reg[15:0]memory[0:1048575];
 integer jobs=0,frames=0,checks=0,opaque=0,keyed=0,music_frames=0,envelopes=0,palette_writes=0;
 integer px[0:2],py[0:2],dx[0:2],dy[0:2],valid[0:1],old_visible[0:1];
 reg[3:0]seen_page=0;
 reg[7:0]music[0:1119],ay_shadow[0:15];
 assign #10 pa=sa;assign #10 pc=ce,po=oe,pu=ub,pl=lb;
 assign #6 pw=we;assign #14.5 pd=sd;
 reg[15:0]read_word;reg epoch=0;
 always @(pa or pc or po or pw or epoch)read_word=!pc&&!po&&pw?memory[pa]:16'bz;
 assign #18 sd=read_word;
 always @(posedge pw)if(!pc)begin
  if(^pd===1'bx)$fatal(1,"GFXMUSIC invalid SRAM write");
  if(!pl)memory[pa][7:0]=pd[7:0];
  if(!pu)memory[pa][15:8]=pd[15:8];
  epoch<=!epoch;
 end
 function[7:0]byte_at;input[20:0]a;reg[15:0]w;
 begin w=memory[a[20:1]];byte_at=a[0]?w[15:8]:w[7:0];end endfunction
 function[7:0]background;input integer x,y;integer col,row,r,g,b;
 begin
  col=x/4;row=y/4;r=col<64?col:127-col;g=row+14;b=(col+2*row)&63;
  case(x%4)
   0:background=(((r+10)/21)<<4)|(((g+10)/21)<<2)|((b+10)/21);
   1:background=64|b;2:background=128|r;3:background=192|g;
  endcase
 end endfunction
 function integer inset;input integer y;
 begin inset=y<2||y>=30?12:y<4||y>=28?8:y<8||y>=24?4:0;end endfunction
 function[7:0]sprite;input integer x,y,b;
 begin
  if(x<inset(y)||x>=32-inset(y))sprite=0;
  else if(x>=8&&x<12&&y>=8&&y<12)sprite=63;
  else sprite=b==0?48:b==1?12:3;
 end endfunction
 task check_frame;input integer page;
 integer x,y,b,sx,sy,visible;reg[7:0]expected,c,actual;
 begin
  visible=0;
  for(b=0;b<3;b=b+1)if($signed(px[b])<320&&px[b]+32>0&&$signed(py[b])<200&&py[b]+32>0)visible++;
  if(keyed!=visible||opaque!=(valid[page]?old_visible[page]:0))$fatal(1,"GFXMUSIC wrong dirty rectangles frame=%d page=%d opaque=%d keyed=%d visible=%d valid=%d old=%d xy=%d,%d / %d,%d / %d,%d",frames,page,opaque,keyed,visible,valid[page],old_visible[page],px[0],py[0],px[1],py[1],px[2],py[2]);
  for(y=0;y<200;y=y+1)for(x=0;x<320;x=x+1)begin
   expected=background(x,y);
   for(b=0;b<3;b=b+1)begin
    sx=x-px[b];sy=y-py[b];
    if(sx>=0&&sx<32&&sy>=0&&sy<32)begin c=sprite(sx,sy,b);if(c!=0)expected=c;end
   end
   actual=byte_at(21'h100000+page*65536+y*320+x);
   if(actual!==expected)
    $fatal(1,"GFXMUSIC frame %d page %d pixel %d,%d got %h expected %h",frames,page,x,y,actual,expected);
   if(byte_at(21'h130000+y*320+x)!==background(x,y))$fatal(1,"GFXMUSIC background damaged");
   checks++;
  end
  for(b=0;b<3;b=b+1)for(y=0;y<32;y=y+1)for(x=0;x<32;x=x+1)
   if(byte_at(21'h120000+y*320+b*32+x)!==sprite(x,y,b))$fatal(1,"GFXMUSIC atlas damaged");
  for(b=0;b<3;b=b+1)begin
   px[b]+=dx[b];py[b]+=dy[b];
   if($signed(px[b])< -32)begin px[b]=-32;dx[b]=-dx[b];end
   if($signed(px[b])>320)begin px[b]=320;dx[b]=-dx[b];end
   if($signed(py[b])< -32)begin py[b]=-32;dy[b]=-dy[b];end
   if($signed(py[b])>200)begin py[b]=200;dy[b]=-dy[b];end
  end
  valid[page]=1;old_visible[page]=visible;frames++;opaque=0;keyed=0;

 end endtask
 always @(posedge clk)begin
  #1;
  if(dut.gfx_enabled&&dut.gfx.front_page!=seen_page)begin
   seen_page=dut.gfx.front_page;
   check_frame(seen_page);
  end
 end
 always @(posedge clk)if(dut.bus_write&&cpu_addr==16'he651)begin
  jobs++;
  if(dut.gfx_enabled)begin
   if(cpu_out==2)opaque++;
   if(cpu_out==6)keyed++;
   if(cpu_out==2||cpu_out==6)begin
    if(dut.gfx.job_width>32||dut.gfx.job_height>32||dut.gfx.job_destination_offset%320+dut.gfx.job_width>320||dut.gfx.job_source_offset%320+dut.gfx.job_width>320)$fatal(1,"GFXMUSIC full-frame copy during animation");
    if(dut.gfx.job_destination_page==dut.gfx.front_page)$fatal(1,"GFXMUSIC writes displayed page");
   end
  end
 end
 always @(negedge cpu_clk)if(dut.locked&&cpu_hold)$fatal(1,"GFXMUSIC stalled CPU");
 task send;input[7:0]b;reg[10:0]frame;integer k;
 begin
  frame={1'b1,~^b,b,1'b0};
  for(k=0;k<11;k=k+1)begin psdata=frame[k];#10000;psclk=0;#30000;psclk=1;#30000;end
  psdata=1;#10000;
 end endtask
 integer reg_index;
 always @(posedge clk)if(dut.bus_write&&cpu_addr>=16'he610&&cpu_addr<=16'he61d)begin
  ay_shadow[cpu_addr[3:0]]=cpu_out;
  if(cpu_addr==16'he61c&&dut.audio_control.enabled)begin
   if(music_frames>=80)$fatal(1,"music exceeded EOF");
   for(reg_index=0;reg_index<13;reg_index++)if(ay_shadow[reg_index]!==music[music_frames*14+reg_index])
    $fatal(1,"GFXMUSIC AY frame %d register %d got %h expected %h",music_frames,reg_index,ay_shadow[reg_index],music[music_frames*14+reg_index]);
   music_frames++;
   if(dut.audio_control.period!==240000||dut.audio_control.divider_value!==32'h01b11101)
    $fatal(1,"GFXMUSIC 100Hz/1.7734MHz config period=%h divider=%h",dut.audio_control.period,dut.audio_control.divider_value);
  end
  if(cpu_addr==16'he61d&&dut.audio_control.enabled)begin
   if(music[(music_frames-1)*14+13]==255||cpu_out!==music[(music_frames-1)*14+13])$fatal(1,"GFXMUSIC envelope retrigger");
   envelopes++;
  end
 end
 always @(posedge clk)if(dut.gfx_enabled&&(dut.gfx.underrun||dut.audio_control.overrun))$fatal(1,"video/audio underrun");
 initial begin
  $readmemh("build/gfxmusic/rtl-sram.mem",memory);
  $readmemh("build/gfxmusic/rtl-frames.mem",music);
  px[0]=-16;py[0]=-16;dx[0]=4;dy[0]=1;
  px[1]=304;py[1]=184;dx[1]=-4;dy[1]=-2;
  px[2]=140;py[2]=85;dx[2]=-4;dy[2]=3;valid[0]=0;valid[1]=0;
  wait(frames>=10);send(8'h76);send(8'hf0);send(8'h76);
 end
 always @(posedge clk)if(dut.bus_write&&cpu_addr==16'he65e&&!dut.gfx_enabled&&music_frames>0)begin
  if(cpu_out!==((palette_writes*17+palette_writes/32+5)&63))$fatal(1,"original palette restore byte %d",palette_writes);
  palette_writes++;
 end
 integer k,expected_envelopes,manager;
 always @(negedge cpu_clk)if(dut.locked&&!dut.boot_mode&&cpu_rw&&cpu_vma&&cpu_addr==RETURN_PC)begin
  if(frames<10||music_frames<18||dut.gfx_enabled||dut.gfx.busy||dut.gfx.underrun||dut.audio_control.enabled||dut.audio_control.overrun)
   $fatal(1,"GFXMUSIC bad exit frames=%d music=%d",frames,music_frames);
  if(byte_at(APP+UNDERRUNS)!==0||dut.page!=SAVED_PAGE||dut.ram_pages.group_number!=SAVED_GROUP||{byte_at(16'hefc8),byte_at(16'hefc9)}!=ORIGINAL_IRQ)
   $fatal(1,"GFXMUSIC queue/page/vector cleanup");
  if(palette_writes!=8192||dut.palette_read_mode)$fatal(1,"incomplete palette restore");
  manager={byte_at(16'hefca),byte_at(16'hefcb)};
  if(manager<256||manager>=16'hbe00||byte_at(manager+6)!==111)$fatal(1,"RAM manager capacity not restored");
  for(k=0;k<111;k=k+1)if(byte_at(manager+112+k)!==0)$fatal(1,"song bank leaked at exit");
  for(k=0;k<16;k=k+1)if(byte_at(manager+32+5*k+4)!==0)$fatal(1,"song lease leaked at exit");
  expected_envelopes=0;
  for(k=0;k<music_frames;k=k+1)if(music[k*14+13]!=255)expected_envelopes++;
  if(envelopes!=expected_envelopes)$fatal(1,"GFXMUSIC lost envelope write");
  $display("PASS actual HD6303 GFXMUSIC.PGM 601A=%0d %0dMHz: %0d flips/%0d AY frames, full-frame HAM pixels, transparent clipping, shared IRQ/SRAM-10, PS2 ESC/palette/pages/vector cleanup without HOLD",MODEL_A,1<<SPEED,frames,music_frames);$finish;
 end
 initial begin #2000000000;$fatal(1,"GFXMUSIC timeout PC=%h jobs=%d frames=%d music=%d",cpu_addr,jobs,frames,music_frames);end
endmodule
