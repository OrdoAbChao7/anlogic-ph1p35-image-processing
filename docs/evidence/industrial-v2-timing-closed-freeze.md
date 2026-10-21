# Industrial V2 时序收敛版冻结报告

**冻结标识**：`industrial-v2-timing-closed-freeze-20261021`
**冻结日期**：2026-10-21
**分支**：`ds/industrial-v2-timing-closure`
**适用版本**：AWB-Lite 固定红色零件整机，`red_part`，目标总数 `0/1`

## 1. 冻结结论

本次冻结对象是第一个**真实通过整机时序门禁**的 Industrial V2 可上板候选。

- 冻结包：`release/candidate-industrial-v2-timing-closed-r2/`（21 文件）
- 下载入口：

  `release/candidate-industrial-v2-timing-closed-r2/camera_to_dsi_display.bit`

- Bitstream SHA-256：

  `E6BA3DA87DABF82907F3DB1B4FAC18A9E8350A43917F3D5E6DA64A0A35617C36`

后续任何 RTL、约束、阈值、SDC 或 TD 输入包变更，都必须创建新的候选目录和新的冻结 tag，
不得覆盖本目录中的位流。

**本冻结不等同于比赛交付完成**：`HARDWARE_PASS` 仍为否，详见第 5 节。

## 2. 本版本能够实现的功能

证据等级沿用 v1 冻结报告的口径：

- `PROJECT_BUILT`：综合、布局、布线、Bitgen 全部通过
- `RTL_PASS`：对冻结基线逐周期差分等价，0 mismatch
- `NOT_ON_BOARD`：从未下载，无任何硬件观测

| 功能 | 冻结状态 | 证据/说明 |
|---|---|---|
| SC520CS → MIPI D-PHY/CSI-2 → ISP → DDR2 → HDMI 720p 主链路 | `PROJECT_BUILT` | 整机 Route 通过，MIPI 域 +0.755 ns、HDMI 域 +0.644 ns |
| MIPI 接收（2-lane，RAW10） | `PROJECT_BUILT` | `u_mipi_dphy_rx_ph1p` |
| ISP：去马赛克 / 白平衡 / 色彩流水 | `PROJECT_BUILT` | **帧级 AWB 关闭**，增益固定 1.0（Q8.8 256） |
| 原图模式 | `PROJECT_BUILT` + `RTL_PASS` | 三模式切换逻辑在网表中 |
| Sobel 边缘检测 | `PROJECT_BUILT` | 3×3 梯度流水 |
| 卡通化（颜色量化 + 区域填充 + 轮廓） | `PROJECT_BUILT` | `u_video_cartoon` |
| 红色零件分割（`85<Cb<125`、`135<Cr<200`） | `PROJECT_BUILT` + `RTL_PASS` | E4 差分：701,440 检查 / 691,200 beat / 0 mismatch |
| 3×3 形态学开运算 | `PROJECT_BUILT` | `morph_open_96` |
| BBox / 面积 / 质心 / 单目标 `0/1` | `PROJECT_BUILT` + `RTL_PASS` | E1 差分：1,058 检查 / 0 mismatch |
| `PASS` / `NG` / `NO_OBJECT` / `INVALID` 四态判定 | `PROJECT_BUILT` | `defect_classifier`，120×80 px ±15/±12 |
| 尺寸标定与形状判定（占用率 ≥ 78.1 %，纵横比 1.25–1.75） | `PROJECT_BUILT` | 标定常数为临时值 |
| OSD：安路 Logo + 12 行文字（`MODE`/`FRAME`/`RED_PART`/`STATUS`/延迟遥测/`COUNT`/`PASS:NG`/`CAL`/`W·H(mm)`/`SHAPE`） | `PROJECT_BUILT` + `RTL_PASS` | E2 差分：2,475,199 周期 / 2 帧 / 0 mismatch |
| 按键模式切换 | `PROJECT_BUILT` | `I_button[1:0]`，帧边界生效 |
| LED 状态联动 | `PROJECT_BUILT` | `O_led1..3` |
| 时序跟踪 + 轨迹叠加 | `PROJECT_BUILT` | 8 帧历史 |
| 运动检测（160×120 固定栅格） | `PROJECT_BUILT` | `motion_diff_160` |
| 帧标签 / 延迟遥测 | `PROJECT_BUILT` | OSD 直接显示 proc/video/e2e 周期 |
| 分拣执行器输出 | **INHIBITED** | `I_arm = 1'b0`，`O_sort_pulse` 永不触发 |
| 帧级 AWB（V2 第七项） | **OFF** | `ENABLE_V2_FRAME_AWB = 0`，继承 AWB-Lite 取舍 |
| YOLO / Micro-CNN / 多类别 / WM8978 | `OUT_OF_SCOPE` | 项目变更提案已移除 |

**上板可用性**：以上全部为 `PROJECT_BUILT`，没有任何一项是 `USER_REPORTED_ON_BOARD`。

## 3. TD 构建与资源结果

- 工具：TangDynasty `v6.2.168116`，`DefaultFlow.tcl` + `set_param place seed 1`
- 器件：`PH1P35MDG324 Speed 3`
- Setup WNS / TNS：**+644 ps / 0**
- Hold WNS / TNS：**+21 ps / 0**
- 违例端点：Setup `0`，Hold `0`
- 检查条件：final 模式，slow + fast 双角，CRPR 开启
- Slice：`18,233 / 21,216`（`85.94%`）
- ERAM：`75 / 108`；DSP：`32 / 40`；DRAMHARDCON：`230`
- 线长：`4,912,048`
- STA coverage：`96.54%`

