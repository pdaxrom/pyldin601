// Test fixture: byte-engine wiring, not production logic.
module sd_test_host #(parameter INIT_DIV=29,RUN_DIV=1)(
 input clk,reset,request,write,input[31:0]lba,
 output ready,initialized,done,error,input[8:0]buffer_address,input buffer_write,input[7:0]buffer_data_in,
 output[7:0]buffer_data_out,output sd_cs,sd_sck,sd_mosi,input sd_miso
);
wire start,busy,byte_done;wire[7:0]tx,divider,rx;
sd_spi_block #(.INIT_DIV(INIT_DIV),.RUN_DIV(RUN_DIV)) core(
 clk,reset,request,write,lba,ready,initialized,done,error,buffer_address,buffer_write,buffer_data_in,
 buffer_data_out,sd_cs,1'b0,1'b0,1'b0,start,tx,divider,busy,byte_done,rx);
spi_byte_master engine(clk,reset,start,tx,divider,sd_miso,sd_sck,sd_mosi,busy,byte_done,rx);
endmodule
