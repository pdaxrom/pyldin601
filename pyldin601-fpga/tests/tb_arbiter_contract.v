`timescale 1ns/1ps
// Adversarial clients: simultaneous requests, changing withdrawn payloads,
// delayed backend readiness, reset in every flight phase, and slot boundaries.
module tb_arbiter_contract;
 reg clk=0; always #5 clk=~clk;
 reg reset=1,runtime=0;reg[4:0]phase=0;
 reg[2:0]req=0,write=0;reg[62:0]address=0;reg[23:0]data=0;
 wire[2:0]accept,done;wire busy,mreq,mwrite;wire[20:0]ma;wire[7:0]md;
 reg ready=0,complete=0;
 memory_arbiter #(.RUNTIME_SLOTS(1)) dut(clk,reset,req,write,address,data,
  accept,done,busy,mreq,mwrite,ma,md,ready,complete,runtime,phase);
 reg[31:0]rng=32'h6018272;integer owner=-1,age=0,latency=0;
 reg[20:0]held_address;reg[7:0]held_data;reg held_write;
 integer accepted[0:2],completed[0:2],cancelled[0:2],wait_age[0:2];
 integer n,step,flight_resets=0;reg[2:0]previous_accept=0;
 always @(posedge clk)begin
  if(reset)begin
   if(owner>=0)begin cancelled[owner]=cancelled[owner]+1;flight_resets=flight_resets+1;end
   owner=-1;age=0;
   for(n=0;n<3;n=n+1)wait_age[n]=0;
   if(accept||done||mreq)$fatal(1,"reset leaked a handshake");
  end else begin
   if((accept&(accept-1))||(done&(done-1)))$fatal(1,"multiple owners");
   if(accept&&done)$fatal(1,"completion reused as a new acceptance");
   if(owner>=0)begin
    if({mwrite,ma,md}!=={held_write,held_address,held_data})$fatal(1,"payload changed during flight");
    if(accept||mreq)$fatal(1,"accepted while occupied");
    if(done)begin
     if(done!==(3'b001<<owner))$fatal(1,"response went to wrong owner");
     completed[owner]=completed[owner]+1;owner=-1;
    end else age=age+1;
   end else if(done)$fatal(1,"stale/unowned completion");
   if(accept)begin
    for(n=0;n<3;n=n+1)if(accept[n])begin
     if(!req[n]||!ready)$fatal(1,"accept without request/ready");
     if(runtime&&((n==0&&phase!=3)||n==1||(n==2&&phase!=10&&phase!=17)))$fatal(1,"slot collision");
     owner=n;accepted[n]=accepted[n]+1;age=0;
     held_write=write[n];held_address=address[n*21+:21];held_data=data[n*8+:8];
     if({mwrite,ma,md}!=={held_write,held_address,held_data})$fatal(1,"wrong accepted payload");
    end
   end
   // Under saturation every client must be served within three grants.
   if(!runtime&&req==7&&accept)for(n=0;n<3;n=n+1)begin
    wait_age[n]=accept[n]?0:wait_age[n]+1;
    if(wait_age[n]>2)$fatal(1,"boot client starved %d",n);
   end
   if(runtime||req!=7)for(n=0;n<3;n=n+1)wait_age[n]=0;
  end
  previous_accept<=accept;
 end
 initial begin
  for(n=0;n<3;n=n+1)begin accepted[n]=0;completed[n]=0;cancelled[n]=0;wait_age[n]=0;end
  for(step=0;step<30000;step=step+1)begin
   @(negedge clk);
   rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
   reset=step<3 || (step>4000&&(step%127==64||rng[7:0]==0));
   runtime=step>=15000;
   phase=phase==23?0:phase+1'b1;
   // First exercise saturated fairness, then arbitrary clients.
   req=step<4000?7:rng[2:0];write=rng[5:3];
   address={rng[20:0],rng[21:1],rng[22:2]};data=rng[31:8];
   ready=owner<0&&rng[7];
   if(previous_accept)latency=runtime?4:1+rng[11:8];
   complete=owner>=0&&age>=latency;
  end
  @(negedge clk);reset=1;req=0;
  @(negedge clk);
  for(n=0;n<3;n=n+1)if(accepted[n]!=completed[n]+cancelled[n]||accepted[n]<100)
   $fatal(1,"lost/duplicate response owner=%d accept=%d done=%d cancelled=%d",n,accepted[n],completed[n],cancelled[n]);
  if(flight_resets<5)$fatal(1,"insufficient reset coverage");
  $display("PASS arbiter contract: 30000 adversarial clocks, boot fairness, fixed runtime slots, frozen payload, %d in-flight resets",flight_resets);$finish;
 end
endmodule
