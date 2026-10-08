// PS/2 set 2 receiver and classic Pyldin character/status interface.
// Translation tables derive from Pyldin-601, Sasha Chukov & Yura Kuznetsov.
module classic_keyboard #(
    parameter TRANSLATE_FILE="rtl/keyboard_translate.mem",
    parameter SET2_FILE="rtl/ps2_set2.mem"
) (
    input wire clk,reset,ps2_clk,ps2_data,
    input wire cyrillic,
    input wire read_data,read_status,
    output wire [7:0] data,
    output wire [7:0] status,
    output reg irq,
    input wire runtime_mode,timer_ack
);
    reg [2:0] clock_sync,data_sync;
    reg [7:0] filter;
    reg filtered_clock,last_clock;
    reg [10:0] frame;
    reg [3:0] count;
    reg [15:0] timeout;
    reg received;
    reg [7:0] scan;
    reg extended,released,shift_l,shift_r,ctrl_l,ctrl_r;
    reg key_ready,trigger,consumed;
    reg [7:0] key_code,active_scan;
    reg active_extended,active_down;
    reg[7:0]queue_valid,queue_down;
    reg[7:0]queue_code[0:7],queue_scan[0:7];reg queue_extended[0:7];
    reg held_match;integer j,k;
    always @*begin
        held_match=key_ready&&active_down&&active_scan==scan&&active_extended==extended;
        for(j=0;j<8;j=j+1)
            if(queue_valid[j]&&queue_down[j]&&queue_scan[j]==scan&&queue_extended[j]==extended)held_match=1;
    end
    reg[2:0]queue_head,queue_tail;reg[3:0]queue_count;
    reg[3:0]pause_remaining;
    // Native int09 discards reads while key_timer0 is nonzero (3 PAL ticks).
    // Identical taps also need key_timer2 to expire (5 ticks -> old_key=FF).
    // Timer calls int17 with nested IRQs enabled before decrementing counters;
    // the next acknowledge proves the preceding decrement has completed.
    // Count acknowledged timer IRQs, not CPU clocks or PS/2 typematic frames.
    // Keep receiving into the FIFO while the BIOS is in its debounce window.
    reg[2:0]quiet_ticks;
    (* syn_ramstyle="block_ram" *) reg [7:0] translate[0:1023];
    (* syn_ramstyle="block_ram" *) reg [7:0] set2[0:255];
    reg[7:0]set2_byte,translated_byte;reg[1:0]translation_ready;
    // Two synchronous ROM stages. A complete PS/2 frame is held throughout
    // the pipeline, including its E0/F0 state; FIFO/BIOS pacing is unchanged.
    wire shift=shift_l||shift_r,ctrl=ctrl_l||ctrl_r;
    // Both Windows keys act as the classic LAT/CYR key (FB in every table).
    // Preserve their E0 identity for make/break and typematic suppression.
    wire [7:0] pc_scan=extended&&(scan==8'h1f||scan==8'h27)?8'h46:set2_byte;
    wire [2:0] mode={cyrillic,ctrl,shift};
    wire [9:0] translate_address={mode,pc_scan[6:0]};
    always @(posedge clk)begin
        set2_byte<=set2[scan];translated_byte<=translate[translate_address];
        if(reset)translation_ready<=0;else translation_ready<={translation_ready[0],received};
    end
    wire queued_ready=!runtime_mode||quiet_ticks==6
        ||(quiet_ticks>=4&&queue_code[queue_head]!=key_code);
    wire incoming_ready=!runtime_mode||quiet_ticks==6
        ||(quiet_ticks>=4&&translated_byte!=key_code);
    assign data=key_ready?key_code:8'hff;
    assign status=key_ready&&trigger?8'h80:0;
    initial begin $readmemh(TRANSLATE_FILE,translate);$readmemh(SET2_FILE,set2);end
    always @(posedge clk)begin
        clock_sync<={clock_sync[1:0],ps2_clk};data_sync<={data_sync[1:0],ps2_data};
        filter<={filter[6:0],clock_sync[2]};last_clock<=filtered_clock;
        if(&filter)filtered_clock<=1;else if(~|filter)filtered_clock<=0;
        received<=0;
        if(reset)begin
            clock_sync<=7;data_sync<=7;filter<=8'hff;filtered_clock<=1;last_clock<=1;
            count<=0;timeout<=0;frame<=0;scan<=0;received<=0;
            extended<=0;released<=0;shift_l<=0;shift_r<=0;ctrl_l<=0;ctrl_r<=0;
            irq<=0;active_down<=0;queue_valid<=0;queue_down<=0;queue_head<=0;queue_tail<=0;queue_count<=0;pause_remaining<=0;
            key_ready<=0;trigger<=0;consumed<=0;key_code<=8'hff;active_scan<=0;active_extended<=0;
            quiet_ticks<=6;
        end else begin
            if(!runtime_mode)quiet_ticks<=6;
            else if(read_data&&key_ready)quiet_ticks<=0;
            else if(timer_ack&&quiet_ticks!=6)quiet_ticks<=quiet_ticks+1'b1;
            if(count!=0)begin
                if(timeout==16'd24000)begin count<=0;timeout<=0;end
                else timeout<=timeout+1'b1;
            end
            if(last_clock&&!filtered_clock)begin
                timeout<=0;frame<={data_sync[2],frame[10:1]};
                if(count==10)begin
                    count<=0;
                    if(frame[1]==0&&data_sync[2]&&(^frame[10:2]))begin
                        scan<=frame[9:2];received<=1;
                    end
                end else count<=count+1'b1;
            end
            if(read_status&&key_ready)trigger<=!trigger;
            if(read_data)begin trigger<=0;consumed<=1;irq<=0;end
            if(key_ready&&consumed&&!active_down)begin
                key_ready<=0;trigger<=0;consumed<=0;
            end
            if(!key_ready&&queue_count!=0&&!received&&translation_ready==0&&queued_ready)begin
                key_code<=queue_code[queue_head];active_scan<=queue_scan[queue_head];
                active_extended<=queue_extended[queue_head];active_down<=queue_down[queue_head];
                queue_valid[queue_head]<=0;queue_head<=queue_head+1'b1;
                queue_count<=queue_count-1'b1;key_ready<=1;trigger<=1;consumed<=0;irq<=1;
            end
            if(translation_ready[1])begin
                if(pause_remaining!=0)pause_remaining<=pause_remaining-1'b1;
                else if(scan==8'he1)begin pause_remaining<=7;extended<=0;released<=0;end
                else if(scan==8'he0)extended<=1;
                else if(scan==8'hf0)released<=1;
                else begin
                    extended<=0;released<=0;
                    if(!extended&&scan==8'h12)shift_l<=!released;
                    else if(!extended&&scan==8'h59)shift_r<=!released;
                    else if(scan==8'h14)begin
                        if(extended)ctrl_r<=!released;else ctrl_l<=!released;
                    end else if(scan==8'h11||scan==8'he1||scan==8'h77)begin
                        // Alt and Pause sequence do not produce character data.
                        // Caps Lock passes through as the classic FC key for UniBIOS.
                    end else if(released)begin
                        if(active_scan==scan&&active_extended==extended)active_down<=0;
                        for(k=0;k<8;k=k+1)
                            if(queue_valid[k]&&queue_scan[k]==scan&&queue_extended[k]==extended)queue_down[k]<=0;
                        if(active_scan==scan&&active_extended==extended&&consumed)begin
                            key_ready<=0;trigger<=0;consumed<=0;
                        end
                    end else if(pc_scan!=8'hff&&translated_byte!=8'hff)begin
                        // Typematic make repeats retain the active key, as the classic PIA does.
                        if(!held_match)begin
                            if(!key_ready&&queue_count==0&&incoming_ready)begin
                                key_code<=translated_byte;key_ready<=1;consumed<=0;
                                active_scan<=scan;active_extended<=extended;active_down<=1;trigger<=1;irq<=1;
                            end else if(queue_count<8)begin
                                queue_code[queue_tail]<=translated_byte;queue_scan[queue_tail]<=scan;
                                queue_extended[queue_tail]<=extended;queue_down[queue_tail]<=1;queue_valid[queue_tail]<=1;queue_tail<=queue_tail+1'b1;queue_count<=queue_count+1'b1;
                            end
                        end
                    end
                end
            end
        end
    end
endmodule
