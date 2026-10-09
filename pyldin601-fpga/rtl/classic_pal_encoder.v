// PAL RGB/YUV matrix, quadrature modulation and swinging burst, as in the
// uJ11 encoder. Here the 16 IRGB colours use a synchronous waveform ROM:
// no multipliers. HAM reuses the indexed table at 96 MHz; all outputs
// share three 24 MHz pipeline stages, including sync and burst.
module classic_pal_encoder #(parameter WAVEFORM_FILE="rtl/pal_waveform.mem",parameter GFX=0) (
    input wire clk,reset,
    input wire sync,burst,alternate,
    input wire [3:0] colour,
    output reg [5:0] dac,
    input wire extended,input wire[7:0] rgb332,
    input wire palette_write,input wire[3:0]palette_register,input wire[7:0]palette_data,
    output wire palette_read_mode,output wire[5:0]palette_result,
    input wire fast
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
    wire[5:0]indexed_sample,ham_sample_buffer;
    wire ham_selected;
    generate if(GFX)begin:rgb
        (* syn_ramstyle="block_ram" *) reg[5:0]table_rgb[8191:0];
        reg[5:0]value;
        reg[12:0]palette_address;
        reg read_mode;
        reg[5:0]read_value;
        reg ham_mode;
        reg[5:0]ham_r,ham_g,ham_b;
        reg[4:0]picture_phase;
        reg[7:0]picture_index;
        reg sample_token;
        // HAM8: two control bits, six component bits, fixed RGB22264 base.
        // Each physical line starts from black.
        wire[1:0]control=rgb332[7:6];
        wire[5:0]component=rgb332[5:0];
        wire[5:0]base_r={3{rgb332[5:4]}};
        wire[5:0]base_g={3{rgb332[3:2]}};
        wire[5:0]base_b={3{rgb332[1:0]}};
        always @(posedge clk)begin
            if(reset)begin
                ham_mode<=0;ham_r<=0;ham_g<=0;ham_b<=0;
                picture_phase<=0;picture_index<=0;sample_token<=0;
            end else begin
                picture_phase<=carrier_phase;picture_index<=rgb332;sample_token<=!sample_token;
                if(palette_write&&palette_register==0)ham_mode<=palette_data[2:1]==3;
                if(!extended)begin ham_r<=0;ham_g<=0;ham_b<=0;end
                else case(control)
                    0:begin ham_r<=base_r;ham_g<=base_g;ham_b<=base_b;end
                    1:ham_b<=component;
                    2:ham_r<=component;
                    3:ham_g<=component;
                endcase
            end
        end
        // Descending declaration plus explicit ascending load agrees in RTL
        // and Synplify's six 8192x1 EBR bit planes. An ascending declaration
        // reverses every synthesized word; check_pal_ebr audits the netlist.
        initial $readmemh("rtl/pal_rgb332.mem",table_rgb,0,8191);
        // One read port, four 96 MHz clocks per PAL sample. The slot rests
        // at zero between tuples, avoiding a token-to-EBR-address path.
        // A half-cycle buffer transfers the completed sum back to 24 MHz;
        // this also works when the two rising clock edges coincide.
        reg last_token;reg[1:0]slot;
        reg[5:0]red_sample,green_sample,ham_sample;
        wire start_sample=sample_token!=last_token;
        wire[1:0]read_slot=slot;
        wire[12:0]read_address=!ham_mode?{picture_index,picture_phase}:
            read_slot==1?{2'd1,ham_g,picture_phase}:
            read_slot==2?{2'd2,ham_b,picture_phase}:{2'd0,ham_r,picture_phase};
        always @(posedge fast)value<=table_rgb[read_address];
        always @(posedge fast)begin
            if(reset)begin last_token<=0;slot<=0;red_sample<=0;green_sample<=0;ham_sample<=15;end
            else begin
                last_token<=sample_token;
                if(start_sample)slot<=1;
                else begin
                    if(slot!=0)slot<=slot+1'b1;
                    case(slot)
                        1:red_sample<=value;
                        2:green_sample<=value;
                        3:ham_sample<=({2'b0,red_sample}+{2'b0,green_sample}+{2'b0,value})-8'd10;
                    endcase
                end
            end
        end
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
        reg[5:0]indexed_buffer,ham_buffer;
        always @(posedge clk)begin
            if(reset)indexed_buffer<=0;else indexed_buffer<=value;
        end
        always @(negedge clk)begin
            if(reset)ham_buffer<=15;else ham_buffer<=ham_sample;
        end
        assign indexed_sample=indexed_buffer;
        assign ham_sample_buffer=ham_buffer;
        assign ham_selected=ham_mode;
        assign palette_read_mode=read_mode;assign palette_result=read_value;
    end else begin:monochrome
        assign indexed_sample=0;assign ham_sample_buffer=0;assign ham_selected=0;
        assign palette_read_mode=0;assign palette_result=0;
    end endgenerate
    reg[1:0]sync_delayed,extended_delayed,ham_delayed;
    reg[5:0]native_buffer;
    // Keep the ROM output free of reset and muxes to infer synchronous EBR.
    always @(posedge clk)sample<=waveform[address];
    always @(posedge clk)begin
        if(reset)begin
            phase<=0;sync_delayed<=3;extended_delayed<=0;ham_delayed<=0;native_buffer<=0;
        end else begin
            phase<=phase+32'd793426981;
            sync_delayed<={sync_delayed[0],sync};
            extended_delayed<={extended_delayed[0],GFX&&extended&&!burst};
            ham_delayed<={ham_delayed[0],ham_selected};
            native_buffer<=sample;
        end
    end
    // Register after EBR/sync mux so the DAC also meets the board's 15 ns
    // clock-to-output constraint. Sync, burst and picture share this stage.
    always @(posedge clk)begin
        if(reset)dac<=0;
        else dac<=sync_delayed[1] ? 6'd0 : extended_delayed[1]?
            (ham_delayed[1]?ham_sample_buffer:indexed_sample):native_buffer;
    end
endmodule
