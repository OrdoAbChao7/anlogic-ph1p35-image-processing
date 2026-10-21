# Industrial V2 G8：单时钟 I2C 计数器位宽优化探针

## 判定

`REJECTED_RESOURCE_GATE`。在已批准的单一 `I_clk` + 边沿使能 I2C 隔离候选上，将分频计数器从固定 16 位改为按完整 SCL 周期推导的最小位宽。12 组逐周期等价仿真通过，完整 TD 综合/布局布线/STA/Bitgen 完成；最终时序通过，但 Slice 为 `18,670/21,216 = 88.00%`，超过 `<=85%` 门槛，PHY 时钟告警仍在。该候选不晋升，未下载。

## 变更范围

隔离候选仅将 `clkdiv` 位宽定义为 `$clog2(SCL_FULL_PERIOD)`，并使用匹配位宽的零初始化/复位值；完整周期仍由 `SCL_DIV`、`SCL_HALF_PERIOD` 和 `SCL_FULL_PERIOD` 原公式决定。状态机、SCL/SDA 相位和事务逻辑未改。当前工作区实际相机配置的周期需要 8 位；默认 `CLK_DIV=499` 的回归配置需要 9 位。

- 仿真 RTL：`fallback/sim/config/uii2c_single_clock_candidate.v`，SHA-256 `b18d6a449b005951a2f5260d9d263e2a1caed9d097d85286a2a81a3e6e02ccc6`。
- TD 输入 RTL：`work/td_i2c_single_clock_width_input/user_source/hdl_source/uics500_cfg/uii2c_single_clock.v`，SHA-256 `5c142e9082073c69020ee49637fdcdd40a54d129e0abe0f18f28561122162777`。
- 位宽断言位于 `fallback/sim/config/tb_i2c_single_clock_equivalence.v`。
- 两份候选 manifest 均列出 30 个已跟踪 V2 源文件；其哈希在本次对照中完全相同。TD 输入包是隔离副本，manifest 没有将厂商 `uii2c_single_clock.v` 纳入 `sources` 数组，因此此处单独记录该文件哈希。

## RTL 验证

先加位宽断言并运行 `CLK_DIV=7`，在原 16 位候选上按预期失败：实际 16 位、期望 3 位。实现参数化位宽后，以下 12 个等价用例全部 PASS，比较 SCL、SDA 驱动/采样、busy、bus_error 和读数据，并检查计数器声明宽度：

- ACK：`CLK_DIV=0,1,2,3,6,7,49,50,499`（9 组）。
- NACK：`CLK_DIV=7,49,499`（3 组）。
- 读回数据符合 ACK=`00`、NACK=`FF`；无 mismatch、timeout 或非零退出码。

## TD、STA 与告警

环境为 `HX1P35A / PH1P35MDG324`、Tang Dynasty `6.2.168116`、官方 `DefaultFlow.tcl`、placement seed `1`。输入包、work project 和候选 release 目录均独立；TD 命令、日志和报告见本文件关联的证据与路径。

| 指标 | 本次位宽候选 |
|---|---:|
| Setup WNS / TNS / 违例端点 | `+106 ps / 0 / 0` |
| Hold WNS / TNS / 违例端点 | `+20 ps / 0 / 0` |
| Slice | `18,670 / 21,216 = 88.00%` |
| RAM / DSP / DRAMHARDCON | `43 / 24 / 229` |
| Bitstream SHA-256 | `1a28f64f5ac12ab4e6cbc26d8e28637ef618cd34e8538fbab8b1384f57e9fb7e` |

原始日志计数：综合 `SYN-5011 ×13`、`SYN-5025 ×3`；路由 `PHY-5016 ×4`、`PHY-5060 ×1`、`PHY-5079 ×1`、`PHY-5088 ×4`。时序收敛不等于这些告警已关闭。

原单时钟 seed=1 候选报告为 `18,209/21,216 = 85.83%`、Setup/Hold `+112/+20 ps`，Bitstream SHA-256 `03bfb4bc820ef4e9e3b9727d05e8e6ddb2ca0be972fbf0b31dd78fec8fe296b5`。TD 同 seed 构建此前已观察到资源/Bitstream 对运行敏感，因此本次 `+461` Slice 不能单独归因于位宽修改；但本次物理实现结果确实超过资源门槛，不能作为通过候选。

## 结论与边界

位宽参数在仿真及 TD 中均可综合，但没有得到资源收益的可审计证据，且 Slice 与 PHY 告警门均未通过。保留隔离结果供比较，不修改 `fallback/td_source`、`release/industrial-v2/` 或 V1。无板卡下载、摄像头/HDMI、复位、长稳、外部执行器或物理性能测试证据。

冻结 V1 SHA-256 复核仍为 `b483a1ffc30d0b7ae9e8ebef4f31f617d33a53d6784ded8007d5443c51ad80ef`；现有正式 V2 候选 SHA-256 仍为 `d6e6a7e12ef7558834904dcc8d2783d5fda827b7fe11c6e407b0119fc3ce1c0d`。
