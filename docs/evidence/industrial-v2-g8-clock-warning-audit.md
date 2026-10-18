# Industrial Vision V2 G8 时钟告警审计

状态：`OPEN`。本记录绑定一次当前七功能正式顶层的独立 TD 重建，用于补足告警来源和重复构建证据；不把告警解释为已关闭。

## 构建证据

- 日期：2026-10-19（Asia/Shanghai）
- 工作树：`E:/Projects/FPGA-v2`
- 源码提交：`0e4c305fc53c0d7ba1dc47412d074c40c7615f0d`
- 器件：`PH1P35MDG324`
- TD：`v6.2.168116`
- 输入包：`fallback/td_package`
- 独立构建目录：`work/td_industrial_v2_warning_audit2/`
- 原始物理日志：`work/td_industrial_v2_warning_audit2/td_project/camera_to_dsi_display_Runs/phy_1/flow_exec.log`
- 构建结果：TD 综合、P&R、STA、Bitgen exit `0`
- 本次候选 Bitstream SHA-256：`f268aca98be49ccc4feef4c0d34a02976a57654740152d40f35a46e06025998f`

本次独立构建 QoR 为 Slice `18244/21216`（`85.99%`）、RAM `43`、DSP `24`、Setup WNS `+127 ps`、Hold WNS `+20 ps`、Setup/Hold TNS `0/0`。它没有替换正式候选目录；同一源码的此前候选为 Slice `18261/21216`、Setup WNS `+100 ps`、Bitstream SHA-256 `60aea582cff6fa2d5a03eaa5f1d9aab4bdc142371af86053d04f8acf40e9ebc1`。两次结果说明 TD P&R 结果存在运行间波动，必须以冻结构建和重复性实验作为发布依据。

## 原始告警

本次 `phy_1/flow_exec.log` 记录：

| 告警 | 原始定位 | 当前判定 |
|---|---|---|
| `PHY-5016` | PLL `clkc` 驱动无 location 的 IO，且不是 clock-capable IO | `OPEN`；需要 PLL/IP 输出和管脚约束核对 |
| `PHY-5060` | `u_uicfgcs520/u_i2c/scl_clk`：1 个 clock pin、2 个 data/ctrl sink；`O_cam_24m_syn_3`：160 个 clock pin、1 个 data/ctrl sink | `OPEN`；需区分 I2C 内部时序与外部摄像头时钟输出 |
| `PHY-5079` | 2 个时钟网使用 local routing，标记 1 个；CTS 表中 `scl_clk` 为 `1/3` fanout、12 个 local wire，`pll_clk_24m` 为 `111/112` fanout、3 个 local wire | `OPEN`；需时钟网络详细分析和硬件稳定性证据 |
| `PHY-5088` | clock analyzer 报告 1 个 clkin 非时钟 sink、1 个 clkout 非时钟 sink，以及 2 个时钟网驱动其他时钟网；前置 DRC 检查曾报告 3 个 clock-net | `OPEN`；需 `analyze_clock -detail` 和逐网 sink/约束审计 |

## 2026-10-19 详细分析重跑

在提交 `73e4048c7830db069d800fe18e0d542692072d7d` 上，使用 placement seed `1` 的隔离派生 Flow，在 `route` 后执行了 `analyze_clock -detail`。构建完整通过，诊断候选位于 `release/candidates/industrial-v2-clock-detail-seed1/`，Bitstream SHA-256 为 `d58a8640d9b3d3d6c19842053ee5159e723842152172c1583ad29602fadb2e3a`。

详细输出确认：

- `u_uicfgcs520/u_i2c/scl_clk` 被标记为 clkin 非时钟 sink 混合 fanout；
- `O_cam_24m_syn_3` 被标记为 clkout 非时钟 sink 混合 fanout；
- `O_cam_24m_dup_1...sclk_outnet` 驱动 `u_uicfgcs520/u_i2c/scl_clk_reg_syn_9`，再进入 `u_uicfgcs520/u_i2c/scl_clk`，形成时钟网级联；
- `pll_clk_24m` / `O_cam_24m_dup_1...sclk_outnet` 使用 local routing；
- `PHY-5016` 的 PLL `clkc` 无 location 且不是 clock-capable IO 的告警仍存在。

详细摘录见 `docs/evidence/industrial-v2-g8-clock-warning-detail-log.txt`；这次分析补足了 source/sink 定位，但没有补足官方 pin/IP 合同或板级稳定性证据，所以四类告警继续保持 `OPEN`。

## 工程判断与边界

- `O_cam_24m` 在 `pin.adc:5` 约束到 `L3`，并在 `design_top_wrapper.v:538` 由 `S_24m_clk` 驱动，属于摄像头外部时钟输出；但不能仅因其名字、已有 pin assignment 或正时序就把混合 fanout 标为无害。
- `u_uicfgcs520`、PLL、MIPI、DDR 和板级约束包含厂商/板级边界；本次没有盲改生成 IP、PLL 配置、管脚或时序例外。
- 早期审计构建没有执行 `analyze_clock -detail`；本节记录的重跑已经执行该命令，但仍没有板卡、SC520CS、HDMI、冷启动或长稳证据，因此告警门保持 `BLOCKED`。

## 关闭条件

对每个告警保存详细时钟分析输出，解释 source/sink/约束和协议保证；如果需要修改 RTL/IP/约束，完成最小修改后重跑完整 TD，并重新进行冷启动、热复位和长稳测试。未满足前不得把 `PHY-5016/5060/5079/5088` 标为关闭。
