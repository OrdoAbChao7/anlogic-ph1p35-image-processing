# STATUS — 当前实现状态与阻塞

> **更新规则**：本文件可根据真实证据（构建报告、仿真、上板结果）持续更新。  
> 修改 PROJECT_GOAL.md 中定义的目标或验收标准须提变更提案。  
> 用户口头反馈记录为 `USER_REPORTED_ON_BOARD`，不等于硬件验证通过。

最后更新：2026-10-12（Y2 软件预研）

---

## 状态定义

| 标签 | 含义 |
|---|---|
| `PLANNED` | 已纳入计划，未开始实现 |
| `IMPLEMENTED_UNVERIFIED` | RTL 已编写，未经仿真或上板验证 |
| `SIM_PASS` | 通过软件参考模型 + RTL 仿真比对 |
| `BUILD_PASS` | TD 综合 + 布局布线 + 位流生成成功，时序收敛 |
| `USER_REPORTED_ON_BOARD` | 用户报告上板现象，未绑定位流哈希/工程版本 |
| `VERIFIED_ON_BOARD` | 已完成上板实测，有完整证据链 |
| `FAIL` | 已知失败，有根因记录 |
| `BLOCKED` | 依赖未就绪，无法推进 |

---

## 阶段状态总览

| 阶段 | 内容 | 当前状态 | 关键证据 |
|---|---|---|---|
| **G1** | 视频采集与显示闭环 | `BUILD_PASS` / `USER_REPORTED_ON_BOARD` | 位流 SHA: `A311...6010`（Lab1）；用户报告原图可显示 |
| **G2** | 接口 / 时钟 / ISP 基线审计 | `BLOCKED` | 待 G1 硬件闭环通过；接口草案存在 |
| **G3** | 卡通化与基础模式 | `SIM_PASS`（部分）/ `BUILD_PASS`（候选） | 见下方 G3 详情 |
| **G4** | Sobel 实时流水线 | `IMPLEMENTED_UNVERIFIED` | Sobel 算法研究已有；RTL 待仿真 |
| **G5** | YOLO-tiny 检测 | `PLANNED` / `PE_SIM_PASS`；Y2 软件候选 `FAIL` | 单个 INT8 PE RTL 仿真通过；Y1 模型直接部署 NO-GO，Y2 微型模型仅 128 输入匹配 2 个瓶子且误报严重；整网/硬件均未通过 |
| **G6** | OSD + 外设联动 | `PLANNED` | 基础 OSD 模块存在于组员工程 |
| **G7** | 优化与创新 | `PLANNED` | 待 G3–G6 稳定后 |
| **G8** | 冻结 / 发布 / 答辩 | `PLANNED` | — |

---

## G1 详情

**目标**：SC520CS → MIPI → ISP → DDR2 → HDMI 原始视频闭环

| 子项 | 状态 | 证据 |
|---|---|---|
| SC520 Lab1 工程可定位 | `BUILD_PASS` | `.tools/td/work/lab_ex1_mipi_hdmi_sc520/` |
| TD 综合 + 布局布线通过 | `BUILD_PASS` | Setup WNS 1242 ps，Hold WNS 20 ps；见 [`docs/build/goal-1-sc520-lab1/build-summary.md`](../build/goal-1-sc520-lab1/build-summary.md) |
| 位流文件 | `BUILD_PASS` | `camera_to_dsi_display.bit`，SHA-256: `A3117B3CA6BB68326DA2B14914B713FD9DE49DCC4A2B9FDE8A8ABB19F9FF6010` |
| 告警分类完成 | `BLOCKED` | PHY-5060、PHY-5079、PHY-5088 时钟告警待分类 |
| 下载器识别 | `BLOCKED` | 2026-10-02 未发现设备；见 [`docs/evidence/goal-1/2026-10-02-bringup.md`](../evidence/goal-1/2026-10-02-bringup.md) |
| SC520 I2C 初始化 | `USER_REPORTED_ON_BOARD` | 用户报告原图可显示；具体位流哈希未绑定 |
| HDMI 实时原图 | `USER_REPORTED_ON_BOARD` | 同上 |
| 冷启动 / 热复位 / 长稳 | `BLOCKED` | 未执行 |
| **G1 阶段门** | **未通过** | 硬件闭环证据不完整 |

