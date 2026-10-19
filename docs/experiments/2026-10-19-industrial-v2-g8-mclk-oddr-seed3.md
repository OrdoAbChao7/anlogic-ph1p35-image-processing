# Industrial V2 G8：MCLK ODDR-only seed=3 候选

## 状态

`CANDIDATE_WARNING_PARTIAL_REDUCTION`。本次在隔离 TD 工作区使用与 seed=1/2 相同的 MCLK ODDR-only 顶层，仅改变 placement seed；正式 V2 顶层和 `release/industrial-v2/` 未修改。

## 输入与构建

- 目标器件：`PH1P35MDG324`
- TD：`6.2.168116`，官方 `DefaultFlow.tcl`
- placement：`seed=3`
- 顶层：`release/candidates/industrial-v2-mclk-oddr-seed3/design_top_wrapper_mclk_oddr.v`
- 顶层 SHA-256：`fd65440dc4dfaea1305f0dd31e42fcb79413628301106a87272cb3647ab2c3e0`

## TD 结果

| 指标 | 结果 |
|---|---:|
| Setup WNS / TNS / violated S-EP | `+103 ps / 0 / 0` |
| Hold WNS / TNS / violated H-EP | `+20 ps / 0 / 0` |
| Slice | `17358/21216 = 81.82%` |
| RAM / DSP / DRAMHARDCON | `43 / 24 / 229` |
| Bitstream | `1,370,801 bytes` |
| SHA-256 | `08da31a0f5fe2f9aadb7177e0794b4eb5438c74b97a32071b5ac592f856d2c25` |

Synthesis、placement、routing、hold fix、最终 STA 和 Bitgen 均完成，时序和初始 `≤85%` Slice 资源门通过。

## 告警对照

本次日志未出现摄像头 `O_cam_24m` 的 `PHY-5060` 混合扇出，也未出现 `PHY-5079`。仍存在：

- I2C `u_uicfgcs520/u_i2c/scl_clk` 的 `PHY-5060` 混合时钟扇出；
- PLL `clkc` 的 `PHY-5016` 无 location、非 clock-capable IO 告警；
- `PHY-5088` clock analyzer 非时钟 sink 和 clock-net cascade 告警。

因此该候选证明了 ODDR-only 结构在一个 placement seed 下可以同时满足资源/时序门，并局部改善摄像头 MCLK 告警；它不能关闭整体 PHY/CDC/IO 告警门，也没有板级波形、下载或功能证据。

## 判定

- `RTL/TD/STA/Bitgen`：候选级 PASS。
- `resource_timing_budget`：候选级 PASS（`81.82%`，不代表正式 V2 包已替换）。
- `warnings_cdc_constraints_audit`：OPEN。
- `hardware`：NOT_RUN。
- `reproducible_build_package`：OPEN；本次只完成一次 seed=3 构建。
- 正式 `release/industrial-v2/`：保持不变。

