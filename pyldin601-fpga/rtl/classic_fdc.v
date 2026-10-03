// i8272 command facade for the classic BIOS, sector storage through SD SPI.
// One 512-byte sector per READ/WRITE command (the BIOS asserts TC after it).
module classic_fdc (
    input wire clk, reset,
    input wire bus_read, bus_write,
    input wire [4:0] bus_address,
    input wire [7:0] bus_data,
    output reg [7:0] bus_result,
    input wire boot_b,
    input wire [31:0] a_start,a_length,b_start,b_length,
    input wire [7:0] a_spt,a_heads,b_spt,b_heads,
    input wire [8:0] a_cylinders,b_cylinders,
    output wire sd_request, sd_write,
    output wire [31:0] sd_lba,
    input wire sd_ready,sd_done,sd_error,
    output wire [8:0] buffer_address,
    output wire buffer_write,
    output wire [7:0] buffer_data,
    input wire [7:0] buffer_result,
    output wire active
);
    localparam COMMAND=0,ARGS=1,EXECUTE=2,READ_REQ=3,READ_WAIT=4,
        READ_DATA=5,WRITE_DATA=6,WRITE_REQ=7,WRITE_WAIT=8,
        RESULT=9,FORMAT_ID=10,FORMAT_FILL=11;
    reg [3:0] state;
    reg [7:0] select_reg,command,args[0:7],results[0:6];
    reg [3:0] arg_index,arg_count,result_index,result_count;
    reg [8:0] byte_index;
    reg [7:0] c,h,r,n,fill,format_remaining,format_index;
    reg [7:0] track_a,track_b,seek_status,seek_track;
    reg formatting,selected_b,reset_pending;
    assign active=state!=COMMAND&&state!=RESULT;
    wire [31:0] drive_start = selected_b ? b_start:a_start;
    wire [31:0] drive_length = selected_b ? b_length:a_length;
    wire [7:0] drive_spt=selected_b?b_spt:a_spt;
    wire [7:0] drive_heads=selected_b?b_heads:a_heads;
    wire [8:0] drive_cylinders=selected_b?b_cylinders:a_cylinders;
    wire address_valid;
    chs_to_lba #(.CLASSIC_GEOMETRY(1)) translate(c,h,r,drive_cylinders,drive_heads,drive_spt,
                         drive_start,drive_length,sd_lba,address_valid);
    assign sd_request=(state==READ_REQ||state==WRITE_REQ)&&address_valid&&n==2&&!sd_error;
    assign sd_write=state==WRITE_REQ;
    assign buffer_address=byte_index;
    assign buffer_write=(state==WRITE_DATA&&sd_ready&&bus_write&&bus_address==17)
                         ||(state==FORMAT_FILL&&sd_ready);
    assign buffer_data=state==FORMAT_FILL?fill:bus_data;
    always @* begin
        bus_result=8'hff;
        case(bus_address)
            0:bus_result=select_reg;
            16:case(state)
                READ_DATA:bus_result=8'hf0;
                WRITE_DATA:bus_result=sd_ready?8'hb0:8'h10;
                FORMAT_ID:bus_result=8'hb0;
                RESULT:bus_result=8'hd0;
                ARGS:bus_result=8'h90;
                COMMAND:bus_result=8'h80;
                default:bus_result=8'h10;
            endcase
            17:if(state==RESULT)bus_result=results[result_index];
               else if(state==READ_DATA)bus_result=buffer_result;
        endcase
    end
    task rw_result;
        input [7:0] st0,st1;
        begin
            results[0]<=st0|{5'b0,args[0][2:0]};results[1]<=st1;results[2]<=0;
            results[3]<=c;results[4]<=h;results[5]<=r;results[6]<=n;
            result_count<=7;result_index<=0;state<=RESULT;
        end
    endtask
    integer i;
    always @(posedge clk) begin
        if(reset)begin
            state<=COMMAND;select_reg<=1;command<=0;arg_index<=0;arg_count<=0;
            result_index<=0;result_count<=0;byte_index<=0;
            selected_b<=boot_b;reset_pending<=0;
            c<=0;h<=0;r<=1;n<=2;fill<=0;format_remaining<=0;format_index<=0;
            track_a<=0;track_b<=0;seek_status<=8'h20;seek_track<=0;formatting<=0;
            for(i=0;i<8;i=i+1)args[i]<=0;
            for(i=0;i<7;i=i+1)results[i]<=0;
        end else begin
            if(bus_write&&bus_address==0)begin
                select_reg<=bus_data;
                // A reset while SD is busy drains the outstanding request first.
                if(!bus_data[0])begin
                    reset_pending<=state==READ_WAIT||state==WRITE_WAIT;
                    if(state!=READ_WAIT&&state!=WRITE_WAIT)state<=COMMAND;
                end
            end
            if(bus_write&&bus_address==0&&!bus_data[0])begin end
            else if(!select_reg[0]&&!reset_pending)state<=COMMAND;
            else if(bus_write&&bus_address==0&&bus_data[1]&&!select_reg[1]&&state==READ_DATA)rw_result(0,0);
            else if(bus_write&&bus_address==0&&bus_data[1]&&!select_reg[1]&&state==WRITE_DATA)rw_result(8'h40,8'h10);
            else case(state)
                COMMAND:if(bus_write&&bus_address==17&&select_reg[0])begin
                    selected_b<=!select_reg[2]^boot_b;reset_pending<=0;
                    command<=bus_data;arg_index<=0;formatting<=0;
                    case(bus_data[4:0])
                        3:begin arg_count<=2;state<=ARGS;end
                        4,7,10:begin arg_count<=1;state<=ARGS;end
                        15:begin arg_count<=2;state<=ARGS;end
                        5,6:begin arg_count<=8;state<=ARGS;end
                        13:begin arg_count<=5;state<=ARGS;end
                        8:state<=EXECUTE;
                        default:begin results[0]<=8'h80;result_count<=1;result_index<=0;state<=RESULT;end
                    endcase
                end
                ARGS:if(bus_write&&bus_address==17)begin
                    args[arg_index]<=bus_data;arg_index<=arg_index+1'b1;
                    if(arg_index+1==arg_count)state<=EXECUTE;
                end
                EXECUTE:case(command[4:0])
                    3:state<=COMMAND;
                    4:begin
                        results[0]<=8'h20|args[0][2:0];result_count<=1;result_index<=0;state<=RESULT;
                    end
                    7,15:begin
                        if(!selected_b)track_a<=command[4:0]==7?0:args[1];
                        else track_b<=command[4:0]==7?0:args[1];
                        seek_status<=8'h20|{6'b0,args[0][1:0]};
                        seek_track<=command[4:0]==7?0:args[1];state<=COMMAND;
                    end
                    8:begin
                        results[0]<=seek_status;results[1]<=seek_track;
                        result_count<=2;result_index<=0;state<=RESULT;
                    end
                    10:begin
                        results[0]<=0;results[1]<=0;results[2]<=0;
                        results[3]<=selected_b?track_b:track_a;
                        results[4]<={7'b0,args[0][2]};results[5]<=1;results[6]<=2;
                        result_count<=7;result_index<=0;state<=RESULT;
                    end
                    5,6:begin
                        c<=args[1];h<=args[2];r<=args[3];n<=args[4];byte_index<=0;
                        state<=command[4:0]==6?READ_REQ:WRITE_DATA;
                    end
                    13:begin
                        n<=args[1];fill<=args[4];format_remaining<=args[2];
                        format_index<=0;formatting<=1;
                        if(args[1]!=2||args[2]==0)rw_result(8'h40,8'h04);
                        else state<=FORMAT_ID;
                    end
                    default:state<=COMMAND;
                endcase
                READ_REQ:if(!address_valid||n!=2)rw_result(8'h40,8'h04);
                    else if(sd_error)rw_result(8'h40,8'h20);
                    else if(sd_ready)state<=READ_WAIT;
                READ_WAIT:if(reset_pending&&(sd_done||sd_error))begin state<=COMMAND;reset_pending<=0;end
                    else if(sd_error)rw_result(8'h40,8'h20);
                    else if(sd_done)begin
                        if(select_reg[0])state<=READ_DATA;else state<=COMMAND;
                    end
                READ_DATA:if(bus_read&&bus_address==17)begin
                    if(byte_index==511)rw_result(0,0);
                    else byte_index<=byte_index+1'b1;
                end
                WRITE_DATA:if(!address_valid||n!=2)rw_result(8'h40,8'h04);
                    else if(sd_ready&&bus_write&&bus_address==17)begin
                        if(byte_index==511)state<=WRITE_REQ;
                        else byte_index<=byte_index+1'b1;
                    end
                WRITE_REQ:if(!address_valid||n!=2)rw_result(8'h40,8'h04);
                    else if(sd_error)rw_result(8'h40,8'h20);
                    else if(sd_ready)state<=WRITE_WAIT;
                WRITE_WAIT:if(reset_pending&&(sd_done||sd_error))begin state<=COMMAND;reset_pending<=0;end
                    else if(sd_error)rw_result(8'h40,8'h20);
                    else if(sd_done)begin
                        if(!select_reg[0])state<=COMMAND;
                        else if(formatting&&format_remaining>1)begin
                            format_remaining<=format_remaining-1'b1;format_index<=0;state<=FORMAT_ID;
                        end else rw_result(0,0);
                    end
                RESULT:if(bus_read&&bus_address==17)begin
                    if(result_index+1==result_count)state<=COMMAND;
                    else result_index<=result_index+1'b1;
                end
                FORMAT_ID:if(bus_write&&bus_address==17)begin
                    case(format_index)
                        0:c<=bus_data;1:h<=bus_data;2:r<=bus_data;3:n<=bus_data;
                    endcase
                    if(format_index==3)begin byte_index<=0;state<=FORMAT_FILL;end
                    else format_index<=format_index+1'b1;
                end
                FORMAT_FILL:if(sd_ready)begin
                    if(!address_valid||n!=2)rw_result(8'h40,8'h04);
                    else if(byte_index==511)state<=WRITE_REQ;
                    else byte_index<=byte_index+1'b1;
                end
            endcase
        end
    end
endmodule
