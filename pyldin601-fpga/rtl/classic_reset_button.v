// Short release: one speed event. A >=2 s press: warm reset until release.
// Count milliseconds, debounce both edges, and consume long presses completely.
module classic_reset_button #(parameter TICK_DIV=24000,DEBOUNCE_MS=20,LONG_MS=2000)(
 input wire clk,cold_reset,button_n,output reg tap,output reg warm_request
);
 reg[2:0]synchronizer=7;
 localparam WIDTH=TICK_DIV<2?1:$clog2(TICK_DIV);
 reg[WIDTH-1:0]divider=0;
 reg[4:0]debounce=0;reg released=1;localparam DURATION_WIDTH=LONG_MS<2?1:$clog2(LONG_MS);
 reg[DURATION_WIDTH-1:0]duration=0;reg long_seen=0;
 always @(posedge clk)begin
  synchronizer<={synchronizer[1:0],button_n};tap<=0;
  if(cold_reset)begin divider<=0;debounce<=0;released<=1;duration<=0;long_seen<=0;warm_request<=0;end
  else begin
   divider<=divider==TICK_DIV-1?0:divider+1'b1;
   if(divider==TICK_DIV-1)begin
    if(synchronizer[2]==released)debounce<=0;
    else if(debounce==DEBOUNCE_MS-1)begin
     debounce<=0;released<=synchronizer[2];
     if(synchronizer[2])begin tap<=!long_seen;warm_request<=0;long_seen<=0;duration<=0;end
     else begin duration<=0;long_seen<=0;end
    end else debounce<=debounce+1'b1;
    if(!released&&!long_seen&&!(synchronizer[2]&&debounce==DEBOUNCE_MS-1))begin
     if(duration==LONG_MS-1)begin warm_request<=1;long_seen<=1;end
     else duration<=duration+1'b1;
    end
   end
  end
 end
endmodule
