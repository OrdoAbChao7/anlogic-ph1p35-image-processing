# Industrial V2 G8：I2C clock/data fanout 隔离探针

## 状态

`REJECTED_WARNING_CLOSURE`。本次只在隔离 TD 输入包中给 `uii2c.v` 增加一个与 `scl_clk` 同步的 `scl_data_clk`，让 SCL 输出数据路径不直接读取事件时钟。完整 TD/STA/Bitgen 通过，资源仍在目标内，但综合/物理实现将副本合并回 `scl_clk`，PHY-5060 及其他时钟告警没有关闭。因此不修改正式源、正式包或正式候选位流。

## 输入与变更

- 目标器件：`PH1P35MDG324`
- TD：`6.2.168116`
- Flow：`release/industrial-v2/DefaultFlow.tcl`
- 输入包：`fallback/td_package/` 的隔离副本
- 变更文件：`user_source/hdl_source/uics500_cfg/uii2c.v`
- 变更源 SHA-256：`58742ebf12b2fe21ad63a6c77c4f2208405dd9d9ff323ba27a26f32f29f74556`
- placement seed：`1`
- 顶层和视频 RTL：正式发布包中的同版本源快照

变更只替换 `scl_r <= scl_clk` 的数据读取为 `scl_r <= scl_data_clk`，并在同一分频计数器中同步翻转副本；`posedge/negedge scl_clk` 事件时钟和模块端口保持不变。

## RTL 证据

- TDD 静态结构测试：先红（目标转换脚本不存在），再绿：`1 passed`。
- Icarus 定向仿真：`PASS busy=0 bus_error=0 scl_transitions=20`。
- 仿真使用永久 ACK/低电平从设备模型，覆盖单字节写事务的 busy、bus error 和 SCL 变化，不代表摄像头硬件验收。

## TD 结果

| 指标 | 结果 |
|---|---:|
| Setup WNS / TNS / violated S-EP | `+103 ps / 0 / 0` |
| Hold WNS / TNS / violated H-EP | `+20 ps / 0 / 0` |
| Slice | `17247/21216 = 81.29%` |
| RAM / DSP / DRAMHARDCON | `43 / 24 / 229` |
| 压缩 Bitstream | `1,366,833 bytes` |
| Bitstream SHA-256 | `0b54ad07d4413b4d7627d3af67fd4c9fd75af56cd8eff9d4f611800ee5125535` |
| `route.qor` SHA-256 | `1925d1ad795bbcd78f6cafc5979e5b3753af0b6c535761ae3a429c618e3b5d1b` |
| `final_timing.rpt` SHA-256 | `d66256a442fad174610d4ff7d1cc737ca02ea6bbd6bc1af2b6d60d1024706318` |

完整产物位于 `release/candidates/industrial-v2-i2c-data-isolation/`，包括 `td-logs/` 原始综合/物理流程日志和阶段状态。

## Warning 判定

最终 PHY 日志仍报告：

- PHY-5060：`u_uicfgcs520/u_i2c/scl_clk` 仍为 `1 clock pin; 1 data/ctrl pin`；`O_cam_24m_syn_3` 仍为混合扇出。
- PHY-5016：PLL `clkc` 到 IO 的 location/clock-capable IO 告警仍在。
- PHY-5079：local routing clock net 告警仍在。
- PHY-5088：clock analyzer 非时钟 sink、跨区域和级联告警仍在。

这说明 `scl_data_clk` 被 TD 优化/合并后，不能作为当前器件和工具链下的资源中性告警关闭方案。该假设已被完整实现结果否证；后续应转向有官方器件/IP 依据的时钟输出架构，不能继续叠加未经证实的保持属性。

正式 `release/industrial-v2/industrial-v2.bit` 保持 SHA-256 `d6e6a7e12ef7558834904dcc8d2783d5fda827b7fe11c6e407b0119fc3ce1c0d`，硬件下载仍未执行。

