# Main_Proj

最终工程版本：2026-11-02。硬件：PH1P35MDG324（-3）、SC500CS 摄像头、7 寸 DSI 触摸屏（1024×600）。

- [工程入口](td_project/wb_ui_dsi.al)：使用 TD 6.2.168116 打开，顶层模块为 `design_top_wrapper`。
- [user_source/](user_source/)：RTL、IP、引脚约束和初始化数据。
- [bitstream/](bitstream/)：本版烧写文件。

编译时以 `td_project/` 为工作目录，执行综合、布局布线和位流生成。工程时序约束位于 `td_project/wb_ui_dsi.sdc`。

重新生成 `w8_d1024_rom` IP 时，将 `Mif_File` 选择为仓库内的 `user_source/ip_source/w8_d1024_rom/config_data_panel7.mif`。

直接烧写可使用 [压缩位流](bitstream/wb_ui_dsi_compress.bit)，另提供 [普通位流](bitstream/wb_ui_dsi.bit)。
