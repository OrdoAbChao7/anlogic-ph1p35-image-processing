# Industrial V2 G8：MCLK ODDR-only 告警候选

## 状态

`CANDIDATE_REJECTED_RESOURCE_GATE`。本次只在隔离 TD 构建中替换摄像头 MCLK 输出结构，正式 V2 源码和 Bitstream 未修改。

## 变更

从 `fallback/td_source/design_top_wrapper.v` 派生顶层，仅将：

```verilog
assign O_cam_24m = S_24m_clk;
```

替换为 `PH1P_LOGIC_HD_ODDR`，使用 `S_24m_clk`、`~S_pll_lock`、`d0=1'b1`、`d1=1'b0` 驱动 `O_cam_24m`。候选顶层已保存到 `release/candidates/industrial-v2-mclk-oddr-seed1/design_top_wrapper_mclk_oddr.v`，SHA-256 为 `fd65440dc4dfaea1305f0dd31e42fcb79413628301106a87272cb3647ab2c3e0`。

构建入口使用新增的 `--top-rtl` 隔离覆盖参数；默认不传该参数时仍使用正式 V2 顶层。

## TD 结果

使用官方 `DefaultFlow.tcl`、`place seed=1`、当前七功能 V2 输入包完成 synthesis、placement、routing、hold fix、STA 和 Bitgen：

| 指标 | 结果 |
|---|---:|
| Setup WNS/TNS/violated S-EP | `+104 ps / 0 / 0` |
| Hold WNS/TNS/violated H-EP | `+20 ps / 0 / 0` |
| Slice | `18520/21216 = 87.29%` |
| RAM / DSP / DRAMHARDCON | `43 / 24 / 229` |
| Bitstream | `1,369,201 bytes` |
| SHA-256 | `91a6c99b5d384a0291d48e6f9a19c7ec1261bbdafde18174854c17ccbee2c3b5` |

时序与 Bitgen 通过，但资源超过 `≤85%` 门限，候选不晋级。

## 告警对照

该候选物理日志中不再出现 `O_cam_24m` 的 `PHY-5060` 混合扇出，也未出现 `PHY-5079`。仍存在：

- `PHY-5060`：I2C 内部 `u_uicfgcs520/u_i2c/scl_clk` 混合时钟扇出。
- `PHY-5016`：PLL `clkc` 驱动无 location、非 clock-capable IO。
- `PHY-5088`：clock analyzer 的非时钟 sink/clock-net cascade 告警。

因此 ODDR 只证明一个 MCLK 拓扑候选，不能关闭整体 PHY/CDC/IO 告警门，也没有板级波形或上板证据。

## 判定

- `RTL/TD/STA/Bitgen`：候选级 PASS。
- `resource_timing_budget`：FAIL（87.29%）。
- `warnings_cdc_constraints_audit`：OPEN。
- `hardware`：NOT_RUN。
- 正式 `release/industrial-v2/`：保持不变。
