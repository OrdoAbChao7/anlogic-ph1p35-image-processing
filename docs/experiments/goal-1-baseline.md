# Goal 1：SC520CS 视频硬件闭环基线

## 实验状态

- 状态：`build-verified / hardware-blocked`
- 目标：`SC520CS → MIPI CSI-2 → PH1P35 → HDMI`
- 当前工程：`SC520CS摄像头资料/lab_ex1_mipi_hdmi_SC520 (2)/lab_ex1_mipi_hdmi_SC520/lab_ex1_mipi_hdmi/`
- TD 版本：`6.2.168116`
- 器件：`PH1P35MDG324`
- 顶层：`design_top_wrapper`
- 证据分类：以下软件信息为 `project`；硬件画面和帧率暂为 `unknown`。

## 工程链路

当前顶层已经出现以下链路信号和模块边界：

`SC520 I2C/MCLK/RESET → MIPI D-PHY RX → CSI unpack / RAW10 → ISP demosaic/AWB → DDR write/read → HDMI video timing/mixer/TMDS`

具体接口位宽、同步语义、跨时钟域和固定延迟尚未在 Goal 2 接口合同中完成审计，不把本段推断当作完整接口结论。

## 软件基线证据

来自 `.tools/td/work/lab_ex1_mipi_hdmi_sc520/td_project/camera_to_dsi_display_Runs/`：

| 阶段 | 结果 |
|---|---|
| Synthesis | 2026-10-02 新构建；Setup WNS `860ps`、Hold WNS `114ps`、TNS `0ps` |
| Physical design | 2026-10-02 新构建；Setup WNS `1242ps`、Hold WNS `20ps`、TNS `0ps` |
| Resource | 新构建 `route.qor`：`12390` slices、`39` RAMs、`8` DSPs |
| Bitstream | 新构建位于 `phy_1/camera_to_dsi_display.bit`，`1789539` bytes；SHA-256 见 [`build-summary.md`](../build/goal-1-sc520-lab1/build-summary.md) |
| Path audit | `.al` 中 57 个相对路径引用，缺失 0 个 |

完整构建摘要见 [`docs/build/goal-1-sc520-lab1/build-summary.md`](../build/goal-1-sc520-lab1/build-summary.md)。本次新 `phy_1` 位流与 `best_result` 旧位流哈希不同，后续上板必须使用新构建路径并记录 Bitstream 哈希。

## 未完成验收

- [x] 用当前 TD 6.2.1 工作副本重新执行可复现构建并记录本次日志、时序、资源和位流哈希。
- [ ] 按板卡和模组资料完成 SC520CS、HX1P35A、下载器、HDMI 显示器接线记录。
- [ ] 下载并记录 Bitstream 标识。
- [ ] 验证 SC520 I2C sensor ID、初始化完成和 MIPI 接收状态。
- [ ] 验证 HDMI 原始画面、分辨率、帧率和连续运行。
- [ ] 验证重新下载、热复位和冷启动恢复。
- [ ] 分类综合/实现告警，尤其是位宽、未连接、未驱动和 `PHY-5060` 时钟告警。

## 阶段判断

Goal 1 **尚未通过**。当前已达到“软件构建可追溯”，但 Task 3 被当前主机未识别到下载器/开发板阻塞；在没有下载和屏幕/测量证据前，不进入算法接入阶段。阻塞记录见 [`docs/evidence/goal-1/2026-10-02-bringup.md`](../evidence/goal-1/2026-10-02-bringup.md)。

## 下一步

进入计划 Task 3：使用 [`build-summary.md`](../build/goal-1-sc520-lab1/build-summary.md) 中 `phy_1` 的新位流做上板下载和 Goal 1 硬件闭环验证。若当前没有板卡、摄像头、下载器或显示器，则记录硬件阻塞，不把软件构建结果升级为硬件通过。
