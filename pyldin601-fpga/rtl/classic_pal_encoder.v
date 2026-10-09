// PAL RGB/YUV matrix, quadrature modulation and swinging burst, as in the
// uJ11 encoder. Here the 16 IRGB colours use a synchronous waveform ROM:
// no multipliers, no extra clock domain, two-clock latency for all signals.
module classic_pal_encoder #(parameter WAVEFORM_FILE="rtl/pal_waveform.mem",parameter GFX=0) (
    input wire clk,reset,
    input wire sync,burst,alternate,
    input wire [3:0] colour,
    output reg [5:0] dac,
    input wire extended,input wire[7:0] rgb332,
    input wire palette_write,input wire[3:0]palette_register,input wire[7:0]palette_data,
    output wire palette_read_mode,output wire[5:0]palette_result
);
    // round(2^32 * 4433618.75 / 24000000), frequency error +0.002286 Hz.
    reg [31:0] phase;
    (* syn_ramstyle = "block_ram" *) reg [5:0] waveform[0:1023];
    initial $readmemh(WAVEFORM_FILE,waveform);
    // theta -> pi-theta keeps U*sin(theta) and negates V*cos(theta).
    // The table uses bin midpoints, so its reflected index is 15-p modulo 32.
    wire [4:0] carrier_phase=alternate?5'd15-phase[31:27]:phase[31:27];
    wire [9:0] address={burst,colour,carrier_phase};
    reg [5:0] sample;
    wire[5:0]rgb_sample;
    generate if(GFX)begin:rgb
        (* syn_ramstyle="block_ram" *) reg[5:0]table_rgb[8191:0];
        reg[5:0]value;
        reg[12:0]palette_address;
        reg read_mode;
        reg[5:0]read_value;
        // Descending declaration plus explicit ascending load agrees in RTL
        // and Synplify's six 8192x1 EBR bit planes. An ascending declaration
        // reverses every synthesized word; check_pal_ebr audits the netlist.
        initial $readmemh("rtl/pal_rgb332.mem",table_rgb,0,8191);
        always @(posedge clk)value<=table_rgb[{rgb332,carrier_phase}];
        // Port B belongs to the CPU; port A continues the PAL scanout.
        // Applications update with E650 disabled. Contents survive CPU reset,
        // just like the font RAM; reset clears only the port address/mode.
        always @(posedge clk)begin
            read_value<=table_rgb[palette_address];
            if(!reset&&palette_write&&palette_register==14)
                table_rgb[palette_address]<=palette_data[5:0];
        end
        always @(posedge clk)begin
            if(reset)begin palette_address<=0;read_mode<=0;end
            else if(palette_write)case(palette_register)
                2:palette_address[7:0]<=palette_data;
                13:palette_address[12:8]<=palette_data[4:0];
                14:palette_address<=palette_address+1'b1;
                15:begin
                    read_mode<=palette_data[0];
                    if(palette_data[1])palette_address<=palette_address+1'b1;
                end
            endcase
        end
        assign rgb_sample=value;
        assign palette_read_mode=read_mode;assign palette_result=read_value;
    end else begin:monochrome
        assign rgb_sample=0;
        assign palette_read_mode=0;assign palette_result=0;
    end endgenerate
    reg sync_delayed;
    reg extended_delayed;
    // Keep the ROM output free of reset and muxes to infer synchronous EBR.
    always @(posedge clk)sample<=waveform[address];
    always @(posedge clk)begin
        if(reset)begin phase<=0;sync_delayed<=1;extended_delayed<=0;end
        else begin phase<=phase+32'd793426981;sync_delayed<=sync;extended_delayed<=GFX&&extended&&!burst;end
    end
    // Register after EBR/sync mux so the DAC also meets the board's 15 ns
    // clock-to-output constraint. Sync, burst and picture share this stage.
    always @(posedge clk)begin
        if(reset)dac<=0;
        else dac<=sync_delayed ? 6'd0 : extended_delayed?rgb_sample:sample;
    end
endmodule
