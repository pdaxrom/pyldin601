`timescale 1ns/1ps
module tb_fat;
    reg clk=0;always #5 clk=~clk;
    reg reset=1,start=0;reg [87:0] filename="P601    ROM";
    wire busy,done,error,req,valid;wire[31:0]lba,size,pa,na,pb,nb;
    wire[8:0]address;reg sd_ready=1,sd_done=0,sd_error=0;
    reg[7:0]buffer[0:511];wire[7:0]data;wire[7:0]byte_data=buffer[address];
    reg ready=0;integer cycles=0,bytes=0,sectors=0;
    fat16_file_reader dut(clk,reset,start,filename,busy,done,error,req,lba,
        sd_ready,sd_done,sd_error,address,byte_data,valid,ready,data,size,pa,na,pb,nb);
    integer fd,reference,result;reg[2047:0]image_path,reference_path;reg[7:0]expected;
    always @(posedge clk)begin
        sd_done<=0;cycles<=cycles+1;
        ready<=cycles%7!=0; // consumer back pressure
        if(!reset)begin
            if(req&&sd_ready)begin
                result=$fseek(fd,lba*512,0);result=$fread(buffer,fd);
                if(result!=512)$fatal(1,"short SD read");sd_ready<=0;sectors<=sectors+1;
            end else if(!sd_ready)begin sd_done<=1;sd_ready<=1;end
            if(valid&&ready)begin
                result=$fread(expected,reference);if(result!=1||expected!=data)$fatal(1,"file mismatch at %0d",bytes);
                bytes<=bytes+1;
            end
        end
    end
    initial begin
        if(!$value$plusargs("image=%s",image_path)||!$value$plusargs("reference=%s",reference_path))$fatal(1,"paths required");
        fd=$fopen(image_path,"rb");reference=$fopen(reference_path,"rb");
        if(!fd||!reference)$fatal(1,"open");
        #22;reset=0;start=1;#10;start=0;
        wait(done||error);#10;
        if($test$plusargs("reject"))begin if(!error)$fatal(1,"bad FAT accepted");end
        else begin
            if(error||bytes!=333824+512||size!=bytes)$fatal(1,"reader failure bytes=%0d state=%0d",bytes,dut.state);
            if(pa!=34816||pb<=pa||na==0||nb==0)$fatal(1,"partition metadata");
            $display("PASS FAT16 root lookup, fragmented chains and back pressure (%0d sectors)",sectors);
        end
        $finish;
    end
    initial begin #100000000;$fatal(1,"FAT timeout");end
endmodule
