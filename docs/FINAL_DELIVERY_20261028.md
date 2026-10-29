# 最终工程上传记录

上传日期：2026-10-29（Asia/Shanghai）。交付版本：`20261028_RESTORED_ROUTED`。

## 工程位置

主分支的 `project/` 已替换为 `ISP_RGB_SC500_RESTORED_ROUTED_20261028.zip` 内 `ISP_RGB_SC500_INTEGRATED/` 的完整内容；仅去掉外层目录名，内部相对路径与全部文件字节不变。

- 原始压缩包：[downloads/ISP_RGB_SC500_RESTORED_ROUTED_20261028.zip](../downloads/ISP_RGB_SC500_RESTORED_ROUTED_20261028.zip)
- 压缩包大小：4,305,011 字节。
- 压缩包 SHA-256：`715196185d6b9f54b11c871e6992a22578ec23c791df7d0a4a8ad738e1b16452`。
- 工程文件：975 个；交付清单列出其中 974 个文件，清单本身为第 975 个。
- 替换前 main 提交：`3402b9795baddfa1e7fcc62ccabbd505e80cbeb0`；旧版可通过 Git 历史回溯。

当前工程的使用说明、烧写文件命名和构建步骤见 [最终工程说明](../project/README_整合说明.md)。原始 ZIP 同步保留，方便直接下载和还原。

## 本次实际校验

1. 读取压缩包全部文件并检查 CRC、路径及重复文件。
2. 核对 `DELIVERY_MANIFEST.json` 中全部 974 项大小与 SHA-256。
3. 核对 279 项布线源码冻结哈希、19 项构建配置哈希。
4. 检查三份 TD 工程的内部相对依赖，每份均为 104 项有效引用。
5. 核对普通/压缩 bitstream、资格记录及 45 项回归记录的对应哈希。
6. 上传前检查 Git 中 `project/` 的文件集合及内容与压缩包完全一致，防止忽略规则漏掉交付文件。

## 随包构建记录

`NATIVE_QUALIFICATION.json` 状态为 `qualified`，94 项资格检查通过，无失败项。`SOURCE_VALIDATION.json` 记录 45 项回归、SWNS `+0.067 ns`、HWNS `+0.020 ns`，DSP `34/40`。原始日志和报告位于 `project/build_evidence/current_native/`。

上述仿真和原生工具结果来自最终交付包；本次操作范围是上传与完整性校验，没有重新生成源码、字体或烧写文件。包内说明仍标记尚未完成实体开发板测试。

## 版本入口调整

仓库首页与 `docs/latest/README.md` 已改为链接本版说明和烧写文件。旧 `lab_*` 历史工程和其他文档保持原有内容；旧版文件名、长按手势、单目标限制和旧资源数值不适用于本版时，以当前包内说明为准。