分时钟裕量：MIPI `+0.755 ns`、HDMI `+0.644 ns`、ddr usr_clk `+2.628 ns`、
其余均 ≥ `+1.364 ns`。

### 约束诚实性

`camera_to_dsi_display.sdc` 与冻结基线逐字节相同
（`390DFE5FA12669AFC5E8DB01E893300132605FFB6BFB962EC40DA5BE022B068F`）。
全设计仅有两类时间例外，均为 DDR2 厂商 IP 的灰码 CDC
`set_max_delay -datapath_only`，且被 `set_clock_groups` 100 % 忽略。
**未添加任何 false path、multicycle 或降频。**

### 与项目内部目标的偏差（须明示）

`PROJECT_GOAL.md` 记录的资源目标是 `< 80% Slice`，本版为 `85.94%`，**高于该目标**。
本版满足用户后来批准的 `20,000` 片上限。若 `80%` 仍为硬指标，需另立实验继续压缩。

## 4. 冻结前验证

三项结构改动均在合并前独立完成逐周期差分，基线为继承的 AWB-Lite 快照：

| 实验 | 差分规模 | 结果 | 模块 Gate |
|---|---|---|---|
| E1 MIPI BBox 预计算 | 1,058 检查 / 528 帧 | 0 mismatch | `−403 → +2,289 ps` |
| E2 HDMI/OSD 三级流水 | 2,475,199 周期 / 1.84 M 有效像素 | 0 mismatch | `−657 → +3,189 ps` |
| E4 检测器并行组统计 | 701,440 检查 / 691,200 beat / 3 帧 3 次检出 | 0 mismatch | `−1,096 → +2,786 ps` |

整机：基线 `−2.539 ns / 24 违例` → 本版 **`+0.644 ns / 0 违例`**。

`check_timing -verbose` 在 Routed DB 上完整枚举了 3.46 % 的覆盖缺口：
1 个 99.2 kHz I2C 生成时钟、34 输入 / 65 输出无 IO delay（硬核焊盘与杂项 IO）、
4 个无害 dangling 节点、0 非法约束、0 组合环。两个关键时钟域没有未约束内部逻辑。

综合告警谱与基线逐项一致，未新增、未屏蔽。

## 5. 硬件证据边界

**`HARDWARE_PASS = false`。** 本 Bitstream 从未下载过，没有任何一项硬件观测：

- 未验证配置成功、MIPI 锁定、HDMI 出图
- 未验证检测精度、判决正确性、LED/按键
- 未验证连续运行的稳定性（赛题基本要求第 3 条）
- 未实测端到端延迟（`PROJECT_GOAL.md` 目标 < 2 ms）

上板步骤与失败判据见冻结包内 `BOARD_TEST.md`（B1–B14）。

### 回退

`release/candidate-industrial-v2-timing-closed/`（r1）保留为回退参考：

- Bitstream SHA-256 `ADD2DC46403670C279CADCE2E051F79B83EA9F2BBD1F4E78E7FBB7EB5606BC8C`
- Setup `+0.137 ns`，Slice `18,248`
- 与 r2 共享 E1 与 E2，**仅检测器实现不同**

r2 改动了检测器这一最安全关键的模块。虽然逐周期等价已证明，若上板出现异常，
可先切回 r1 以区分类别：故障随检测器变化 → 定位在 E4；故障不变 → 在链路或板级。

## 6. 分支与工作树地图

本仓库使用多工作树并行，四个工作树共享同一 `.git`：

| 分支 | 工作树 | 用途 | 状态 |
|---|---|---|---|
| `main` | 无独立工作树 | 默认分支 | 本地领先 `origin/main` 1 个提交（历史状态，未处理） |
| `chore/fpga-agent-loop` | `E:\Projects\FPGA` | 主工程、历史实验、审计；含 `.tools\td` | 活跃 |
| `fallback/industrial-inspection` | `E:\Projects\FPGA-fallback` | industrial-v1 冻结版（已上板） | 已冻结 |
| `goal/industrial-v2-advanced` | `E:\Projects\FPGA-v2` | V2 目标文档、实验记录、发布候选目录 | 活跃 |
| **`ds/industrial-v2-timing-closure`** | `E:\Projects\FPGA-ds-timing` | **本次冻结对象**：时序收敛工程与 r2 发布包 | **冻结于本 tag** |
| tag `industrial-v1-hx1p35a-pin-correction-freeze-20261018` | — | v1 冻结标识 | 已推送 |
| tag **`industrial-v2-timing-closed-freeze-20261021`** | — | **本版冻结标识** | 已推送 |

两个冻结 tag 是本仓库中唯一应当被当作“成品”引用的对象。其余分支是工作分支，
可以继续演进，不影响本冻结。

## 7. 后续推进入口

从本 tag 派生新分支或新候选目录，优先补齐：

1. **上板**：按 `BOARD_TEST.md` 完成 B1–B14，把 `HARDWARE_PASS` 的空白填上；
2. 逐项记录 MIPI 锁定、HDMI 出图、检测精度、30 分钟长稳数据；
3. 真实工位标定，替换临时毫米常数并重新构建；
4. 资源从 `85.94%` 压向项目目标的 `< 80%`；
5. 若需要恢复帧级 AWB（V2 第七项），单独立项，不得混入本冻结版本。

本报告不宣称赛题全部要求已达成，只冻结“第一个整机时序通过的 V2 可上板候选”。
