// Independent PS/2 set 2 byte FIFO. Native keyboard translation/IRQ is untouched.
// E6B0: identity 'R'; E6B1: overflow/full/available (bits 7/5/0).
// E6B2: read/pop oldest byte (FF if empty); E6B3: count (0..64).
// Write E6B3: bit 0 flush, bit 1 clear sticky overflow. No raw keyboard IRQ.
module classic_ps2_raw (
    input wire clk,reset,received,
    input wire [7:0] scan,
    input wire read,write,
    input wire [1:0] address,
    input wire [7:0] data_in,
    output reg [7:0] data_out
);
    (* syn_ramstyle="distributed" *) reg [7:0] bytes[0:63];
    reg [5:0] head,tail;
    reg [6:0] count;
    reg overflow;
    wire pop=read&&address==2&&count!=0;
    // A simultaneous read frees a slot even when the FIFO was full.
    wire push=received&&(count<64||pop);
    wire flush=write&&address==3&&data_in[0];
    wire clear_overflow=write&&address==3&&data_in[1];
    always @*case(address)
        0:data_out=8'h52;
        1:data_out={overflow,1'b0,count==64,4'b0,count!=0};
        2:data_out=count!=0?bytes[head]:8'hff;
        3:data_out={1'b0,count};
    endcase
    always @(posedge clk)begin
        if(reset)begin head<=0;tail<=0;count<=0;overflow<=0;end
        else begin
            if(clear_overflow)overflow<=0;
            // Overflow wins over clear if a new byte is dropped on that edge.
            if(received&&!push&&!flush)overflow<=1;
            if(flush)begin head<=0;tail<=0;count<=0;end
            else begin
                if(push)begin bytes[tail]<=scan;tail<=tail+1'b1;end
                if(pop)head<=head+1'b1;
                case({push,pop})
                    2'b10:count<=count+1'b1;
                    2'b01:count<=count-1'b1;
                endcase
            end
        end
    end
endmodule
