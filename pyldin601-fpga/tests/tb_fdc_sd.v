`timescale 1ns/1ps
// End-to-end hardware i8272 -> synchronous sector RAM -> SD SPI test.
module tb_fdc_sd;
    reg clk=0;always #5 clk=~clk;
    reg reset=1,rd=0,wr=0;reg[4:0]address=0;reg[7:0]input_data=0;
    wire[7:0]result;wire request,write,ready,done,error,initialized,active;
    wire[31:0]lba;wire[8:0]ba;wire bw;wire[7:0]bd,br;
    wire cs,sck,mosi;reg miso=1;
    classic_fdc fdc(clk,reset,rd,wr,address,input_data,result,1'b0,
        32'd32,32'd36,32'd128,32'd36,8'd18,8'd2,8'd18,8'd2,
        9'd1,9'd1,request,write,lba,ready,done,error,ba,bw,bd,br,active);
    sd_test_host #(.INIT_DIV(1),.RUN_DIV(0)) sd(clk,reset,request,write,lba,
        ready,initialized,done,error,ba,bw,bd,br,cs,sck,mosi,miso);
    reg[7:0]fifo[0:2047],command[0:5],incoming=0,current=8'hff;
    reg[7:0]sector32[0:511],sector33[0:511];
    integer fifo_read=0,fifo_write=0,bits=0,cmd_count=0,write_phase=0,write_count=0;
    integer reads=0,writes=0,i;
    reg[15:0]read_crc=0,write_crc=0,received_crc=0;
    reg[31:0]argument,write_lba,last_read_lba;
    function[15:0]crc16;
        input[15:0]old;input[7:0]data;reg[15:0]c;integer k;
        begin c=old^{data,8'b0};for(k=0;k<8;k=k+1)c=c[15]?(c<<1)^16'h1021:c<<1;crc16=c;end
    endfunction
    task enqueue;input[7:0]b;begin fifo[fifo_write]=b;fifo_write=fifo_write+1;end endtask
    task receive_byte;input[7:0]b;integer j;reg[7:0]value;
        begin
            if(write_phase==1)begin
                if(b==8'hfe)begin write_phase=2;write_count=0;write_crc=0;end
            end else if(write_phase==2)begin
                if(write_lba==32)sector32[write_count]=b;
                else if(write_lba==33)sector33[write_count]=b;
                else $fatal(1,"unexpected write LBA %d",write_lba);
                write_crc=crc16(write_crc,b);write_count=write_count+1;
                if(write_count==512)write_phase=3;
            end else if(write_phase==3)begin received_crc[15:8]=b;write_phase=4;end
            else if(write_phase==4)begin
                received_crc[7:0]=b;if(received_crc!=write_crc)$fatal(1,"FDC/SD write CRC");
                enqueue(8'h05);enqueue(0);enqueue(8'hff);write_phase=0;writes=writes+1;
            end else if(cmd_count!=0||b[7:6]==2'b01)begin
                command[cmd_count]=b;cmd_count=cmd_count+1;
                if(cmd_count==6)begin
                    argument={command[1],command[2],command[3],command[4]};cmd_count=0;
                    case(command[0][5:0])
                        0:enqueue(1);
                        8:begin enqueue(1);enqueue(0);enqueue(0);enqueue(1);enqueue(8'haa);end
                        55:enqueue(1);
                        41:enqueue(0);
                        58:begin enqueue(0);enqueue(8'hc0);enqueue(8'hff);enqueue(8'h80);enqueue(0);end
                        17:begin
                            reads=reads+1;last_read_lba=argument;
                            enqueue(0);enqueue(8'hff);enqueue(8'hfe);read_crc=0;
                            for(j=0;j<512;j=j+1)begin
                                value=argument==32?sector32[j]:argument==33?sector33[j]:j[7:0]^argument[7:0];
                                enqueue(value);read_crc=crc16(read_crc,value);
                            end
                            enqueue(read_crc[15:8]);enqueue(read_crc[7:0]);
                        end
                        24:begin enqueue(0);write_lba=argument;write_phase=1;end
                        default:$fatal(1,"unexpected SD command %d",command[0][5:0]);
                    endcase
                end
            end
        end
    endtask
    always @(negedge cs)begin fifo_read=0;fifo_write=0;bits=0;cmd_count=0;incoming=0;current=8'hff;miso=1;end
    always @(posedge cs)begin miso=1;if(write_phase!=0)$fatal(1,"CS broke FDC write");end
    always @(posedge sck)if(!cs)begin
        incoming={incoming[6:0],mosi};bits=bits+1;
        if(bits==8)begin bits=0;receive_byte(incoming);end
    end
    always @(negedge sck)if(!cs)begin
        if(bits==0)begin
            if(fifo_read<fifo_write)begin current=fifo[fifo_read];fifo_read=fifo_read+1;end else current=8'hff;
        end
        miso=current[7-bits];
    end
    task put;input[4:0]a;input[7:0]d;
        begin @(negedge clk);address=a;input_data=d;wr=1;@(negedge clk);wr=0;end
    endtask
    task get;input[4:0]a;input[7:0]expected;
        begin @(negedge clk);address=a;rd=1;#1;
            if(result!==expected)$fatal(1,"FDC/SD port %x got %x expected %x state %d index %d",a,result,expected,fdc.state,ba);
            @(negedge clk);rd=0;
        end
    endtask
    task rw_command;input[7:0]op,c,h,r;
        begin put(17,op);put(17,0);put(17,c);put(17,h);put(17,r);put(17,2);put(17,18);put(17,0);put(17,0);end
    endtask
    task result7;input[7:0]c,h,r;
        begin get(17,0);get(17,0);get(17,0);get(17,c);get(17,h);get(17,r);get(17,2);end
    endtask
    initial begin
        for(i=0;i<512;i=i+1)begin sector32[i]=i[7:0]^8'h20;sector33[i]=i[7:0]^8'h21;end
        #22;reset=0;wait(ready||error);if(error)$fatal(1,"SD initialization");
        put(0,5);rw_command(8'h66,0,1,18);wait(fdc.state==5);
        if(last_read_lba!=67)$fatal(1,"A last sector LBA");get(16,8'hf0);
        for(i=0;i<512;i=i+1)get(17,i[7:0]^8'h43);result7(0,1,18);
        rw_command(8'h45,0,0,1);wait(fdc.state==6);
        for(i=0;i<512;i=i+1)put(17,i[7:0]^8'h55);
        wait(fdc.state==9);if(writes!=1)$fatal(1,"SD write completion");result7(0,0,1);
        rw_command(8'h66,0,0,1);wait(fdc.state==5);
        for(i=0;i<512;i=i+1)get(17,i[7:0]^8'h55);result7(0,0,1);
        put(17,8'h4d);put(17,0);put(17,2);put(17,1);put(17,0);put(17,8'he5);
        wait(fdc.state==10);put(17,0);put(17,0);put(17,2);put(17,2);
        wait(fdc.state==9);if(writes!=2)$fatal(1,"SD format completion");result7(0,0,2);
        rw_command(8'h66,0,0,2);wait(fdc.state==5);
        for(i=0;i<512;i=i+1)get(17,8'he5);result7(0,0,2);
        put(0,1);rw_command(8'h66,0,0,1);wait(fdc.state==4);put(0,5);wait(fdc.state==5);
        if(last_read_lba!=128)$fatal(1,"B selection changed in flight");
        for(i=0;i<512;i=i+1)get(17,i[7:0]^8'h80);result7(0,0,1);
        rw_command(8'h45,0,0,1);wait(fdc.state==6);put(17,8'h12);put(0,7);
        wait(fdc.state==9);if(writes!=2)$fatal(1,"early TC wrote partial SD sector");
        get(17,8'h40);get(17,8'h10);get(17,0);get(17,0);get(17,0);get(17,1);get(17,2);
        put(0,5);rw_command(8'h66,1,0,1);wait(fdc.state==9);
        get(17,8'h40);get(17,8'h04);if(reads!=4)$fatal(1,"invalid CHS read SD");
        $display("PASS hardware i8272 -> synchronous sector RAM -> SD SPI: A/B, READ/WRITE/FORMAT, CRC, TC and CHS bounds");$finish;
    end
    initial begin #10000000;$fatal(1,"FDC/SD timeout fdc=%d sd=%d",fdc.state,sd.core.state);end
endmodule