---

## G3 详情

**目标**：三种显示模式 + 卡通化 RTL 经过仿真和上板验证

| 子项 | 状态 | 证据 |
|---|---|---|
| 卡通化 RTL（组员版） | `FAIL` | WNS -1574 ps；源码有除法、行指针、握手问题；见 team-sync-2026-10-11.md |
| `video_cartoon.v`（s1_color / s2_contour）| `BUILD_PASS` | 见 `work/td_cartoon/`；告警未完全分类 |
| `video_cartoon_luma.v`（s3_luma 亮度量化） | `SIM_PASS` / `BUILD_PASS` | 仿真：5329 周期小尺寸 + 1188032 周期全尺寸通过；TD构建：Setup WNS +143ps, Hold WNS +20ps, 位流 `s3_luma.bit` (71c8...abc6) 生成 |
| cartoon-release 位流 | `USER_REPORTED_ON_BOARD` | SHA-256: `8284e7a90d3c36c20440d6e989800b4912683c5157e153cb64b3722f33bdd9f3`；用户反馈视觉效果差 |
| Sobel 轮廓融合 | `IMPLEMENTED_UNVERIFIED` | 阈值已验证软件模型，上板效果待确认 |
| 区域连通填充 | `PLANNED` | 未实现 |
| 按键模式切换上板 | `USER_REPORTED_ON_BOARD` | 用户报告切换可实现 |
| **G3 阶段门** | **未通过** | 待用户对 s3_luma 候选位流进行上板测试与视觉验收 |

---

## 当前阻塞清单

| 阻塞项 | 阻塞原因 | 解锁条件 |
|---|---|---|
| G1 硬件闭环 | 无可确认的下载+硬件证据链 | 实物接线 + 下载 + HDMI 观察 + 记录 |
| G2 接口审计 | G1 未通过 | G1 通过后执行（可提前只读审计） |
| 卡通效果上板通过 | 已有位流效果差；新候选待下载 | 新 s3_luma 构建通过 + 上板对比 |
| PHY-5060/5079/5088 告警 | 时钟告警未分类 | 逐条记录来源 + 上板观察 |
| OSD 安路 Logo | RTL 未实现 | 设计 + 仿真 + 集成 |
| YOLO Micro-CNN | Y2 候选权重与 x86 INT8 已固定，但独立测试仅 128 输入有 2 个瓶子 TP 且误报严重；工位数据和验收指标未冻结 | 工位分批数据 + 预设指标 → 重训并通过独立测试 → 视觉验收 |
| WM8978 语音 | 管脚 / 时序 / Codec 配置未核对 | 原理图核对 + I2S 驱动 |

---

## 关键文件与位流清单

| 标识 | 路径 | SHA-256 | 状态 |
|---|---|---|---|
| Lab1 位流（原图） | `.tools/td/work/lab_ex1_mipi_hdmi_sc520/.../phy_1/camera_to_dsi_display.bit` | `A311...6010` | `BUILD_PASS`，待上板 |
| cartoon-release 位流 | `work/output/cartoon-release/camera_to_dsi_display.bit` | `8284...dd9f3` | `USER_REPORTED_ON_BOARD`，效果差 |
| 卡通组员版位流 | `HX1P35A2026/lab_ex1-3_SC520_add_cartoon/.../best_result/...bit` | `848a...fc78` | `FAIL`（时序失败） |

---

## 备选路线（传统工业检测）状态

详见 [`../fallback-status.md`](../fallback-status.md)。  
关键资产：`color_detect_96.v`，状态 `IMPLEMENTED_UNVERIFIED`。F2–F5 均为 `PLANNED`。

## 2026-10-12 卡通效果重新评审

