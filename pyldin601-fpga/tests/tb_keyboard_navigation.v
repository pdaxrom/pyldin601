`timescale 1ns/1ps
module tb_keyboard_navigation;
    reg clk=0;always #5 clk=~clk;
    reg reset=1,psclk=1,psdata=1,cyr=0,rd=0;
    wire[7:0]data,status;wire irq;
    classic_keyboard dut(clk,reset,psclk,psdata,cyr,rd,1'b0,data,status,irq,1'b0,1'b0);
    reg[7:0]reference[0:1023],scan2[0:10],scan1[0:10];
    integer mode,key,checked=0;
    reg[7:0]shift_scan;
    task send;input[7:0]b;reg[10:0]frame;integer bit_index;
        begin
            frame={1'b1,~^b,b,1'b0};
            for(bit_index=0;bit_index<11;bit_index=bit_index+1)begin
                psdata=frame[bit_index];#300;psclk=0;#300;psclk=1;#300;
            end
            psdata=1;#300;
        end
    endtask
    task event_key;input ext,up;input[7:0]scan;
        begin if(ext)send(8'he0);if(up)send(8'hf0);send(scan);end
    endtask
    task idle;
        begin
            if(data!==8'hff||status!==0||irq||dut.queue_count!=0)
                $fatal(1,"unexpected keyboard event mode=%d data=%h status=%h irq=%b",mode,data,status,irq);
        end
    endtask
    task check_key;input ext;input[7:0]physical,pc;
        reg[7:0]expected;
        begin
            expected=reference[mode*128+pc];
            event_key(ext,0,physical);
            if(data!==expected)$fatal(1,"navigation mode=%d E0=%b scan=%h got=%h expected=%h",mode,ext,physical,data,expected);
            if(expected==8'hff)begin
                idle;event_key(ext,0,physical);idle;event_key(ext,1,physical);idle;
            end else begin
                if(status!==8'h80||!irq)$fatal(1,"navigation make lost status/IRQ");
                event_key(ext,0,physical);
                if(data!==expected||dut.queue_count!=0)$fatal(1,"held navigation queued a duplicate");
                @(negedge clk);rd=1;@(negedge clk);rd=0;#1;
                if(irq||status!==0||data!==expected)$fatal(1,"navigation read/held data");
                event_key(ext,0,physical);
                if(irq||status!==0||dut.queue_count!=0)$fatal(1,"consumed repeat rearmed navigation");
                event_key(ext,1,physical);idle;
            end
            checked=checked+1;
        end
    endtask
    initial begin
        $readmemh("build/keyboard-reference.mem",reference);
        scan2[0]=8'h6c;scan1[0]=8'h47; // Home
        scan2[1]=8'h75;scan1[1]=8'h48; // Up
        scan2[2]=8'h7d;scan1[2]=8'h49; // Page Up
        scan2[3]=8'h6b;scan1[3]=8'h4b; // Left
        scan2[4]=8'h73;scan1[4]=8'h4c; // Keypad 5 (no native character)
        scan2[5]=8'h74;scan1[5]=8'h4d; // Right
        scan2[6]=8'h69;scan1[6]=8'h4f; // End
        scan2[7]=8'h72;scan1[7]=8'h50; // Down
        scan2[8]=8'h7a;scan1[8]=8'h51; // Page Down
        scan2[9]=8'h70;scan1[9]=8'h52; // Insert
        scan2[10]=8'h71;scan1[10]=8'h53; // Delete
        #22;reset=0;
        for(mode=0;mode<8;mode=mode+1)begin
            cyr=(mode&4)!=0;shift_scan=cyr?8'h59:8'h12;
            if(mode&1)event_key(0,0,shift_scan);
            if(mode&2)event_key(cyr,0,8'h14);
            idle;
            for(key=0;key<11;key=key+1)begin
                check_key(0,scan2[key],scan1[key]); // keypad aliases
                if(key!=4)check_key(1,scan2[key],scan1[key]);
            end
            event_key(0,0,8'h7e);idle; // Scroll Lock has no native character
            event_key(0,0,8'h7e);idle;event_key(0,1,8'h7e);idle;
            check_key(1,8'h1f,8'h46);check_key(1,8'h27,8'h46);
            if(mode&1)event_key(0,1,shift_scan);
            if(mode&2)event_key(cyr,1,8'h14);
            idle;
        end
        if(checked!=184)$fatal(1,"navigation coverage %d",checked);
        $display("PASS 184 native navigation/Win cases: LAT/CYR, Shift/Ctrl, keypad aliases, make/repeat/read/break; Scroll Lock ignored");$finish;
    end
    initial begin #30000000;$fatal(1,"keyboard navigation timeout");end
endmodule
