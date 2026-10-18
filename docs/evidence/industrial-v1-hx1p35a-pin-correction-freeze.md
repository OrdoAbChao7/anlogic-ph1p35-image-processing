# Industrial v1 HX1P35A 管脚修正版冻结报告

**冻结标识**：`industrial-v1-hx1p35a-pin-correction-freeze-20261018`
**冻结日期**：2026-10-18
**分支**：`fallback/industrial-inspection`
**适用版本**：固定红色零件 `fixed-red v1`，类别 `red_part`，目标总数 `0/1`

## 1. 冻结结论

本次冻结对象是当前已经完成 TD 构建、并由用户完成基本上板验证的 HX1P35A 管脚修正版。冻结包集中放在：

`release/candidates/industrial-v1-hx1p35a-pin-correction/`

下载入口只有一个：

`release/candidates/industrial-v1-hx1p35a-pin-correction/camera_to_dsi_display_compress.bit`

该 Bitstream 的 SHA-256 为：

`b483a1ffc30d0b7ae9e8ebef4f31f617d33a53d6784ded8007d5443c51ad80ef`

后续任何 RTL、约束、阈值或 TD 输入包变更，都必须创建新的候选目录和新的冻结 tag，不得覆盖本目录中的位流。

## 2. 当前版本能够实现的效果

| 功能 | 冻结状态 | 证据/说明 |
|---|---|---|
| SC520CS → MIPI D-PHY → CSI/ISP → DDR → HDMI 视频链路 | `PROJECT_BUILT` | TD 综合、布局布线、Hold Fix、Bitgen 均通过 |
| MIPI 接收 | `PROJECT_BUILT` | `DPHY0 + 2-lane` |
| 原图模式 | `RTL_PASS` / `USER_REPORTED_ON_BOARD` | 工业回归、三模式流式回归；用户报告上板基本稳定 |
| Sobel 模式 | `RTL_PASS` / `USER_REPORTED_ON_BOARD` | 工业回归、三模式流式回归；用户报告上板基本稳定 |
| 卡通化模式 | `RTL_PASS` / `USER_REPORTED_ON_BOARD` | 区域填充版本已绑定当前 TD 输入包；用户报告上板基本稳定 |
| 固定红色零件检测 | `RTL_PASS` / `USER_REPORTED_ON_BOARD` | `red_part`，PASS/NG/NO_OBJECT/INVALID 四态分类 |
| 检测框和状态 OSD | `RTL_PASS` / `USER_REPORTED_ON_BOARD` | 框线、模式、Logo、帧计数和检测状态已进入当前结构 |
| 按键 | `PROJECT_BUILT` / `USER_REPORTED_ON_BOARD` | `KEY1=D5`、`KEY2=A9`，帧边界模式切换 |
| LED 状态 | `PROJECT_BUILT` / `USER_REPORTED_ON_BOARD` | `LED1=D10`、`LED2=E10`、`LED3=C6`，高电平有效 |
| YOLO、多类别检测、WM8978 语音 | `OUT_OF_SCOPE_FOR_V1` | 已从固定红色 v1 交付门槛移除，历史研究资料保留 |

### LED 现象

物理映射为 `{LED1, LED2, LED3} = {PASS, NG, DETECTED}`：

| 状态 | LED1 | LED2 | LED3 |
|---|---:|---:|---:|
| `PASS` | 亮 | 灭 | 亮 |
| `NG` | 灭 | 亮 | 亮 |
| `NO_OBJECT` | 灭 | 灭 | 灭 |
| `INVALID` | 亮 | 亮 | 灭 |

## 3. TD 构建和资源结果

- 工具：TangDynasty `v6.2.168116`
- 器件：`PH1P35MDG324 Speed 3`
- Setup WNS：`+103 ps`
- Hold WNS：`+20 ps`
- Setup/Hold TNS：`0 / 0`
- 违例端点：`0`
- Slice：`17,642 / 21,216`（`83.15%`）
- RAM：`43`
- DSP：`24`
- DRAMHARDCON：`229`

TD 日志副本已整理到正式证据目录：

- `docs/evidence/industrial-v1-td-logs/2026-10-18-hx1p35a-pin-correction-syn.log`
- `docs/evidence/industrial-v1-td-logs/2026-10-18-hx1p35a-pin-correction-phy.log`

## 4. 冻结前验证

- `python -B -m pytest work/tests/test_hx1p35a_board_contract.py work/tests/test_industrial_build_contract.py -q`：`31 passed`
- 已有完整工业回归记录：`13/13 PASS`，并有 `1280×720` 三模式全帧、检测分类、OSD/LED、CDC 和 VTC/HDMI 契约证据，归档在 `docs/evidence/industrial-v1-regression-logs/2026-10-18/`。
- 本次冻结前再次运行完整脚本时，前 9/13 阶段通过；第 10 阶段全帧仿真超过当前自动执行等待上限，未将该次等待超时计为失败。冻结结论以已有完整回归归档和本次 `31 passed` 契约回归为依据。

## 5. 硬件证据边界

用户已完成当前 Bitstream 的上板验证，并反馈“大功能基本能够稳定运行”。因此本版本记录为 `USER_REPORTED_ON_BOARD`。由于本次没有同步保存摄像头型号、显示器、分辨率、冷启动/热复位、长稳时长、空场/目标/边界样本和 LED 逐项记录，报告不把它升级为带完整实验记录的 `VERIFIED_ON_BOARD`。

这不影响本版本作为用户当前使用的冻结候选；它只限定了报告中“已完成效果”的证据等级。

## 6. 后续推进入口

下一版应从本 tag 派生新分支或新候选目录，优先补齐：

1. Stage G 标准化上板记录和长稳数据；
2. 资源占用从 `83.15%` 继续降到项目目标附近；
3. PHY、AWB、生成 DDR 和时钟相关结构性告警的逐项审计；
4. 现场下载说明、演示脚本和最终比赛要求映射。

本报告不宣称八个 Goal 全部完成，也不宣称完整比赛交付包已经冻结；它明确冻结的是“固定红色零件 v1 的 HX1P35A 管脚修正版可下载候选”。
