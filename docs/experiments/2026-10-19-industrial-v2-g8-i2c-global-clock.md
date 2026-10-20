# Industrial V2 G8：I2C event clock 官方 BUFG 探针

## 状态

`REJECTED_RESOURCE_AND_WARNING_CLOSURE`。本次只在隔离 TD 输入包中把 `uii2c.v` 的 `scl_clk` 事件时钟送入官方 `PH1P_LOGIC_BUFG`，SCL 输出数据电平仍读取原始寄存器。TD 能识别该原语并完成综合、布局布线、STA 和 Bitgen，但 Slice 达 `86.35%`，超过 `<=85%` 资源门；PHY-5060、PHY-5079、PHY-5088 仍存在，因此不修改正式源、正式包或正式候选位流。

## 输入与变更

- 目标器件：`PH1P35MDG324`
- TD：`6.2.168116`
- Flow：官方 `DefaultFlow.tcl`
- placement seed：`1`
- 输入包：`fallback/td_package/` 的隔离副本
- 变更脚本：`scripts/prepare_i2c_global_clock.py`
- 变更文件：`user_source/hdl_source/uics500_cfg/uii2c.v`
- 变更源 SHA-256：`3ba46b1b8d73e4c69a49ee9eedad70d8030c86dcbadce4dc670e3bdb3a84691c`

官方原语接口来自本地 TD PH1P 宏定义：`PH1P_LOGIC_BUFG` 使用 `.i` 输入和 `.o` 输出。变换把 `posedge/negedge scl_clk` 事件路径改为 `scl_clk_global`，并保留 `scl_r <= scl_clk` 的数据路径。

## 验证结果

静态契约测试先因转换脚本不存在而失败，补上脚本后通过：`1 passed`。完整工作区回归通过：`136 passed in 0.88s`。

TD/STA/Bitgen 候选位于 `release/candidates/industrial-v2-i2c-global-clock/`：

| 指标 | 结果 |
|---|---:|
| 综合 Setup WNS / TNS / violated S-EP | `-1147 ps / -9424 ps / 17` |
| 最终路由 Setup WNS / TNS / violated S-EP | `+104 ps / 0 / 0` |
| 最终路由 Hold WNS / TNS / violated H-EP | `+20 ps / 0 / 0` |
| Slice | `18321/21216 = 86.35%` |
| RAM / DSP / DRAMHARDCON | `43 / 24 / 229` |
| Bitstream SHA-256 | `64751a3000ccae4ca917b4f18d7ad0c62bb174bae797121fa92323e460a159a6` |

综合阶段已识别 `4 BUFG to GCLK`；最终 PHY 仍报告：

- `PHY-5060`：`u_uicfgcs520/u_i2c/scl_clk` 混合 `2 clock pins; 2 data/ctrl pins`；`O_cam_24m_syn_3` 混合扇出仍在。
- `PHY-5016`：PLL `clkc` 驱动 IO 的 location/clock-capable IO 告警仍在。
- `PHY-5079`：仍有 1 条 clock net 使用 local routing。
- `PHY-5088`：仍有 clock analyzer 的非时钟 sink 与 clock-net 级联告警。

## 结论

官方 BUFG 不是当前结构下的资源中性告警关闭方案；它还使综合阶段时序恶化，并使最终 Slice 超过发布目标。候选仅保留为审计证据，不提升为正式候选。硬件下载、摄像头波形、HDMI、冷启动和长稳均未执行。
