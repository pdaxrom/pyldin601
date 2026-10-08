`timescale 1ns/1ps
// Geometry, packed graphics and E629 values come from the native 601 BIOS
// and verified XBIOS PLOT calls, not from the RTL or waveform generator.
module tb_video_colour;
    reg clk=0;always #5 clk=~clk;
    reg reset=1,wr=0,address=0;reg [7:0] data=0,mode=0;
    wire request;wire [20:0] ma;wire [5:0] tv;
    reg done=0;reg [7:0] memory_data;
    classic_video dut(clk,reset,1'b0,wr,address,data,,mode,
        1'b0,11'b0,8'b0,request,ma,1'b1,done,memory_data,tv,,1'b0,1'b0,8'b0,,,,,);
    reg [7:0] ram[0:65535],reference[0:63999],crtc_values[0:16];
    reg [3:0] expected_colour;
    reg expected_sync,expected_burst,expected_alternate,valid;
    reg [15:0] seen=0;
    integer test_case=0,checked=0,frames=0,phase_cycles=0,raster,row,x,h,half,canonical,line,frame;
    integer burst_checks=0,wave_checks=0;
    real angle,r,g,b,y,u,v,want,error,max_error=0;
    always @(posedge clk)begin
        done<=request;if(request)begin
            if(ma>=65536)$fatal(1,"colour DMA escaped base RAM");
            memory_data<=ram[ma];
        end
        if(reset)begin phase_cycles=0;frames=0;end
        else begin
            if(dut.divide==2)begin
                h={dut.half_line[0],dut.half_pixel};
                raster=(dut.half_line>>1)-(dut.half_line>=625?312:0);
                row=raster-50;x=h-100;
                valid=row>=0&&row<200&&x>=0&&x<320;
                expected_colour=valid?reference[row*320+x]:0;
                half=dut.half_line%625;
                if(half<5||(half>=10&&half<15))expected_sync=dut.half_pixel<19;
                else if(half<10)expected_sync=dut.half_pixel<237;
                else expected_sync=h<37;
                canonical=(dut.half_line+1245)%1250;line=canonical/2;
                frame=(dut.half_line<5?frames-1:frames)&1;
                expected_burst=h>=45&&h<63 && (frame?
                    !(line<5||line>=621||(line>=310&&line<=318)):
                    !(line<6||line>=622||(line>=309&&line<=317)));
                expected_alternate=((dut.half_line/2)+625*frames)&1;
                // Sparse continuous-phase samples cover both pixel boundaries
                // and every burst. The separate encoder test checks all phases.
                angle=(phase_cycles-1)*(4433618.75/24000000.0)*6.283185307179586;
                r=(2.0*expected_colour[2]+expected_colour[3])/3.0;
                g=(2.0*expected_colour[1]+expected_colour[3])/3.0;
                b=(2.0*expected_colour[0]+expected_colour[3])/3.0;
                y=0.299*r+0.587*g+0.114*b;u=0.493*(b-y);v=0.877*(r-y);
                if(expected_burst)begin y=0;u=-(0.3/0.7)/(2.0*$sqrt(2.0));v=-u;end
                if(expected_alternate)v=-v;
                want=expected_sync?0:15.0+34.0*(y+u*$sin(angle)+v*$cos(angle));
                if(dut.half_line==1249&&dut.half_pixel==255)frames++;
                #1;
                if(dut.held_colour!==expected_colour||dut.held_sync!==expected_sync
                    ||dut.held_burst!==expected_burst||dut.held_alternate!==expected_alternate)
                    $fatal(1,"601 colour/flags case=%d raster=%d x=%d colour=%h expected=%h sync/burst/alternate=%b%b%b expected=%b%b%b",test_case,row,x,dut.held_colour,expected_colour,dut.held_sync,dut.held_burst,dut.held_alternate,expected_sync,expected_burst,expected_alternate);
                error=real'(tv)-want;if(error<0)error=-error;
                if(error>max_error)max_error=error;
                if(error>2.1||(^tv===1'bx))$fatal(1,"colour DAC case=%d raster=%d x=%d DAC=%d expected=%.3f",test_case,row,x,tv,want);
                wave_checks++;
                if(valid)begin seen[expected_colour]=1;checked++;end
                if(expected_burst)burst_checks++;
            end
            phase_cycles++;
        end
    end
    task put;input a;input [7:0] d;
        begin @(negedge clk);address=a;data=d;wr=1;@(negedge clk);wr=0;end
    endtask
    initial begin
        for(integer n=0;n<5;n++)begin
            @(negedge clk);reset=1;checked=0;seen=0;test_case=n;
            $readmemh($sformatf("build/colour-%0d-ram.mem",n),ram);
            $readmemh($sformatf("build/colour-%0d-pixels.mem",n),reference);
            $readmemh($sformatf("build/colour-%0d-config.mem",n),crtc_values);
            mode=crtc_values[0];repeat(3)@(negedge clk);reset=0;
            for(integer j=0;j<16;j++)begin put(0,j);put(1,crtc_values[j+1]);end
            // Four fields check continuous V alternation across an odd-length
            // 625-line frame and both four-field burst-blanking patterns.
            wait(checked==256000);
            if(n==0&&seen!=16'hffff)$fatal(1,"incomplete 16-colour coverage");
            if(n>0)for(integer c=0;c<4;c++)
                if(!seen[((n-1)/2)*8+c*2+!((n-1)&1)])$fatal(1,"incomplete palette coverage");
        end
        $display("PASS 1280000 classic colour pixels from native BIOS: 80x200 IRGB, 160x200 all palettes, four fields each; %0d burst pixels, %0d DAC samples, maximum error %.3f",burst_checks,wave_checks,max_error);
        $finish;
    end
    initial begin #120000000;$fatal(1,"colour video timeout case=%d pixels=%d",test_case,checked);end
endmodule
