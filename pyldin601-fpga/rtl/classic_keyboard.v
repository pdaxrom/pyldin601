// Software-fed original keyboard ports. No scancode tables or key state machine.
// DATA writes load a code. STATUS bit 7 arms the strobe only for a fresh code;
// native BIOS Caps Lock writes cannot re-arm an already consumed character.
module classic_keyboard(input wire clk,reset,capture,
 input wire read_data,read_status,write_data,write_status,
 input wire [7:0]data_in,
 output wire [7:0]data,status,output wire irq,output reg consumed);
 reg [7:0]code;reg trigger,pending;
 assign data=capture?8'hff:code;
 assign status=capture?0:(trigger?8'h80:0);
 assign irq=pending&&!capture;
 always @(posedge clk)begin
  if(reset||capture)begin code<=8'hff;trigger<=0;pending<=0;consumed<=1;end
  else begin
   if(read_status&&!consumed&&code!=8'hff)trigger<=!trigger;
   if(read_data)begin trigger<=0;pending<=0;consumed<=1;end
   if(write_data)begin code<=data_in;trigger<=0;pending<=0;consumed<=data_in==8'hff;end
   if(write_status&&data_in[7]&&!consumed&&code!=8'hff)begin trigger<=1;pending<=1;end
  end
 end
endmodule
