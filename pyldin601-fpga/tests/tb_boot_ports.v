`timescale 1ns/1ps
module tb_boot_ports;
reg clk=0;always #5 clk=~clk;
reg cold=1,warm=0,rd=0,wr=0;reg[3:0]address=0;reg[7:0]di=0;
wire[7:0]result,md;wire request,mw,locked,boot_mode,error;wire[20:0]ma;
reg ready=1,done=0;reg[7:0]memory_data=0;reg auto_complete=1;
classic_boot_ports dut(.clk(clk),.cold_reset(cold),.warm_reset(warm),.bus_read(rd),.bus_write(wr),
 .address(address),.bus_data(di),.bus_result(result),.mem_request(request),.mem_write(mw),.mem_address(ma),.mem_data(md),
 .mem_ready(ready),.mem_done(done),.mem_read_data(memory_data),.spi_idle(1'b1),.locked(locked),.boot_mode(boot_mode),.error(error));
reg[7:0]header[0:63];integer i,writes=0,reads=0;
always @(posedge clk)begin
 done<=0;if(request&&ready)begin
  if(mw)writes<=writes+1;else begin reads<=reads+1;memory_data<=8'ha6;end
  ready<=0;end
 else if(!ready&&auto_complete)begin done<=1;ready<=1;end
end
task put;input[3:0]a;input[7:0]d;
begin @(negedge clk);address=a;di=d;wr=1;@(negedge clk);wr=0;end endtask
initial begin
 for(i=0;i<64;i=i+1)header[i]=0;
 {header[0],header[1],header[2],header[3],header[4],header[5],header[6],header[7]}="P601BOOT";
 header[8]=2;header[14]=1;header[17]=8'h18;header[18]=1;
 #22;cold=0;
 for(i=0;i<16;i=i+1)begin
  put(0,i);address=0;#1;
  if(result[3:0]!=i||dut.boot_speed!=(i>>2)||dut.model_a!=i[0]||dut.hd6303_en!=i[1])$fatal(1,"retained boot settings mapping");
 end
 put(0,0);put(14,7);
 put(6,1);put(7,8'h5a);repeat(8)@(negedge clk);
 if(writes!=1)$fatal(1,"aperture duplicate write");
 put(11,0);repeat(8)@(negedge clk);
 address=11;rd=1;#1;
 if(reads!=1||writes!=1||result!=8'ha6||dut.write_address!=24'h010002)
  $fatal(1,"readback data/direction/increment");
 repeat(4)@(negedge clk);
 if(reads!=1)$fatal(1,"reading result must not trigger another transaction");
 rd=0;
 // Drain an accepted read during warm reset, but do not accept new requests.
 auto_complete=0;put(11,0);wait(dut.issued);warm=1;
 repeat(4)@(negedge clk);
 if(!dut.pending||request)$fatal(1,"warm reset aborted accepted read");
 auto_complete=1;repeat(8)@(negedge clk);warm=0;
 address=11;#1;if(result!=8'ha6||dut.pending||reads!=2)$fatal(1,"warm read completion");
 // Independent standard CRC32 vector, used by SRAM readback before commit.
 for(i=0;i<9;i=i+1)put(9,8'h31+i);
 address=12;#1;if(result!=8'h26)$fatal(1,"CRC32 low byte");
 address=13;#1;if(result!=8'h39)$fatal(1,"CRC32 byte 1");
 address=14;#1;if(result!=8'hf4)$fatal(1,"CRC32 byte 2");
 address=15;#1;if(result!=8'hcb)$fatal(1,"CRC32 high byte");
 put(10,0);
 // Empty CRC stream is zero; this fixture validates lock geometry separately.
 for(i=0;i<64;i=i+1)put(3,header[i]);
 put(0,8'ha5);#10;if(!locked||error||boot_mode)$fatal(1,"commit");
 address=14;#1;if(result!=7)$fatal(1,"boot partition readback");
 warm=1;#20;if(!locked||dut.boot_partition!=7)$fatal(1,"warm unlock");warm=0;
 put(7,8'h5a);#20;put(11,0);#20;if(writes!=1||reads!=2)$fatal(1,"access after lock");
 cold=1;#20;if(locked||!boot_mode)$fatal(1,"cold unlock");
 cold=0;
 // Model 601A status, mismatch rejection, pre-load selection and warm retention.
 put(0,1);address=0;#1;if(result!=1||!dut.model_a)$fatal(1,"601A selection/status");
 for(i=0;i<64;i=i+1)put(3,header[i]);
 put(0,8'ha5);#1;if(locked||!error)$fatal(1,"wrong model accepted");
 cold=1;repeat(2)@(negedge clk);cold=0;
 if(dut.model_a)$fatal(1,"cold model not classic");
 put(0,1);header[25]=1;for(i=0;i<64;i=i+1)put(3,header[i]);
 put(0,0);#1;if(!dut.model_a||!error)$fatal(1,"model changed after configuration");
 cold=1;repeat(2)@(negedge clk);cold=0;
 put(0,3);address=0;#1;if(result!=3||!dut.hd6303_en)$fatal(1,"CPU ISA selection/status");
 for(i=0;i<64;i=i+1)put(3,header[i]);put(0,8'ha5);
 if(!locked||!dut.model_a||error)$fatal(1,"601A commit failed");
 warm=1;repeat(2)@(negedge clk);warm=0;put(0,0);
 if(!locked||!dut.model_a||!dut.hd6303_en||error)$fatal(1,"warm reset or runtime mode change");
 cold=1;repeat(2)@(negedge clk);cold=0;if(dut.hd6303_en)$fatal(1,"cold CPU not MC6800");put(4,0);put(5,0);put(6,8'h20);put(11,0);#20;
 if(!error||request||reads!=2)$fatal(1,"out-of-range SRAM read accepted");
 $display("PASS boot aperture readback, warm drain, bounds, retained lock; compact header and boot-partition retention");$finish;
end
endmodule
