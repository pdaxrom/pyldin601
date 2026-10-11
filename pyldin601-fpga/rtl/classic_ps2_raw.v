// Independent PS/2 set 2 byte FIFO with optional exclusive native-keyboard capture.
// E6B0: identity 'R'; E6B1: overflow/captured/full/parser reset/consumed/available
// (bits 7/6/5/3/2/0). E6B4: interface revision 2.
// E6B2: read/pop oldest byte (FF if empty); E6B3: count (0..64).
// Write E6B3: bit 0 flush, bit 1 clear overflow, bit 2 capture, bit 3 release.
// Bits 4/5/6 enable IRQ / acknowledge parser reset / disable IRQ.
// IRQ holds while bytes, overflow or parser reset need service; capture masks it.
// Reset or an explicit return to native video releases capture.
module classic_ps2_raw (
    input wire clk,reset,received,
    input wire [7:0] scan,
    input wire read,write,
    input wire [2:0] address,
    input wire [7:0] data_in,
    output reg [7:0] data_out,
    input wire release_capture,
    output reg native_capture,
    input wire native_consumed,
    output wire irq
);
    reg irq_enabled,parser_reset;
    (* syn_ramstyle="distributed" *) reg [7:0] bytes[0:63];
    reg [5:0] head,tail;
    reg [6:0] count;
    reg overflow;
    assign irq=irq_enabled&&!native_capture&&(count!=0||overflow||parser_reset);
    wire pop=read&&address==2&&count!=0;
    // A simultaneous read frees a slot even when the FIFO was full.
    wire push=received&&(count<64||pop);
    wire flush=write&&address==3&&data_in[0];
    wire clear_overflow=write&&address==3&&data_in[1];
    always @*case(address)
        0:data_out=8'h52;
        1:data_out={overflow,native_capture,count==64,1'b0,parser_reset,native_consumed,1'b0,count!=0};
        2:data_out=count!=0?bytes[head]:8'hff;
        3:data_out={1'b0,count};
        4:data_out=8'h02;
        default:data_out=8'hff;
    endcase
    always @(posedge clk)begin
        if(reset)begin head<=0;tail<=0;count<=0;overflow<=0;native_capture<=0;irq_enabled<=0;parser_reset<=0;end
        else begin
            if(write&&address==3)begin
                if(data_in[4])irq_enabled<=1;
                if(data_in[6])irq_enabled<=0;
                if(data_in[5])parser_reset<=0;
                if(data_in[2]&&!native_capture)parser_reset<=1;
                if(data_in[3]&&native_capture)parser_reset<=1;
                if(data_in[2])native_capture<=1;
            end
            if(release_capture||(write&&address==3&&data_in[3]))begin
                native_capture<=0;
                if(native_capture)parser_reset<=1;
            end
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
