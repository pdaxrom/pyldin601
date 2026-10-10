// Boot-only RAM access and retained ROM validity. No filesystem, copying or reset FSM.
// E6A0 commit/status; A1 debug; A2 SDHC mode; A3 compact v2 header (64 bytes);
// A4-A6 address; A7 write/increment; A8 busy/error; A9 CRC feed; AA CRC reset;
// writing AB starts a read/increment, reading AB returns its completed byte; AC-AF CRC.
// Before header upload AE writes AUTO/partition; after lock AE reads that choice.
module classic_boot_ports(
 input wire clk,cold_reset,warm_reset,bus_read,bus_write,
 input wire[3:0]address,input wire[7:0]bus_data,output reg[7:0]bus_result,
 output wire mem_request,output wire mem_write,output wire[20:0]mem_address,output wire[7:0]mem_data,
 input wire mem_ready,mem_done,input wire[7:0]mem_read_data,input wire spi_idle,
 output reg locked,output wire boot_mode,output reg error,output reg[7:0]debug,
 output reg sd_block_addressing,output reg model_a,output reg hd6303_en,
 output reg[7:0]boot_partition,output reg[1:0]boot_speed
);
 reg[23:0]write_address;reg[7:0]write_data,read_data;reg pending,issued,writing;
 reg[31:0]crc,expected_crc;reg[6:0]config_index;reg header_bad;
 assign boot_mode=!locked;
 assign mem_request=pending&&!issued&&!warm_reset;
 assign mem_write=writing;
 assign mem_address=write_address[20:0];assign mem_data=write_data;
 // Validate fixed header bytes as they arrive; no registers for constants or
 // unused bytes. Partition choice is validated separately before header upload.
 reg byte_bad;
 always @*begin
  byte_bad=0;
  case(config_index)
   0:byte_bad=bus_data!=8'h50;1:byte_bad=bus_data!=8'h36;2:byte_bad=bus_data!=8'h30;3:byte_bad=bus_data!=8'h31;
   4:byte_bad=bus_data!=8'h42;5:byte_bad=bus_data!=8'h4f;6:byte_bad=bus_data!=8'h4f;7:byte_bad=bus_data!=8'h54;
   8:byte_bad=bus_data!=2;14,18:byte_bad=bus_data!=1;17:byte_bad=bus_data!=8'h18;
   9,10,11,12,13,15,16,19,24:byte_bad=bus_data!=0;
   25:byte_bad=bus_data!={7'b0,model_a};
   default:if(config_index>=26)byte_bad=bus_data!=0;
  endcase
 end
 function[31:0]crc32;input[31:0]old;input[7:0]data;reg[31:0]c;integer n;
 begin c=old^{24'b0,data};for(n=0;n<8;n=n+1)c=c[0]?(c>>1)^32'hedb88320:c>>1;crc32=c;end endfunction
 always @*begin
  bus_result=8'hff;
  case(address)
   0:bus_result={locked,error,2'b0,boot_speed,hd6303_en,model_a};1:bus_result=debug;2:bus_result={7'b0,sd_block_addressing};
   8:bus_result={error,6'b0,pending};
   11:bus_result=read_data;
   12:bus_result=crc[7:0]^8'hff;13:bus_result=crc[15:8]^8'hff;
   14:bus_result=locked?boot_partition:crc[23:16]^8'hff;15:bus_result=crc[31:24]^8'hff;
  endcase
 end
 always @(posedge clk)begin
  if(cold_reset)begin
   locked<=0;model_a<=0;hd6303_en<=0;boot_speed<=0;error<=0;debug<=0;sd_block_addressing<=0;write_address<=0;write_data<=0;
   pending<=0;issued<=0;writing<=0;read_data<=0;crc<=32'hffffffff;config_index<=0;header_bad<=0;expected_crc<=0;
   boot_partition<=0;
  end else begin
   if(mem_request&&mem_ready)issued<=1;
   if(issued&&mem_done)begin
    pending<=0;issued<=0;write_address<=write_address+1'b1;
    if(!writing)read_data<=mem_read_data;
   end
   if(warm_reset&&!locked&&!issued)begin pending<=0;error<=0;config_index<=0;header_bad<=0;crc<=32'hffffffff;end
   if(!locked&&!warm_reset&&bus_write)case(address)
    1:debug<=bus_data;2:sd_block_addressing<=bus_data[6];
    3:if(config_index<64)begin
     config_index<=config_index+1'b1;header_bad<=header_bad||byte_bad;
     if(config_index[6:2]==5)expected_crc[config_index[1:0]*8+:8]<=bus_data;
    end else error<=1;
    14:if(config_index==0&&!pending&&bus_data<=36)boot_partition<=bus_data;else error<=1;
    4:if(!pending)write_address[7:0]<=bus_data;else error<=1;
    5:if(!pending)write_address[15:8]<=bus_data;else error<=1;
    6:if(!pending)write_address[23:16]<=bus_data;else error<=1;
    7:if(!pending&&write_address<24'h200000)begin write_data<=bus_data;writing<=1;pending<=1;issued<=0;end else error<=1;
    11:if(!pending&&write_address<24'h200000)begin writing<=0;pending<=1;issued<=0;end else error<=1;
    9:crc<=crc32(crc,bus_data);10:crc<=32'hffffffff;
    // Machine and ISA are selected before configuration and retained with ROM.
    0:if(bus_data<=15&&config_index==0&&!pending)begin model_a<=bus_data[0];hd6303_en<=bus_data[1];boot_speed<=bus_data[3:2];end
      else if(bus_data==8'ha5&&!error&&!pending&&spi_idle&&config_index==64&&!header_bad
       &&(crc^32'hffffffff)==expected_crc)
       locked<=1;else error<=1;
   endcase
  end
 end
endmodule