- `project`：Algorithm Lab 新增同图三方案即时对比接口；使用 `sample_city.png` 生成 A 保色亮度分层、B RGB 色阶量化、C 双边平滑与自适应描边效果。代码见 `work/algorithm_lab/app.py` 和 `static/index.html`。
- `project`：`python -m unittest test_lab.py` 4 项通过，前端 JavaScript 语法检查通过，三方案样本生成成功；这只证明软件预览可运行。
- 本轮新效果选择保持 `VISUAL_REVIEW_PENDING`。登记册中 `cartoon` 既有 `v1.0-test` 批准记录对应历史 s3_luma 参数，不代表本轮 A/B/C 已获用户选择，也不能作为新硬件化授权。
- `unknown`：用户本轮效果选择、所选参数锁定、硬件等价模型复核、G1/G2 阶段门、当前板卡资源和时序余量。选择后才进入 Stage D；此前不改 RTL 和位流。

## 2026-10-12 Y1 FastestDet 软件复现

- `project`：Y1 研究交付 PASS，FastestDet 官方 COCO 80 类模型已在 Windows CPU 上复现，Algorithm Lab 可显示杯子、瓶子、手机检测框与置信度、调阈值、处理图片/视频并导出结果。源码与证据见 [Y1 报告](../experiments/2026-10-12-y1-fastestdet.md)。算法状态仍为 `VISUAL_REVIEW_PENDING`，不得据此启动 Stage D/E/F。
- `project`：独立 COCO val2017 29 图在 352 输入、0.25 阈值下 bottle P/R 0.184/0.280，cup 0.216/0.170，cell phone 0.125/0.083；160/128/96 未重训时三类 IoU≥0.5 均无正确匹配。该结果限制在本次抽样，不代表总体 COCO mAP。
- `project`：现有资源报告显示 32 DSP 和 69 ERAM 尚未占用；实际 FastestDet 卷积权重至少 236,112 B，超过 176,640 B 空闲 ERAM；352 输入最大单张 INT8 特征图 743,424 B。因此原模型直接部署 PH1P35 判 NO-GO。完整 INT8 模型和板级可行性仍未验证，G5 阶段门保持未通过。
- 本轮未修改 FPGA 视频工程、`conv_pe_int8.v`、`micro_cnn_golden.py`、PROJECT_GOAL.md、PHASES.md 或验收条件；未运行 TD、未生成位流。Y2 最小入口是三类数据集隔离、微型模型重训、INT8 软件验证和重新预算。

## 2026-10-12 Y2 三类微型检测软件预研

- `project`：Y2 公开数据预研 **FAIL（检测效果门）**，详见 [Y2 报告](../experiments/2026-10-12-y2-microdet.md)。COCO train/tune/new test 按图像 ID 隔离为 580/120/55 张；Y1 曾用的 29 图另列开发诊断集。96/160 在新测试 0 TP；128 仅 2 个瓶子 TP、822 个 FP；杯子和手机三尺寸均 0 TP，空场误报明显。工位场景和拍摄批次隔离尚未完成。
- `project`：三个模型 6,988 参数，PyTorch x86 静态 PTQ 后卷积 INT8 权重 6,436 B；量化后的新测试结论同样失败。逐层形状、MAC 和存储见 `work/y2_micro/results/`。160 输入的相邻完整特征峰值 153,600 B，紧贴本工程报告的 176,640 B 未占用 ERAM；这不是硬件综合或可用性证据。
- `project`：Algorithm Lab 新版在本机 `http://127.0.0.1:8503/` 提供 Y1/Y2 图片、视频、阈值、检测框和 ZIP 导出；接口冒烟通过。Y2 登记为 `SOFTWARE_IMPLEMENTED`，未获 `VISUAL_APPROVED`。
- `unknown`：用户稍后提供工位素材与验收数值。G1/G2 阶段门仍未通过；未改 FPGA 视频工程、核心 RTL 或长期目标，未运行 TD/生成位流。
