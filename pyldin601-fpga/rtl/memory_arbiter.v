// One request accepted at the SRAM controller, one completion to its owner.
// A client holds request/payload until accept, then waits for done. The owner
// and payload remain frozen even if the client is reset or changes its bus.
// Runtime slots reserve phase 3 for CPU, 10/17 for video. Boot uses round robin.
module memory_arbiter #(parameter RUNTIME_SLOTS=0)(
    input wire clk, reset,
    input wire [2:0] request, write,
    input wire [62:0] address,
    input wire [23:0] data,
    output wire [2:0] accept, done,
    output wire busy,
    output wire ram_request, ram_write,
    output wire [20:0] ram_address,
    output wire [7:0] ram_data,
    input wire ram_ready, ram_done,
    input wire runtime,
    input wire [4:0] phase
);
    reg inflight;
    reg [1:0] owner, next_owner;
    reg held_write;
    reg [20:0] held_address;
    reg [7:0] held_data;
    wire slotted = RUNTIME_SLOTS && runtime;
    wire [2:0] eligible = slotted
        ? {phase==10 || phase==17, 1'b0, phase==3} : 3'b111;
    wire [2:0] waiting = request & eligible;
    reg [1:0] chosen;
    always @* begin
        case (next_owner)
            0: chosen = waiting[0] ? 0 : waiting[1] ? 1 : 2;
            1: chosen = waiting[1] ? 1 : waiting[2] ? 2 : 0;
            default: chosen = waiting[2] ? 2 : waiting[0] ? 0 : 1;
        endcase
    end
    assign busy = inflight;
    assign ram_request = !reset && !inflight && |waiting;
    assign ram_write = inflight ? held_write : write[chosen];
    assign ram_address = inflight ? held_address : address[chosen*21+:21];
    assign ram_data = inflight ? held_data : data[chosen*8+:8];
    assign accept = ram_request && ram_ready ? (3'b001 << chosen) : 3'b000;
    assign done = !reset && inflight && ram_done ? (3'b001 << owner) : 3'b000;
    always @(posedge clk) begin
        if (reset) begin
            inflight <= 0;
            owner <= 0;
            next_owner <= 0;
            held_write <= 0;
            held_address <= 0;
            held_data <= 0;
        end else if (inflight) begin
            if (ram_done) inflight <= 0;
        end else if (ram_request && ram_ready) begin
            inflight <= 1;
            owner <= chosen;
            next_owner <= chosen==2 ? 0 : chosen+1'b1;
            held_write <= write[chosen];
            held_address <= address[chosen*21+:21];
            held_data <= data[chosen*8+:8];
        end
    end
endmodule
