// Physical byte addresses. CPU writes retain RAM underneath ROM overlays.
module classic_memory_map (
    input wire [15:0] cpu_addr,
    input wire cpu_write,
    input wire [7:0] page_select,
    output reg [20:0] physical_addr,
    output wire io_selected
);
    assign io_selected = cpu_addr[15:8] == 8'he6;
    always @* begin
        physical_addr = {5'b0, cpu_addr};
        if (!cpu_write && cpu_addr >= 16'hf000)
            physical_addr = {9'h020,cpu_addr[11:0]};
        else if (!cpu_write && cpu_addr >= 16'hc000 && cpu_addr < 16'he000
                 && page_select[3])
            physical_addr = {5'b0,1'b1,page_select[2:0],cpu_addr[12:0]};
    end
endmodule
