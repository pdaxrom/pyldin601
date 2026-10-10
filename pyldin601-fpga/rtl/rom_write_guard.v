// Commit is one way until cold reset. Apply AFTER arbitration to every writer.
module rom_write_guard (
    input wire clk, cold_reset,
    input wire commit,
    input wire write_request,
    input wire [20:0] address,
    output reg locked,
    output wire write_allowed
);
    wire rom_address = address >= 21'h10000 && address < 21'h21800;
    assign write_allowed = write_request && !(rom_address && (locked || commit));
    always @(posedge clk) begin
        if (cold_reset) locked <= 0;
        else if (commit) locked <= 1;
    end
endmodule
