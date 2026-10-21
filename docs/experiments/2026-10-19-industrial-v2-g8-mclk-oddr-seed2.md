# Industrial V2 G8：MCLK ODDR-only seed=2 候选

## 状态

`CANDIDATE_REJECTED_RESOURCE_GATE`。本次在隔离 TD 工作区使用与 seed=1 相同的 MCLK ODDR-only 顶层，仅改变 placement seed；正式 V2 顶层和 `release/industrial-v2/` 未修改。

## 输入与构建

- 目标器件：`PH1P35MDG324`
- TD：`6.2.168116`，官方 `DefaultFlow.tcl`
- placement：`seed=2`
- 顶层覆盖：`release/candidates/industrial-v2-mclk-oddr-seed2/design_top_wrapper_mclk_oddr.v`
- 顶层 SHA-256：`fd65440dc4dfaea1305f0dd31e42fcb79413628301106a87272cb3647ab2c3e0`
- 构建方式：`scripts/build_industrial_td.py` 的隔离 `--top-rtl`、`--release-dir` 和 `--work-project` 参数

## TD 结果

| 指标 | 结果 |
|---|---:|
| Setup WNS / TNS / violated S-EP | `+104 ps / 0 / 0` |
| Hold WNS / TNS / violated H-EP | `+20 ps / 0 / 0` |
| Slice | `18202/21216 = 85.79%` |
| RAM / DSP / DRAMHARDCON | `43 / 24 / 229` |
| Bitstream | `1,365,553 bytes` |
| SHA-256 | `a041cc7ff82b9b03d1dc21f1c0ebe4fa0f4f74ad733309cfbff0db2868a26189` |

Synthesis、placement、routing、hold fix、最终 STA 和 Bitgen 均完成；时序门通过，但 Slice 超过项目候选门限 `≤85%`，因此不晋级。

## 告警对照

本次日志未出现摄像头 `O_cam_24m` 的 `PHY-5060` 混合扇出，也未出现 `PHY-5079`。仍存在：

- I2C `u_uicfgcs520/u_i2c/scl_clk` 的 `PHY-5060` 混合时钟扇出；
- PLL `clkc` 的 `PHY-5016` 无 location、非 clock-capable IO 告警；
- `PHY-5088` clock analyzer 非时钟 sink 和 clock-net cascade 告警。

因此该 seed 只重复确认 MCLK ODDR 拓扑的局部告警改善，不能关闭整体 PHY/CDC/IO 告警门，也没有板级波形或上板证据。

## 判定

- `RTL/TD/STA/Bitgen`：候选级 PASS。
- `resource_timing_budget`：FAIL（`85.79%`）。
- `warnings_cdc_constraints_audit`：OPEN。
- `hardware`：NOT_RUN。
- 正式 `release/industrial-v2/`：保持不变。

