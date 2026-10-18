# V2 G8 clock detail audit

## 结果

在不修改 RTL、PLL 配置、管脚约束或默认 Flow 的前提下，使用隔离派生 Flow 在 `route` 后执行 `analyze_clock -detail`。完整 TD 综合、布局布线、STA 和 Bitgen 均通过；详细分析输出已能把 `PHY-5016/5060/5079/5088` 关联到具体时钟源、sink 和网级联关系，但没有足够的官方板级和硬件证据关闭任何告警。

## 构建

- 工作树：`E:/Projects/FPGA-v2`
- 提交：`73e4048c7830db069d800fe18e0d542692072d7d`
- 器件：`PH1P35MDG324`
- TD：`6.2.168116`
- Flow：`DefaultFlow.tcl`，在 `opt_route_fun` 的 `route` 后插入 `analyze_clock -detail`
- placement seed：`1`
- 候选：`release/candidates/industrial-v2-clock-detail-seed1/`
- Bitstream SHA-256：`d58a8640d9b3d3d6c19842053ee5159e723842152172c1583ad29602fadb2e3a`

## QoR

| 指标 | 结果 |
|---|---:|
| Slice | `17002 / 21216`（`80.14%`）|
| RAM / DSP / DRAMHARDCON | `43 / 24 / 229` |
| Setup WNS / TNS / violated endpoints | `+102 ps / 0 / 0` |
| Hold WNS / TNS / violated endpoints | `+20 ps / 0 / 0` |

该次资源结果低于此前候选，但其他同 seed 运行出现过不同 Slice 占用；因此只记录为 measured run，不把它写成已关闭的资源预算或可复现结论。

## 告警定位

- `PHY-5016`：PLL `clkc` 驱动无 location 且不是 clock-capable IO。需要官方 PLL/IP 输出用途与板级 pin 约束核对，当前保持 `OPEN`。
- `PHY-5060`：`u_uicfgcs520/u_i2c/scl_clk` 是 `1` 个 clock pin 加 `2` 个 data/ctrl sink；`O_cam_24m_syn_3` 是 `160` 个 clock pin 加 `1` 个 data/ctrl sink。前者需要确认 I2C 内部时钟实现，后者需要确认摄像头外部时钟输出的允许 fanout，当前保持 `OPEN`。
- `PHY-5079`：详细输出显示 `pll_clk_24m` 和 `O_cam_24m_dup_1...sclk_outnet` 使用 local routing，当前保持 `OPEN`。
- `PHY-5088`：`scl_clk` 被标记为 clkin 非时钟 sink，`O_cam_24m_syn_3` 被标记为 clkout 非时钟 sink；另有 `O_cam_24m_dup_1...sclk_outnet → scl_clk_reg_syn_9 → scl_clk` 的时钟网级联，当前保持 `OPEN`。

## 证据与下一步

- 详细摘录：`docs/evidence/industrial-v2-g8-clock-warning-detail-log.txt`
- 候选 README、`route.qor`、`final_timing.rpt` 和 Bitstream：`release/candidates/industrial-v2-clock-detail-seed1/`
- 关闭前置条件：取得官方管脚/IP 资料，确认 I2C/摄像头时钟协议，必要时做最小约束或 RTL 修复；再重跑 TD，并在板上完成冷启动、热复位和长稳验证。
