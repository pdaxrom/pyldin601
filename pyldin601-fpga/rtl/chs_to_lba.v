// CHS values are zero based except sector (1 based). No 80-track/18-sector limit.
module chs_to_lba #(parameter CLASSIC_GEOMETRY=0) (
    input wire [7:0] cylinder, head, sector,
    input wire [8:0] cylinders,
    input wire [7:0] heads, sectors_per_track,
    input wire [31:0] partition_start, partition_sectors,
    output wire [31:0] lba,
    output wire valid
);
    wire [23:0] offset;
    wire geometry_valid;
    generate if(CLASSIC_GEOMETRY)begin:classic
        // Classic i8272 image profile: <=80 cylinders, <=2 heads, <=18 sectors.
        // Bounds remain checked on full inputs before using the narrow arithmetic.
        wire[7:0]track=cylinder[6:0]*heads[1:0]+head[0];
        wire[12:0]sector_offset=track*sectors_per_track[4:0]+sector[4:0]-13'd1;
        assign offset={11'b0,sector_offset};
        assign geometry_valid=cylinders<=80&&heads<=2&&sectors_per_track<=18;
    end else begin:generic
        // Maximum byte-valued CHS offset fits 24 bits.
        wire[15:0]track=cylinder*heads+head;
        assign offset=track*sectors_per_track+sector-24'd1;
        assign geometry_valid=1;
    end endgenerate
    wire [32:0] absolute_lba = {1'b0, partition_start} + {9'b0, offset};
    assign lba = absolute_lba[31:0];
    assign valid = geometry_valid && cylinders != 0 && cylinders <= 256 && heads != 0
                   && sectors_per_track != 0 && cylinder < cylinders
                   && head < heads && sector != 0 && sector <= sectors_per_track
                   && offset < partition_sectors && !absolute_lba[32];
endmodule
