

module design_top_wrapper #(
    parameter DISPLAY_TEST_PATTERN = 0, // 0: camera; 1: vendor generated test pattern
    parameter TOUCH_AUTO_SWAP = 1,
    parameter TOUCH_INVERT_X = 0,
    parameter TOUCH_INVERT_Y = 0
) (
    input wire        I_sys_clk,
    input wire        I_rst_n,
      
    output wire       O_cam_scl,
    inout  wire       IO_cam_sda,
    output wire       O_cam_24m,
    output wire       O_cam_rst,
      
    inout wire [1:0]  I_button,

    output wire       O_screen_pwm,
    output wire       O_screen_reset_n,
    inout wire        IO_touch_scl,
    inout wire        IO_touch_sda,
    inout wire        IO_touch_int,

    inout wire        IO_tx_clk_pad_n,
    inout wire        IO_tx_clk_pad_p,
    inout wire[3:0]   IO_tx_data_pad_n,
    inout wire[3:0]   IO_tx_data_pad_p,

    inout wire        IO_rx_clk_pad_n, 
    inout wire        IO_rx_clk_pad_p, 
    inout wire[3:0]   IO_rx_data_pad_n,
    inout wire[3:0]   IO_rx_data_pad_p,

    output wire[12:0] ddr_addr,
    output wire[ 1:0] ddr_ba,
    output wire[ 0:0] ddr_cke,
    output wire[ 0:0] ddr_odt,
    output wire[ 0:0] ddr_cs_n,
    output wire       ddr_ras_n,
    output wire       ddr_cas_n,
    output wire       ddr_we_n,
    output wire[ 0:0] ddr_ck_p,
    output wire[ 0:0] ddr_ck_n,
    inout wire[1:0]   ddr_dm,
    inout wire[15:0]  ddr_dq,
    inout wire[1:0]   ddr_dqs_p,
    inout wire[1:0]   ddr_dqs_n   
);


    wire        	S_100m_clk;
    wire        	S_24m_clk;
    wire        	S_dpll_ref_clk;
	wire        	S_10m_clk;
		
	wire        	S_pll_lock;
    wire        	S_rst_n;
	
	wire [15:0] 	S_ae;
    wire [15:0] 	S_ag;
    wire 			S_cam_cfg_done;
    wire 			S_ae_cfg_done;
    wire 			S_ae_req; 
	
	wire        	S_csi_rx_clk;  
    wire        	S_hs_rx_valid;  
    wire[15:0]  	S_hs_rx_data;   
	wire[1:0]   	S_lane_error;
	
	wire        	S_csi_frame_start;       
	wire        	S_csi_frame_end;         
	wire        	S_csi_valid;             
	wire[31:0]  	S_csi_data;  
		
	wire        	S_raw10_frame_start; 
	wire        	S_raw10_frame_end;   
	wire        	S_raw10_valid;       
	wire [39:0] 	S_raw10_data;
		
	wire 			S_axis_tlast;  
	wire 			S_axis_tuser;  
	wire [39:0]		S_axis_tdata;  
	wire 			S_axis_tvalid; 
	
	wire [39:0]		S_raw_tdata ;
	wire			S_raw_tlast ;
	wire 			S_raw_tvalid;
	wire 			S_raw_tuser ;
	
	wire			S_ISP_O_tready;
	wire [127:0]	S_ISP_O_tdata ;
	wire 			S_ISP_O_tlast ;
	wire 			S_ISP_O_tuser ;
	wire 			S_ISP_O_tvalid; 
	

    wire        S_ddr_clk;
    wire        S_dsi_tx_clk;
    wire        S_display_rst_n;
    wire        S_video_out_rst_n;


    wire        S_vi_128b_frame_start;
    wire        S_vi_128b_valid;      
    wire[127:0] S_vi_128b_data;    
    
    wire        S_video_out_rd_busy;
    wire        S_video_in_wr_busy; 
    wire[1:0]   S_video_out_rp;     

    wire        S_ddr_user_wr_en;       
    wire        S_ddr_user_rd_en;       
    wire[24:0]  S_ddr_user_addr;        
    wire[127:0] S_ddr_user_wr_data;     
    wire        S_ddr_user_ready;       
    wire        S_ddr_user_rd_valid;    
    wire[127:0] S_ddr_user_rd_data;     

    wire        S_vi_ddr_wr_en;   
    wire[24:0]  S_vi_ddr_wr_addr; 
    wire[127:0] S_vi_ddr_wr_data;
    wire        S_vi_ddr_wr_ready;

    wire        S_vo_ddr_rd_en;   
    wire[24:0]  S_vo_ddr_rd_addr; 
    wire        S_vo_ddr_rd_ready;
    wire        S_vo_dbg_fifo_rst;
    wire        S_vo_dbg_ddr_rd_valid;
    wire        S_vo_dbg_fifo_rd_en;
    wire        S_vo_dbg_fifo_empty;

    wire        S_init_calib_complete; 
    wire[24:0]  S_mc_app_addr;          
    wire[2:0]   S_mc_app_cmd;           
    wire        S_mc_app_en;            
    wire[127:0] S_mc_app_wdf_data;      
    wire        S_mc_app_wdf_end;       
    wire[15:0]  S_mc_app_wdf_mask;      
    wire        S_mc_app_wdf_wren;      
    wire[127:0] S_mc_app_rd_data;       
    wire        S_mc_app_rd_data_end;   
    wire        S_mc_app_rd_data_valid; 
    wire        S_mc_app_rdy;           
    wire        S_mc_app_wdf_rdy;       
    wire        S_mc_dbg_fifo_afull;
    wire        S_mc_dbg_app_rdy;
    wire        S_mc_dbg_wdf_rdy;
    wire        S_mc_dbg_cmd_pop;

    wire        S_vs_vsync;
    wire        S_vs_hsync;
    wire        S_vs_de;
    wire        S_hdmi_user;
    wire        S_hdmi_last;
    wire        S_video_out_vsync;
    wire        S_crop_rd_en;
    wire        S_hdmi_out_vsync;
    wire        S_hdmi_out_hsync;
    wire        S_hdmi_out_de;
    wire[23:0]  S_hdmi_out_data;

    wire[23:0]  S_video_rd_data;
    reg         S_dbg_raw_seen;
    reg         S_dbg_isp_seen;
    reg         S_dbg_ddr_wr_seen;
    reg         S_dbg_ddr_rd_seen;
    reg         S_dbg_cam_cfg_seen;
    reg         S_dbg_hs_seen;
    reg         S_dbg_csi_seen;
    reg         S_dbg_raw10_seen;
    reg         S_dbg_isp_fs_seen;
    reg         S_dbg_isp_valid_seen;
    reg         S_dbg_ddr_req_seen;
    reg         S_dbg_ddr_ready_seen;
    reg [1:0]   S_dbg_raw_seen_sync;
    reg [1:0]   S_dbg_isp_seen_sync;
    reg [1:0]   S_dbg_ddr_wr_seen_sync;
    reg [1:0]   S_dbg_ddr_rd_seen_sync;
    reg [1:0]   S_dbg_cam_cfg_seen_sync;
    reg [1:0]   S_dbg_hs_seen_sync;
    reg [1:0]   S_dbg_csi_seen_sync;
    reg [1:0]   S_dbg_raw10_seen_sync;
    reg [1:0]   S_dbg_isp_fs_seen_sync;
    reg [1:0]   S_dbg_isp_valid_seen_sync;
    reg [1:0]   S_dbg_ddr_req_seen_sync;
    reg [1:0]   S_dbg_ddr_ready_seen_sync;
    reg         S_dbg_video_nonzero_seen;
    reg         S_dbg_rd_req_seen;
    reg         S_dbg_rd_valid_seen;
    reg         S_dbg_rd_nonzero_seen;
    reg [1:0]   S_dbg_rd_req_seen_sync;
    reg [1:0]   S_dbg_rd_valid_seen_sync;
    reg [1:0]   S_dbg_rd_nonzero_seen_sync;
    reg         S_dbg_mc_init_seen;
    reg         S_dbg_mc_app_rdy_seen;
    reg         S_dbg_mc_wdf_rdy_seen;
    reg         S_dbg_mc_cmd_pop_seen;
    reg [1:0]   S_dbg_mc_init_seen_sync;
    reg [1:0]   S_dbg_mc_app_rdy_seen_sync;
    reg [1:0]   S_dbg_mc_wdf_rdy_seen_sync;
    reg [1:0]   S_dbg_mc_cmd_pop_seen_sync;
    // 720p input-format diagnostics.  One RAW10 line from the factory
    // 1280-pixel mode contains 1600 bytes, i.e. 400 valid 32-bit CSI words.
    reg         S_dbg_hs_valid_d;
    reg [10:0]  S_dbg_csi_words;
    reg [10:0]  S_dbg_good_lines;
    reg         S_dbg_frame_seen_once;
    reg         S_dbg_frame_repeat_seen;
    reg         S_dbg_width_1280_seen;
    reg         S_dbg_height_720_seen;
    reg         S_dbg_isp_frame_seen_once;
    reg         S_dbg_isp_frame_repeat_seen;
    reg [1:0]   S_dbg_frame_repeat_sync;
    reg [1:0]   S_dbg_width_1280_sync;
    reg [1:0]   S_dbg_height_720_sync;
    reg [1:0]   S_dbg_isp_frame_repeat_sync;
    wire[3:0]   S_vs_debug_status;
    wire        S_lane_error_any;



    wire S_lp_config_done;
    wire S_mipi_tx_dpll_locked;
    wire S_lp_tx_p, S_lp_tx_n;
    wire S_32b_vsync, S_32b_hsync, S_32b_de;
    wire [31:0] S_32b_data;
    wire S_hs_tx_valid, S_hs_tx_last, S_hs_tx_ready;
    wire [31:0] S_hs_tx_data;
    wire S_base_vsync, S_base_hsync, S_base_de;
    wire [23:0] S_base_data;
    wire S_mixer_vsync, S_mixer_hsync, S_mixer_de;
    wire [23:0] S_mixer_data;
    wire [23:0] S_vs_data;
    reg [31:0] S_delay_cnt;
    wire S_lp_config_start;

    // Vendor reference uses an always-powered 3.3 V panel, released reset,
    // continuous backlight enable, and a 10 ms settling time at 10 MHz.
    // No panel-specific reset pulse duration is supplied; do not invent one.
    // FFC pin 33 is TP-RES on this screen assembly; it is NOT LCD RESX.
    // Standalone white balance UI; no image-style mode selector remains.
    wire S_touch_online,S_pointer_report,S_ui_report;
    wire [3:0] S_pointer_contacts,S_ui_contacts;
    wire [15:0] S_touch_errors,S_pointer_x,S_pointer_y,S_touch_width,S_touch_height;
    wire [9:0] S_ui_x,S_ui_y;
    wire [3:0] S_ui_page;
    wire [2:0] S_image_mode,S_image_mode_camera,S_isp_frame_mode,S_ddr_frame_mode;
    wire [11:0] S_slot_modes;
    wire [1:0] S_wb_mode;
    wire [6:0] S_wb_index,S_ui_gain,S_gain_camera;
    wire [18:0] S_wb_camera;
    wire signed [4:0] S_wb_ab,S_wb_gm;
    wire [36:0] S_wb_telemetry,S_wb_telemetry_display;
    wire [51:0] S_ui_display;
    wire [63:0] S_slot_sequences;
    wire [15:0] S_capture_sequence;
    wire [7:0] S_frame_latency;
    wire S_frame_latency_valid;
    wire [31:0] S_read_underflow_count,S_read_overflow_count;
    wire [8:0] S_latency_display;
    wire [23:0] S_diagnostics_display;
    wire [7:0] S_underflow_display;
    wire S_hist_enable,S_hist_auto;wire [6:0] S_hist_strength;wire [8:0] S_hist_config;
    wire S_hist_we,S_hist_publish,S_hist_ready,S_hist_valid,S_hist_frame_start;
    wire [5:0] S_hist_addr,S_hist_read_addr;wire [7:0] S_hist_height,S_hist_read_height;
    wire S_ae_enable,S_show_meter;wire [1:0] S_meter_mode,S_meter_camera;wire [9:0] S_sensor_config;wire [6:0] S_applied_gain_ui;
    wire [7:0] S_ae_stats,S_ae_stats_camera;
    wire [2:0] S_ae_status;wire [9:0] S_ae_display;
    config_mailbox #(.WIDTH(2),.RESET_VALUE(2'd1)) u_meter_config(
      .I_src_clk(I_sys_clk),.I_dst_clk(S_csi_rx_clk),.I_rst_n(S_rst_n),
      .I_data(S_meter_mode),.O_data(S_meter_camera));
    config_mailbox #(.WIDTH(7),.RESET_VALUE(7'd80)) u_gain_feedback(
      .I_src_clk(S_24m_clk),.I_dst_clk(I_sys_clk),.I_rst_n(S_rst_n),
      .I_data(S_ag[6:0]),.O_data(S_applied_gain_ui));
    config_mailbox #(.WIDTH(8),.RESET_VALUE(8'd64)) u_ae_statistics(
      .I_src_clk(S_csi_rx_clk),.I_dst_clk(S_24m_clk),.I_rst_n(S_rst_n),
      .I_data(S_ae_stats),.O_data(S_ae_stats_camera));
    config_mailbox #(.WIDTH(9),.RESET_VALUE(9'd178)) u_hist_config(
      .I_src_clk(I_sys_clk),.I_dst_clk(S_24m_clk),.I_rst_n(S_rst_n),
      .I_data({S_hist_enable,S_hist_auto,S_hist_strength}),.O_data(S_hist_config));
    config_mailbox #(.WIDTH(10),.RESET_VALUE(10'd80)) u_ae_telemetry(
      .I_src_clk(S_24m_clk),.I_dst_clk(S_dsi_tx_clk),.I_rst_n(S_rst_n),
      .I_data({S_ae_status,S_ag[6:0]}),.O_data(S_ae_display));
    wire S_detect_enable,S_tag_enable,S_wb_key_axis,S_ui_bars_hide;
    wire S_touch_reset_n;
    display_reset_sync u_touch_reset (
        .I_clk(I_sys_clk),.I_async_reset_n(I_rst_n),.O_reset_n(S_touch_reset_n));
    gt911_pointer u_touch (
        .I_clk(I_sys_clk),.I_rst_n(S_touch_reset_n),
        .IO_scl(IO_touch_scl),.IO_sda(IO_touch_sda),.IO_int(IO_touch_int),
        .O_reset_n(O_screen_reset_n),.O_online(S_touch_online),.O_report(S_pointer_report),
        .O_contacts(S_pointer_contacts),.O_x(S_pointer_x),.O_y(S_pointer_y),
        .O_width(S_touch_width),.O_height(S_touch_height),.O_errors(S_touch_errors));
    touch_coord_map #(.AUTO_SWAP(TOUCH_AUTO_SWAP),.INVERT_X(TOUCH_INVERT_X),.INVERT_Y(TOUCH_INVERT_Y)) u_touch_map (
        .I_clk(I_sys_clk),.I_rst_n(S_touch_reset_n),.I_report(S_pointer_report),.I_contacts(S_pointer_contacts),
        .I_x(S_pointer_x),.I_y(S_pointer_y),.I_width(S_touch_width),.I_height(S_touch_height),
        .O_report(S_ui_report),.O_contacts(S_ui_contacts),.O_x(S_ui_x),.O_y(S_ui_y));
    wb_ui_control u_ui_control (
        .I_clk(I_sys_clk),.I_rst_n(S_touch_reset_n),.I_online(S_touch_online),
        .I_report(S_ui_report),.I_contacts(S_ui_contacts),.I_x(S_ui_x),.I_y(S_ui_y),.I_buttons_n(I_button),
        .I_applied_gain(S_applied_gain_ui),.O_hist_enable(S_hist_enable),.O_hist_auto(S_hist_auto),.O_hist_strength(S_hist_strength),.O_meter_mode(S_meter_mode),.O_show_meter(S_show_meter),.O_ae_enable(S_ae_enable),.O_page(S_ui_page),.O_mode(S_wb_mode),
        .O_index(S_wb_index),.O_gain(S_ui_gain),.O_detect_enable(S_detect_enable),
        .O_tag_enable(S_tag_enable),.O_image_mode(S_image_mode),
        .O_ab(S_wb_ab),.O_gm(S_wb_gm),.O_key_axis(S_wb_key_axis),.O_bars_hide(S_ui_bars_hide));
    config_mailbox #(.WIDTH(19),.RESET_VALUE(19'd30)) u_wb_config (
        .I_src_clk(I_sys_clk),.I_dst_clk(S_csi_rx_clk),.I_rst_n(S_rst_n),
        .I_data({S_wb_ab,S_wb_gm,S_wb_mode,S_wb_index}),.O_data(S_wb_camera));
    config_mailbox #(.WIDTH(10),.RESET_VALUE({2'd1,1'b1,7'd80})) u_gain_config (
        .I_src_clk(I_sys_clk),.I_dst_clk(S_24m_clk),.I_rst_n(S_rst_n),
        .I_data({S_meter_mode,S_ae_enable,S_ui_gain}),.O_data(S_sensor_config));
    assign S_gain_camera=S_sensor_config[6:0];
    config_mailbox #(.WIDTH(3),.RESET_VALUE(3'd0)) u_image_config (
        .I_src_clk(I_sys_clk),.I_dst_clk(S_csi_rx_clk),.I_rst_n(S_rst_n),
        .I_data(S_image_mode),.O_data(S_image_mode_camera));
    config_mailbox #(.WIDTH(52),.RESET_VALUE({7'd50,1'b1,1'b0,1'b0,2'd1,1'b1,1'b0,5'd0,5'd0,1'b0,1'b0,4'd0,2'd0,2'd0,7'd30,7'd80,3'd0,1'b0})) u_ui_config (
        .I_src_clk(I_sys_clk),.I_dst_clk(S_dsi_tx_clk),.I_rst_n(S_rst_n),
        .I_data({S_hist_strength,S_hist_auto,S_hist_enable,S_show_meter,S_meter_mode,S_ae_enable,S_wb_key_axis,S_wb_ab,S_wb_gm,S_detect_enable,S_tag_enable,
                 S_ui_page,S_wb_mode,1'b0,S_ui_bars_hide,S_wb_index,S_ui_gain,
                 S_image_mode,S_touch_online}),.O_data(S_ui_display));
    config_mailbox #(.WIDTH(37),.RESET_VALUE({1'b0,12'd1024,12'd1024,12'd1024})) u_wb_telemetry (
        .I_src_clk(S_csi_rx_clk),.I_dst_clk(S_dsi_tx_clk),.I_rst_n(S_rst_n),
        .I_data(S_wb_telemetry),.O_data(S_wb_telemetry_display));
    // One coherent DDR-to-display mailbox for age, peak, drops and read overflow.
    diagnostic_telemetry u_diagnostic_telemetry(
        .I_ddr_clk(S_ddr_clk),.I_display_clk(S_dsi_tx_clk),.I_rst_n(S_rst_n),
        .I_age_valid(S_frame_latency_valid),.I_age(S_frame_latency),
        .I_dropped_frames(S_drop_count),.I_read_overflow_frames(S_read_overflow_count),
        .I_display_underflow_frames(S_read_underflow_count),
        .O_latency(S_latency_display),.O_diagnostics(S_diagnostics_display),
        .O_underflow(S_underflow_display));
    always @(posedge S_10m_clk or negedge S_lp_reset_n) begin
        if (!S_lp_reset_n) S_delay_cnt <= 32'd0;
        else if (S_delay_cnt < 32'd10000000) S_delay_cnt <= S_delay_cnt + 1'b1;
    end
    assign S_lp_config_start = (S_delay_cnt >= 32'd100000);

    // Blank backlight until initialization and ten-frame settling complete.
    // At ~61 Hz, 200 ms exceeds the ten-VSYNC interval in JD9165BA Fig.5.1.
    reg [1:0] S_init_done_lp;
    reg [21:0] S_backlight_delay;
    always @(posedge S_10m_clk or negedge S_lp_reset_n) begin
        if (!S_lp_reset_n) begin
            S_init_done_lp <= 0;
            S_backlight_delay <= 0;
        end else begin
            S_init_done_lp <= {S_init_done_lp[0], S_lp_config_done};
            if (!S_init_done_lp[1]) S_backlight_delay <= 0;
            else if (S_backlight_delay < 22'd2000000)
                S_backlight_delay <= S_backlight_delay + 1'b1;
        end
    end
    assign O_screen_pwm = (S_backlight_delay == 22'd2000000);
    assign S_video_out_vsync = S_vs_vsync; // vendor DSI VS is active high
	
	
    assign S_rst_n 		= S_pll_lock;
    wire S_display_async_n = S_rst_n & S_mipi_tx_dpll_locked & S_lp_config_done;
    wire S_lp_async_n = S_rst_n & S_mipi_tx_dpll_locked;
    wire S_lp_reset_n, S_dsi_ready_n;
    display_reset_sync u_read_reset (.I_clk(S_ddr_clk), .I_async_reset_n(S_display_async_n), .O_reset_n(S_display_rst_n));
    display_reset_sync u_dsi_reset (.I_clk(S_dsi_tx_clk), .I_async_reset_n(S_display_async_n), .O_reset_n(S_dsi_ready_n));
    display_reset_sync u_lp_reset (.I_clk(S_10m_clk), .I_async_reset_n(S_lp_async_n), .O_reset_n(S_lp_reset_n));

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_raw_seen <= 1'b0;
        else if(S_raw10_frame_start | S_axis_tvalid)
            S_dbg_raw_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_seen <= 1'b0;
        else if(S_ISP_O_tuser | S_ISP_O_tvalid)
            S_dbg_isp_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_wr_seen <= 1'b0;
        else if(S_vi_ddr_wr_en)
            S_dbg_ddr_wr_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_rd_seen <= 1'b0;
        else if(S_ddr_user_rd_valid)
            S_dbg_ddr_rd_seen <= 1'b1;
    end

    always @(posedge S_24m_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_cam_cfg_seen <= 1'b0;
        else if(S_cam_cfg_done)
            S_dbg_cam_cfg_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_hs_seen <= 1'b0;
        else if(S_hs_rx_valid)
            S_dbg_hs_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_csi_seen <= 1'b0;
        else if(S_csi_frame_start | S_csi_valid)
            S_dbg_csi_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_raw10_seen <= 1'b0;
        else if(S_raw10_frame_start | S_raw10_valid)
            S_dbg_raw10_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_fs_seen <= 1'b0;
        else if(S_ISP_O_tuser)
            S_dbg_isp_fs_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_valid_seen <= 1'b0;
        else if(S_ISP_O_tvalid)
            S_dbg_isp_valid_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_req_seen <= 1'b0;
        else if(S_vi_ddr_wr_en)
            S_dbg_ddr_req_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_ready_seen <= 1'b0;
        else if(S_ddr_user_ready)
            S_dbg_ddr_ready_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_req_seen <= 1'b0;
        else if(S_vo_ddr_rd_en)
            S_dbg_rd_req_seen <= 1'b1;
    end

    // Count CSI payload words between HS packet boundaries.  This avoids
    // probing an internal net of csi_unpacket_2lane (which ChipWatcher cannot
    // legally connect to) and verifies the received line length externally.
    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin
            S_dbg_hs_valid_d          <= 1'b0;
            S_dbg_csi_words           <= 11'd0;
            S_dbg_good_lines          <= 11'd0;
            S_dbg_frame_seen_once     <= 1'b0;
            S_dbg_frame_repeat_seen   <= 1'b0;
            S_dbg_width_1280_seen     <= 1'b0;
            S_dbg_height_720_seen     <= 1'b0;
            S_dbg_isp_frame_seen_once <= 1'b0;
            S_dbg_isp_frame_repeat_seen <= 1'b0;
        end
        else begin
            S_dbg_hs_valid_d <= S_hs_rx_valid;

            if(!S_dbg_hs_valid_d && S_hs_rx_valid)
                S_dbg_csi_words <= 11'd0;
            else if(S_csi_valid)
                S_dbg_csi_words <= S_dbg_csi_words + 11'd1;

            // A packet with CSI payload is an image line.  Ignore short
            // frame-start/frame-end packets, whose payload count is zero.
            if(S_dbg_hs_valid_d && !S_hs_rx_valid && (S_dbg_csi_words != 0)) begin
                if(S_dbg_csi_words == 11'd400) begin
                    S_dbg_width_1280_seen <= 1'b1;
                    S_dbg_good_lines <= S_dbg_good_lines + 11'd1;
                end
            end

            if(S_csi_frame_start) begin
                if(S_dbg_frame_seen_once) begin
                    S_dbg_frame_repeat_seen <= 1'b1;
                    if(S_dbg_good_lines == 11'd720)
                        S_dbg_height_720_seen <= 1'b1;
                end
                else
                    S_dbg_frame_seen_once <= 1'b1;
                S_dbg_good_lines <= 11'd0;
            end

            if(S_ISP_O_tuser) begin
                if(S_dbg_isp_frame_seen_once)
                    S_dbg_isp_frame_repeat_seen <= 1'b1;
                else
                    S_dbg_isp_frame_seen_once <= 1'b1;
            end
        end
    end

    always @(posedge S_ddr_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_valid_seen <= 1'b0;
        else if(S_ddr_user_rd_valid)
            S_dbg_rd_valid_seen <= 1'b1;
    end

    always @(posedge S_dsi_tx_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_nonzero_seen <= 1'b0;
        else if(S_crop_rd_en && (S_video_rd_data != 24'd0))
            S_dbg_rd_nonzero_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_init_seen <= 1'b0;
        else if(S_init_calib_complete)
            S_dbg_mc_init_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_app_rdy_seen <= 1'b0;
        else if(S_mc_dbg_app_rdy)
            S_dbg_mc_app_rdy_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_wdf_rdy_seen <= 1'b0;
        else if(S_mc_dbg_wdf_rdy)
            S_dbg_mc_wdf_rdy_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_cmd_pop_seen <= 1'b0;
        else if(S_mc_dbg_cmd_pop)
            S_dbg_mc_cmd_pop_seen <= 1'b1;
    end

    always @(posedge S_dsi_tx_clk or negedge S_display_rst_n) begin
        if(!S_display_rst_n) begin
            S_dbg_cam_cfg_seen_sync <= 2'b00;
            S_dbg_hs_seen_sync      <= 2'b00;
            S_dbg_csi_seen_sync     <= 2'b00;
            S_dbg_raw10_seen_sync   <= 2'b00;
            S_dbg_raw_seen_sync    <= 2'b00;
            S_dbg_isp_seen_sync    <= 2'b00;
            S_dbg_ddr_wr_seen_sync <= 2'b00;
            S_dbg_ddr_rd_seen_sync <= 2'b00;
            S_dbg_isp_fs_seen_sync  <= 2'b00;
            S_dbg_isp_valid_seen_sync <= 2'b00;
            S_dbg_ddr_req_seen_sync <= 2'b00;
            S_dbg_ddr_ready_seen_sync <= 2'b00;
            S_dbg_video_nonzero_seen <= 1'b0;
            S_dbg_rd_req_seen_sync <= 2'b00;
            S_dbg_rd_valid_seen_sync <= 2'b00;
            S_dbg_rd_nonzero_seen_sync <= 2'b00;
            S_dbg_mc_init_seen_sync <= 2'b00;
            S_dbg_mc_app_rdy_seen_sync <= 2'b00;
            S_dbg_mc_wdf_rdy_seen_sync <= 2'b00;
            S_dbg_mc_cmd_pop_seen_sync <= 2'b00;
            S_dbg_frame_repeat_sync <= 2'b00;
            S_dbg_width_1280_sync <= 2'b00;
            S_dbg_height_720_sync <= 2'b00;
            S_dbg_isp_frame_repeat_sync <= 2'b00;
        end
        else begin
            S_dbg_cam_cfg_seen_sync <= {S_dbg_cam_cfg_seen_sync[0], S_dbg_cam_cfg_seen};
            S_dbg_hs_seen_sync      <= {S_dbg_hs_seen_sync[0],      S_dbg_hs_seen};
            S_dbg_csi_seen_sync     <= {S_dbg_csi_seen_sync[0],     S_dbg_csi_seen};
            S_dbg_raw10_seen_sync   <= {S_dbg_raw10_seen_sync[0],   S_dbg_raw10_seen};
            S_dbg_raw_seen_sync    <= {S_dbg_raw_seen_sync[0],    S_dbg_raw_seen};
            S_dbg_isp_seen_sync    <= {S_dbg_isp_seen_sync[0],    S_dbg_isp_seen};
            S_dbg_ddr_wr_seen_sync <= {S_dbg_ddr_wr_seen_sync[0], S_dbg_ddr_wr_seen};
            S_dbg_ddr_rd_seen_sync <= {S_dbg_ddr_rd_seen_sync[0], S_dbg_ddr_rd_seen};
            S_dbg_isp_fs_seen_sync  <= {S_dbg_isp_fs_seen_sync[0],  S_dbg_isp_fs_seen};
            S_dbg_isp_valid_seen_sync <= {S_dbg_isp_valid_seen_sync[0], S_dbg_isp_valid_seen};
            S_dbg_ddr_req_seen_sync <= {S_dbg_ddr_req_seen_sync[0], S_dbg_ddr_req_seen};
            S_dbg_ddr_ready_seen_sync <= {S_dbg_ddr_ready_seen_sync[0], S_dbg_ddr_ready_seen};
            S_dbg_rd_req_seen_sync <= {S_dbg_rd_req_seen_sync[0], S_dbg_rd_req_seen};
            S_dbg_rd_valid_seen_sync <= {S_dbg_rd_valid_seen_sync[0], S_dbg_rd_valid_seen};
            S_dbg_rd_nonzero_seen_sync <= {S_dbg_rd_nonzero_seen_sync[0], S_dbg_rd_nonzero_seen};
            S_dbg_mc_init_seen_sync <= {S_dbg_mc_init_seen_sync[0], S_dbg_mc_init_seen};
            S_dbg_mc_app_rdy_seen_sync <= {S_dbg_mc_app_rdy_seen_sync[0], S_dbg_mc_app_rdy_seen};
            S_dbg_mc_wdf_rdy_seen_sync <= {S_dbg_mc_wdf_rdy_seen_sync[0], S_dbg_mc_wdf_rdy_seen};
            S_dbg_mc_cmd_pop_seen_sync <= {S_dbg_mc_cmd_pop_seen_sync[0], S_dbg_mc_cmd_pop_seen};
            S_dbg_frame_repeat_sync <= {S_dbg_frame_repeat_sync[0], S_dbg_frame_repeat_seen};
            S_dbg_width_1280_sync <= {S_dbg_width_1280_sync[0], S_dbg_width_1280_seen};
            S_dbg_height_720_sync <= {S_dbg_height_720_sync[0], S_dbg_height_720_seen};
            S_dbg_isp_frame_repeat_sync <= {S_dbg_isp_frame_repeat_sync[0], S_dbg_isp_frame_repeat_seen};
            if(S_crop_rd_en && (S_video_rd_data != 24'd0))
                S_dbg_video_nonzero_seen <= 1'b1;
        end
    end

    assign S_lane_error_any = |S_lane_error;

    assign S_vo_dbg_fifo_rst = 1'b0;
    assign S_vo_dbg_ddr_rd_valid = 1'b0;
    assign S_vo_dbg_fifo_rd_en = 1'b0;
    assign S_vo_dbg_fifo_empty = 1'b0;
    assign S_mc_dbg_fifo_afull = 1'b0;
    assign S_mc_dbg_app_rdy = 1'b0;
    assign S_mc_dbg_wdf_rdy = 1'b0;
    assign S_mc_dbg_cmd_pop = 1'b0;

    // On-screen bring-up status, from left to right in DEBUG_MODE=3:
    // I2C configuration completed, MIPI HS activity seen, repeated CSI frames,
    // and a 1280-pixel RAW10 line (400 x 32-bit CSI payload words) seen.
    assign S_vs_debug_status = {
        S_dbg_width_1280_sync[1],
        S_dbg_frame_repeat_sync[1],
        S_dbg_hs_seen_sync[1],
        S_dbg_cam_cfg_seen_sync[1]
    };
	
	assign O_cam_rst 	= 1'b1;
    assign O_cam_24m 	= S_24m_clk;
	
	
	
	
    PLL u_PLL(
        .refclk      ( I_sys_clk         ),
        .reset    	 ( ~I_rst_n          ),
        
        .clk0_out    ( S_100m_clk        ),
        .clk1_out    ( S_24m_clk         ),

        .clk2_out    ( S_dpll_ref_clk ),
        .clk3_out    ( S_10m_clk ),

        .lock        ( S_pll_lock        )

    );


	

  
    wire S_csi_line_end;
    wire S_previous_bad,S_camera_frame_toggle,S_front_valid,S_frame_release,S_writes_idle;
  camera_gain_apply u_gain_apply (
      .I_clk(S_24m_clk),
      .I_rst_n(S_rst_n),
      .I_gain(S_gain_camera),.I_auto_enable(S_sensor_config[7]),.I_meter_mode(S_sensor_config[9:8]),.I_stats(S_ae_stats_camera),.O_status(S_ae_status),
      .I_cam_done(S_cam_cfg_done),.I_frame_toggle(S_camera_frame_toggle),
      .I_ae_done(S_ae_cfg_done),
      .O_req(S_ae_req),
      .O_ae(S_ae),
      .O_ag(S_ag)
  );
  
    uicfgcs500_720p #(
      .CLK_DIV(24000000 / 100000 - 1)
  ) u_uicfgcs500 (
      .I_clk(S_24m_clk),  //系统时钟输入
      .I_rst_n(S_rst_n),  //系统复位输入
      .I_ae_req(S_ae_req),
      .I_ae(S_ae),
      .I_ag(S_ag),
      .O_cam_scl(O_cam_scl),  //I2C总线，SCL时钟
      .IO_cam_sda(IO_cam_sda),  //I2C总线，SDA数据
      .O_cfg_done(S_cam_cfg_done),  //摄像头寄存器初始化完成
      .O_ae_cfg_done(S_ae_cfg_done)  //AE配置完成
  );
	
    mipi_dphy_rx_ph1p_mipiio_wrapper#(
        .DPHY_RX_LOCATION      ( "DPHY0" ),
        .HS_EQUALIZER          ( "0dB"   ),//"0dB","1.5dB","3dB","4.5dB","6dB","7.5dB","9dB","10.5dB"
        .HS_VGA_GAIN           ( "8dB" ),//"-3dB","-1.5dB","0dB","1.5dB","3dB","4.5dB","6dB","7.5dB"
        .LANE_NUM              ( 2       ),
        .BYTE_NUM              ( 1       )
    )u_mipi_dphy_rx_ph1p_mipiio_wrapper(
        .I_lp_clk              ( S_100m_clk       ),
        .I_rst                 ( ~S_rst_n         ),

        .I_clk_lane_in_delay   ( 6'd0             ),
        .I_data_lane0_in_delay ( 6'd0             ),
        .I_data_lane1_in_delay ( 6'd0             ),
        .I_data_lane2_in_delay ( 6'd0             ),
        .I_data_lane3_in_delay ( 6'd0             ),

        .I_lane_invert         ( 4'b0000          ),
     
        .O_hs_rx_clk           ( S_csi_rx_clk     ),
        .O_hs_rx_valid         ( S_hs_rx_valid    ),
        .O_hs_rx_data          ( S_hs_rx_data     ),
      
        .O_lp_rx_lane0_p       (  ),
        .O_lp_rx_lane0_n       (  ),
      
        .I_lp_tx_en            ( 1'b0             ),
        .I_lp_tx_lane0_p       ( 1'b1             ),
        .I_lp_tx_lane0_n       ( 1'b1             ),
      
        .O_lane_match_error    (                  ),
        .O_lane_error          ( S_lane_error     ),
      
        .IO_rx_clk_pad_n       ( IO_rx_clk_pad_n  ),
        .IO_rx_clk_pad_p       ( IO_rx_clk_pad_p  ),
        .IO_rx_data_pad_n      ( IO_rx_data_pad_n ),
        .IO_rx_data_pad_p      ( IO_rx_data_pad_p )
    );
	
	
 //  cwc cwc_inst
 //(
 //    .probe0(S_hs_rx_valid),
 //    .probe1(S_hs_rx_data),
 //    .probe2(S_lane_error),
 //    .clk(S_csi_rx_clk)
 //);

 //csi 解码为RAW数据
csi_unpacket_2lane u_csi_unpacket(
.I_clk                 ( S_csi_rx_clk       ),
.I_rst_n               ( S_rst_n        	),
.I_hs_valid            ( S_hs_rx_valid     ),
.I_hs_data             ( S_hs_rx_data      ),

.O_csi_frame_start     ( S_csi_frame_start ),
.O_csi_frame_end       ( S_csi_frame_end   ),
.O_csi_line_end        ( S_csi_line_end    ),
.O_csi_valid           ( S_csi_valid       ),
.O_csi_data            ( S_csi_data        )
);


//解码为RAW8
raw10_unpacket_2lane u_raw10_unpacket (
.I_clk  (S_csi_rx_clk),
.I_rst_n(S_rst_n),

.I_csi_frame_start(S_csi_frame_start),
.I_csi_frame_end  (S_csi_frame_end),
.I_csi_valid      (S_csi_valid),
.I_csi_data       (S_csi_data),

.O_raw10_frame_start(S_raw10_frame_start),
.O_raw10_frame_end  (S_raw10_frame_end),
.O_raw10_valid      (S_raw10_valid),
.O_raw10_data       (S_raw10_data)
  );


//将数据转为stream流
uial2axis #(
.IMG_WIDTH(1280),
.IMG_HEIGHT(720),
.INPUT_DATA_WIDTH(40)
) 
u_uial2axis (
.I_native_clk(S_csi_rx_clk),
.I_rst_n     (S_rst_n),
.I_data      (S_raw10_data       ),
.I_data_valid(S_raw10_valid      ),
.I_data_start(S_raw10_frame_start),
.I_data_end  (S_raw10_frame_end  ),
.axis_tvalid (S_axis_tvalid),
.axis_tdata  (S_axis_tdata ),
.axis_tuser  (S_axis_tuser ),
.axis_tlast  (S_axis_tlast )
);
	

// SC500 factory HD mode already outputs native 1280x720 RAW10.
assign S_raw_tdata  = S_axis_tdata;
assign S_raw_tvalid = S_axis_tvalid;
assign S_raw_tlast  = S_axis_tlast;
assign S_raw_tuser  = S_axis_tuser;


//cwc1 cwc1_Inst
//  (
//      .probe0(S_axis_tuser),
//      .probe1(S_axis_tvalid),
//      .probe2(S_axis_tlast),
//      .probe3(S_axis_tdata),
//      .probe4(S_ISP_O_tuser),
//      .probe5(S_ISP_O_tvalid),
//      .probe6(S_ISP_O_tlast),
//      .probe7(S_ISP_O_tdata),
//      .probe8 (S_raw_tdata ),
//      .probe9 (S_raw_tlast ),
//      .probe10(S_raw_tvalid),
//      .probe11(S_raw_tuser ),
//      .clk(S_csi_rx_clk)
//  );


//ISP算法顶层模块
wire S_filter_cdc_overflow;
isp_top u_isp_top (
.I_process_clk(S_24m_clk),.O_cdc_overflow(S_filter_cdc_overflow),
.I_wb_config(S_wb_camera),.I_image_mode(S_image_mode_camera),
.I_hist_config(S_hist_config),.I_hist_ready(S_hist_ready),.O_hist_we(S_hist_we),
.O_hist_publish(S_hist_publish),.O_hist_addr(S_hist_addr),.O_hist_height(S_hist_height),
.I_meter_mode(S_meter_camera),.O_ae_stats(S_ae_stats),.O_wb_telemetry(S_wb_telemetry),.I_previous_bad(S_previous_bad), .O_frame_mode(S_isp_frame_mode),
.axi4s_video_aclk(S_csi_rx_clk),
.I_rst_n         (S_rst_n),
.I_tlast         (S_raw_tlast	),
.I_tuser         (S_raw_tuser	),
.I_tdata         (S_raw_tdata	),
.I_tvalid        (S_raw_tvalid	),
.I_tdest         (),
.O_tready        (S_ISP_O_tready),
.O_tdata         (S_ISP_O_tdata ),
.O_tlast         (S_ISP_O_tlast ),
.O_tuser         (S_ISP_O_tuser ),
.O_tvalid        (S_ISP_O_tvalid),
.I_tready        ()
  );


    wire [31:0] S_capture_bad_count,S_drop_count,S_good_count,S_overflow_count;
    camera_frame_check u_camera_check(.I_clk(S_csi_rx_clk),.I_rst_n(S_rst_n),
      .I_sof(S_csi_frame_start),.I_eof(S_csi_frame_end),.I_valid(S_csi_valid),
      .I_line_end(S_csi_line_end),
      .I_lane_error(|S_lane_error),.O_previous_bad(S_previous_bad),
      .O_frame_toggle(S_camera_frame_toggle),.O_bad_frames(S_capture_bad_count));
    (* async_reg="true" *) reg [1:0] S_process_bad;
    always @(posedge S_24m_clk or negedge S_rst_n)
      if(!S_rst_n)S_process_bad<=0;else S_process_bad<={S_process_bad[0],S_previous_bad};
    video_in u_video_in(
        .I_rst_n              (  S_rst_n             ),

        .I_camera_clk         ( S_24m_clk             ),
        .I_camera_frame_start ( S_ISP_O_tuser  ),
        .I_camera_valid       ( S_ISP_O_tvalid ),
        .I_camera_data        ( S_ISP_O_tdata  ),
        .I_camera_mode        ( S_isp_frame_mode ),
        .O_slot_modes         ( S_slot_modes ),
        .O_slot_sequences(S_slot_sequences),.O_capture_sequence(S_capture_sequence),
        .I_mipi_rx_error      ( S_process_bad[1]|S_filter_cdc_overflow ),

        .I_ddr_clk            ( S_ddr_clk             ),
		.I_display_pause      ( 1'b0                  ),
        .I_video_out_rd_busy  ( S_video_out_rd_busy   ),
        .O_video_in_wr_busy   ( S_video_in_wr_busy    ),
        .O_video_out_rp       ( S_video_out_rp        ),
        .O_front_valid(S_front_valid),.I_display_frame_release(S_frame_release),
        .I_ddr_writes_idle(S_writes_idle),.O_dropped_frames(S_drop_count),
        .O_good_frames(S_good_count),.O_fifo_overflows(S_overflow_count),

        .O_ddr_user_wr_en     ( S_vi_ddr_wr_en        ),
        .O_ddr_user_addr      ( S_vi_ddr_wr_addr      ),
        .O_ddr_user_wr_data   ( S_vi_ddr_wr_data      ),
        .I_ddr_user_ready     ( S_ddr_user_ready      )
    );



    assign S_ddr_user_wr_en    = S_vi_ddr_wr_en;

    assign S_ddr_user_rd_en    = S_vo_ddr_rd_en;

    assign S_ddr_user_addr     = S_vi_ddr_wr_en ? S_vi_ddr_wr_addr :
                                 S_vo_ddr_rd_en ? S_vo_ddr_rd_addr : 'd0;

    assign S_ddr_user_wr_data  = S_vi_ddr_wr_data;


    assign S_video_out_rst_n = S_display_rst_n;

    video_out u_video_out(
        .I_rst_n             ( S_video_out_rst_n    ),
        .I_ddr_clk           ( S_ddr_clk            ),
 
        .O_video_out_rd_busy ( S_video_out_rd_busy  ),
        .I_video_in_wr_busy  ( S_video_in_wr_busy   ),
        .I_video_out_rp      ( S_video_out_rp       ),
        .I_front_valid(S_front_valid),.O_frame_release(S_frame_release),
        .O_underflow_frames(S_read_underflow_count),.O_overflow_frames(S_read_overflow_count),
        .I_slot_modes        ( S_slot_modes ),
        .I_slot_sequences(S_slot_sequences),.I_capture_sequence(S_capture_sequence),
        .O_frame_latency(S_frame_latency),.O_frame_latency_valid(S_frame_latency_valid),
        .O_frame_mode        ( S_ddr_frame_mode ),
 
        .O_ddr_user_rd_en    ( S_vo_ddr_rd_en       ),
        .O_ddr_user_addr     ( S_vo_ddr_rd_addr     ),
        .I_ddr_user_ready    ( S_ddr_user_ready     ),
        .I_ddr_user_rd_valid ( S_ddr_user_rd_valid  ),
        .I_ddr_user_rd_data  ( S_ddr_user_rd_data   ),

        .I_dsi_clk           ( S_dsi_tx_clk     ),
        .I_video_vsync       ( S_video_out_vsync    ),
        .I_video_rd_en       ( S_crop_rd_en  ),
        .O_vdieo_data        ( S_video_rd_data      )
    );



    mc_to_user_interface u_mc_to_user_interface(
        .I_clk                   ( S_ddr_clk               ),
        .I_rst_n                 ( S_rst_n                 ),

        .I_ddr_user_wr_en        ( S_ddr_user_wr_en        ),
        .I_ddr_user_rd_en        ( S_ddr_user_rd_en        ),
        .I_ddr_user_addr         ( S_ddr_user_addr         ),
        .I_ddr_user_wr_data      ( S_ddr_user_wr_data      ),
        .O_ddr_user_ready        ( S_ddr_user_ready        ),
        .O_writes_idle(S_writes_idle),
        .O_ddr_user_rd_valid     ( S_ddr_user_rd_valid     ),
        .O_ddr_user_rd_data      ( S_ddr_user_rd_data      ),
            
        .O_mc_app_en             ( S_mc_app_en             ),
        .O_mc_app_addr           ( S_mc_app_addr           ),
        .O_mc_app_cmd            ( S_mc_app_cmd            ),
        .I_mc_app_rdy            ( S_mc_app_rdy            ),
        .O_mc_app_wdf_wren       ( S_mc_app_wdf_wren       ),
        .O_mc_app_wdf_data       ( S_mc_app_wdf_data       ),
        .O_mc_app_wdf_end        ( S_mc_app_wdf_end        ),
        .O_mc_app_wdf_mask       ( S_mc_app_wdf_mask       ),
        .I_mc_app_wdf_rdy        ( S_mc_app_wdf_rdy        ),
        .I_mc_app_rd_data        ( S_mc_app_rd_data        ),
        .I_mc_app_rd_data_end    ( S_mc_app_rd_data_end    ),
        .I_mc_app_rd_data_valid  ( S_mc_app_rd_data_valid  )
    );



    ph1p35_324_ddr_wrapper u_ph1p35_324_ddr_wrapper(
        .I_sys_clk              ( S_100m_clk             ),
        .I_sys_rst_n            ( S_rst_n                ),

        .O_ddr_clk              ( S_ddr_clk              ),
        .O_init_calib_complete  ( S_init_calib_complete  ),
        .I_mc_app_addr          ( S_mc_app_addr          ),
        .I_mc_app_cmd           ( S_mc_app_cmd           ),
        .I_mc_app_en            ( S_mc_app_en            ),
        .I_mc_app_wdf_data      ( S_mc_app_wdf_data      ),
        .I_mc_app_wdf_end       ( S_mc_app_wdf_end       ),
        .I_mc_app_wdf_mask      ( S_mc_app_wdf_mask      ),
        .I_mc_app_wdf_wren      ( S_mc_app_wdf_wren      ),
        .O_mc_app_rd_data       ( S_mc_app_rd_data       ),
        .O_mc_app_rd_data_end   ( S_mc_app_rd_data_end   ),
        .O_mc_app_rd_data_valid ( S_mc_app_rd_data_valid ),
        .O_mc_app_rdy           ( S_mc_app_rdy           ),
        .O_mc_app_wdf_rdy       ( S_mc_app_wdf_rdy       ),

        .ddr_addr               ( ddr_addr               ),
        .ddr_ba                 ( ddr_ba                 ),
        .ddr_cke                ( ddr_cke                ),
        .ddr_odt                ( ddr_odt                ),
        .ddr_cs_n               ( ddr_cs_n               ),
        .ddr_ras_n              ( ddr_ras_n              ),
        .ddr_cas_n              ( ddr_cas_n              ),
        .ddr_we_n               ( ddr_we_n               ),
        .ddr_ck_p               ( ddr_ck_p               ),
        .ddr_ck_n               ( ddr_ck_n               ),
        .ddr_dm                 ( ddr_dm                 ),
        .ddr_dq                 ( ddr_dq                 ),
        .ddr_dqs_p              ( ddr_dqs_p              ),
        .ddr_dqs_n              ( ddr_dqs_n              )
    );



    video_source #(
        .HTOTAL ( 1344  ),
        .HSA    ( 24    ),
        .HBP    ( 136   ),
        .HFP    ( 160   ),
 
        .VTOTAL ( 635 ),
        .VSA    ( 2    ),
        .VBP    ( 21   ),
        .VFP    ( 12   )
    )u_video_source(
        .I_clk          ( S_dsi_tx_clk     ),
        .I_rst          ( ~S_dsi_ready_n   ),

        .I_config_done  ( S_dsi_ready_n   ),

        .O_rgb24b_vsync ( S_vs_vsync       ),
        .O_rgb24b_hsync ( S_vs_hsync       ),
        .O_rgb24b_de    ( S_vs_de          ),
        .O_rgb24b_data  ( S_vs_data        )
    );


    generate if (DISPLAY_TEST_PATTERN != 0) begin : TEST_PATTERN
        // PDATA/PDEN are aligned by the vendor video_tpg pipeline.
        assign S_crop_rd_en = 1'b0;
        assign S_base_vsync = S_vs_vsync;
        assign S_base_hsync = S_vs_hsync;
        assign S_base_de = S_vs_de;
        assign S_base_data = S_vs_data;
    end else begin : CAMERA_IMAGE
    mixer u_mixer(
        .I_clk           ( S_dsi_tx_clk    ),

        .I_video_vsync   ( S_vs_vsync      ),
        .I_video_hsync   ( S_vs_hsync      ),
        .I_video_de      ( S_vs_de         ),

        .O_vdieo_rd_en   ( S_crop_rd_en   ),
        .I_video_rd_data ( S_video_rd_data ),

        .O_mixer_vsync   ( S_base_vsync   ),
        .O_mixer_hsync   ( S_base_hsync   ),
        .O_mixer_de      ( S_base_de      ),
        .O_mixer_data    ( S_base_data    )
    );
    end endgenerate

    wire S_target_vsync,S_target_hsync,S_target_de;
    wire [23:0] S_target_data;
    wire [51:0] S_target_info;
    red_target_video #(.USE_ISP_FILTERS(1)) u_rgb_target_video (
        .I_clk(S_dsi_tx_clk),.I_rst_n(S_dsi_ready_n),
        .I_enable(S_ui_frame_active[27]),.I_page(S_ui_frame_active[25:22]==0?3'd0:3'd1),
        .I_image_mode(S_ui_frame_active[3:1]),.I_effect(2'd0),.O_info(S_target_info),
        .I_vsync(S_base_vsync),.I_hsync(S_base_hsync),.I_de(S_base_de),.I_data(S_base_data),
        .O_vsync(S_target_vsync),.O_hsync(S_target_hsync),.O_de(S_target_de),.O_data(S_target_data));

    // One base-frame snapshot is stable before the delayed detector VS.
    // The UI captures it at its own VS; watermark enable travels with each pixel.
    localparam [51:0] UI_CONFIG_RESET = {7'd50,1'b1,1'b0,1'b0,2'd1,1'b1,1'b0,5'd0,5'd0,1'b0,1'b0,4'd0,
                                         2'd0,2'd0,7'd30,7'd80,3'd0,1'b0};
    reg S_base_vs_d;
    reg [51:0] S_ui_frame;
    wire [51:0] S_ui_frame_active=(S_base_vsync&&!S_base_vs_d)?S_ui_display:S_ui_frame;
    always @(posedge S_dsi_tx_clk or negedge S_dsi_ready_n)
    if(!S_dsi_ready_n)begin S_base_vs_d<=0;S_ui_frame<=UI_CONFIG_RESET;end
    else begin
        S_base_vs_d<=S_base_vsync;
        if(S_base_vsync&&!S_base_vs_d)S_ui_frame<=S_ui_display;
        
    end
    wire S_ui_vsync,S_ui_hsync,S_ui_de,S_ui_watermark;wire [23:0] S_ui_data;
    histogram_snapshot u_hist_snapshot(
      .I_wclk(S_24m_clk),.I_rclk(S_dsi_tx_clk),.I_rst_n(S_rst_n),
      .I_we(S_hist_we),.I_publish(S_hist_publish),.I_addr(S_hist_addr),.I_height(S_hist_height),
      .O_ready(S_hist_ready),.I_frame_start(S_hist_frame_start),.I_read_addr(S_hist_read_addr),
      .O_height(S_hist_read_height),.O_valid(S_hist_valid));
    wb_ui_overlay u_wb_ui_overlay (
        .I_clk(S_dsi_tx_clk),.I_rst_n(S_dsi_ready_n),.I_config(S_ui_frame),
        .I_latency(S_latency_display),.I_diagnostics(S_diagnostics_display),
        .I_underflow(S_underflow_display),
        .I_target_info(S_target_info),.I_hist_height(S_hist_read_height),.I_hist_valid(S_hist_valid),
        .O_hist_read_addr(S_hist_read_addr),.O_hist_frame_start(S_hist_frame_start),.I_ae_telemetry(S_ae_display),.I_telemetry(S_wb_telemetry_display),
        .I_vsync(S_target_vsync),.I_hsync(S_target_hsync),.I_de(S_target_de),.I_data(S_target_data),
        .O_tag_enable(S_ui_watermark),.O_vsync(S_ui_vsync),.O_hsync(S_ui_hsync),.O_de(S_ui_de),.O_data(S_ui_data));
    // Exact touch123 watermark assets/coordinates/colors. Keep UI controls
    // unobstructed on settings pages; counter continues while hidden.
    dsi_osd_overlay u_original_osd(
        .I_clk(S_dsi_tx_clk),.I_rst_n(S_dsi_ready_n),
        .I_enable(S_ui_watermark),
        .I_vsync(S_ui_vsync),.I_hsync(S_ui_hsync),.I_de(S_ui_de),.I_data(S_ui_data),
        .O_vsync(S_mixer_vsync),.O_hsync(S_mixer_hsync),.O_de(S_mixer_de),.O_data(S_mixer_data));

    rgb_24b_to_32b #(
       .H_ACTIVE (1024)
    )u_rgb_24b_to_32b(
        .I_clk   ( S_dsi_tx_clk      ),
        .I_rst   ( ~S_dsi_ready_n    ),

        .I_vsync ( S_mixer_vsync     ),
        .I_hsync ( S_mixer_hsync     ),
        .I_de    ( S_mixer_de        ),
        .I_data  ( S_mixer_data      ),
                                               
        .O_vsync ( S_32b_vsync       ),
        .O_hsync ( S_32b_hsync       ),
        .O_de    ( S_32b_de          ),
        .O_data  ( S_32b_data        )
    );


    dsi_video_mode_packet #(
       .H_ACTIVE (1024)
    ) u_dsi_video_mode_packet(
        .I_clk     ( S_dsi_tx_clk  ),
        .I_rst     ( ~S_dsi_ready_n ),
    
        .I_vsync   ( S_32b_vsync   ),
        .I_hsync   ( S_32b_hsync   ),
        .I_de      ( S_32b_de      ),
        .I_data    ( S_32b_data    ),
            
        .O_hs_en   ( S_hs_tx_valid ),
        .O_hs_data ( S_hs_tx_data  ),
        .O_hs_last ( S_hs_tx_last  )
    );



    display_config_wrapper u_display_config_wrapper(
        .I_clk          ( S_10m_clk         ),
        .I_rst          ( ~S_lp_reset_n     ),

        .I_config_start ( S_lp_config_start ),
        .O_config_done  ( S_lp_config_done  ),

        .O_lp_tx_p      ( S_lp_tx_p         ),
        .O_lp_tx_n      ( S_lp_tx_n         )
    );


    mipi_dphy_tx_over_ph1p_mipiio_wrapper#(
        .DPHY_TX_LOCATION        ( "DPHY1"    ),
        .BYTE_NUM                ( 1          ),
        .LANE_NUM                ( 4          ),

        .CLK_LANE_MODE           ( "CONTINUE" ),
        .HS_OUTPUT_VOD           ( "200mV"    ),//"175mV","187.5mV","200mV","212.5mV","225mV","237.5mV","250mV","450mV"
        .HS_OUTPUT_IMPEDANCE     ( "50ohm"    ),//"70ohm","64ohm","58ohm","54ohm","50ohm","47ohm","44ohm","41ohm"
        .HS_OUTPUT_DE_EMPHASIS   ( "0dB"      ),//"0dB","1dB","2dB","3dB","4dB","5dB","6dB"

        .CK_OUTPUT_DELAY         ( 0  ),
        .L0_OUTPUT_DELAY         ( 0  ),
        .L1_OUTPUT_DELAY         ( 0  ),
        .L2_OUTPUT_DELAY         ( 0  ),
        .L3_OUTPUT_DELAY         ( 0  ),

        .DPLL_MULTI_RATIO        ( 15 ), // encoded M=15, N=1: byte clock equals 52.173913 MHz ref
        .DPLL_DIV_RATIO          ( 1  ),

        .T_DATA_LPX              ( 10 ),
        .T_DATA_HS_PREPARE       ( 10 ),
        .T_DATA_HS_ZERO          ( 20 ),
        .T_DATA_HS_TRAIL         ( 10 ),
        .T_CLK_LPX               ( 10 ),
        .T_CLK_PREPARE           ( 10 ),
        .T_CLK_ZERO              ( 10 ),
        .T_CLK_PRE               ( 10 ),
        .T_CLK_POST              ( 10 ),
        .T_CLK_TRAIL             ( 10 )
    )u_mipi_dphy_tx_over_ph1p_mipiio_wrapper(
        .I_dphy_pll_ref_clk ( S_dpll_ref_clk        ),
        .I_rst              ( ~S_rst_n              ),
        .O_dpll_locked      ( S_mipi_tx_dpll_locked ),

        .O_hs_tx_clk        ( S_dsi_tx_clk          ),
        .I_hs_tx_valid      ( S_hs_tx_valid         ),
        .I_hs_tx_data       ( S_hs_tx_data          ),
        .I_hs_tx_last       ( S_hs_tx_last          ),
        .O_hs_tx_ready      ( S_hs_tx_ready         ),

        .I_lp_tx_p          ( S_lp_tx_p             ),
        .I_lp_tx_n          ( S_lp_tx_n             ),
   
        .I_lp_rx_en         ( 1'b0                  ),
        .O_lp_rx_p          (                       ),
        .O_lp_rx_n          (                       ),
    
        .IO_tx_clk_pad_n    ( IO_tx_clk_pad_n       ),
        .IO_tx_clk_pad_p    ( IO_tx_clk_pad_p       ),
        .IO_tx_data_pad_n   ( IO_tx_data_pad_n      ),
        .IO_tx_data_pad_p   ( IO_tx_data_pad_p      )
    );


    

endmodule
