// PAL RGB/YUV matrix, quadrature modulation and swinging burst, as in the
// uJ11 encoder. Here the 16 IRGB colours use a synchronous waveform ROM:
// no multipliers, no extra clock domain, two-clock latency for all signals.
module classic_pal_encoder #(parameter WAVEFORM_FILE="rtl/pal_waveform.mem") (
    input wire clk,reset,
    input wire sync,burst,alternate,
    input wire [3:0] colour,
    output reg [5:0] dac
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
    reg sync_delayed;
    // Keep the ROM output free of reset and muxes to infer synchronous EBR.
    always @(posedge clk)sample<=waveform[address];
    always @(posedge clk)begin
        if(reset)begin phase<=0;sync_delayed<=1;end
        else begin phase<=phase+32'd793426981;sync_delayed<=sync;end
    end
    // Register after EBR/sync mux so the DAC also meets the board's 15 ns
    // clock-to-output constraint. Sync, burst and picture share this stage.
    always @(posedge clk)begin
        if(reset)dac<=0;
        else dac<=sync_delayed ? 6'd0 : sample;
    end
endmodule
