// Read-only FAT16 root-directory file streamer. Supports fragmented files.
// SD interface: request accepted on ready; done/error completes the sector.
// Buffer is asynchronous read, shared with the SD host; only one owner at a time.
module fat16_file_reader (
    input wire clk, reset, start,
    input wire [87:0] filename, // {"P601    ROM"}, first character in MSB
    output reg busy, done, error,
    output wire sd_request,
    output reg [31:0] sd_lba,
    input wire sd_ready, sd_done, sd_error,
    output reg [8:0] buffer_address,
    input wire [7:0] buffer_data,
    output wire valid,
    input wire ready,
    output wire [7:0] data,
    output reg [31:0] file_size,
    output reg [31:0] drive_a_start, drive_a_sectors,
    output reg [31:0] drive_b_start, drive_b_sectors
);
    localparam IDLE=0, REQ=1, WAIT_SD=2, CAPTURE=3, MBR=4, BPB=5,
        ROOT=6, STREAM=7, NEXT_CLUSTER=8, FAT=9, FAIL=10, SIGNATURE=11;
    reg [3:0] state, after_sd, after_capture, after_signature;
    reg [511:0] scratch;
    reg [6:0] capture_count;
    reg [31:0] part_start, part_sectors, fat_start, root_start, data_start;
    reg [31:0] volume_sectors, data_clusters;
    reg [15:0] root_entries, root_index, cluster;
    reg [7:0] spc, cluster_sector;
    reg [31:0] remaining, chain_budget;
    reg [8:0] data_index;
    integer k;
    reg name_match;
    wire [15:0] bpb_bps = scratch[8*11+:16];
    wire [15:0] bpb_reserved = scratch[8*14+:16];
    wire [15:0] bpb_root = scratch[8*17+:16];
    wire [15:0] bpb_spf = scratch[8*22+:16];
    wire [31:0] bpb_total = scratch[8*19+:16] != 0
                            ? {16'b0,scratch[8*19+:16]} : scratch[8*32+:32];
    wire [31:0] root_count = ({16'b0,bpb_root}+15)>>4;
    wire [31:0] overhead = {16'b0,bpb_reserved}
                          + scratch[8*16+:8]*{16'b0,bpb_spf} + root_count;
    // Division by spc (power of two) synthesizes to a barrel shift.
    reg [3:0] cluster_shift;
    always @* begin
        case (scratch[8*13+:8])
            1: cluster_shift=0; 2: cluster_shift=1; 4: cluster_shift=2;
            8: cluster_shift=3; 16: cluster_shift=4; 32: cluster_shift=5;
            64: cluster_shift=6; 128: cluster_shift=7;
            default: cluster_shift=15;
        endcase
        name_match=1;
        for (k=0;k<11;k=k+1)
            if (scratch[k*8+:8] != filename[87-k*8-:8]) name_match=0;
    end
    assign sd_request = state == REQ;
    assign valid = state == STREAM;
    assign data = buffer_data;
    task read_sector;
        input [31:0] lba;
        input [3:0] next;
        begin sd_lba<=lba; after_sd<=next; state<=REQ; end
    endtask
    task capture;
        input [8:0] base;
        input [6:0] count;
        input [3:0] next;
        begin
            buffer_address<=base; capture_count<=count;
            scratch<=0; after_capture<=next; state<=CAPTURE;
        end
    endtask
    task fail;
        begin error<=1; busy<=0; done<=1; state<=FAIL; end
    endtask
    always @(posedge clk) begin
        done<=0;
        if (reset) begin
            state<=IDLE; busy<=0; error<=0; done<=0;
            buffer_address<=0; sd_lba<=0; file_size<=0;
            scratch<=0; capture_count<=0; after_sd<=0; after_capture<=0;
            after_signature<=0; part_start<=0; part_sectors<=0;
            fat_start<=0; root_start<=0; data_start<=0; volume_sectors<=0;
            data_clusters<=0; root_entries<=0; root_index<=0; cluster<=0;
            spc<=0; cluster_sector<=0; remaining<=0; chain_budget<=0; data_index<=0;
            drive_a_start<=0; drive_a_sectors<=0; drive_b_start<=0; drive_b_sectors<=0;
        end else if (sd_error && busy) fail();
        else case (state)
            IDLE: if (start) begin busy<=1; error<=0; read_sector(0,MBR); end
            REQ: if (sd_ready) state<=WAIT_SD;
            WAIT_SD: if (sd_done) begin
                case (after_sd)
                    MBR: capture(446,64,MBR);
                    BPB: capture(0,64,BPB);
                    ROOT: capture({root_index[3:0],5'b0},32,ROOT);
                    FAT: capture({cluster[7:0],1'b0},2,FAT);
                    STREAM: begin buffer_address<=0; data_index<=0; state<=STREAM; end
                    default: fail();
                endcase
            end
            CAPTURE: begin
                // Append into low bytes in little endian order.
                scratch <= {buffer_data,scratch[511:8]};
                buffer_address <= buffer_address+1'b1;
                if (capture_count==1) begin
                    // For short captures, right-align on the next state.
                    state<=after_capture;
                end
                capture_count<=capture_count-1'b1;
            end
            MBR: begin
                part_start<=scratch[8*8+:32]; part_sectors<=scratch[8*12+:32];
                drive_a_start<=scratch[8*24+:32]; drive_a_sectors<=scratch[8*28+:32];
                drive_b_start<=scratch[8*40+:32]; drive_b_sectors<=scratch[8*44+:32];
                if ((scratch[8*4+:8]!=6 && scratch[8*4+:8]!=14)
                    || scratch[8*12+:32]==0 || scratch[8*8+:32]==0
                    || scratch[8*20+:8]!=1 || scratch[8*36+:8]!=1
                    || scratch[8*28+:32]==0 || scratch[8*44+:32]==0
                    || {1'b0,scratch[8*8+:32]}+{1'b0,scratch[8*12+:32]}
                       > {1'b0,scratch[8*24+:32]}
                    || {1'b0,scratch[8*24+:32]}+{1'b0,scratch[8*28+:32]}
                       > {1'b0,scratch[8*40+:32]}
                    || {1'b0,scratch[8*40+:32]}+{1'b0,scratch[8*44+:32]}>33'hffffffff)
                    fail();
                else begin buffer_address<=510; state<=SIGNATURE; after_signature<=MBR; end
            end
            BPB: begin
                if (bpb_bps!=512 || cluster_shift==15 || bpb_reserved==0
                    || scratch[8*16+:8]==0 || bpb_root==0 || bpb_spf==0
                    || bpb_total>part_sectors || bpb_total<=overhead
                    || ((bpb_total-overhead)>>cluster_shift)<4085
                    || ((bpb_total-overhead)>>cluster_shift)>=65525
                    || (((bpb_total-overhead)>>cluster_shift)+2)>({16'b0,bpb_spf}<<8))
                    fail();
                else begin
                    spc<=scratch[8*13+:8]; root_entries<=bpb_root;
                    fat_start<=part_start+bpb_reserved;
                    root_start<=part_start+bpb_reserved+scratch[8*16+:8]*{16'b0,bpb_spf};
                    data_start<=part_start+overhead; volume_sectors<=bpb_total;
                    data_clusters<=(bpb_total-overhead)>>cluster_shift;
                    root_index<=0;
                    buffer_address<=510; state<=SIGNATURE; after_signature<=BPB;
                end
            end
            SIGNATURE: if (buffer_address==510) begin
                if (buffer_data!=8'h55) fail(); else buffer_address<=511;
            end else if (buffer_data!=8'haa) fail();
            else if (after_signature==MBR) read_sector(part_start,BPB);
            else read_sector(root_start,ROOT);
            ROOT: begin
                // Short captures occupy upper scratch bytes (32 captured bytes).
                scratch<=scratch>>256;
                state<=NEXT_CLUSTER; // shared dispatch; root flag below
            end
            NEXT_CLUSTER: begin
                if (after_sd==ROOT) begin
                    if (scratch[7:0]==0) fail();
                    else if (scratch[7:0]!=8'he5 && (scratch[8*11+:8]&8'h18)==0
                             && name_match) begin
                        if (scratch[8*26+:16]<2 || scratch[8*26+:16]>=data_clusters+2
                            || scratch[8*28+:32]==0 || scratch[8*20+:16]!=0) fail();
                        else begin
                            cluster<=scratch[8*26+:16]; cluster_sector<=0;
                            remaining<=scratch[8*28+:32]; file_size<=scratch[8*28+:32];
                            chain_budget<=data_clusters;
                            read_sector(data_start+(scratch[8*26+:16]-32'd2)*{24'b0,spc},STREAM);
                        end
                    end else if (root_index+1>=root_entries) fail();
                    else begin
                        root_index<=root_index+1'b1;
                        if (root_index[3:0]==15) read_sector(root_start+((root_index+1)>>4),ROOT);
                        else capture({(root_index[3:0]+4'd1),5'b0},32,ROOT);
                    end
                end else if (cluster_sector+1<spc) begin
                    cluster_sector<=cluster_sector+1'b1;
                    read_sector(data_start+(cluster-32'd2)*{24'b0,spc}+cluster_sector+1,STREAM);
                end else if (chain_budget==0) fail();
                else begin
                    chain_budget<=chain_budget-1'b1;
                    read_sector(fat_start+{24'b0,cluster[15:8]},FAT);
                end
            end
            STREAM: if (ready) begin
                remaining<=remaining-1'b1;
                if (remaining==1) begin done<=1; busy<=0; state<=IDLE; end
                else if (data_index==511) state<=NEXT_CLUSTER;
                else begin data_index<=data_index+1'b1; buffer_address<=buffer_address+1'b1; end
            end
            FAT: begin
                // Two-byte FAT entry occupies the top 16 bits after capture.
                if (scratch[511:496]<2 || scratch[511:496]>=data_clusters+2) fail();
                else begin
                    cluster<=scratch[511:496]; cluster_sector<=0;
                    read_sector(data_start+(scratch[511:496]-32'd2)*{24'b0,spc},STREAM);
                end
            end
            FAIL: ;
            default: fail();
        endcase
    end
endmodule
