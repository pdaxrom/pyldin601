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
 output reg sd_block_addressing,output wire[31:0]a_start,a_sectors,b_start,b_sectors,
 output wire[7:0]a_spt,a_heads,b_spt,b_heads,
 output wire[8:0]a_cylinders,b_cylinders,output wire boot_b,output reg model_a,output reg hd6303_en
);
 reg[23:0]write_address;reg[7:0]write_data,read_data;reg pending,issued,writing;
 reg[31:0]crc;reg[767:0]configuration;reg[6:0]config_index;
 wire[31:0]version=configuration[64+:32],base=configuration[96+:32],length=configuration[128+:32];
 wire[31:0]expected_crc=configuration[160+:32];
 assign a_start=configuration[256+:32];assign a_sectors=configuration[288+:32];
 assign b_start=configuration[384+:32];assign b_sectors=configuration[416+:32];
 wire[15:0]aspt=configuration[320+:16],ah=configuration[336+:16],ac=configuration[352+:16];
 wire[15:0]bspt=configuration[448+:16],bh=configuration[464+:16],bc=configuration[480+:16];
 assign a_spt=aspt[7:0];assign a_heads=ah[7:0];assign a_cylinders=ac[8:0];
 assign b_spt=bspt[7:0];assign b_heads=bh[7:0];assign b_cylinders=bc[8:0];
 assign boot_b=configuration[192];assign boot_mode=!locked;
 assign mem_request=pending&&!issued&&!warm_reset;
 assign mem_write=writing;
 assign mem_address=write_address[20:0];assign mem_data=write_data;
 wire[31:0]mbr_a_start=configuration[576+:32],mbr_a_count=configuration[608+:32];
 wire[31:0]mbr_b_start=configuration[704+:32],mbr_b_count=configuration[736+:32];
 wire[13:0]a_capacity=(aspt[4:0]*ah[1:0])*ac[6:0];
 wire[13:0]b_capacity=(bspt[4:0]*bh[1:0])*bc[6:0];
 wire geometry_valid=aspt!=0&&aspt<=18&&bspt!=0&&bspt<=18&&ah!=0&&ah<=2&&bh!=0&&bh<=2
   &&ac!=0&&ac<=80&&bc!=0&&bc<=80&&a_sectors!=0&&b_sectors!=0&&a_sectors<=2880&&b_sectors<=2880
   &&a_sectors<=a_capacity&&b_sectors<=b_capacity;
 wire bounds_valid=configuration[544+:8]==1&&configuration[672+:8]==1
   &&a_start==mbr_a_start&&b_start==mbr_b_start&&a_sectors<=mbr_a_count&&b_sectors<=mbr_b_count
   &&a_start!=0&&{1'b0,a_start}+{1'b0,mbr_a_count}<={1'b0,b_start}
   &&{1'b0,b_start}+{1'b0,mbr_b_count}<=33'hffffffff;
 function[31:0]crc32;input[31:0]old;input[7:0]data;reg[31:0]c;integer n;
 begin c=old^{24'b0,data};for(n=0;n<8;n=n+1)c=c[0]?(c>>1)^32'hedb88320:c>>1;crc32=c;end endfunction
 always @*begin
  bus_result=8'hff;
  case(address)
   0:bus_result={locked,error,4'b0,hd6303_en,model_a};1:bus_result=debug;2:bus_result={7'b0,sd_block_addressing};
   8:bus_result={error,6'b0,pending};
   11:bus_result=read_data;
   12:bus_result=crc[7:0]^8'hff;13:bus_result=crc[15:8]^8'hff;
   14:bus_result=crc[23:16]^8'hff;15:bus_result=crc[31:24]^8'hff;
  endcase
 end
 always @(posedge clk)begin
  if(cold_reset)begin
   locked<=0;model_a<=0;hd6303_en<=0;error<=0;debug<=0;sd_block_addressing<=0;write_address<=0;write_data<=0;
   pending<=0;issued<=0;writing<=0;read_data<=0;crc<=32'hffffffff;configuration<=0;config_index<=0;
  end else begin
   if(mem_request&&mem_ready)issued<=1;
   if(issued&&mem_done)begin
    pending<=0;issued<=0;write_address<=write_address+1'b1;
    if(!writing)read_data<=mem_read_data;
   end
   if(warm_reset&&!locked&&!issued)begin pending<=0;error<=0;config_index<=0;crc<=32'hffffffff;end
   if(!locked&&!warm_reset&&bus_write)case(address)
    1:debug<=bus_data;2:sd_block_addressing<=bus_data[6];
    3:if(config_index<96)begin configuration[config_index*8+:8]<=bus_data;config_index<=config_index+1'b1;end else error<=1;
    4:if(!pending)write_address[7:0]<=bus_data;else error<=1;
    5:if(!pending)write_address[15:8]<=bus_data;else error<=1;
    6:if(!pending)write_address[23:16]<=bus_data;else error<=1;
    7:if(!pending&&write_address<24'h200000)begin write_data<=bus_data;writing<=1;pending<=1;issued<=0;end else error<=1;
    11:if(!pending&&write_address<24'h200000)begin writing<=0;pending<=1;issued<=0;end else error<=1;
    9:crc<=crc32(crc,bus_data);10:crc<=32'hffffffff;
    // Machine and ISA are selected before configuration and retained with ROM.
    0:if(bus_data<=3&&config_index==0&&!pending)begin model_a<=bus_data[0];hd6303_en<=bus_data[1];end
      else if(bus_data==8'ha5&&!error&&!pending&&spi_idle&&config_index==96
       &&configuration[63:0]==64'h544f4f4231303650&&version==1&&base==32'h10000&&length==32'h51800
       &&configuration[200+:8]=={7'b0,model_a}&&configuration[192+:8]<=1&&(crc^32'hffffffff)==expected_crc&&geometry_valid&&bounds_valid)
       locked<=1;else error<=1;
   endcase
  end
 end
endmodule
