// Native C000..DFFF expansion: E6F0 pages 1..6 are RAM; 0/7 remain
// main RAM and 8..F retain the legacy ROM overlay. E6F1 selects a group.
// The 111 aligned 8-KiB pages occupy 22000..FFFFF, never ROM/font/video.
module classic_ram_pages (
    input wire clk, reset, runtime,
    input wire group_write,
    input wire [7:0] write_data,
    input wire [15:0] cpu_addr,
    input wire [7:0] page_select,
    input wire [20:0] legacy_address,
    output wire [7:0] register_data,
    output wire [20:0] physical_address,
    output wire invalid_window
);
    reg [4:0] group_number;
    reg [7:0] page_base;
    wire selected = runtime && cpu_addr[15:13] == 3'b110
                    && page_select[3:0] >= 1 && page_select[3:0] <= 6;
    wire [7:0] physical_page = page_base + {5'b0,page_select[2:0]};
    // Group 18 only has slots 1..3. Invalid slots must not alias video RAM.
    assign invalid_window = selected && physical_page[7];
    assign physical_address = selected && !invalid_window
                            ? {physical_page,cpu_addr[12:0]} : legacy_address;
    assign register_data = cpu_addr[1:0] == 1 ? {3'b0,group_number}
                         : cpu_addr[1:0] == 2 ? 8'h52 : 8'd111;
    always @(posedge clk) begin
        if (reset) begin
            group_number <= 0;
            page_base <= 8'h10;
        end else if (group_write && write_data <= 18) begin
            group_number <= write_data[4:0];
            // Compute once on a register write, off the SRAM address path.
            page_base <= 8'h10 + {1'b0,write_data[4:0],2'b0}
                              + {2'b0,write_data[4:0],1'b0};
        end
    end
endmodule
