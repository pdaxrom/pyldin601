// MC6800 bus-cycle adapter, clocked entirely by the 24 MHz system clock.
// Latch one CPU operation at phase 2. Peripheral strobes occur exactly once;
// SRAM requests persist through acceptance and completion. Retain CPU data
// independently of the shared SRAM output until the CPU falling edge.
module classic_cpu_bus(
 input wire clk,reset,
 input wire[4:0]phase,
 input wire cpu_vma,cpu_rw,input wire[7:0]cpu_out,
 input wire peripheral,input wire[7:0]peripheral_data,
 input wire[20:0]physical_address,input wire disk_access,
 output wire cycle,request,hold,disk_advance,
 output reg write,output reg[20:0]address,output reg[7:0]data,
 input wire accept,done,input wire[7:0]read_data,
 output reg[7:0]cpu_in
);
 reg pending,complete,issued,memory_cycle,accessing_disk;
 assign cycle=phase==2&&!reset&&!pending&&cpu_vma;
 assign request=pending&&memory_cycle&&!complete&&!issued&&!reset;
 assign hold=pending&&!complete;
 assign disk_advance=!reset&&done&&pending&&issued&&accessing_disk;
 always @(posedge clk)begin
  if(reset)begin
   pending<=0;complete<=0;issued<=0;memory_cycle<=0;accessing_disk<=0;
   write<=0;address<=0;data<=0;cpu_in<=8'hff;
  end else begin
   // This edge follows CPU capture by half a system period.
   if(phase==0&&complete)begin pending<=0;complete<=0;issued<=0;end
   if(accept)issued<=1;
   if(done&&pending&&issued)begin cpu_in<=read_data;complete<=1;end
   if(cycle)begin
    pending<=1;complete<=peripheral;issued<=0;memory_cycle<=!peripheral;
    write<=!cpu_rw;address<=physical_address;data<=cpu_out;accessing_disk<=disk_access;
    if(peripheral)cpu_in<=peripheral_data;
   end
  end
 end
endmodule
