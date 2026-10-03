// Request/acknowledge controller for IS61WV102416, byte lane selection.
// Like the working uJ11 SRAM path: setup, two access clocks, hold, release.
// Accept at N, assert OE/WE at N+1, sample/end WE at N+3, release at N+4.
// Completion at N+5 reaches the owner at N+6; next slot starts at N+7.
module sram_byte_controller (
    input wire clk, reset,
    input wire request, write,
    input wire [20:0] address,
    input wire [7:0] write_data,
    output wire ready,
    output reg done,
    output reg [7:0] read_data,
    output reg [19:0] SRAM_ADDR,
    inout wire [15:0] SRAM_DATA,
    output reg SRAM_CE, SRAM_OE, SRAM_WE, SRAM_LB, SRAM_UB
);
    localparam IDLE=0, SETUP=1, ACCESS1=2, ACCESS2=3, HOLD=4, RELEASE=5;
    reg [2:0] state;
    reg writing, lane, data_drive;
    reg [7:0] data;
    assign ready = !reset && state == IDLE;
    // Do not decode the FSM into the pad's tristate enable. State-bit skew
    // can release the bus while WE is low, or before its rising pad edge.
    // This register spans the whole write and a full clock of data hold.
    assign SRAM_DATA = data_drive
                     ? (lane ? {data,8'b0} : {8'b0,data}) : 16'bz;
    always @(posedge clk) begin
        done <= 0;
        if (reset) begin
            state <= IDLE; writing <= 0; lane <= 0; data_drive <= 0; data <= 0; read_data <= 0;
            SRAM_ADDR <= 0;
            SRAM_CE <= 1; SRAM_OE <= 1; SRAM_WE <= 1; SRAM_LB <= 1; SRAM_UB <= 1;
        end else case (state)
            IDLE: if (request) begin
                writing <= write; lane <= address[0]; data <= write_data; data_drive <= write;
                SRAM_ADDR <= address[20:1]; SRAM_CE <= 0;
                SRAM_LB <= address[0]; SRAM_UB <= !address[0];
                // Keep OE and WE high while address, lane and DQ settle.
                SRAM_OE <= 1; SRAM_WE <= 1; state <= SETUP;
            end
            SETUP: begin SRAM_OE <= writing; SRAM_WE <= !writing; state <= ACCESS1; end
            ACCESS1: state <= ACCESS2;
            ACCESS2: begin
                if (!writing) read_data <= lane ? SRAM_DATA[15:8] : SRAM_DATA[7:0];
                SRAM_WE <= 1; state <= HOLD;
            end
            HOLD: begin
                SRAM_CE <= 1; SRAM_OE <= 1; SRAM_LB <= 1; SRAM_UB <= 1;
                data_drive <= 0;
                state <= RELEASE;
            end
            RELEASE: begin done <= 1; state <= IDLE; end
            default: begin
                state <= IDLE; data_drive <= 0;
                SRAM_CE <= 1; SRAM_OE <= 1; SRAM_WE <= 1; SRAM_LB <= 1; SRAM_UB <= 1;
            end
        endcase
    end
endmodule
