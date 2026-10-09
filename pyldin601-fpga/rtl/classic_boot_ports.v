// Boot-only RAM access and retained ROM validity. No filesystem, copying or reset FSM.
// E6A0 commit/status; A1 debug; A2 SDHC mode; A3 header+MBR config (96 bytes);
// A4-A6 address; A7 write/increment; A8 busy/error; A9 CRC feed; AA CRC reset;
// writing AB starts a read/increment, reading AB returns its completed byte; AC-AF CRC.
module classic_boot_ports(
 input wire clk,cold_reset,warm_reset,bus_read,bus_write,
 input wire[3:0]address,input wire[7:0]bus_data,output reg[7:0]bus_result,
 output wire mem_request,output wire mem_write,output wire[20:0]mem_address,output wire[7:0]mem_data,
 input wire mem_ready,mem_done,input wire[7:0]mem_read_data,input wire spi_idle,
 output reg locked,output wire boot_mode,output reg error,output reg[7:0]debug,
 output reg sd_block_addressing,output reg[31:0]a_start,a_sectors,b_start,b_sectors,
 output reg[7:0]a_spt,a_heads,b_spt,b_heads,
 output wire[8:0]a_cylinders,b_cylinders,output reg boot_b,output reg model_a,output reg hd6303_en,
 output reg[1:0]boot_speed
);
 reg[23:0]write_address;reg[7:0]write_data,read_data;reg pending,issued,writing;
 reg[31:0]crc,expected_crc;reg[6:0]config_index;reg header_bad;
 reg[7:0]cyl_a,cyl_b;
 reg[31:0]mbr_a_start,mbr_a_count,mbr_b_start,mbr_b_count;
 assign a_cylinders={1'b0,cyl_a};assign b_cylinders={1'b0,cyl_b};
 assign boot_mode=!locked;
 assign mem_request=pending&&!issued&&!warm_reset;
 assign mem_write=writing;
 assign mem_address=write_address[20:0];assign mem_data=write_data;
 // Validate fixed header bytes as they arrive; no registers for constants or
 // unused bytes. Geometry high bytes are also checked before narrowing them.
 reg byte_bad;
 always @*begin
  byte_bad=0;
  case(config_index)
   0:byte_bad=bus_data!=8'h50;1:byte_bad=bus_data!=8'h36;2:byte_bad=bus_data!=8'h30;3:byte_bad=bus_data!=8'h31;
   4:byte_bad=bus_data!=8'h42;5:byte_bad=bus_data!=8'h4f;6:byte_bad=bus_data!=8'h4f;7:byte_bad=bus_data!=8'h54;
   8,14:byte_bad=bus_data!=1;17:byte_bad=bus_data!=8'h18;18:byte_bad=bus_data!=5;
   9,10,11,12,13,15,16,19,41,43,45,57,59,61:byte_bad=bus_data!=0;
   24:byte_bad=bus_data>1;25:byte_bad=bus_data!={7'b0,model_a};
   40,56:byte_bad=bus_data==0||bus_data>18;
   42,58:byte_bad=bus_data==0||bus_data>2;
   44,60:byte_bad=bus_data==0||bus_data>80;
   68,84:byte_bad=bus_data!=1;
  endcase
 end
 // Header bytes arrive serially. Compute each capacity in seven clocks,
 // sharing one narrow adder instead of two combinational multipliers.
 reg[12:0]a_capacity,b_capacity,capacity_sum,capacity_term;
 reg[6:0]capacity_bits;reg[2:0]capacity_count;reg capacity_bank;
 wire[12:0]capacity_next=capacity_sum+(capacity_bits[0]?capacity_term:13'd0);
 wire geometry_valid=!header_bad&&a_sectors!=0&&b_sectors!=0&&a_sectors<=2880&&b_sectors<=2880
   &&a_sectors<=a_capacity&&b_sectors<=b_capacity;
 wire bounds_valid=a_start==mbr_a_start&&b_start==mbr_b_start&&a_sectors<=mbr_a_count&&b_sectors<=mbr_b_count
   &&a_start!=0&&{1'b0,a_start}+{1'b0,mbr_a_count}<={1'b0,b_start}
   &&{1'b0,b_start}+{1'b0,mbr_b_count}<=33'hffffffff;
 function[31:0]crc32;input[31:0]old;input[7:0]data;reg[31:0]c;integer n;
 begin c=old^{24'b0,data};for(n=0;n<8;n=n+1)c=c[0]?(c>>1)^32'hedb88320:c>>1;crc32=c;end endfunction
 always @*begin
  bus_result=8'hff;
  case(address)
   0:bus_result={locked,error,2'b0,boot_speed,hd6303_en,model_a};1:bus_result=debug;2:bus_result={6'b0,boot_b,sd_block_addressing};
   8:bus_result={error,6'b0,pending};
   11:bus_result=read_data;
   12:bus_result=crc[7:0]^8'hff;13:bus_result=crc[15:8]^8'hff;
   14:bus_result=crc[23:16]^8'hff;15:bus_result=crc[31:24]^8'hff;
  endcase
 end
 always @(posedge clk)begin
  if(cold_reset)begin
   locked<=0;model_a<=0;hd6303_en<=0;boot_speed<=0;error<=0;debug<=0;sd_block_addressing<=0;write_address<=0;write_data<=0;
   pending<=0;issued<=0;writing<=0;read_data<=0;crc<=32'hffffffff;config_index<=0;header_bad<=0;expected_crc<=0;
   a_start<=0;a_sectors<=0;b_start<=0;b_sectors<=0;a_spt<=0;a_heads<=0;b_spt<=0;b_heads<=0;cyl_a<=0;cyl_b<=0;boot_b<=0;
   mbr_a_start<=0;mbr_a_count<=0;mbr_b_start<=0;mbr_b_count<=0;
   a_capacity<=0;b_capacity<=0;capacity_count<=0;capacity_sum<=0;capacity_term<=0;capacity_bits<=0;capacity_bank<=0;
  end else begin
   if(capacity_count!=0)begin
    capacity_sum<=capacity_next;capacity_term<=capacity_term<<1;capacity_bits<=capacity_bits>>1;
    capacity_count<=capacity_count-1'b1;
    if(capacity_count==1)begin
     if(capacity_bank)b_capacity<=capacity_next;else a_capacity<=capacity_next;
    end
   end
   if(mem_request&&mem_ready)issued<=1;
   if(issued&&mem_done)begin
    pending<=0;issued<=0;write_address<=write_address+1'b1;
    if(!writing)read_data<=mem_read_data;
   end
   if(warm_reset&&!locked&&!issued)begin pending<=0;error<=0;config_index<=0;header_bad<=0;capacity_count<=0;crc<=32'hffffffff;end
   if(!locked&&!warm_reset&&bus_write)case(address)
    1:debug<=bus_data;2:sd_block_addressing<=bus_data[6];
    3:if(config_index<96)begin
     config_index<=config_index+1'b1;header_bad<=header_bad||byte_bad;
     case(config_index[6:2])
      5:expected_crc[config_index[1:0]*8+:8]<=bus_data;
      8:a_start[config_index[1:0]*8+:8]<=bus_data;9:a_sectors[config_index[1:0]*8+:8]<=bus_data;
      12:b_start[config_index[1:0]*8+:8]<=bus_data;13:b_sectors[config_index[1:0]*8+:8]<=bus_data;
      18:mbr_a_start[config_index[1:0]*8+:8]<=bus_data;19:mbr_a_count[config_index[1:0]*8+:8]<=bus_data;
      22:mbr_b_start[config_index[1:0]*8+:8]<=bus_data;23:mbr_b_count[config_index[1:0]*8+:8]<=bus_data;
     endcase
     case(config_index)
      24:boot_b<=bus_data[0];40:a_spt<=bus_data;42:a_heads<=bus_data;44:cyl_a<=bus_data;
      56:b_spt<=bus_data;58:b_heads<=bus_data;60:cyl_b<=bus_data;
     endcase
     if(config_index==45||config_index==61)begin
      capacity_bank<=config_index==61;capacity_count<=7;capacity_sum<=0;
      capacity_bits<=config_index==61?cyl_b[6:0]:cyl_a[6:0];
      capacity_term<=config_index==61?(b_heads==2?{7'b0,b_spt[4:0],1'b0}:{8'b0,b_spt[4:0]}):
          (a_heads==2?{7'b0,a_spt[4:0],1'b0}:{8'b0,a_spt[4:0]});
     end
    end else error<=1;
    4:if(!pending)write_address[7:0]<=bus_data;else error<=1;
    5:if(!pending)write_address[15:8]<=bus_data;else error<=1;
    6:if(!pending)write_address[23:16]<=bus_data;else error<=1;
    7:if(!pending&&write_address<24'h200000)begin write_data<=bus_data;writing<=1;pending<=1;issued<=0;end else error<=1;
    11:if(!pending&&write_address<24'h200000)begin writing<=0;pending<=1;issued<=0;end else error<=1;
    9:crc<=crc32(crc,bus_data);10:crc<=32'hffffffff;
    // Machine and ISA are selected before configuration and retained with ROM.
    0:if(bus_data<=15&&config_index==0&&!pending)begin model_a<=bus_data[0];hd6303_en<=bus_data[1];boot_speed<=bus_data[3:2];end
      else if(bus_data==8'ha5&&!error&&!pending&&spi_idle&&config_index==96&&capacity_count==0
       &&(crc^32'hffffffff)==expected_crc&&geometry_valid&&bounds_valid)
       locked<=1;else error<=1;
   endcase
  end
 end
endmodule
