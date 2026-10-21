# Industrial V2 G8：I²C 分频计数器窄位宽探针

## 状态

`REJECTED_RESOURCE_GATE`。本次只在隔离 TD 输入包中按已展开的 `SCL_DIV` 选择 I²C 分频计数器宽度：SC520 当前实例使用 8 bit，保留旧 SC500 默认参数所需的 16 bit 分支。事件时钟、状态机、SCL/SDA 逻辑和模块端口未改变。正式源、正式包和正式候选 Bitstream 均未修改。

## 输入与变更

- 目标器件：`PH1P35MDG324`
- TD：`6.2.168116`
- Flow：官方 `DefaultFlow.tcl`
- placement seed：`1`
- 输入包：`work/td_i2c_counter_width_input/`，由 `fallback/td_package/` 隔离复制
- 变换脚本：`scripts/prepare_i2c_counter_width.py`
- 变更文件：`user_source/hdl_source/uics500_cfg/uii2c.v`
- 变更源 SHA-256：`da507aae17f1a464566bf741323da8b782ff4d7b46c30e676d9b8ed7d124da58`

变换新增：

```verilog
localparam integer CLKDIV_WIDTH = (SCL_DIV < 256) ? 8 : 16;
reg [CLKDIV_WIDTH-1:0] clkdiv;
```

因此当前 SC520 实例的 `SCL_DIV=118` 不再综合 16 位计数器；旧 SC500 默认 `SCL_DIV=499` 仍保留 16 位能力。

## 软件/RTL证据

- `work/tests/test_v2_i2c_counter_width.py`：`1 passed`。
- Icarus 参数化 RTL 编译：`PASS`，参数为 `WMEN_LEN=1`、`RMEN_LEN=1`、`CLK_DIV=237`。
- 该变换没有改变 `posedge/negedge scl_clk` 事件块或协议状态机；既有 I²C 定向读写证据见 `docs/experiments/2026-10-19-industrial-v2-g8-i2c-clock-enable-candidate.md` 与 `docs/evidence/industrial-v2-g8-i2c-clock-enable-log.txt`。本次没有把旧定向仿真结果冒充为新变换的完整事务回归。

## 隔离 TD 结果

TD 已在隔离工作目录完成到物理实现并生成候选 `.bit`；外层构建收集器在 300 秒工具调用上限处终止，因而没有把候选复制成正式包，也没有将其标记为完整构建脚本 PASS。

| 指标 | 结果 |
|---|---:|
| 路由 Setup WNS / TNS / violated S-EP | `+107 ps / 0 / 0` |
| 路由 Hold WNS / TNS / violated H-EP | `+20 ps / 0 / 0` |
| Slice | `18295/21216 = 86.23%` |
| RAM / DSP / DRAMHARDCON | `43 / 24 / 229` |
| Bitstream | `1,369,923 bytes` |
| Bitstream SHA-256 | `4c85e27006742452c80d7aba475169b95b7ad13572565bc7228514777662c767` |

候选文件位于 `release/candidates/industrial-v2-i2c-counter-width/`，完整构建日志和隔离工作目录位于 `work/td_i2c_counter_width_build/`。

## Warning 对照

该变换未关闭现有 PHY 告警。物理实现日志仍出现 `PHY-5060`（I²C `scl_clk` 与 MCLK 混合扇出）、`PHY-5016`（PLL 时钟驱动 IO）和 `PHY-5088`（clock analyzer 非时钟 sink/clock-net 级联）。

## 结论

计数器窄位宽没有改善资源预算：`86.23%` 高于 `<=85%`，且高于当前正式候选 `80.72%`。候选拒绝，不提升正式候选。该结果支持停止继续在同一 vendor I²C fabric-clock 结构上做微小位宽试探；若继续关闭 PHY 告警，应转向有官方器件/IP 依据的时钟拓扑或等待板级/官方资料，而不是继续堆叠未验证变换。

硬件下载、摄像头波形、HDMI、冷启动、长稳和外部执行器验收均未执行。
