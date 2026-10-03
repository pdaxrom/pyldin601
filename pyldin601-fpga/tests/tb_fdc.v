`timescale 1ns/1ps
module tb_fdc;
    reg clk=0;always #5 clk=~clk;
    reg reset=1,rd=0,wr=0;reg[4:0]address=0;reg[7:0]input_data=0;
    wire[7:0]result;wire req,write;wire[31:0]lba;reg ready=1,done=0,error=0;
    wire[8:0]ba;wire bw;wire[7:0]bd;reg[7:0]buffer[0:511];wire[7:0]br=buffer[ba];
    classic_fdc dut(clk,reset,rd,wr,address,input_data,result,1'b0,
        32'd34816,32'd2880,32'd38912,32'd2880,8'd18,8'd2,8'd18,8'd2,
        9'd80,9'd80,req,write,lba,ready,done,error,ba,bw,bd,br,);
    integer i,writes=0,reads=0;reg[31:0]last_lba;
    always @(posedge clk)begin
        done<=0;
        if(bw)buffer[ba]<=bd;
        if(req&&ready)begin
            last_lba<=lba;ready<=0;
            if(write)writes<=writes+1;
            else begin reads<=reads+1;for(integer j=0;j<512;j=j+1)buffer[j]<=j[7:0];end
        end else if(!ready)begin ready<=1;done<=1;end
    end
    task put;input[4:0]a;input[7:0]d;
        begin @(negedge clk);address=a;input_data=d;wr=1;@(negedge clk);wr=0;end
    endtask
    task get;input[4:0]a;input[7:0]expected;
        begin @(negedge clk);address=a;rd=1;#1;if(result!=expected)$fatal(1,"FDC port %x got %x expected %x state %d",a,result,expected,dut.state);
        @(negedge clk);rd=0;end
    endtask
    task rw_command;input[7:0]op;input[7:0]c,h,r;
        begin put(17,op);put(17,0);put(17,c);put(17,h);put(17,r);put(17,2);put(17,18);put(17,0);put(17,0);end
    endtask
    task result7;input[7:0]c,h,r;
        begin get(17,0);get(17,0);get(17,0);get(17,c);get(17,h);get(17,r);get(17,2);end
    endtask
    initial begin
        #22;reset=0;put(0,5); // select A, reset released
        rw_command(8'h66,79,1,18);wait(dut.state==5);
        if(last_lba!=37695)$fatal(1,"last disk sector");
        for(i=0;i<512;i=i+1)get(17,i[7:0]);result7(79,1,18);
        rw_command(8'h45,0,0,1);
        for(i=0;i<512;i=i+1)put(17,i[7:0]^8'h5a);
        wait(dut.state==9);if(writes!=1||last_lba!=34816)$fatal(1,"write completion");
        for(i=0;i<512;i=i+1)if(buffer[i]!=(i[7:0]^8'h5a))$fatal(1,"write buffer");
        result7(0,0,1);
        put(17,8'h4d);put(17,0);put(17,2);put(17,1);put(17,0);put(17,8'he5);
        put(17,0);put(17,0);put(17,2);put(17,2);
        wait(dut.state==9);if(writes!=2||last_lba!=34817)$fatal(1,"format");
        for(i=0;i<512;i=i+1)if(buffer[i]!=8'he5)$fatal(1,"format fill");
        result7(0,0,2);
        rw_command(8'h66,80,0,1);wait(dut.state==9);
        get(17,8'h40);get(17,8'h04);
        if(reads!=1)$fatal(1,"out of bounds touched SD");
        // Clear seven-byte failed result, then abort a partial write with TC.
        get(17,0);get(17,80);get(17,0);get(17,1);get(17,2);
        rw_command(8'h45,0,0,1);put(17,8'h12);put(0,7);
        wait(dut.state==9);if(writes!=2)$fatal(1,"TC wrote partial sector");
        get(17,8'h40);get(17,8'h10);get(17,0);get(17,0);get(17,0);get(17,1);get(17,2);
        put(0,5);rw_command(8'h66,0,0,1);wait(dut.state==5);
        get(17,0);put(0,7);wait(dut.state==9);result7(0,0,1);
        put(0,5);rw_command(8'h66,0,0,2);put(0,0);
        repeat(10)@(negedge clk);if(dut.state!=0)$fatal(1,"reset failed to drain");
        $display("PASS i8272 READ/WRITE/FORMAT, result phases and last-sector bounds");$finish;
    end
    initial begin #1000000;$fatal(1,"FDC timeout");end
endmodule
