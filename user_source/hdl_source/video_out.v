


module video_out (
    input wire        I_rst_n,

    input wire        I_ddr_clk,
    output wire       O_video_out_rd_busy,  
    input wire        I_video_in_wr_busy,   
    input wire[1:0]   I_video_out_rp,
    input wire I_front_valid,output wire O_frame_release,
    output reg [31:0] O_underflow_frames,O_overflow_frames,
    input wire[11:0]   I_slot_modes,
    input wire[63:0]   I_slot_sequences,
    input wire[15:0]   I_capture_sequence,
    output wire[7:0]   O_frame_latency,
    output wire        O_frame_latency_valid,
    output reg[2:0]   O_frame_mode,
    output wire       O_ddr_user_rd_en,
    output reg[24:0]  O_ddr_user_addr,
    input wire        I_ddr_user_ready,
    input wire        I_ddr_user_rd_valid,
    input wire[127:0] I_ddr_user_rd_data,

    input wire        I_dsi_clk,
    input wire        I_video_vsync,
    input wire        I_video_rd_en,  
    output reg[23:0]  O_vdieo_data
);

    wire S_video_frame_start;
    localparam CROP_OFFSET = 25'd115392;  
    localparam ROW_SKIP = 25'd384;  
    reg [7:0] S_crop_word;
    reg [9:0] S_crop_row;
    reg [9:0] S_outstanding_reads;
    reg S_frame_pending;
    reg S_frame_ready;
    reg         S_fifo_rst;     
    wire S_flush_start = S_frame_pending && (S_outstanding_reads == 0) && !S_fifo_rst;
    assign O_frame_release=S_flush_start;
    wire S_fifo_full;
    reg overflow_seen;
    always @(posedge I_ddr_clk or negedge I_rst_n)
    if(!I_rst_n)begin O_overflow_frames<=0;overflow_seen<=0;end
    else if(S_video_frame_start)overflow_seen<=0;
    else if(I_ddr_user_rd_valid&&S_fifo_full&&!overflow_seen)begin
      O_overflow_frames<=O_overflow_frames+1'b1;overflow_seen<=1;
    end
    reg[7:0]    S_fifo_rst_cnt;
    wire[8:0]   S_fifo_wr_num;       
    wire        S_fifo_rd_en;        
    wire[127:0] S_fifo_rd_data;      
    reg         S_video_vsync_1d;
    reg         S_video_vsync_2d;
    reg         S_video_vsync_3d;
   
    wire        S_ddr_rd_trig;       
    reg         S_ddr_rd_valid;      
    reg[9:0]    S_ddr_rd_cnt;        
    reg[3:0]    S_fifo_rd_cnt;       
    reg         S_video_rd_en_1d;
    reg[3:0]    S_fifo_rd_cnt_1d;     
    reg[127:0]  S_fifo_rd_data_1d;    
	wire        S_fifo_emtpy;     



     
    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n) O_frame_mode<=0;
        else if(S_video_frame_start) O_frame_mode<=I_slot_modes[I_video_out_rp*3 +: 3];
    end

     
     
    wire S_frame_load=S_fifo_rst&&(S_fifo_rst_cnt==8'd10);
    frame_latency_meter u_frame_latency_meter(
        .I_clk(I_ddr_clk),.I_rst_n(I_rst_n),.I_sample(S_frame_load),.I_valid(I_front_valid),
        .I_capture_sequence(I_capture_sequence),
        .I_display_sequence(I_slot_sequences[I_video_out_rp*16 +: 16]),
        .O_valid(O_frame_latency_valid),.O_frame_latency(O_frame_latency));

    localparam IMAGE_BASE_ADDR_0 = 25'd0;
    localparam IMAGE_BASE_ADDR_1 = 25'd7000000;
    localparam IMAGE_BASE_ADDR_2 = 25'd14000000;
    localparam IMAGE_BASE_ADDR_3 = 25'd21000000;


    always @(posedge I_ddr_clk) begin
        S_video_vsync_1d <= I_video_vsync;
        S_video_vsync_2d <=S_video_vsync_1d;
        S_video_vsync_3d <= S_video_vsync_2d;
    end

    assign S_video_frame_start = ~S_video_vsync_3d & S_video_vsync_2d;


     
    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            S_outstanding_reads <= 0;
            S_frame_pending <= 0;
            S_frame_ready <= 0;
            S_fifo_rst <= 0;
            S_fifo_rst_cnt <= 0;
        end else begin
            case ({O_ddr_user_rd_en, I_ddr_user_rd_valid})
                2'b10: S_outstanding_reads <= S_outstanding_reads + 1'b1;
                2'b01: S_outstanding_reads <= S_outstanding_reads - 1'b1;
                default: S_outstanding_reads <= S_outstanding_reads;
            endcase
            if (S_video_frame_start) begin
                S_frame_pending <= 1;
                S_frame_ready <= 0;
            end
            if (S_flush_start) begin
                S_fifo_rst <= 1;
                S_fifo_rst_cnt <= 0;
                S_frame_pending <= 0;
            end else if (S_fifo_rst) begin
                if (S_fifo_rst_cnt == 8'd10) begin
                    S_fifo_rst <= 0;
                    S_frame_ready <= I_front_valid;
                end else S_fifo_rst_cnt <= S_fifo_rst_cnt + 1'b1;
            end
        end
    end

    



    assign S_ddr_rd_trig = (({2'd0,S_fifo_wr_num}+{1'b0,S_outstanding_reads}) <= 11'd304) && (!I_video_in_wr_busy) && (!S_ddr_rd_valid) && (!S_fifo_rst) && I_rst_n && S_frame_ready && !S_video_frame_start && (S_crop_row < 600) ? 1'b1 : 1'b0;

    


    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            S_ddr_rd_valid <= 1'b0;
        else
			if(S_video_frame_start || S_frame_pending || (O_ddr_user_rd_en && S_ddr_rd_cnt == 'd191))
                S_ddr_rd_valid <= 1'b0;
            else if(S_ddr_rd_trig)
                S_ddr_rd_valid <= 1'b1;
            else
                S_ddr_rd_valid <= S_ddr_rd_valid;
    end

    assign O_ddr_user_rd_en = S_ddr_rd_valid & I_ddr_user_ready & S_frame_ready & ~S_video_frame_start;

    always @(posedge I_ddr_clk) begin
        if(S_ddr_rd_valid && !S_video_frame_start)
            begin
                if(O_ddr_user_rd_en)
                    S_ddr_rd_cnt <= S_ddr_rd_cnt + 'd1;
                else
                    S_ddr_rd_cnt <= S_ddr_rd_cnt;
            end
        else    
            S_ddr_rd_cnt <= 'd0;
    end


    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            O_ddr_user_addr <= 'd0;
        else
            if(S_fifo_rst&&S_fifo_rst_cnt==8'd10)
                begin
                    case(I_video_out_rp)
                        'd0: O_ddr_user_addr <= IMAGE_BASE_ADDR_0 + CROP_OFFSET;
                        'd1: O_ddr_user_addr <= IMAGE_BASE_ADDR_1 + CROP_OFFSET;
                        'd2: O_ddr_user_addr <= IMAGE_BASE_ADDR_2 + CROP_OFFSET;
                        'd3: O_ddr_user_addr <= IMAGE_BASE_ADDR_3 + CROP_OFFSET;
                    endcase
                end
            else if(O_ddr_user_rd_en)
                O_ddr_user_addr <= O_ddr_user_addr + 25'd8 +
                                   ((S_crop_word == 191) ? ROW_SKIP : 25'd0);
            else    
                O_ddr_user_addr <= O_ddr_user_addr;
    end

    
    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin S_crop_word <= 0; S_crop_row <= 0; end
        else if (S_video_frame_start) begin S_crop_word <= 0; S_crop_row <= 0; end
        else if (O_ddr_user_rd_en) begin
            if (S_crop_word == 191) begin
                S_crop_word <= 0;
                S_crop_row <= S_crop_row + 1'b1;
            end else S_crop_word <= S_crop_word + 1'b1;
        end
    end

    assign O_video_out_rd_busy = S_ddr_rd_trig | S_ddr_rd_valid;


    w128_d512_fifo U_w128_d512_fifo(
        .rst        ( S_fifo_rst | !I_rst_n ),   

        .clkw       ( I_ddr_clk           ),     
        .we         ( I_ddr_user_rd_valid && !S_fifo_full && !S_fifo_rst ),
        .di         ( I_ddr_user_rd_data  ),
        .wrusedw    ( S_fifo_wr_num       ),
        .afull      (),
        .full_flag  (S_fifo_full),
 
        .clkr       ( I_dsi_clk           ),
        .re         ( S_fifo_rd_en        ), 
        .dout       ( S_fifo_rd_data      ),  
        .rdusedw    (), 
        .valid      (),  
        .empty_flag ( S_fifo_emtpy        ),
        .aempty     ()
    );


   always @(posedge I_dsi_clk) begin
       if(!I_rst_n)S_fifo_rd_cnt<=0;
       else if(I_video_rd_en)
           S_fifo_rd_cnt <= S_fifo_rd_cnt + 'd1;
       else
           S_fifo_rd_cnt <= 'd0;
   end

   wire need_word=I_video_rd_en&&(S_fifo_rd_cnt==0||S_fifo_rd_cnt==5||S_fifo_rd_cnt==10);
   (* async_reg="true" *) reg [1:0] front_sync;
   reg vs_d,underflow,read_fault_d;
   reg [23:0] last_good;
   wire miss=need_word&&S_fifo_emtpy&&front_sync[1];
   always @(posedge I_dsi_clk or negedge I_rst_n)
   if(!I_rst_n)begin front_sync<=0;vs_d<=0;underflow<=0;O_underflow_frames<=0;read_fault_d<=0;end
   else begin
     front_sync<={front_sync[0],I_front_valid};vs_d<=I_video_vsync;
     read_fault_d<=underflow||miss||!front_sync[1];
     if(I_video_vsync&&!vs_d)underflow<=0;
     else if(miss&&!underflow)begin underflow<=1;O_underflow_frames<=O_underflow_frames+1'b1;end
   end
   assign S_fifo_rd_en=need_word&&!S_fifo_emtpy&&!underflow&&front_sync[1];

   always @(posedge I_dsi_clk) begin
       S_video_rd_en_1d  <= I_video_rd_en;
       S_fifo_rd_cnt_1d  <= S_fifo_rd_cnt;
       S_fifo_rd_data_1d <= S_fifo_rd_data;
   end

   always @(posedge I_dsi_clk) begin
       if(!I_rst_n)begin O_vdieo_data<=0;last_good<=0;end
       else if(S_video_rd_en_1d&&read_fault_d)O_vdieo_data<=last_good;
       else if(S_video_rd_en_1d)
           begin
               last_good<=O_vdieo_data;
               case(S_fifo_rd_cnt_1d)
                   'd0: O_vdieo_data  <= S_fifo_rd_data[127:104];
                   'd1: O_vdieo_data  <= S_fifo_rd_data[103:80];
                   'd2: O_vdieo_data  <= S_fifo_rd_data[79:56];
                   'd3: O_vdieo_data  <= S_fifo_rd_data[55:32];
                   'd4: O_vdieo_data  <= S_fifo_rd_data[31:8];
                   'd5: O_vdieo_data  <= {S_fifo_rd_data_1d[7:0],S_fifo_rd_data[127:112]};
                   'd6: O_vdieo_data  <= S_fifo_rd_data[111:88];
                   'd7: O_vdieo_data  <= S_fifo_rd_data[87:64];
                   'd8: O_vdieo_data  <= S_fifo_rd_data[63:40];
                   'd9: O_vdieo_data  <= S_fifo_rd_data[39:16];
                   'd10: O_vdieo_data <= {S_fifo_rd_data_1d[15:0],S_fifo_rd_data[127:120]};
                   'd11: O_vdieo_data <= S_fifo_rd_data[119:96];
                   'd12: O_vdieo_data <= S_fifo_rd_data[95:72];
                   'd13: O_vdieo_data <= S_fifo_rd_data[71:48];
                   'd14: O_vdieo_data <= S_fifo_rd_data[47:24];
                   'd15: O_vdieo_data <= S_fifo_rd_data[23:0];
               endcase
           end
       else
           O_vdieo_data <= 'd0;
   end

    
endmodule
