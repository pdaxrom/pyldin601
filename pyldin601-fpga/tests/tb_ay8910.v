`timescale 1ns/1ps
// Independent chip-level reference; does not execute the hardware microcode.
module tb_ay8910;
 reg clk=0,fast=0,reset=1,write=0,beeper=0;
 always #20.833 clk=~clk;
 always #5.20825 fast=~fast;
 reg[3:0]address=0;reg[7:0]data=0;wire[7:0]result;wire audio;
 classic_ay8910 dut(clk,fast,reset,write,address,data,result,audio,beeper);
`ifdef SYNTHESIS
 GSR GSR_INST(1'b1);PUR PUR_INST(1'b1);
`endif
 function[8:0]ram_word;input integer a;
 begin
`ifdef SYNTHESIS
  for(integer b=0;b<9;b++)ram_word[b]=dut.ram.v_MEM[a*9+b];
`else
  ram_word=dut.memory[a];
`endif
 end endfunction
 integer r[0:15],c[0:4],tone[0:2],noise=1,prescale=0,step=0,attack=0,holding=1;
 integer restart=0,mix=0,ticks=0,checks=0,desired[0:15],seq=1;
 reg ready=0;
 function integer gain;input integer level;
 begin case(level)
  0:gain=0;1:gain=1;2:gain=2;3:gain=3;4:gain=4;5:gain=6;6:gain=8;7:gain=12;
  8:gain=16;9:gain=23;10:gain=32;11:gain=45;12:gain=64;13:gain=80;14:gain=101;15:gain=127;
 endcase end endfunction
 task reference_tick;
 integer k,p,level;
 begin
  for(k=0;k<3;k=k+1)begin
   p=r[2*k]+256*r[2*k+1];if(p==0)p=1;
   c[k]=c[k]+1;
   if(c[k]>=p)begin c[k]=0;tone[k]=1-tone[k];end
  end
  p=r[6];if(p==0)p=1;c[3]=c[3]+1;
  if(c[3]>=p)begin
   c[3]=0;prescale=1-prescale;
   if(prescale==0)noise=(noise>>1)|(((noise^(noise>>3))&1)<<16);
  end
  p=2*(r[11]+256*r[12]);if(p==0)p=1;
  if(restart)begin c[4]=0;step=15;attack=(r[13]>>2)&1;holding=0;restart=0;end
  else if(!holding)begin
   c[4]=c[4]+1;
   if(c[4]>=p)begin
    c[4]=0;
    if(!holding)begin
     if(step!=0)step=step-1;
     else if(!(r[13]&8)||(r[13]&1))begin
      step=0;holding=1;
      if(!(r[13]&8))attack=0;else if(r[13]&2)attack=1-attack;
     end else begin step=15;if(r[13]&2)attack=1-attack;end
    end
   end
  end
  mix=0;
  for(k=0;k<3;k=k+1)begin
   level=(r[8+k]&16)?step^(attack?15:0):r[8+k]&15;
   if((tone[k]||((r[7]>>k)&1))&&((noise&1)||((r[7]>>(k+3))&1)))mix=mix+gain(level);
  end
  ticks=ticks+1;
 end endtask
 always @(posedge fast)begin
  if(ready&&!reset&&!dut.initializing&&dut.state==0&&dut.pc==0&&!dut.service_write)reference_tick;
  if(ready&&!reset&&!dut.initializing&&dut.state==4&&dut.operation==13&&dut.clock_count<260&&!dut.service_write)begin
   #1;
   if(dut.sample!==mix)$fatal(1,"AY mixer tick=%d sample=%d ref=%d",ticks,dut.sample,mix);
   if(dut.tone!=={tone[2][0],tone[1][0],tone[0][0]}||dut.noise_lfsr!==noise||dut.noise_prescale!==prescale)
    $fatal(1,"AY tone/noise mismatch tick=%d",ticks);
   if(dut.env_step!==step||dut.env_attack!==attack||dut.env_holding!==holding)$fatal(1,"AY envelope shape=%h tick=%d got=%d/%d/%d ref=%d/%d/%d",r[13],ticks,dut.env_step,dut.env_attack,dut.env_holding,step,attack,holding);
   for(integer k=0;k<5;k=k+1)if(256*ram_word(17+2*k)+(ram_word(16+2*k)&255)!==c[k])$fatal(1,"AY counter %d tick=%d ref=%d",k,ticks,c[k]);
   checks=checks+1;
   // The wait instruction remains parked: check only its first execution.
   while(dut.state==4&&dut.operation==13)@(negedge fast);
  end
 end
 task wr;input integer n,v;
 integer masked;
 begin
  @(negedge clk);address=n;data=v;write=1;
  @(posedge clk);#1;write=0;
  masked=v&255;
  case(n)
   1,3,5,13:masked=masked&15;
   6,8,9,10:masked=masked&31;
  endcase
  r[n]=masked;if(n==13)restart=1;
  repeat(2)@(negedge clk);
  if(result!==(n>=14?8'hff:masked))$fatal(1,"AY register %d read %h expected %h",n,result,masked);
 end endtask
 task idle;begin while(dut.clock_count!=220)@(negedge fast);end endtask
 task frames;input integer n;integer target;
 begin target=ticks+n;while(ticks<target||dut.pc!=42||dut.state!=4)@(negedge fast);end endtask
 integer k,j,s,p,total,seed;
 initial begin
  for(k=0;k<16;k=k+1)r[k]=0;
  for(k=0;k<5;k=k+1)c[k]=0;
  for(k=0;k<3;k=k+1)tone[k]=0;
  repeat(5)@(negedge clk);reset=0;
  wait(!dut.initializing);ready=1;
  frames(2);
  idle();for(k=0;k<16;k=k+1)wr(k,255);frames(4);
  idle();wr(7,63);wr(8,15);wr(9,15);wr(10,15);frames(3);
  // Three channels plus beeper remain below the nine-bit mixer limit.
  beeper=1;repeat(3)@(negedge clk);
  total=0;repeat(512)begin @(negedge clk);total=total+audio;end
  if(total!=509)$fatal(1,"AY sigma-delta density %d/512",total);
  beeper=0;
  for(k=0;k<16;k=k+1)begin idle();wr(8,k);wr(9,0);wr(10,0);frames(3);end
  // Every noise period, including zero=one, and all mixer gate combinations.
  for(k=0;k<32;k=k+1)begin idle();wr(6,k);wr(7,k*2);frames(80);end
  for(k=0;k<8;k=k+1)begin
   case(k)0:p=0;1:p=1;2:p=2;3:p=15;4:p=255;5:p=256;6:p=2048;7:p=4095;endcase
   idle();for(j=0;j<3;j=j+1)begin wr(j*2,p&255);wr(j*2+1,p>>8);end
   wr(7,56);wr(8,15);wr(9,14);wr(10,13);frames(2*p+80);
  end
  // All sixteen shapes, zero's half-period, normal period and retrigger.
  for(s=0;s<16;s=s+1)for(p=0;p<3;p=p+1)begin
   idle();wr(7,63);wr(8,16);wr(9,0);wr(10,0);wr(11,p);wr(12,0);wr(13,s);
   frames(150);idle();wr(13,s);wr(13,s);frames(150);
  end
  // Maximum 16-bit envelope period, then change while its counter is high.
  idle();wr(11,255);wr(12,255);wr(13,10);frames(131080);
  idle();wr(11,1);wr(12,0);frames(100);
  seed=32'h6351;
  for(k=0;k<600;k=k+1)begin
   seed=seed*1103515245+12345;j=(seed>>16)&15;
   idle();wr(j,(seed>>3)&255);frames(3);
  end
  if(checks<150000)$fatal(1,"AY reference checks missing: %d",checks);
  ready=0;@(negedge clk);reset=1;repeat(10)@(negedge clk);reset=0;
  wait(!dut.initializing);repeat(3)@(negedge clk);
  for(k=0;k<14;k=k+1)begin address=k;repeat(2)@(negedge clk);if(result!==0)$fatal(1,"AY warm reset register %d not zero",k);end
  if(dut.sample!=0||audio)$fatal(1,"AY reset not silent");
  $display("PASS AY-3-8910: %d chip ticks/%d independent state checks, three 12-bit tones, zero/change periods, 17-bit noise, 16 envelope shapes/retrigger/65535 period, logarithmic levels, mixer, register masks/GPIO, sigma-delta density, warm reset",ticks,checks);$finish;
 end
 initial begin #800000000;$fatal(1,"AY timeout ticks=%d checks=%d pc=%d state=%d",ticks,checks,dut.pc,dut.state);end
endmodule
