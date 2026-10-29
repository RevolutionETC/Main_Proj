create_clock -name {sys_clk_25m} -period 40.000 -waveform {0.000 20.000} [get_ports {I_sys_clk}]
# SC500 720p input clock constraint retained from the supplied HDMI project.
create_clock -name {mipi_rx_ck_pad} -period 4.167 -waveform {0.000 2.083} [get_nets {IO_rx_clk_pad_p}]
derive_clocks
rename_clock -name {pll_clk_100m} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[0]}]
rename_clock -name {pll_clk_24m} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[1]}]
rename_clock -name {dpll_ref_clk} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[2]}]
rename_clock -name {pll_clk_10m} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[3]}]
rename_clock -name {MIPI_RX_BYTE_CLK} [get_clocks {u_mipi_dphy_rx_ph1p_mipiio_wrapper/u_ph1p_mipiio_rx_wrapper/u_PH1P_LOGIC_DPHY_MIPI_RX.o_fabric_div4_8_clk}]
rename_clock -name {MIPI_TX_BYTE_CLK} [get_clocks {u_mipi_dphy_tx_over_ph1p_mipiio_wrapper/u_ph1p_mipiio_tx_wrapper/u_PH1P_LOGIC_DPHY_MIPI_TX.o_fabric_div4_8_clk}]
set_clock_groups -asynchronous \
    -group [get_clocks {mipi_rx_ck_pad MIPI_RX_BYTE_CLK}] \
    -group [get_clocks {MIPI_TX_BYTE_CLK}] \
    -group [get_clocks {sys_clk_25m pll_clk_100m pll_clk_24m dpll_ref_clk pll_clk_10m u_ph1p35_324_ddr_wrapper/u_ddr2/ddr_clk u_ph1p35_324_ddr_wrapper/u_ddr2/usr_clk}]

# Only asynchronous assertion of the new display reset synchronizers is cut.
# Reset release is registered in each destination domain and remains timed.
set_false_path -through [get_nets {S_display_async_n}]
set_false_path -through [get_nets {S_lp_async_n}]

# Touch I2C asynchronous inputs, sampled by two-stage synchronizers.
set_false_path -from [get_ports {IO_touch_scl IO_touch_sda}]
# Held configuration payloads; request/ACK synchronizers provide settling time.
set_false_path -through [get_nets {u_wb_config/payload[0] u_wb_config/payload[1] u_wb_config/payload[2] u_wb_config/payload[3] u_wb_config/payload[4] u_wb_config/payload[5] u_wb_config/payload[6] u_wb_config/payload[7] u_wb_config/payload[8] u_wb_config/payload[9] u_wb_config/payload[10] u_wb_config/payload[11] u_wb_config/payload[12] u_wb_config/payload[13] u_wb_config/payload[14] u_wb_config/payload[15] u_wb_config/payload[16] u_wb_config/payload[17] u_wb_config/payload[18]}]
set_false_path -through [get_nets {u_gain_config/payload[0] u_gain_config/payload[1] u_gain_config/payload[2] u_gain_config/payload[3] u_gain_config/payload[4] u_gain_config/payload[5] u_gain_config/payload[6]}]
set_false_path -through [get_nets {u_ui_config/payload[0] u_ui_config/payload[1] u_ui_config/payload[2] u_ui_config/payload[3] u_ui_config/payload[4] u_ui_config/payload[5] u_ui_config/payload[6] u_ui_config/payload[7] u_ui_config/payload[8] u_ui_config/payload[9] u_ui_config/payload[10] u_ui_config/payload[11] u_ui_config/payload[12] u_ui_config/payload[13] u_ui_config/payload[14] u_ui_config/payload[15] u_ui_config/payload[16] u_ui_config/payload[17] u_ui_config/payload[18] u_ui_config/payload[19] u_ui_config/payload[20] u_ui_config/payload[21] u_ui_config/payload[22] u_ui_config/payload[23] u_ui_config/payload[24] u_ui_config/payload[25] u_ui_config/payload[26] u_ui_config/payload[27] u_ui_config/payload[28] u_ui_config/payload[29] u_ui_config/payload[30] u_ui_config/payload[31] u_ui_config/payload[32] u_ui_config/payload[33]}]

# 25MHz UI <-> 24MHz sensor-config control uses request/ACK synchronizers.
# No direct synchronous data path crosses this pair.
set_false_path -from [get_clocks {sys_clk_25m}] -to [get_clocks {pll_clk_24m}]
set_false_path -from [get_clocks {pll_clk_24m}] -to [get_clocks {sys_clk_25m}]

# Held telemetry mailbox; same request/ACK discipline as UI config.
set_false_path -through [get_nets {u_wb_telemetry/payload[0] u_wb_telemetry/payload[1] u_wb_telemetry/payload[2] u_wb_telemetry/payload[3] u_wb_telemetry/payload[4] u_wb_telemetry/payload[5] u_wb_telemetry/payload[6] u_wb_telemetry/payload[7] u_wb_telemetry/payload[8] u_wb_telemetry/payload[9] u_wb_telemetry/payload[10] u_wb_telemetry/payload[11] u_wb_telemetry/payload[12] u_wb_telemetry/payload[13] u_wb_telemetry/payload[14] u_wb_telemetry/payload[15] u_wb_telemetry/payload[16] u_wb_telemetry/payload[17] u_wb_telemetry/payload[18] u_wb_telemetry/payload[19] u_wb_telemetry/payload[20] u_wb_telemetry/payload[21] u_wb_telemetry/payload[22] u_wb_telemetry/payload[23] u_wb_telemetry/payload[24] u_wb_telemetry/payload[25] u_wb_telemetry/payload[26] u_wb_telemetry/payload[27] u_wb_telemetry/payload[28] u_wb_telemetry/payload[29] u_wb_telemetry/payload[30] u_wb_telemetry/payload[31] u_wb_telemetry/payload[32] u_wb_telemetry/payload[33] u_wb_telemetry/payload[34] u_wb_telemetry/payload[35] u_wb_telemetry/payload[36]}]

# BEGIN PROCESS_DDR_GRAY_CDC
# Frame-store FIFO: 24MHz processing <-> DDR user clock. Source Gray to
# FIRST synchronizer stage is CDC. Bound every bit to the faster 7.5ns period;
# remove only phase-dependent HOLD. Second-stage paths stay normally timed.
# Match the original HDL register buses as in the supplied vendor FIFO SDC.
set_max_delay -from [get_regs {u_video_in/fifo/rg[*]}] -to [get_regs {u_video_in/fifo/rg1[*]}] -datapath_only 7.500
set_false_path -hold -from [get_regs {u_video_in/fifo/rg[*]}] -to [get_regs {u_video_in/fifo/rg1[*]}]
set_max_delay -from [get_regs {u_video_in/fifo/wg[*]}] -to [get_regs {u_video_in/fifo/wg1[*]}] -datapath_only 7.500
set_false_path -hold -from [get_regs {u_video_in/fifo/wg[*]}] -to [get_regs {u_video_in/fifo/wg1[*]}]
