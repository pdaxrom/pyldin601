// Composite PAL 625/50, MC6845 facade and selectable 601/601A video.
// 24 MHz single domain: 601 uses 8 MHz pixels, 601A two pixels per 3 clocks. The existing font EBR is seeded at
// FPGA configuration, then receives the SD font through physical SRAM writes.
module classic_video #(parameter FONT_FILE="rtl/font_boot.mem") (
    input wire clk,reset,
    input wire bus_read,bus_write,bus_address,
    input wire [7:0] bus_data,
    output wire [7:0] bus_result,
    input wire [7:0] mode,
    input wire font_write,
    input wire [10:0] font_address,
    input wire [7:0] font_data,
    output wire mem_request,
    output reg [20:0] mem_address,
    input wire mem_ready,mem_done,
    input wire [7:0] mem_data,
    output wire [5:0] tvout,
    output reg tick50,
    input wire model_a
);
    reg [7:0] registers[0:15];reg[7:0] register_index;
    wire graphics=mode[5];
    wire text40=model_a&&!graphics&&mode[1];
    wire colour_enabled=mode[2]&&(graphics||text40);
    (* syn_ramstyle = "block_ram" *) reg [7:0] font[0:2047];
    initial $readmemh(FONT_FILE,font);
    // Two 80-byte scanlines fit one 128x16 EBR. Pair bytes on write so
    // character and preceding attribute share one synchronous read port.
    (* syn_ramstyle = "block_ram" *) reg [15:0] line_cache[0:127];
    reg [15:0] cache_data;reg [7:0] dma_even,font_pixels;
    reg [1:0] divide;
    reg [7:0] half_pixel;
    reg [10:0] half_line;
    wire [9:0] field_half=half_line<625?half_line:half_line-625;
    wire [8:0] horizontal={half_line[0],half_pixel};
    // Raster rows follow complete horizontal lines in both fields. The PAL
    // second field begins halfway through a line; using field_half >> 1
    // changes y at x=156 and gives its left half the preceding font row.
    wire [8:0] field_line=(half_line>>1)-(half_line<625?9'd0:9'd312);
    reg colour_frame;
    // The established raster starts at pre-equalization. uJ11's BT.1700
    // burst-blanking sequence starts five half-lines later, at broad sync.
    wire [10:0] burst_half=half_line<5 ? half_line+11'd1245 : half_line-11'd5;
    wire [9:0] burst_line=burst_half>>1;
    wire burst_frame=half_line<5 ? !colour_frame : colour_frame;
    wire burst_blank=burst_frame ?
        (burst_line<5 || burst_line>=621 || (burst_line>=310&&burst_line<=318)) :
        (burst_line<6 || burst_line>=622 || (burst_line>=309&&burst_line<=317));
    // A frame has 625 full lines, so V polarity must also flip between frames.
    wire alternate=half_line[1]^colour_frame;
    wire [8:0] y=field_line-50;
    wire [8:0] next_y=field_line+1-50;
    wire [15:0] start_addr={registers[12],registers[13]};
    wire [15:0] cursor_addr={registers[14],registers[15]};
    // Match the original MC6845 renderer's txt260/grf260=-1 convention.
    // Text compares after src++, graphics before advancing the eight-byte cell.
    wire [15:0] text_cursor=model_a?cursor_addr:cursor_addr-16'd2;
    wire [15:0] graphics_cursor=(model_a?cursor_addr:cursor_addr-16'd1)<<3;
    wire [7:0] stride=model_a?(registers[1]>80?8'd80:registers[1]):registers[1]>(graphics?48:42)?(graphics?8'd48:8'd42):registers[1];
    wire [8:0] x=horizontal-100;
    wire [9:0] logical_x=model_a?{x,divide==2}: {1'b0,x};
    wire [6:0] column=logical_x>>3;
    wire [6:0] character_column=text40?{column[6:1],1'b1}:column;
        wire [7:0] video_byte=column[0]?cache_data[15:8]:cache_data[7:0];
    wire [7:0] attribute=cache_data[7:0];
    // Keep the carry until applying the classic display's wrap. A 16-bit
    // addition alone would select base RAM after scrolling past screen RAM.
    // Match mc6845.c: text advances FFFE -> F000; graphics skips cell FFF8.
    function [15:0] text_address;
        input [15:0] origin;
        input [11:0] offset;
        reg [16:0] sum;
        begin
            sum={1'b0,origin}+offset;
            if(model_a)text_address={origin[15:12],sum[11:0]};
            else if(origin==16'hffff && offset!=0)text_address=16'hf000+offset-1'b1;
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
            graphics_address=model_a?sum[15:0]:sum>=17'h0fff8 ? sum-17'h0fff8 : sum[15:0];
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
    wire [15:0] text_position=text_address(start_addr,line_offset+character_column);
    wire [15:0] graphics_position=graphics_address(start_addr,line_offset+column);
    wire [15:0] next_text=text_address(start_addr,next_line_offset);
    wire [15:0] next_graphics=graphics_address(start_addr,next_line_offset)+next_y[2:0];
    reg [7:0] pixels;
    reg [5:0] blink;
    reg sync_low;
    wire active=horizontal>=100&&horizontal<420&&field_line>=50&&field_line<282
        &&y<registers[6]*8&&column<registers[1];
    wire burst=colour_enabled&&!burst_blank&&horizontal>=45&&horizontal<63;
    reg [1:0] four_colour;
    reg [3:0] pixel_colour;
    always @*begin
        case(logical_x[2:1])
            0:four_colour=pixels[7:6];
            1:four_colour=pixels[5:4];
            2:four_colour=pixels[3:2];
            3:four_colour=pixels[1:0];
        endcase
        pixel_colour=0;
        if(active)begin
            if(text40)begin
                if(!colour_enabled)pixel_colour=pixels[7-logical_x[3:1]]?4'hf:4'h0;
                else pixel_colour=(pixels[7-logical_x[3:1]]&&!(attribute[7]&&blink[5]))?
                    {1'b0,attribute[6:4]}:attribute[3:0];
            end else if(!colour_enabled)pixel_colour=pixels[7-logical_x[2:0]]?4'hf:4'h0;
            else if(mode[1])pixel_colour=logical_x[2]?pixels[3:0]:pixels[7:4];
            // Palettes 0/2 are cold (B=1), 1/3 warm (B=0); PB4 is I.
            else pixel_colour={mode[4],four_colour,!mode[3]};
        end
    end
    reg [3:0] held_colour;
    reg held_sync,held_burst,held_alternate;
    wire pixel_enable=divide==1||(model_a&&divide==2);
    // Feed the EBR one clock before the 8 MHz pixel boundary. Its following
    // output register then changes the DAC on the original divide==2 edge.
    // Hold colour/raster between pixels while DDS runs at 24 MHz.
    classic_pal_encoder encoder(clk,reset,
        pixel_enable?sync_low:held_sync,pixel_enable?burst:held_burst,
        pixel_enable?alternate:held_alternate,pixel_enable?pixel_colour:held_colour,tvout);
    reg[1:0] dma_state;
    reg[6:0] dma_column;reg dma_bank;
    assign mem_request=dma_state==1;
    assign bus_result=bus_address?registers[register_index[3:0]]:register_index;
    integer i;
    always @*begin
        if(field_half<5 || (field_half>=10&&field_half<15))sync_low=half_pixel<19;
        else if(field_half<10)sync_low=half_pixel<237;
        else sync_low=horizontal<37;
        pixels=0;
        if(column<(model_a?80:40))begin
            if(graphics)pixels=video_byte;
            else pixels=font_pixels;
            if((!graphics&&text_position==text_cursor
                ||graphics&&graphics_position==graphics_cursor)
                && y[2:0]>=registers[10][4:0]&&y[2:0]<=registers[11][4:0]
                && registers[10][6:5]!=1 && (registers[10][6:5]==0||!blink[5]))pixels=~pixels;
        end
    end
    // Font reads have one system-clock latency; two clocks remain before pixel enable.
    wire[7:0]font_character=column<(model_a?80:40)?
        (character_column[0]?cache_data[15:8]:cache_data[7:0]):8'b0;
    // On divide==2 the raster advances after this edge. Read its next byte
    // pair now, leaving a clock for the font EBR before the first pixel.
    wire[8:0]cache_x=x+(divide==2?9'd1:9'd0);
    wire[6:0]cache_column=model_a?(cache_x>>2):(cache_x>>3);
    always @(posedge clk)cache_data<=line_cache[{model_a&&y[0],cache_column[6:1]}];
    always @(posedge clk)begin
        if(font_write)font[font_address]<=font_data;
        font_pixels<=font[{font_character[6:0],font_character[7],y[2:0]}];
    end
    always @(posedge clk)begin
        tick50<=0;
        if(reset)begin
            register_index<=0;divide<=0;half_pixel<=0;half_line<=0;
            tick50<=0;blink<=0;dma_state<=0;dma_column<=0;dma_bank<=0;mem_address<=0;
            colour_frame<=0;held_colour<=0;held_sync<=1;held_burst<=0;held_alternate<=0;
            for(i=0;i<16;i=i+1)registers[i]<=0;
        end else begin
            if(bus_write)begin
                if(!bus_address)register_index<=bus_data;
                else registers[register_index[3:0]]<=bus_data;
            end
            if(pixel_enable)begin
                held_colour<=pixel_colour;held_sync<=sync_low;
                held_burst<=burst;held_alternate<=alternate;
            end
            if(divide==2)begin
                divide<=0;
                if(half_pixel==255)begin
                    half_pixel<=0;
                    if(half_line==1249)begin half_line<=0;colour_frame<=!colour_frame;end
                    else half_line<=half_line+1'b1;
                    if(half_line==624||half_line==1249)begin tick50<=1;blink<=blink+1'b1;end
                end else half_pixel<=half_pixel+1'b1;
                // 601A fills the other scanline bank during the preceding line.
                // 80 SRAM reads fit the existing two video slots per CPU cycle.
                if(horizontal==(model_a?80:430)&&field_line>=49&&next_y<registers[6]*8&&dma_state==0)begin
                    dma_column<=0;dma_bank<=next_y[0];
                    mem_address<=graphics?{5'b0,next_graphics}:{5'b0,next_text};
                    dma_state<=1;
                end
            end else divide<=divide+1'b1;
            case(dma_state)
                1:if(mem_ready)dma_state<=2;
                2:if(mem_done)begin
                    if(!dma_column[0])dma_even<=mem_data;
                    else line_cache[{model_a&&dma_bank,dma_column[6:1]}]<={mem_data,dma_even};
                    if(dma_column==(model_a?79:39))dma_state<=0;
                    else begin
                        dma_column<=dma_column+1'b1;
                        if(graphics)
                            mem_address<=!model_a&&mem_address[15:3]==13'h1ffe ?
                                {18'b0,mem_address[2:0]}:{5'b0,mem_address[15:0]+16'd8};
                        else
                            mem_address<=model_a?{5'b0,mem_address[15:12],mem_address[11:0]+12'd1}:
                                mem_address[15:0]>=16'hfffe ?21'h0f000:{5'b0,mem_address[15:0]+16'd1};
                        dma_state<=1;
                    end
                end
            endcase
        end
    end
endmodule
