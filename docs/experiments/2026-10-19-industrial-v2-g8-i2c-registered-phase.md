# Industrial V2 G8：I2C registered-phase 探针

## 状态

`REJECTED_RESOURCE_AND_WARNING_CLOSURE`。本次在隔离 TD 输入包中保留 `scl_clk` 作为事件时钟，但把 `scl_r` 改成 `I_clk` 域寄存器，并在状态机空闲/停止状态强制为高。直接 I2C 仿真保持通过，但 Slice 达 `86.78%`，且 PHY-5060、PHY-5016、PHY-5079、PHY-5088 仍存在，因此不修改正式源、正式包或正式候选位流。

## 输入与变更

- 目标器件：`PH1P35MDG324`
- TD：`6.2.168116`
- Flow：官方 `DefaultFlow.tcl`
- placement seed：`1`
- 输入包：`fallback/td_package/` 的隔离副本
- 变更脚本：`scripts/prepare_i2c_registered_phase.py`
- 变更文件：`user_source/hdl_source/uics500_cfg/uii2c.v`
- 变更源 SHA-256：`7ea64d3ef7e8978e2b9011e4fe2d3ed72c5480a9bda06c3b6746d918321a8b6a`

变换删除 `scl_r <= scl_clk` 的组合数据路径，改为由 `clkdiv == SCL_DIV` 的 `I_clk` 域寄存器更新；事件时钟结构和 vendor 状态机未改变。

## 验证结果

- `python -B -m pytest -q work/tests/test_v2_i2c_registered_phase.py`：`2 passed`
- vendor 与候选均完成直接 I2C 事务，`rd_data=00`、`scl_transitions=59`
- 当前完整 `work/tests` 回归：`141 passed`

TD/STA/Bitgen 候选位于 `release/candidates/industrial-v2-i2c-registered-phase/`：

| 指标 | 结果 |
|---|---:|
| 最终路由 Setup WNS / TNS / violated S-EP | `+146 ps / 0 / 0` |
| 最终路由 Hold WNS / TNS / violated H-EP | `+20 ps / 0 / 0` |
| Slice | `18411/21216 = 86.78%` |
| RAM / DSP / DRAMHARDCON | `43 / 24 / 229` |
| Bitstream SHA-256 | `1c2a959f6c45090e8ff89c6b6248bc17f3ca70fa83271fecb406609c70f9d53f` |

最终 PHY 告警仍包括：I2C `scl_clk` mixed fanout、`O_cam_24m_syn_3` mixed fanout、PLL `clkc` 驱动 IO、local clock routing，以及 clock analyzer 非时钟 sink/clock-net cascade。

## 结论

该变换通过了直接事务仿真和最终时序，但不是资源中性且没有完成告警闭合；候选仅保留为审计证据。硬件下载、摄像头波形、HDMI、冷启动和长稳均未执行。
