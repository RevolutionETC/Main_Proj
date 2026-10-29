# Hust508 最终工程

当前主分支的最新工程为 **20261028_RESTORED_ROUTED**，由最终交付包 `ISP_RGB_SC500_RESTORED_ROUTED_20261028.zip` 导入，工程入口位于 **[project/](project/)**。

| 内容 | 入口 |
|---|---|
| 完整原始压缩包 | [下载最终工程 ZIP](downloads/ISP_RGB_SC500_RESTORED_ROUTED_20261028.zip) |
| 最终工程说明与操作 | [README_整合说明.md](project/README_整合说明.md) |
| 推荐压缩烧写文件 | [DSI_ISP_RGB_INTEGRATED_SC500_7inch_compress.bit](project/DSI_ISP_RGB_INTEGRATED_SC500_7inch_compress.bit) |
| 普通烧写文件 | [DSI_ISP_RGB_INTEGRATED_SC500_7inch.bit](project/DSI_ISP_RGB_INTEGRATED_SC500_7inch.bit) |
| TD 工程 | [wb_ui_dsi.al](project/td_project/wb_ui_dsi.al) |
| 资源与验证记录 | [资源与验证结果.md](project/资源与验证结果.md) |
| 原生工具资格记录 | [NATIVE_QUALIFICATION.json](project/NATIVE_QUALIFICATION.json) |
| 本次上传与校验说明 | [最终交付导入记录](docs/FINAL_DELIVERY_20261028.md) |

本版保留八种图像模式、自动/环境预设/手动白平衡、AB/GM 色偏、八目标识别、半透明 ISP 菜单和画面信息页。预览画面**单指向左滑动**打开菜单；具体手势和页面行为以随包工程说明为准。

随包记录为 45 项回归通过，TD 最终 SWNS `+0.067 ns`、HWNS `+0.020 ns`，DSP `34/40`。这些是 2026-10-28 交付包中的既有验证结果；本次上传核对了文件和对应记录的完整性，实物验收状态见包内说明。

硬件：PH1P35MDG324、SC500CS、7 寸 DSI / 1024×600。建议将压缩包解压到较短路径，例如 `C:/FPGA/ISP_RGB`，保留内部目录结构。

`project/` 内的 975 个文件与用户指定的最终压缩包逐字节一致。历史阶段目录 `lab_*` 和旧文档保留用于回溯；当前源码、界面和烧写文件以以上入口为准。
