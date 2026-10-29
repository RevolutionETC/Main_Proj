// SC500 720P standalone white balance demonstration ISP.
// This reference pipeline is a continuous video stream; it has no stall buffer.
module isp_top #(
    parameter BRIGHTEN_ENABLE = 1'b1
)(
    input          axi4s_video_aclk,
    input          I_rst_n,
    input I_process_clk,output O_cdc_overflow,
    input [18:0]   I_wb_config,
    input [2:0]    I_image_mode,
    input [8:0] I_hist_config,input I_hist_ready,
    output O_hist_we,O_hist_publish,output [5:0] O_hist_addr,output [7:0] O_hist_height,
    output [36:0] O_wb_telemetry,
    input [1:0] I_meter_mode,output [7:0] O_ae_stats,
    input I_previous_bad,
    output [2:0]   O_frame_mode,
    input          I_tlast,
    input          I_tuser,
    input  [39:0]  I_tdata,
    input          I_tvalid,
    input  [9:0]   I_tdest,
    input          O_tready,
    output [127:0] O_tdata,
    output         O_tlast,
    output         O_tuser,
    output         O_tvalid,
    output         I_tready
);
    wire [127:0] demosaic_data;
    wire [95:0] rgb_data;
    wire demosaic_last, demosaic_user, demosaic_valid, demosaic_ready;
    wire [95:0] awb_data;
    wire awb_last, awb_user, awb_valid, awb_ready;
    wire [95:0] filter_data;
    wire filter_last,filter_user,filter_valid;

    demosaic #(
        .IMG_HEIGHT(720), .IMG_WIDTH(1280),
        .data_complete_delay(50), .BAYER_MODE("BGGR")
    ) u_demosaic (
        .I_clk(axi4s_video_aclk), .I_rst_n(I_rst_n),
        .axi4s_video_tdata(I_tdata), .axi4s_video_tdest(I_tdest),
        .axi4s_video_tlast(I_tlast), .axi4s_video_tuser(I_tuser),
        .axi4s_video_tvalid(I_tvalid), .axi4s_video_tready(I_tready),
        .O_tdata(demosaic_data), .O_tlast(demosaic_last),
        .O_tuser(demosaic_user), .O_tvalid(demosaic_valid),
        .O_tready(demosaic_ready)
    );

    data128_96 u_data128_96 (
        .I_tdata(demosaic_data), .O_tdata(rgb_data)
    );

    // Tap before WB, tint, tone lift and artistic filters.
    ae_meter_96 u_ae_meter(.I_clk(axi4s_video_aclk),.I_rst_n(I_rst_n),
      .I_data(rgb_data),.I_valid(demosaic_valid),.I_user(demosaic_user),
      .I_last(demosaic_last),.I_previous_bad(I_previous_bad),.I_meter_mode(I_meter_mode),.O_stats(O_ae_stats));
    reg [18:0] frame_config;
    always @(posedge axi4s_video_aclk or negedge I_rst_n)
     if(!I_rst_n)frame_config<=19'd30;else if(demosaic_user)frame_config<=I_wb_config;
    wire [18:0] active_config=demosaic_user?I_wb_config:frame_config;
    wire [11:0] applied_r,applied_b;wire statistics_ok;
    assign O_wb_telemetry={statistics_ok,applied_r,12'd1024,applied_b};
    wb_balance_96 u_white_balance (
        .I_clk(axi4s_video_aclk),.I_rst_n(I_rst_n),
        .I_mode(active_config[8:7]),.I_kelvin_index(active_config[6:0]),
        .I_data(rgb_data),.I_valid(demosaic_valid),.I_user(demosaic_user),.I_last(demosaic_last),
        .I_previous_bad(I_previous_bad),.I_ready(O_tready),.O_ready(demosaic_ready),.O_data(awb_data),
        .O_valid(awb_valid),.O_user(awb_user),.O_last(awb_last),.O_gain_r(applied_r),.O_gain_b(applied_b),.O_statistics_ok(statistics_ok));
    wire [95:0] tint_data;wire tint_valid,tint_user,tint_last;
    wb_tint_96 u_tint(.I_clk(axi4s_video_aclk),.I_rst_n(I_rst_n),.I_enable(frame_config[8]),
      .I_ab(frame_config[18:14]),.I_gm(frame_config[13:9]),.I_data(awb_data),
      .I_valid(awb_valid),.I_user(awb_user),.I_last(awb_last),.O_data(tint_data),
      .O_valid(tint_valid),.O_user(tint_user),.O_last(tint_last));
    wire [95:0] bright_pixels;wire tone_valid,tone_user,tone_last,tone_bad;wire [2:0] tone_mode;
    rgb_brighten_eram_96 #(.ENABLE(BRIGHTEN_ENABLE)) u_brighten(
      .I_clk(axi4s_video_aclk),.I_rst_n(I_rst_n),.I_data(tint_data),
      .I_valid(tint_valid),.I_user(tint_user),.I_last(tint_last),.I_mode(I_image_mode),.I_previous_bad(I_previous_bad),
      .O_data(bright_pixels),.O_valid(tone_valid),.O_user(tone_user),.O_last(tone_last),.O_mode(tone_mode),.O_previous_bad(tone_bad));
    wire [95:0] process_rgb;wire process_valid,process_user,process_last;
    wire [2:0] process_mode;wire process_previous_bad;
    filter_clock_bridge u_filter_clock_bridge(
      .src_clk(axi4s_video_aclk),.dst_clk(I_process_clk),.rst_n(I_rst_n),
      .rgb(bright_pixels),.valid(tone_valid),.sof(tone_user),.last(tone_last),.mode(tone_mode),.previous_bad(tone_bad),
      .out_rgb(process_rgb),.out_valid(process_valid),.out_sof(process_user),.out_last(process_last),
      .out_mode(process_mode),.out_previous_bad(process_previous_bad),.overflow(O_cdc_overflow));
    wire [95:0] equalized;wire he_valid,he_user,he_last;wire [2:0] he_mode;
    histogram_equalizer_96 u_histogram_equalizer(
      .I_clk(I_process_clk),.I_rst_n(I_rst_n),.I_config(I_hist_config),
      .I_data(process_rgb),.I_valid(process_valid),.I_user(process_user),.I_last(process_last),
      .I_previous_bad(process_previous_bad),.I_frame_mode(process_mode),
      .O_data(equalized),.O_valid(he_valid),.O_user(he_user),.O_last(he_last),.O_frame_mode(he_mode),
      .I_hist_ready(I_hist_ready),.O_hist_we(O_hist_we),.O_hist_publish(O_hist_publish),
      .O_hist_addr(O_hist_addr),.O_hist_height(O_hist_height));
    // Store color, not artistic effects: recognition always sees RGB.
    assign filter_data=equalized;
    assign filter_valid=he_valid;
    assign filter_user=he_user;
    assign filter_last=he_last;
    assign O_frame_mode=3'd0;

    data_96bit_to_128bit u_data_96bit_to_128bit (
        .I_clk(I_process_clk), .I_rst_n(I_rst_n),
        .I_96b_frame_start(filter_user), .I_96b_valid(filter_valid),
        .I_96b_data(filter_data),
        .O_128b_frame_start(O_tuser), .O_128b_valid(O_tvalid),
        .O_128b_data(O_tdata)
    );

    // Match the packer latency on the legacy end-of-line status port.
    reg packed_last;
    always @(posedge I_process_clk or negedge I_rst_n) begin
        if (!I_rst_n) packed_last <= 1'b0;
        else          packed_last <= filter_last;
    end
    assign O_tlast = packed_last;
endmodule
