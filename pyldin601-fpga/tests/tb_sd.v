`timescale 1ns/1ps
module tb_sd;
    reg clk=0;always #5 clk=~clk;
    reg reset=1,request=0,write=0;
    reg [31:0] lba=32'h1234;
    wire ready,initialized,done,error,cs,sck,mosi;
    reg miso=1;
    reg [8:0] ba=0;reg bw=0;reg [7:0] bd=0;wire [7:0] br;
    sd_test_host #(.INIT_DIV(1),.RUN_DIV(0)) dut(clk,reset,request,write,lba,
        ready,initialized,done,error,ba,bw,bd,br,cs,sck,mosi,miso);
    reg [7:0] fifo[0:2047],command[0:5],incoming=0,current=8'hff;
    integer rd=0,wr=0,bits=0,cmd_count=0,write_phase=0,write_count=0,i;
    reg [15:0] read_crc=0,write_crc=0,received_crc=0;
    reg high_capacity;
    integer read_attempts=0;
    reg [31:0] argument;
    function [15:0] crc16;
        input [15:0] old;input [7:0] data;reg[15:0]c;integer k;
        begin c=old^{data,8'b0};for(k=0;k<8;k=k+1)c=c[15]?(c<<1)^16'h1021:c<<1;crc16=c;end
    endfunction
    task put;input[7:0]b;begin fifo[wr]=b;wr=wr+1;end endtask
    task receive_byte;input[7:0]b;integer j;
        begin
            if(write_phase==1)begin
                if(b==8'hfe)begin write_phase=2;write_count=0;write_crc=0;end
            end else if(write_phase==2)begin
                if(b!=(write_count[7:0]^8'h55))$fatal(1,"write byte %0d",write_count);
                write_crc=crc16(write_crc,b);write_count=write_count+1;
                if(write_count==512)write_phase=3;
            end else if(write_phase==3)begin received_crc[15:8]=b;write_phase=4;end
            else if(write_phase==4)begin
                received_crc[7:0]=b;if(received_crc!=write_crc)$fatal(1,"write CRC");
                put(8'h05);put(0);put(0);put(8'hff);write_phase=0;
            end else if(cmd_count!=0||b[7:6]==2'b01)begin
                command[cmd_count]=b;cmd_count=cmd_count+1;
                if(cmd_count==6)begin
                    argument={command[1],command[2],command[3],command[4]};
                    cmd_count=0;
                    case(command[0][5:0])
                        0:put(1);
                        8:if(high_capacity)begin put(1);put(0);put(0);put(1);put(8'haa);end else put(5);
                        55:put(1);
                        41:put(0);
                        58:begin put(0);put(high_capacity?8'hc0:8'h80);put(8'hff);put(8'h80);put(0);end
                        16:begin if(argument!=512)$fatal(1,"CMD16");put(0);end
                        17:begin
                            read_attempts=read_attempts+1;
                            if(argument!=(high_capacity?32'h1234:32'h246800))$fatal(1,"read addressing");
                            put(0);put(8'hff);put(8'hfe);read_crc=0;
                            for(j=0;j<512;j=j+1)begin put(j[7:0]);read_crc=crc16(read_crc,j[7:0]);end
                            put(read_crc[15:8]);put(read_crc[7:0]^($test$plusargs("badcrc")&&read_attempts==1?8'h01:0));
                        end
                        24:begin
                            if(argument!=(high_capacity?32'h2234:32'h446800))$fatal(1,"write addressing");
                            put(0);write_phase=1;
                        end
                        default:$fatal(1,"unexpected command %0d",command[0][5:0]);
                    endcase
                end
            end
        end
    endtask
    always @(negedge cs)begin rd=0;wr=0;bits=0;cmd_count=0;incoming=0;current=8'hff;miso=1;end
    always @(posedge cs)begin miso=1;if(write_phase!=0)$fatal(1,"CS broke write transaction");end
    always @(posedge sck)if(!cs)begin
        incoming={incoming[6:0],mosi};bits=bits+1;
        if(bits==8)begin bits=0;receive_byte(incoming);end
    end
    always @(negedge sck)if(!cs)begin
        if(bits==0)begin
            if(rd<wr)begin current=fifo[rd];rd=rd+1;end else current=8'hff;
        end
        miso=current[7-bits];
    end
    initial begin
        high_capacity=!$test$plusargs("sdsc");
        #22;reset=0;
        wait(ready||error);if(error)$fatal(1,"SD init");
        @(negedge clk);request=1;@(negedge clk);request=0;
        wait(done);
        if($test$plusargs("badcrc"))begin
            if(!error)$fatal(1,"bad sector CRC accepted");
            wait(ready&&!error);
            @(negedge clk);request=1;@(negedge clk);request=0;
            wait(done);if(error)$fatal(1,"SD failed to recover after CRC error");
            $display("PASS SD read CRC rejection and retry without reset");$finish;
        end
        if(error)$fatal(1,"SD read");
        for(i=0;i<512;i=i+1)begin ba=i;@(posedge clk);#1;if(br!=i[7:0])$fatal(1,"read byte %0d",i);end
        for(i=0;i<512;i=i+1)begin
            @(negedge clk);ba=i;bd=i[7:0]^8'h55;bw=1;
        end
        @(negedge clk);bw=0;write=1;lba=32'h2234;request=1;
        @(negedge clk);request=0;
        wait(done);if(error)$fatal(1,"SD write");
        $display("PASS SPI SD init/read/write, CS, addressing and CRC (%s)",high_capacity?"SDHC":"SDSC");$finish;
    end
    initial begin #10000000;$fatal(1,"SD timeout state=%0d",dut.core.state);end
endmodule
