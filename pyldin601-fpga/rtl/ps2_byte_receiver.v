// Electrical PS/2 Set 2 byte receiver. Prefixes/layout/held keys live in ROM.
module ps2_byte_receiver(input wire clk,reset,ps2_clk,ps2_data,
 output wire valid,output wire [7:0]data);
    reg [2:0] clock_sync,data_sync;
    reg [7:0] filter;
    reg filtered_clock,last_clock;
    reg [10:0] frame;
    reg [3:0] count;
    reg [15:0] timeout;
    reg received;
    reg [7:0] scan;
    assign valid=received;assign data=scan;
    always @(posedge clk)begin
        clock_sync<={clock_sync[1:0],ps2_clk};data_sync<={data_sync[1:0],ps2_data};
        filter<={filter[6:0],clock_sync[2]};last_clock<=filtered_clock;
        if(&filter)filtered_clock<=1;else if(~|filter)filtered_clock<=0;
        received<=0;
        if(reset)begin
            clock_sync<=7;data_sync<=7;filter<=8'hff;filtered_clock<=1;last_clock<=1;
            count<=0;timeout<=0;frame<=0;scan<=0;received<=0;
        end else begin
            if(count!=0)begin
                if(timeout==16'd24000)begin count<=0;timeout<=0;end
                else timeout<=timeout+1'b1;
            end
            if(last_clock&&!filtered_clock)begin
                timeout<=0;frame<={data_sync[2],frame[10:1]};
                if(count==10)begin
                    count<=0;
                    if(frame[1]==0&&data_sync[2]&&(^frame[10:2]))begin
                        scan<=frame[9:2];received<=1;
                    end
                end else count<=count+1'b1;
            end
        end
    end
endmodule
