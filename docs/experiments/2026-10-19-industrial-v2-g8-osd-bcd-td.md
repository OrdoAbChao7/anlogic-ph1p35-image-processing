# V2 G8 OSD BCD timing candidate

## 结论

将 HDMI 域 OSD 的帧计数和尺寸显示从运行时 `/`、`%` 转换改为 BCD 加一和有界减法转换后，正式 TD 候选完成综合、实现、hold fix、route、QoR 检查和 Bitgen。该候选通过 TD QoR 门，但仍不是七项升级全部接入后的最终 V2 发布版本。

## 优化和等价性

原路径是 `u_industrial_osd/frame_counter_reg[0] → u_industrial_osd/frame_digits_reg[15]`，最终路径数据延迟 `33.201 ns`，导致 HDMI 时钟域 Setup WNS `-20111 ps`。新实现保留帧号十进制显示语义：

- `bcd_increment` 对 10 个十进制 nibble 做帧边界加一。
- `dimension_to_bcd` 对 11-bit 宽高使用有界 compare/subtract 转换。
- 不再综合 32-bit 除法/取模组合逻辑。

新增 `tb_industrial_osd_bcd.v` 覆盖帧 1、帧 2、个位进位到十位，以及 `120×80` 尺寸 BCD 值。

## TD 构建事实

- Tool: Tang Dynasty `v6.2.168116`
- Device: `PH1P35MDG324`
- Top: `design_top_wrapper`
- 输入包：`fallback/td_package`
- 候选 Bitstream：`release/candidates/industrial-v2-osd-bcd/camera_to_dsi_display_compress.bit`
- Bitstream SHA-256：`b52f929fb845ae681e4bb330eb129254dae3d7941b02e4f285c66a33b55532f2`

## QoR 证据

| 指标 | 结果 |
|---|---:|
| Setup WNS | `+132 ps` |
| Setup TNS | `0 ps` |
| Setup violated endpoints | `0` |
| Hold WNS | `+20 ps` |
| Hold TNS | `0 ps` |
| Hold violated endpoints | `0` |
| Slices | `18486/21216 = 87.13%` |
| RAMs | `43` |
| DSPs | `24` |

原始证据为 [route.qor](../../release/candidates/industrial-v2-osd-bcd/route.qor)、[final_timing.rpt](../../release/candidates/industrial-v2-osd-bcd/final_timing.rpt) 和 [provenance manifest](../../release/candidates/industrial-v2-osd-bcd/industrial-v1-manifest.json)。

## 边界

形式顶层仍只接入结果 CDC 和 HDMI 跟踪候选；G4/G5/G6/G7 源侧功能、七项完整集成、SC520CS 上板、HDMI 实测、冷启动、长稳和执行器验收均未完成。该 Bitstream 只能作为有 QoR 证据的 `CANDIDATE_ONLY` 版本，不能标记为最终 V2 发布。
