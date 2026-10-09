// Composite PAL 625/50, MC6845 facade and selectable 601/601A video.
// 24 MHz single domain: 48 us picture width, 264 physical rows per field.
// Rational scalers retain the native 320/640 pixels and CRTC row count.
// The existing font EBR is seeded at
// FPGA configuration, then receives the SD font through physical SRAM writes.
module classic_video #(parameter FONT_FILE="rtl/font_boot.mem",parameter GFX=0) (
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
    input wire model_a,
    input wire gfx_enable,input wire[7:0]gfx_pixel,
    output reg gfx_line_request,gfx_vblank,output reg[7:0]gfx_line_y,
    output wire[8:0]gfx_pixel_x,output wire gfx_pixel_bank,
    input wire palette_write,input wire[3:0]palette_register,input wire[7:0]palette_data,
    output wire palette_read_mode,output wire[5:0]palette_result,
    input wire fast
);
    reg [7:0] registers[0:15];reg[7:0] register_index;
    wire extended=GFX&&gfx_enable;
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
    // Keep every source pixel inside the panel's visible PAL aperture.
    // One common viewport for bootstrap, native video and RGB332; neither
    // E650 nor the CRTC row count moves its physical edges.
    localparam H_FIRST=96,H_LAST=480,V_FIRST=38,V_LAST=302;
    wire picture_h=horizontal>=H_FIRST&&horizontal<H_LAST;
    wire picture_v=field_line>=V_FIRST&&field_line<V_LAST;
    // 640 samples in 1152 system clocks: increment 5/9. The 320-pixel
    // modes use every pair. No derived clock, multiplier or extra PLL.
    reg [9:0] source_x;
    reg [3:0] horizontal_phase;
    // 8*R6 source rows in 264 PAL rows: increment R6/33. Extended graphics
    // always has 25 character-equivalent rows, independently of the CRTC.
    wire [5:0] source_rows=extended?6'd25:registers[6]>29?6'd29:registers[6][5:0];
    reg [8:0] y;
    reg [5:0] vertical_phase;
    wire [6:0] vertical_sum={1'b0,vertical_phase}+{1'b0,source_rows};
    wire [8:0] next_y=field_line==V_FIRST-1?9'd0:y+(vertical_sum>=33);
    // Fetch only when advancing the logical row. Refilling a repeated row
    // would invalidate/overwrite the bank that is currently being displayed.
    wire next_line=field_line==V_FIRST-1 ||
        (picture_v&&field_line<V_LAST-1&&next_y!=y);
    always @(posedge clk)begin
        if(reset)begin source_x<=0;horizontal_phase<=0;y<=0;vertical_phase<=0;end
        else begin
            if(!picture_h)begin source_x<=0;horizontal_phase<=0;end
            else if(horizontal_phase>=4)begin
                source_x<=source_x+1'b1;horizontal_phase<=horizontal_phase-4'd4;
            end else horizontal_phase<=horizontal_phase+4'd5;
            if(divide==2&&horizontal==511)begin
                if(field_line==V_FIRST-1||!picture_v)begin y<=0;vertical_phase<=0;end
                else begin
                    y<=next_y;
                    vertical_phase<=vertical_sum>=33?vertical_sum-7'd33:vertical_sum;
                end
            end
        end
    end
    wire [15:0] start_addr={registers[12],registers[13]};
    wire [15:0] cursor_addr={registers[14],registers[15]};
    // Match the original MC6845 renderer's txt260/grf260=-1 convention.
    // Text compares after src++, graphics before advancing the eight-byte cell.
    wire [15:0] text_cursor=model_a?cursor_addr:cursor_addr-16'd2;
    wire [15:0] graphics_cursor=(model_a?cursor_addr:cursor_addr-16'd1)<<3;
    wire [7:0] stride=model_a?(registers[1]>80?8'd80:registers[1]):registers[1]>(graphics?48:42)?(graphics?8'd48:8'd42):registers[1];
    wire [8:0] x=source_x[9:1];
    wire [9:0] raw_x=model_a?source_x:{1'b0,x};
    // A common two-clock pipeline covers the synchronous scanline and font
    // EBR reads. Coordinates, blanking, sync and burst follow the same delay.
    reg [9:0] x1,logical_x;
    reg [8:0] y1,pixel_y;
    reg [1:0] h_pipe,v_pipe,sync_pipe,burst_pipe,alternate_pipe;
    wire [6:0] column=logical_x>>3;
    wire [6:0] character_column=text40?{column[6:1],1'b1}:column;
    wire [6:0] column1=x1>>3;
    wire [6:0] character_column1=text40?{column1[6:1],1'b1}:column1;
    reg [7:0] video_byte,attribute,rgb_pipe;
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
    // There are 300 system clocks before the first visible pixel. Share one
    // serial adder for the two row offsets; finish six clocks into the line.
    reg [11:0] line_offset,next_line_offset;
    reg [11:0] offset_sum,offset_term;
    reg [5:0] offset_bits;reg [2:0] offset_count;
    wire[11:0]offset_next=offset_sum+(offset_bits[0]?offset_term:12'd0);
    always @(posedge clk)begin
        if(reset)begin line_offset<=0;next_line_offset<=0;offset_sum<=0;offset_term<=0;offset_bits<=0;offset_count<=0;end
        else begin
            if(divide==2&&horizontal==0)begin
                offset_sum<=0;offset_term<=stride;offset_bits<=y[8:3];offset_count<=6;
            end else if(offset_count!=0)begin
                offset_sum<=offset_next;offset_term<=offset_term<<1;offset_bits<=offset_bits>>1;
                offset_count<=offset_count-1'b1;
                if(offset_count==1)begin
                    line_offset<=offset_next;
                    next_line_offset<=next_y[8:3]==0?12'd0:offset_next+(next_y[8:3]!=y[8:3]?stride:8'd0);
                end
            end
        end
    end
    wire [15:0] text_position=text_address(start_addr,line_offset+character_column);
    wire [15:0] graphics_position=graphics_address(start_addr,line_offset+column);
    wire [15:0] next_text=text_address(start_addr,next_line_offset);
    wire [15:0] next_graphics=graphics_address(start_addr,next_line_offset)+next_y[2:0];
    reg [7:0] pixels;
    reg [5:0] blink;
    reg sync_low;
    wire active=h_pipe[1]&&v_pipe[1]&&source_rows!=0&&column<registers[1];
    // Always identify the output as PAL, also in the bootstrap/monochrome
    // console. Dropping burst on RGB332 exit makes receivers reclassify the
    // signal and can move/crop their sampling window despite stable sync.
    wire burst=!burst_blank&&horizontal>=45&&horizontal<63;
    assign gfx_pixel_x=x;assign gfx_pixel_bank=y[0];
    wire[7:0]rgb_pixel=h_pipe[1]&&v_pipe[1]?rgb_pipe:8'd0;
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
    reg[7:0]held_rgb;
    classic_pal_encoder #(.GFX(GFX)) encoder(clk,reset,
        sync_pipe[1],burst_pipe[1],alternate_pipe[1],pixel_colour,tvout,
        extended&&h_pipe[1]&&v_pipe[1],rgb_pixel,
        palette_write,palette_register,palette_data,palette_read_mode,palette_result,fast);
    reg[1:0] dma_state;
    reg[6:0] dma_column;reg dma_bank;
    assign mem_request=dma_state==1;
    assign bus_result=bus_address?registers[register_index[3:0]]:register_index;
    integer i;
    always @*begin
        // PAL at the 8 MHz raster: 2.375 us equalizing, 4.75 us H sync,
        // 27.25 us broad sync with a 4.75 us gap (32 - 4.75).
        // The old 29.625 us broad pulse left only an equalizing-size gap.
        if(field_half<5 || (field_half>=10&&field_half<15))sync_low=half_pixel<19;
        else if(field_half<10)sync_low=half_pixel<218;
        else sync_low=horizontal<38;
        pixels=0;
        if(column<(model_a?80:40))begin
            if(graphics)pixels=video_byte;
            else pixels=font_pixels;
            if((!graphics&&text_position==text_cursor
                ||graphics&&graphics_position==graphics_cursor)
                && pixel_y[2:0]>=registers[10][4:0]&&pixel_y[2:0]<=registers[11][4:0]
                && registers[10][6:5]!=1 && (registers[10][6:5]==0||!blink[5]))pixels=~pixels;
        end
    end
    wire[7:0]font_character=column1<(model_a?80:40)?
        (character_column1[0]?cache_data[15:8]:cache_data[7:0]):8'b0;
    wire[6:0]cache_column=raw_x>>3;
    // Both models use alternating row banks; 601 fits 40 and 601A 80 bytes.
    // Prefetching during the preceding line leaves a full 64 us for SRAM.
    always @(posedge clk)cache_data<=line_cache[{y[0],cache_column[6:1]}];
    always @(posedge clk)begin
        if(font_write)font[font_address]<=font_data;
        font_pixels<=font[{font_character[6:0],font_character[7],y1[2:0]}];
        video_byte<=column1[0]?cache_data[15:8]:cache_data[7:0];
        attribute<=cache_data[7:0];rgb_pipe<=gfx_pixel;
        if(reset)begin
            x1<=0;logical_x<=0;y1<=0;pixel_y<=0;
            h_pipe<=0;v_pipe<=0;sync_pipe<=3;burst_pipe<=0;alternate_pipe<=0;
        end else begin
            x1<=raw_x;logical_x<=x1;y1<=y;pixel_y<=y1;
            h_pipe<={h_pipe[0],picture_h};v_pipe<={v_pipe[0],picture_v};
            sync_pipe<={sync_pipe[0],sync_low};burst_pipe<={burst_pipe[0],burst};
            alternate_pipe<={alternate_pipe[0],alternate};
        end
    end
    always @(posedge clk)begin
        tick50<=0;
        if(reset)begin
            register_index<=0;divide<=0;half_pixel<=0;half_line<=0;
            tick50<=0;blink<=0;dma_state<=0;dma_column<=0;dma_bank<=0;mem_address<=0;
            colour_frame<=0;held_colour<=0;held_sync<=1;held_burst<=0;held_alternate<=0;
            held_rgb<=0;gfx_line_request<=0;gfx_vblank<=0;gfx_line_y<=0;
            for(i=0;i<16;i=i+1)registers[i]<=0;
        end else begin
            if(bus_write)begin
                if(!bus_address)register_index<=bus_data;
                else registers[register_index[3:0]]<=bus_data;
            end
            held_colour<=pixel_colour;held_rgb<=rgb_pixel;held_sync<=sync_pipe[1];
            held_burst<=burst_pipe[1];held_alternate<=alternate_pipe[1];
            if(divide==2)begin
                divide<=0;
                if(half_pixel==255)begin
                    half_pixel<=0;
                    if(half_line==1249)begin half_line<=0;colour_frame<=!colour_frame;end
                    else half_line<=half_line+1'b1;
                    if(half_line==624||half_line==1249)begin tick50<=1;blink<=blink+1'b1;gfx_vblank<=!gfx_vblank;end
                end else half_pixel<=half_pixel+1'b1;
                if(extended&&horizontal==80&&next_line)begin
                    gfx_line_request<=!gfx_line_request;gfx_line_y<=next_y[7:0];
                end
                if(!extended&&horizontal==80&&next_line&&source_rows!=0&&dma_state==0)begin
                    dma_column<=0;dma_bank<=next_y[0];
                    mem_address<=graphics?{5'b0,next_graphics}:{5'b0,next_text};
                    dma_state<=1;
                end
            end else divide<=divide+1'b1;
            case(dma_state)
                1:if(mem_ready)dma_state<=2;
                2:if(mem_done)begin
                    if(!dma_column[0])dma_even<=mem_data;
                    else line_cache[{dma_bank,dma_column[6:1]}]<={mem_data,dma_even};
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
