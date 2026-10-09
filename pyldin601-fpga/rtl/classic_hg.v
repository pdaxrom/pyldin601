// HG v1/v2, FT2232A MPSSE mode 0, LSB first. No access to CPU/video SRAM.
// E670 DATA (RX pop/TX push), E671 STATUS, E672 CONTROL, E673 ID='H'.
// CONTROL: bit0 request/TDO enable, bit1 RX enable, bit2 TX enable,
// bit3 packet credits, bit4 inhibit credit (status phase), bit5 final TX,
// bit7 flush while idle. STATUS: bit0 RX ready, bit1 TX room, bit2 SELECT,
// bit3 TX empty, bit4 v2 capable, bit6 RX overflow, bit7 TX underflow.
// With SELECT low, TDO grants a burst of up to 32 bytes in packet mode.
// Final TX permits the shorter checksum tail. Two 64-byte EBR FIFOs.
module classic_hg(
    input wire clk,reset,read,write,input wire[1:0]address,
    input wire[7:0]data_in,output reg[7:0]data_out,
    input wire tms,tck,tdi,output wire tdo,tdo_enable
);
    reg[2:0]select_sync,clock_sync;
    reg[1:0]data_sync;
    reg request,rx_enable,tx_enable,overflow,underflow,tdo_data;
    reg packet_mode,credit_inhibit,tx_final;
    reg[2:0]bit_index;
    reg[7:0]rx_shift,rx_head,tx_head;
    (* syn_ramstyle="block_ram" *) reg[7:0]rx_fifo[0:63];
    (* syn_ramstyle="block_ram" *) reg[7:0]tx_fifo[0:63];
    // Wrap bits distinguish full/empty without two up/down counters.
    reg[6:0]rx_read,rx_write,tx_read,tx_write;
    wire rx_empty=rx_read==rx_write,tx_empty=tx_read==tx_write;
    wire rx_full=rx_read[5:0]==rx_write[5:0]&&rx_read[6]!=rx_write[6];
    wire tx_full=tx_read[5:0]==tx_write[5:0]&&tx_read[6]!=tx_write[6];
    wire[6:0]rx_count=rx_write-rx_read,tx_count=tx_write-tx_read;
    wire credit=!credit_inhibit&&((rx_enable&&rx_count<=32)||
        (tx_enable&&(tx_count>=32||(tx_final&&!tx_empty))));
    wire selected=select_sync[1];
    reg selected_before;
    wire rising=clock_sync[1]&&!clock_sync[2];
    wire falling=!clock_sync[1]&&clock_sync[2];
    // v2 status query with SELECT low never clocks either FIFO. Bit0 remains
    // the idle GPIO request/credit; the other bits identify direction/phase.
    wire query_mode=packet_mode&&(!selected||(!rx_enable&&!tx_enable));
    wire[7:0]query_status={request,overflow||underflow,tx_final,credit_inhibit,
        packet_mode,tx_enable,rx_enable,request&&(!packet_mode||credit)};
    wire rx_pop=read&&address==0&&!rx_empty;
    wire rx_push=request&&selected&&rising&&bit_index==7&&rx_enable;
    wire tx_push=write&&address==0&&!tx_full;
    wire tx_pop=request&&selected&&falling&&bit_index==7&&tx_enable&&!tx_empty;
    wire flush=write&&address==2&&data_in[7]&&!request&&!selected;
    assign tdo_enable=request;
    // Register the return pin at 24 MHz. This also bounds its setup relative
    // to the synchronized falling TCK edge (supported host TCK <= 1 MHz).
    assign tdo=tdo_data;
    always @*case(address)
        0:data_out=!rx_empty?rx_head:8'hff;
        1:data_out={underflow,overflow,1'b0,1'b1,tx_empty,selected,!tx_full,!rx_empty};
        2:data_out={2'b0,tx_final,credit_inhibit,packet_mode,tx_enable,rx_enable,request};
        3:data_out=8'h48;
    endcase
    // RAM ports stay synchronous and have no reset mux, for EBR inference.
    always @(posedge clk)begin
        tdo_data<=query_mode ? query_status[bit_index] : !selected ? request :
            tx_enable&&!tx_empty ? tx_head[bit_index] : 1'b0;
        rx_head<=rx_fifo[rx_read[5:0]];tx_head<=tx_fifo[tx_read[5:0]];
        if(tx_push)tx_fifo[tx_write[5:0]]<=data_in;
        if(rx_push&&(!rx_full||rx_pop))rx_fifo[rx_write[5:0]]<={data_sync[1],rx_shift[7:1]};
    end
    always @(posedge clk)begin
        select_sync<={select_sync[1:0],tms};clock_sync<={clock_sync[1:0],tck};data_sync<={data_sync[0],tdi};
        selected_before<=selected;
        if(reset)begin
            select_sync<=0;clock_sync<=0;data_sync<=0;
            request<=0;rx_enable<=0;tx_enable<=0;overflow<=0;underflow<=0;
            packet_mode<=0;credit_inhibit<=0;tx_final<=0;
            selected_before<=0;
            bit_index<=0;rx_shift<=0;
            rx_read<=0;rx_write<=0;tx_read<=0;tx_write<=0;
        end else if(flush)begin
            overflow<=0;underflow<=0;bit_index<=0;
            rx_read<=0;rx_write<=0;tx_read<=0;tx_write<=0;
        end else begin
            if(write&&address==2)begin
                request<=data_in[0];rx_enable<=data_in[1];tx_enable<=data_in[2];
                packet_mode<=data_in[3];credit_inhibit<=data_in[4];tx_final<=data_in[5];
            end
            if(!request||selected!=selected_before)bit_index<=0;
            else begin
                if(rising&&selected&&!query_mode)begin
                    rx_shift<={data_sync[1],rx_shift[7:1]};
                    if(tx_enable&&tx_empty)underflow<=1;
                end
                if(falling)bit_index<=bit_index+1'b1;
            end
            if(rx_push&&rx_full&&!rx_pop)overflow<=1;
            if(rx_push&&(!rx_full||rx_pop))rx_write<=rx_write+1'b1;
            if(rx_pop)rx_read<=rx_read+1'b1;
            if(tx_push)tx_write<=tx_write+1'b1;
            if(tx_pop)tx_read<=tx_read+1'b1;
        end
    end
endmodule
