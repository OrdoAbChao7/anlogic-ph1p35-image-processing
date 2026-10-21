# Industrial v1 — HX1P35A Pin-Correction Frozen Candidate

本包是 fixed-red v1 的 HX1P35A 管脚修正版冻结候选，对应冻结标识 `industrial-v1-hx1p35a-pin-correction-freeze-20261018`，使用 TD v6.2.168116 完成综合、布局布线、Hold Fix 和 Bitgen。

- Bitstream：`camera_to_dsi_display_compress.bit`
- SHA-256：`b483a1ffc30d0b7ae9e8ebef4f31f617d33a53d6784ded8007d5443c51ad80ef`
- 按键：`KEY1=D5`、`KEY2=A9`
- LED：`LED1=D10`、`LED2=E10`、`LED3=C6`
- MIPI：`DPHY0 + 2-lane`
- QoR：Setup WNS `+103 ps`、Hold WNS `+20 ps`、TNS/违例端点 `0`

## 四态 LED 编码

LED 为高电平有效，物理映射为 `{LED1, LED2, LED3} = {PASS, NG, DETECTED}`：

| 状态 | LED1 | LED2 | LED3 |
|---|---:|---:|---:|
| `PASS` | 亮 | 灭 | 亮 |
| `NG` | 灭 | 亮 | 亮 |
| `NO_OBJECT` | 灭 | 灭 | 灭 |
| `INVALID` | 亮 | 亮 | 灭 |

用户已完成本位流的基本上板验证并反馈大功能基本稳定；完整场景矩阵、冷启动/热复位和长稳记录仍未归档。详细冻结边界见 `docs/evidence/industrial-v1-hx1p35a-pin-correction-freeze.md`。
