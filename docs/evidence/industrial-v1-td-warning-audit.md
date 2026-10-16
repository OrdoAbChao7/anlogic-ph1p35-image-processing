# fixed-red v1 TD 告警归类记录

本记录对应 2026-10-17 本轮完整 TD 构建，构建时 Git HEAD 为 `e27c1c1`，OSD 逐行字库优化已包含在 manifest 的源码哈希中；工具为 Tang Dynasty `v6.2.168116`，器件为 `PH1P35MDG324 / Speed 3`。告警来自：

`work/td_industrial/td_project/camera_to_dsi_display_Runs/syn_1/flow_exec.log`

和

`work/td_industrial/td_project/camera_to_dsi_display_Runs/phy_1/flow_exec.log`。

## 结论摘要

本轮 TD exit code 为 `0`，Route QoR 为 Setup WNS `+116 ps`、Hold WNS `+20 ps`、TNS `0`；Slice `20,159/95.02%`。相对 HDMI 时序修复基线减少 `702 slices`、DSP 从 `26` 降至 `24`，但仍超过 95% 资源警戒线和项目 80% 目标。这些数值只证明 STA 报告没有违例，不会自动关闭下面的结构性告警。当前没有对厂商 IP 或时钟网络做未经证据支持的屏蔽和修改，因此告警保持可见并列入 Stage G 风险。

| 告警 | 定位 | 当前归类 | 是否关闭 |
|---|---|---|---|
| `SYN-5011` / `SYN-5025` | 生成的 DDR/BRAM 初始化宏，例如 `ph1p_ddrphy_init.v(73)` 的 `ramread0_syn_24/25.di[*]`；日志明确写出未驱动端被置 0 | 厂商生成 IP 的未驱动初始化数据端；未修改 vendor RTL，需结合 IP 配置和板级 DDR 初始化确认 | **OPEN** |
| `HDL-5314` / `HDL-5317` / `HDL-5323` | DDR PHY、Demosaic、FIFO 和 divider 生成源中的未连接/未驱动端 | 生成 IP/存根端口告警；不能仅因 bitgen 成功而判定无害 | **OPEN** |
| `SYN-5065` | `color_detect_96_v2.v` 的 `O_invalid`、`acc_invalid` 被工具识别为同时存在异步复位/置位语义 | 当前工业 RTL 的综合解释风险；仿真和 STA 已通过，但尚未完成结构改写或门级/板级确认 | **OPEN** |
| `PHY-5060` | `O_cam_24m_syn_3`（160 个时钟扇出 + 1 个数据/控制扇出）；`u_uicfgcs520/u_i2c/scl_clk`（1 个时钟扇出 + 2 个数据/控制扇出） | 混合时钟/数据扇出，需审查实际 sink 和约束；不能凭 WNS 正值关闭 | **OPEN** |
| `PHY-5016` | PLL `clkc` 驱动无 location 的 IO，且不是 clock-capable IO | 板级时钟引脚/约束风险，需原理图、约束和上板波形确认 | **OPEN** |
| `PHY-5079` | 1 个时钟网络使用 local routing resources | 时钟路由风险，需 `analyze_clock -detail` 和上板稳定性证据 | **OPEN** |
| `PHY-5088` | clock analyzer 检出 buffer 驱动非时钟 sink、clock 驱动其他 clock net | 时钟树结构风险，需逐网审查；未通过关闭告警 | **OPEN** |
| `PHY-7022` | 物理设计估算 Slice 利用率仍超过 95% 上限，最终 QoR 为 95.02% | 资源和 P&R 余量风险；OSD 字库优化已量化减少 702 slices，但仍需继续优化或取得板级证据 | **OPEN** |
| `PRJ-5611` | Logo ROM 与摄像头寄存器文件 CompileOrder 相同 | 工程编译序号冲突；本轮未导致综合失败，但应在后续项目文件整理中固定唯一序号 | **OPEN** |

## 已确认的边界

- 没有把以上任何告警改写成“无害”或“已修复”。
- 没有修改厂商 DDR、MIPI、HDMI、PLL 或约束生成文件来换取表面通过。
- `route.qor` 的正时序只作为时序结果记录；它不替代 CDC、时钟树、DDR 初始化和板级验证。
- 下一步关闭条件是：逐项给出来源、sink/约束解释、必要的最小修改或官方 IP 依据，并重跑完整 TD；涉及摄像头/DDR/PLL/HDMI 的项还需要真实板卡冷启动、热复位和长稳证据。
