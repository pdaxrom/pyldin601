`timescale 1ns/1ps
module tb_keyboard_repeat;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,psclk=1,psdata=1,rd=0,tick=0;
 wire[7:0]data,status;wire irq;
 classic_keyboard dut(clk,reset,psclk,psdata,1'b0,rd,1'b0,data,status,irq,1'b1,tick);
 task send;input[7:0]b;reg[10:0]frame;integer n;
  begin
   frame={1'b1,~^b,b,1'b0};
   for(n=0;n<11;n=n+1)begin psdata=frame[n];#300;psclk=0;#300;psclk=1;#300;end
   psdata=1;#300;
  end
 endtask
 task read_key;
  begin @(negedge clk);rd=1;@(negedge clk);rd=0;repeat(5)@(negedge clk);end
 endtask
 task acknowledge;
  begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(5)@(negedge clk);end
 endtask
 task hold_key;input[7:0]scan;input extended;reg[7:0]code;integer n;
  begin
   if(extended)send(8'he0);send(scan);code=data;
   if(code==8'hff||!irq)$fatal(1,"missing initial make %h",scan);
   read_key;
   acknowledge;
   if(!irq||status!=8'h80||data!=code)$fatal(1,"held key never reasserted IRQ scan=%h",scan);
   // Incoming hardware typematic frames must not create a second FIFO event.
   if(extended)send(8'he0);send(scan);
   if(dut.queue_count!=0)$fatal(1,"typematic queued another key");
   read_key;
   acknowledge;
   if(!irq||data!=code)$fatal(1,"held key did not rearm a second time");
   // Release cancels a repeat which has not yet been read by the CPU.
   if(extended)send(8'he0);send(8'hf0);send(scan);
   if(irq||data!=8'hff)$fatal(1,"break retained a pending repeat");
   for(n=0;n<12;n=n+1)begin acknowledge;if(irq)$fatal(1,"repeat continued after break");end
  end
 endtask
 task lock_key;input[7:0]scan;input extended;integer n;
  begin
   if(extended)send(8'he0);send(scan);read_key;
   for(n=0;n<40;n=n+1)begin acknowledge;if(irq)$fatal(1,"lock key auto-repeated");end
   if(extended)send(8'he0);send(8'hf0);send(scan);
  end
 endtask
 initial begin
  #22;reset=0;
  hold_key(8'h1c,0);hold_key(8'h66,0); // A and Backspace
  hold_key(8'h6b,1);hold_key(8'h72,1); // Left and Down
  lock_key(8'h58,0);lock_key(8'h1f,1);lock_key(8'h27,1);
  // An unread initial make survives its break and is delivered exactly once.
  send(8'h32);send(8'hf0);send(8'h32);
  if(data!="b"||!irq)$fatal(1,"unread tap was discarded");
  read_key;for(integer n=0;n<12;n=n+1)acknowledge;
  if(irq||data!=8'hff||dut.queue_count!=0)$fatal(1,"tap left a repeat");
  $display("PASS held character/Backspace/arrows IRQ pacing, typematic suppression, break cancellation and nonrepeating lock keys");
  $finish;
 end
endmodule
