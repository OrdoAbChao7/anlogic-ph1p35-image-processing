# Goal 1 / SC520 Lab1 构建归档

构建日期：2026-10-02  
证据类型：`project`（软件构建）；未包含上板 `measured` 证据。

## 结论

当前 SC520 Lab1 工作副本已经使用 TD `6.2.168116` 完成一次新的综合、布局布线和位流生成。最终时序通过：Setup WNS `1242ps`、TNS `0ps`，Hold WNS `20ps`、TNS `0ps`。可用于后续上板尝试的本次位流位于 `phy_1` 输出目录。

Goal 1 仍未通过：尚未完成下载、摄像头应答、HDMI 画面、帧率、复位和长稳实测。

## 构建边界

- TD：`.tools/td/app/bin/td_commands_prompt.exe`
- TD 版本：`Tang Dynasty v6.2.168116`
- 工作副本：`.tools/td/work/lab_ex1_mipi_hdmi_sc520/`
- 工程：`.tools/td/work/lab_ex1_mipi_hdmi_sc520/td_project/camera_to_dsi_display.al`
- 器件：`PH1P35MDG324`
- 顶层：`design_top_wrapper`
- 构建前清单：`.tools/td/logs/sc520-lab1-manifest-20261002.txt`
- 清单 SHA-256：`BF6EE20A6115C7B460C66AA07949B221AECCAB1187A4925A4A8046BBB077C494`

本次调用方式为从各 Run 目录执行 TD 脚本：

```text
E:/Projects/FPGA/.tools/td/app/bin/td_commands_prompt.exe E:\Projects\FPGA\.tools\td\app/arch/../doc/scripts/DefaultFlow.tcl
```

先在 `syn_1` 完成综合，再在 `phy_1` 完成物理实现和位流生成。原始 SC520 源文件和 `.al` 工程未修改。

## 新构建结果

### 综合

来源：`.tools/td/work/lab_ex1_mipi_hdmi_sc520/td_project/camera_to_dsi_display_Runs/syn_1/flow.status`

| 项目 | 结果 |
|---|---:|
| Setup WNS | `860ps` |
| Setup TNS | `0ps` |
| Hold WNS | `114ps` |
| Hold TNS | `0ps` |
| 综合耗时 | `1m44s` |

综合映射输出中记录：`13685` registers、`9449` LUTs、`3432` slices、`39` RAMs、`8` DSPs。该资源摘要来自 TD 综合日志，最终实现资源以 `route.qor` 为准。

### 物理实现

来源：`.tools/td/work/lab_ex1_mipi_hdmi_sc520/td_project/camera_to_dsi_display_Runs/phy_1/route_flow.status` 和 `route.qor`

| 项目 | 结果 |
|---|---:|
| Setup WNS | `1242ps` |
| Setup TNS | `0ps` |
| Hold WNS | `20ps` |
| Hold TNS | `0ps` |
| 违反 Setup 端点 | `0` |
| 违反 Hold 端点 | `0` |
| Slices | `12390`（`58.40%`） |
| RAMs | `39` |
| DSPs | `8` |
| DRAMHARDCON | `37` |

布局阶段曾出现 Hold WNS `-284ps`、TNS `-74138ps`，随后 `fix_hold` 完成修复；最终 `route.qor` 为非负 WNS、TNS `0`。因此只引用最终结果，同时保留该中间风险事实。

### 位流

本次新生成文件来自：

`.tools/td/work/lab_ex1_mipi_hdmi_sc520/td_project/camera_to_dsi_display_Runs/phy_1/`

| 文件 | 大小 | SHA-256 |
|---|---:|---|
| `camera_to_dsi_display.bit` | `1789539` bytes | `A3117B3CA6BB68326DA2B14914B713FD9DE49DCC4A2B9FDE8A8ABB19F9FF6010` |
| `camera_to_dsi_display_compress.bit` | `1347185` bytes | `04A9A47CA5EFF2C13F1767279C9DC8742D2DF1DEB121D7D441C8DCB7272EE7C7` |

TD 位流日志记录了普通位流和压缩位流均生成成功。`best_result/` 中同名文件哈希不同，属于旧产物，不能作为本次构建的 Bitstream 标识。

## 告警摘要

来源：`syn_1/run.log`、`phy_1/run.log`。

- 综合日志匹配到 `122` 条 `WARNING`/相关严重级别文本，主要类别包括 DDR/HDMI 端口位宽差异、未连接端口、未驱动网络、RAM_STYLE 被自动推断、DDR/IP 未驱动引脚，以及异步 reset/set 描述。
- 物理实现日志匹配到 `13` 条 `WARNING`/`CRITICAL-WARNING` 文本。
- 关键物理告警：`PHY-5060` 报告 `u_uicfgcs520/u_i2c/scl_clk` 和 `O_cam_24m_syn_3` 存在时钟/数据混合扇出；`PHY-5079` 报告 1 条时钟网使用 local routing；`PHY-5088` 报告时钟缓冲器驱动非时钟端、时钟网驱动其他时钟网。
- 这些告警尚未被硬件实测证明无害，必须在上板阶段观察 I2C、MIPI 锁定、HDMI 画面和长稳行为；不得以时序通过替代告警关闭。

## Task 2 判定

Task 2：**完成，退出条件为“原始 SC520 Lab1 构建成功”**。  
下一入口：Task 3，上板下载与 Goal 1 硬件闭环验证。
