# SC520CS / PH1P35 / TD 环境审计

审计日期：2026-10-02  
目标平台：HX1P35A / PH1P35MDG324  
目标摄像头：SC520CS  
工具：TangDynasty TD 6.2.1，工程记录版本 `6.2.168116`

## 结论

当前工作区已经具备 SC520CS Lab1/2/3 工程、TD 6.2.1 程序文件、许可文件和 SC520 Lab1 的软件构建产物，可以进入首次可复现构建审计。当前只能确认工程入口和软件构建证据，尚不能把视频链路称为已上板闭环。

## 环境入口

| 项目 | 位置 | 状态 | 证据类型 |
|---|---|---|---|
| TD executable | `.tools/td/app/bin/td.exe` | 存在 | `project` |
| TD license | `.tools/td/app/license/Anlogic.lic` | 存在 | `project` |
| SC520 原始资料与例程 | `SC520CS摄像头资料/` | 存在 | `project` |
| SC520 Lab1 原工程 | `SC520CS摄像头资料/lab_ex1_mipi_hdmi_SC520 (2)/lab_ex1_mipi_hdmi_SC520/lab_ex1_mipi_hdmi/` | 存在 | `project` |
| SC520 Lab2 | `SC520CS摄像头资料/lab_ex2_edge_SC520/` | 存在 | `project` |
| SC520 Lab3 | `SC520CS摄像头资料/lab_ex3_osd_SC520/` | 存在 | `project` |
| TD 工作副本 | `.tools/td/work/lab_ex1_mipi_hdmi_sc520/` | 存在 | `project` |
| 时钟修复候选副本 | `.tools/td/work/lab_ex1_mipi_hdmi_sc520_clockfix/` | 存在 | `project` |

TD 安装、许可和已有软件构建的历史说明见 [`tangdynasty.md`](tangdynasty.md)。SC520 工程型号说明见 [`../research/camera/sc520cs.md`](../research/camera/sc520cs.md)。

## Lab1 工程入口

工程根目录：

`SC520CS摄像头资料/lab_ex1_mipi_hdmi_SC520 (2)/lab_ex1_mipi_hdmi_SC520/lab_ex1_mipi_hdmi/`

关键文件：

- TD 工程：`td_project/camera_to_dsi_display.al`
- 时序约束：`td_project/camera_to_dsi_display.sdc`
- 引脚约束：`user_source/constraints_source/pin.adc`
- 顶层：`user_source/hdl_source/design_top_wrapper.v`
- SC520 配置控制：`user_source/hdl_source/uics520_cfg/uicfgcs520.v`
- SC520 720p 配置表：`user_source/hdl_source/uics520_cfg/uics520reg_720p60.v`
- SC520 2560×1920 备用配置表：`user_source/hdl_source/uics520_cfg/uics520reg_full_2560x1920_30.v`
- MIPI 接收：`user_source/hdl_source/mipi_dphy_rx/`
- CSI/ISP：`user_source/hdl_source/isp/`
- PH1P35 DDR：`user_source/hdl_source/ph1p35_ddr/`
- HDMI：`user_source/hdl_source/hdmi_tx.v`、`hdmi_mixer.v`、`hdmi_phy_warpper.v`
- PLL/FIFO/BRAM IP：`user_source/ip_source/`

`camera_to_dsi_display.al` 记录：

- `TD_Version`：`6.2.168116`
- `Family`：`PH1`
- `Device`：`PH1P35MDG324`
- `TOP_MODULE`：`design_top_wrapper`
- `mclk_freq`：`33MHz`

工程文件中的历史 `C:/Users/Cczzzzzq/Desktop/...` 仅是原始工程元数据；本地工程引用使用相对路径。对 57 个 `Path` 引用做了存在性检查，当前缺失数为 0。

## SC520 型号链路证据

`design_top_wrapper.v` 实例化 `uicfgcs520`。`uicfgcs520.v`：

- I2C sensor address：`8'h6c`
- sensor ID 检查值：`16'hee4b` 或 `16'h9e4b`
- 初始化表实例：`uics520reg_720p60`
- 自动曝光/增益表：`uics520regAE`、`SC520GainTbl`
- 代码注释声明目标模式为 `1280x720@60`

因此当前软件工程口径是 SC520CS；工程中保留的 `uics500_cfg` 文件属于自动排除或历史兼容文件，不能据此把当前工程判定为 SC500CS。

## 已有软件构建证据

工作副本：`.tools/td/work/lab_ex1_mipi_hdmi_sc520/`。

已有报告显示：

- `syn_1/flow.status`：TD `6.2.168116`、顶层 `design_top_wrapper`、器件 `PH1P35MDG324`；Setup WNS `860ps`、Hold WNS `114ps`、TNS `0ps`。
- `phy_1/route_flow.status`：Setup WNS `1242ps`、Hold WNS `20ps`、两类 TNS `0ps`。
- `phy_1/route.qor`：`12390` slices、`39` RAMs、`8` DSPs。
- `td_project/camera_to_dsi_display_Runs/best_result/camera_to_dsi_display.bit`：存在，大小 `1789539` bytes。

以上是工程/软件构建证据，不是 `measured` 硬件证据。

## 当前阻塞与风险

- `unknown/measured`：尚未下载到板卡，SC520 I2C 应答、sensor ID、MCLK 波形、MIPI 锁定、HDMI 画面和实际帧率均未验证。
- `project/unknown`：综合日志含位宽不一致、未连接端口和未驱动网络等普通告警，必须在 Goal 1 构建审计中分类，不能只看 WNS/TNS。
- `project/unknown`：物理实现日志含 `PHY-5060` 时钟网混合扇出告警；时钟修复副本另有普通 PLL/IO 告警，需结合报告和上板行为判定。
- `project/unknown`：工程约束包含 MIPI、PLL、DDR 和 HDMI 时钟关系，但真实板级管脚与模组修订仍需用板卡资料和实物确认。

## Task 1 静态检查结果

- TD executable：存在。
- TD license：存在。
- SC520 Lab1/2/3：存在。
- Lab1 顶层、`.al`、`.sdc`、`.adc`、SC520 配置模块和 IP 目录：存在。
- `.al` 相对路径引用：57 个，缺失 0 个。
- 当前结论：**Task 1 工程入口可定位；硬件验收仍未开始。**
