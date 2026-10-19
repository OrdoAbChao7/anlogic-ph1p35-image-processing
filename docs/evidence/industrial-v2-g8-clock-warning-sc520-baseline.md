# V2 G8 时钟告警与 SC520 Lab1 基线对照

日期：2026-10-19  
证据类型：`project`（本地 SC520 Lab1 构建日志与工程文件）  
状态：`OPEN`，不构成告警关闭

## 对照对象

本次对照了本机保存的 SC520 Lab1 构建与当前 V2 TD 输入：

| 对象 | 路径 |
|---|---|
| SC520 Lab1 约束 | `E:/Projects/FPGA/.tools/td/work/lab_ex1_mipi_hdmi_sc520/user_source/constraints_source/pin.adc` |
| SC520 Lab1 TD 日志 | `E:/Projects/FPGA/.tools/td/work/lab_ex1_mipi_hdmi_sc520/td_project/camera_to_dsi_display_Runs/phy_1/td_20261002_212115.log` |
| V2 约束 | `fallback/td_package/user_source/constraints_source/pin.adc` |
| V2 顶层 | `fallback/td_package/user_source/hdl_source/design_top_wrapper.v` |

外部基线文件校验值：`pin.adc` SHA-256 `99c31a6c3d949e35848184c7cef3c11487e98fa5e803123e84541fbe96d98dbe`；TD 日志（175538 bytes）SHA-256 `6677637fdb6f4c7f093060f599b6058d4b8bc8b1ac29a53628ea37e4fe404ff6`。

## 观察结果

SC520 Lab1 与 V2 的 `pin.adc` 对摄像头时钟、I2C 和复位使用相同管脚合同：

```text
O_cam_scl  -> K3
IO_cam_sda -> J3
O_cam_24m  -> L3
O_cam_rst  -> L2
```

V2 顶层在 `design_top_wrapper.v:538` 将 `S_24m_clk` 直接连接到 `O_cam_24m`；SC520 Lab1 顶层也使用同一类 PLL 输出到摄像头 MCLK 的结构。

SC520 Lab1 日志 `td_20261002_212115.log` 中明确出现：

| 告警 | 日志行 | 观察 |
|---|---:|---|
| `PHY-5060` | 141–142 | `u_uicfgcs520/u_i2c/scl_clk` 与 `O_cam_24m_syn_3` 混合 fanout |
| `PHY-5016` | 211–214 | PLL `clkc` 驱动无 location、非 clock-capable IO |
| `PHY-5088` | 918–920、1594–1596 | clock analyzer 报告非时钟 sink 和 clock-net 级联 |
| `PHY-5079` | 1586 | 存在 local routing clock net |

这表明当前 V2 的四类告警至少在本地 SC520 Lab1 基线中已经存在，不能简单归因于 V2 七功能逻辑；同时也说明它们是该板级/TD 边界上的已知未闭合风险。

## 判定边界

- 这是同工程族基线的日志对照，不是安路官方“告警无害”声明。
- 基线曾有构建通过或用户报告画面，不等价于对 V2 当前 Bitstream 的告警闭环、冷启动、长稳或 MCLK 波形证明。
- 不能因为基线也有这些告警，就把 V2 的 `PHY-5016/5060/5079/5088` 改成 PASS；当前 warning/CDC/constraints gate 继续为 `OPEN/BLOCKED`。

## 关闭所需证据

仍需把当前 V2 Bitstream、SC520CS 模组、PH1P35 板卡和实际下载配置绑定起来，取得 MCLK、I2C、复位、MIPI 锁定以及 HDMI 长稳的原始测量记录，并逐项说明告警对应的协议保证或完成最小 RTL/IP/约束修复后的完整重建。
