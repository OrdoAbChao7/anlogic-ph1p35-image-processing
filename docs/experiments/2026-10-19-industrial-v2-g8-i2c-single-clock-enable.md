# Industrial V2 G8：I2C 单时钟边沿使能探针

## 状态

`NOT_PROMOTED_RESOURCE_REPRODUCIBILITY_AND_WARNING_GATES`。经用户批准，在隔离工程中将 I2C 控制器内部事件统一改为 `posedge I_clk`，由半周期边沿使能推进；原工程 RTL、正式候选和发布位流均未修改。12 组 Icarus 等价仿真通过。初始 TD 试验完成且时序干净，但后续受控 A/B 发现该次 85.83% 资源结果并非可归因于单一 I2C 改动；两次严格单变量候选的 Slice 分别为 80.98% 和 86.48%，相同 seed 仍存在明显实现波动。该方案消除了 SCL 派生时钟告警，但 MCLK/DDR PHY 告警仍开，因此不晋升。

## 输入与隔离范围

- 器件：`PH1P35MDG324`；TD：`6.2.168116`；官方 `DefaultFlow.tcl`；placement seed：`1`。
- 参考 I2C 源：`fallback/td_package/user_source/hdl_source/uics500_cfg/uii2c.v`，SHA-256 `032df05881f9bd7c7cf86cc1381adcb739a18f8a8744ed06b1160ac294a6dc0d`。
- 仿真候选：`fallback/sim/config/uii2c_single_clock_candidate.v`，SHA-256 `4ca0e3321df8c38e90129f9d1954454b9d4ceaded80868db5e7db99af83ace8c`。
- TD 候选副本：`work/td_i2c_single_clock_input/user_source/hdl_source/uics500_cfg/uii2c_single_clock.v`，SHA-256 `9184ee498d25278afec0305e7322331d459f6dcaaf0a38e058337ca4d54ddf5a`。
- 后续包差审计确认，此次原始 TD 输入包除 `.prj` 改为引用候选源外，也包含不同的 `design_top_wrapper.v` 和额外候选文件；因此本次原始 85.83% 结果不能作为单一 I2C RTL 改动的因果对照。精确单变量结果见 [`受控 A/B 实验`](2026-10-19-industrial-v2-g8-i2c-single-clock-controlled-ab.md)。
- 没有写入正式 `fallback/td_source` 或 `release/industrial-v2/`，没有下载或操作板卡。

## 功能等价验证

`tb_i2c_single_clock_equivalence.v` 将参考实现与候选逐周期比较 SCL、SDA 采样/驱动、busy、bus_error、read data 和 master SDA 输出，覆盖读写及仅写事务。

- `CLK_DIV` ACK 组合：`0, 1, 2, 3, 6, 7, 49, 50, 499`，9 组全部 `TB_I2C_SINGLE_CLOCK_EQUIVALENCE_PASS`。
- NACK 组合：`CLK_DIV=7, 49, 499`，3 组全部 PASS，读数据为 `FF`；ACK 组读数据为 `00`。
- 共 12 组配置，仿真无 mismatch、timeout 或非零退出码。

## TD、STA 与时钟告警

TD/STA/Bitgen 完成，候选 Bitstream SHA-256 为 `03bfb4bc820ef4e9e3b9727d05e8e6ddb2ca0be972fbf0b31dd78fec8fe296b5`（1,370,225 bytes）。该位流只保存在 `release/candidates/industrial-v2-i2c-single-clock-enable-seed1/`，未下载。

| 最终路由指标 | 结果 |
|---|---:|
| Setup WNS / TNS / violated endpoints | `+112 ps / 0 / 0` |
| Hold WNS / TNS / violated endpoints | `+20 ps / 0 / 0` |
| Slice | `18,209 / 21,216 = 85.83%` |
| RAM / DSP | `43 / 24` |

Slice 超过 `<=85%` 资源门 `0.83` 个百分点。综合阶段另记录 DDR PHY 的 `SYN-5011/5025` 未驱动输入告警及 `80` 个 unconstrained timing 点；最终路由时序通过不关闭这些告警或整体约束审计。

原始 `phy_1/flow_exec.log` 记录 `PHY-5016` ×4、`PHY-5060` ×1、`PHY-5079` ×1、`PHY-5088` ×4。只读 `analyze_clock -detail` 将候选时钟支路定位为 `O_cam_24m_syn_3`：该派生 SCLK 支路有 `125` 个 clock sinks 和 `1` 个 data/other sink，对应 `O_cam_24m` 顶层 HD pad；clock utilization 表同时记录该支路使用 3 条 local wire，触发 `PHY-5079`。同 seed 的既有 MCLK/ODDR 试验详细分析没有 `O_cam_24m_syn_3`、`PHY-5060` 或 `PHY-5079`，但已有其它 `PHY-5088` 级联/缓冲告警。该差异与本候选相关是 `project` 观测；其精确综合网表成因仍属 `inferred`，不能宣称已关闭时钟问题。

## 结论与边界

该候选证明逐周期 I2C 行为可以由单一 `I_clk` 加边沿使能复现。原始构建未通过资源门；后续严格单变量 A/B 试验中，一次低于 85%、一次高于 85%，且 MCLK/DDR PHY 告警仍在，故目前没有稳定资源通过或警告闭环证据。无硬件下载、摄像头波形、视频、复位或长稳证据。保留隔离产物供比较，不推进为正式 RTL。

主要证据见 [`industrial-v2-g8-i2c-single-clock-enable-log.txt`](../evidence/industrial-v2-g8-i2c-single-clock-enable-log.txt)、隔离构建的原始 `flow_exec.log`、candidate `route.qor`、`final_timing.rpt`、`place_clock_utilization.txt` 和 `analyze_clock_detail.tcl`。
