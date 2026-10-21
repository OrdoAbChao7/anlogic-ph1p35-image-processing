# Industrial V2 G8：I2C counter-derived event-phase 探针

## 状态

`REJECTED_RESOURCE_GATE`。本次在隔离 TD 输入包中取消 `scl_clk` 寄存器反馈，使用 `clkdiv` 直接形成事件相位，并把外部 SCL 相位寄存到 `I_clk` 域。直接 I2C 仿真和完整 TD/STA/Bitgen 均通过；在本次 seed=1 运行中，I2C 相关 PHY-5016/PHY-5088 行消失，但 Slice 达 `85.54%`，超过 `<=85%` 资源门，且 MCLK 的 PHY-5060/PHY-5079 仍存在，因此不提升为正式候选。

## 输入与变更

- 目标器件：`PH1P35MDG324`
- TD：`6.2.168116`
- Flow：官方 `DefaultFlow.tcl`
- placement seed：`1`
- 输入包：`fallback/td_package/` 的隔离副本
- 变更脚本：`scripts/prepare_i2c_counter_phase.py`
- 变更文件：`user_source/hdl_source/uics500_cfg/uii2c.v`
- 变更源 SHA-256：`114c6f265e16ddca1a3336fa209300e2646e6e93d452daa86673369356f78af8`

变换加入 `FULL_DIV = 2 * (SCL_DIV + 1)`，将 `scl_clk` 改为 `clkdiv > SCL_DIV` 的组合事件相位，同时用 `I_clk` 域寄存器更新 `scl_r`，并在两个半周期位置更新 `scl_offset`。原始 `posedge/negedge scl_clk` 状态机保持不变。

## 后续结构审计：仍是派生事件时钟

对变换后源码逐个检查事件控制可见，状态机、SDA 发送/采样及 busy/error 寄存器仍使用 `posedge scl_clk` 或 `negedge scl_clk`。因此该变换只移除了 `scl_clk` 的反馈寄存器，并未把 I2C 内部时序改成单一 `I_clk` 域的 clock-enable 结构；它不是派生时钟修复。原构建中 I2C PHY-5016/PHY-5088 行未出现，只能说明该次 TD 运行的告警扫描结果，不能证明结构已消除。后续组合探针的 `analyze_clock -detail`/时钟状态报告又将 `u_uicfgcs520/u_i2c/scl_clk` 记录为 `AL_PHY_LSLICE` 生成，进一步确认派生事件时钟仍存在。此前将其称为“避免派生 SCL 时钟”的结论应作废；资源拒绝结论及该次日志中的告警行事实不变。

## 验证结果

- `python -B -m pytest -q work/tests/test_v2_i2c_counter_phase.py`：`2 passed`
- vendor 与候选均完成直接 I2C 事务，`rd_data=00`、`scl_transitions=59`
- `python -B -m pytest -q work/tests`：`141 passed in 2.20s`

TD/STA/Bitgen 候选位于 `release/candidates/industrial-v2-i2c-counter-phase/`：

| 指标 | 结果 |
|---|---:|
| 最终路由 Setup WNS / TNS / violated S-EP | `+113 ps / 0 / 0` |
| 最终路由 Hold WNS / TNS / violated H-EP | `+20 ps / 0 / 0` |
| Slice | `18148/21216 = 85.54%` |
| RAM / DSP / DRAMHARDCON | `43 / 24 / 229` |
| Bitstream SHA-256 | `e32361cfc89d6264678e6e0da5f1bda9bf252cafc12c270b05fc48a78eac4f92` |

最终 PHY 日志只保留两类告警：`PHY-5060` 的 `O_cam_24m_syn_3` mixed fanout，以及 `PHY-5079` 的 local clock routing。该结果是本次隔离 seed=1 构建的观测，不构成对其他 seed 或正式候选的保证。

## 结论

该结构是目前 I2C 告警削减最有效的候选之一，但仍越过资源门 `0.54` 个百分点；正式候选、正式 Bitstream 和默认工作区均未修改。硬件下载、摄像头波形、HDMI、冷启动和长稳均未执行。
