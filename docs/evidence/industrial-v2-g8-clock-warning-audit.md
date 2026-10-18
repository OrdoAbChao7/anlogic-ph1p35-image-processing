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

## 工程判断与边界

- `O_cam_24m` 是摄像头外部时钟输出，不能仅因其名字或正时序就把混合 fanout 标为无害。
- `u_uicfgcs520`、PLL、MIPI、DDR 和板级约束包含厂商/板级边界；本次没有盲改生成 IP、PLL 配置、管脚或时序例外。
- 本次没有执行 `analyze_clock -detail`，也没有板卡、SC520CS、HDMI、冷启动或长稳证据，因此告警门保持 `BLOCKED`。

## 关闭条件

对每个告警保存详细时钟分析输出，解释 source/sink/约束和协议保证；如果需要修改 RTL/IP/约束，完成最小修改后重跑完整 TD，并重新进行冷启动、热复位和长稳测试。未满足前不得把 `PHY-5016/5060/5079/5088` 标为关闭。
