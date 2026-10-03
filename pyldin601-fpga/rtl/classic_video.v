// Monochrome composite PAL 625/50, classic MC6845 register facade.
// 24 MHz single domain, 8 MHz pixel enable. The existing font EBR is seeded at
// FPGA configuration, then receives the SD font through physical SRAM writes.
module classic_video #(parameter FONT_FILE="rtl/font_boot.mem") (
    input wire clk,reset,
    input wire bus_read,bus_write,bus_address,
    input wire [7:0] bus_data,
    output wire [7:0] bus_result,
    input wire graphics,
    input wire font_write,
    input wire [10:0] font_address,
    input wire [7:0] font_data,
    output wire mem_request,
    output reg [20:0] mem_address,
    input wire mem_ready,mem_done,
    input wire [7:0] mem_data,
    output reg [5:0] tvout,
    output reg tick50
);
    reg [7:0] registers[0:15];reg[7:0] register_index;
    (* syn_ramstyle = "block_ram" *) reg [7:0] font[0:2047];
    initial $readmemh(FONT_FILE,font);
    reg [7:0] line_cache[0:39],font_pixels;
    reg [1:0] divide;
    reg [7:0] half_pixel;
    reg [10:0] half_line;
    wire [9:0] field_half=half_line<625?half_line:half_line-625;
    wire [8:0] horizontal={half_line[0],half_pixel};
    wire [8:0] field_line=field_half>>1;
    wire [8:0] y=field_line-50;
    wire [8:0] next_y=field_line+1-50;
    wire [15:0] start_addr={registers[12],registers[13]};
    wire [15:0] cursor_addr={registers[14],registers[15]};
    // Match the original MC6845 renderer's txt260/grf260=-1 convention.
    // Text compares after src++, graphics before advancing the eight-byte cell.
    wire [15:0] text_cursor=cursor_addr-16'd2;
    wire [15:0] graphics_cursor=(cursor_addr-16'd1)<<3;
    wire [7:0] stride=registers[1]>(graphics?48:42)?(graphics?8'd48:8'd42):registers[1];
    wire [8:0] x=horizontal-100;
    wire [5:0] column=x>>3;
    // Keep the carry until applying the classic display's wrap. A 16-bit
    // addition alone would select base RAM after scrolling past screen RAM.
    // Match mc6845.c: text advances FFFE -> F000; graphics skips cell FFF8.
    function [15:0] text_address;
        input [15:0] origin;
        input [11:0] offset;
        reg [16:0] sum;
        begin
            sum={1'b0,origin}+offset;
            if(origin==16'hffff && offset!=0)text_address=16'hf000+offset-1'b1;
            else if(sum>=17'h0ffff && offset!=0)text_address=sum-17'h00fff;
            else text_address=sum[15:0];
        end
    endfunction
    function [15:0] graphics_address;
        input [15:0] origin;
        input [11:0] cells;
        reg [16:0] sum;
        begin
            sum={1'b0,origin[12:0],3'b0}+{2'b0,cells,3'b0};
            graphics_address=sum>=17'h0fff8 ? sum-17'h0fff8 : sum[15:0];
        end
    endfunction
    // A scanline is stable well before x=0 or the next-line fetch. Register
    // its stride product so wrap/cursor logic fits one 24 MHz period.
    reg [11:0] line_offset,next_line_offset;
    always @(posedge clk)begin
        if(reset)begin line_offset<=0;next_line_offset<=0;end
        else begin
            line_offset<=(y>>3)*stride;
            next_line_offset<=(next_y>>3)*stride;
        end
    end
    wire [15:0] text_position=text_address(start_addr,line_offset+column);
    wire [15:0] graphics_position=graphics_address(start_addr,line_offset+column);
    wire [15:0] next_text=text_address(start_addr,next_line_offset);
    wire [15:0] next_graphics=graphics_address(start_addr,next_line_offset)+next_y[2:0];
    reg [7:0] pixels;
    reg [5:0] blink;
    reg sync_low;
    reg[1:0] dma_state;
    reg[5:0] dma_column;
    assign mem_request=dma_state==1;
    assign bus_result=bus_address?registers[register_index[3:0]]:register_index;
    integer i;
    always @*begin
        if(field_half<5 || (field_half>=10&&field_half<15))sync_low=half_pixel<19;
        else if(field_half<10)sync_low=half_pixel<237;
        else sync_low=horizontal<37;
        pixels=0;
        if(column<40)begin
            if(graphics)pixels=line_cache[column];
            else pixels=font_pixels;
            if((!graphics&&text_position==text_cursor
                ||graphics&&graphics_position==graphics_cursor)
                && y[2:0]>=registers[10][4:0]&&y[2:0]<=registers[11][4:0]
                && registers[10][6:5]!=1 && (registers[10][6:5]==0||!blink[5]))pixels=~pixels;
        end
    end
    // Font reads have one system-clock latency; two clocks remain before pixel enable.
    wire[7:0]font_character=column<40?line_cache[column]:8'b0;
    always @(posedge clk)begin
        if(font_write)font[font_address]<=font_data;
        font_pixels<=font[{font_character[6:0],font_character[7],y[2:0]}];
    end
    always @(posedge clk)begin
        tick50<=0;
        if(reset)begin
            register_index<=0;divide<=0;half_pixel<=0;half_line<=0;
            tvout<=0;tick50<=0;blink<=0;dma_state<=0;dma_column<=0;mem_address<=0;
            for(i=0;i<16;i=i+1)registers[i]<=0;
        end else begin
            if(bus_write)begin
                if(!bus_address)register_index<=bus_data;
                else registers[register_index[3:0]]<=bus_data;
            end
            if(divide==2)begin
                divide<=0;
                if(half_pixel==255)begin
                    half_pixel<=0;
                    if(half_line==1249)half_line<=0;else half_line<=half_line+1'b1;
                    if(half_line==624||half_line==1249)begin tick50<=1;blink<=blink+1'b1;end
                end else half_pixel<=half_pixel+1'b1;
                if(sync_low)tvout<=0;
                else if(horizontal>=100&&horizontal<420&&field_line>=50&&field_line<282
                        &&y<registers[6]*8&&column<registers[1])
                    tvout<=pixels[7-x[2:0]]?6'd49:6'd15;
                else tvout<=15;
                if(horizontal==430&&field_line>=49&&next_y<registers[6]*8&&dma_state==0)begin
                    dma_column<=0;
                    mem_address<=graphics?{5'b0,next_graphics}:{5'b0,next_text};
                    dma_state<=1;
                end
            end else divide<=divide+1'b1;
            case(dma_state)
                1:if(mem_ready)dma_state<=2;
                2:if(mem_done)begin
                    line_cache[dma_column]<=mem_data;
                    if(dma_column==39)dma_state<=0;
                    else begin
                        dma_column<=dma_column+1'b1;
                        if(graphics)
                            mem_address<=mem_address[15:3]==13'h1ffe ?
                                {18'b0,mem_address[2:0]}:{5'b0,mem_address[15:0]+16'd8};
                        else
                            mem_address<=mem_address[15:0]>=16'hfffe ?
                                21'h0f000:{5'b0,mem_address[15:0]+16'd1};
                        dma_state<=1;
                    end
                end
            endcase
        end
    end
endmodule
