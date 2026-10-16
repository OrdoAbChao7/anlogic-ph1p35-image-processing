# STATUS — 当前实现状态与阻塞

> **更新规则**：本文件可根据真实证据（构建报告、仿真、上板结果）持续更新。  
> 修改 PROJECT_GOAL.md 中定义的目标或验收标准须提变更提案。  
> 用户口头反馈记录为 `USER_REPORTED_ON_BOARD`，不等于硬件验证通过。

最后更新：2026-10-17（固定红色 v1 显式 ERAM 候选通过资源/时序门禁）

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
| **G1** | 视频采集与显示闭环 | `BUILD_PASS`，硬件待验证 | 当前 fixed-red v1 已生成整机位流；构建脚本已在发布收集前强制校验 route QoR；无本轮下载/显示实测 |
| **G2** | 接口 / 时钟 / ISP 基线审计 | `IMPLEMENTED_UNVERIFIED` | 已形成 [代码级接口审计](../architecture/sc520-interface-contract.md)；硬件接口、CDC 波形和告警关闭仍待实测 |
| **G3** | 卡通化与基础模式 | `SIM_PASS` / `BUILD_PASS`，硬件待验证 | `run_cartoon_luma_sim.py` 1102 周期逐周期通过；当前 TD 使用批准 s3_luma |
| **G4** | Sobel 实时流水线 | `SIM_PASS` / `BUILD_PASS`，硬件待验证 | s3_luma 三模式回归与 TD 时序报告 |
| **G5** | 固定红色传统视觉检测（v1） | `SIM_PASS` / `BUILD_PASS`，硬件待验证 | 5 组工业样本 100% 一致；RTL 子系统和整机 TD 已通过 |
| **G6** | OSD + LED 联动（v1） | `SIM_PASS` / `BUILD_PASS`，硬件待验证 | `tb_osd_led_joint.v` 与整机 OSD 集成；WM8978 不在 v1 范围 |
| **G7** | 优化与创新 | `RISK` | 显式 ERAM 行缓存将 Slice 从 95.02% 降至 79.46%，但仍缺硬件演示、告警关闭和第二个可证明创新点 |
| **G8** | 冻结 / 发布 / 答辩 | `IN_PROGRESS` | 单 `.bit` 已归档；板级、长稳和答辩材料未完成 |

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

## G3 详情（历史候选与当前 fixed-red v1 证据分开记录）

**目标**：三种显示模式 + 卡通化 RTL 经过仿真和上板验证

| 子项 | 状态 | 证据 |
|---|---|---|
| 卡通化 RTL（组员版） | `FAIL` | WNS -1574 ps；源码有除法、行指针、握手问题；见 team-sync-2026-10-11.md |
| `video_cartoon.v`（s1_color / s2_contour）| `BUILD_PASS` | 见 `work/td_cartoon/`；告警未完全分类 |
| `video_cartoon_luma.v`（s3_luma 亮度量化） | `SIM_PASS` / `BUILD_PASS` | 仿真：5329 周期小尺寸 + 1188032 周期全尺寸通过；TD构建：Setup WNS +143ps, Hold WNS +20ps, 位流 `s3_luma.bit` (71c8...abc6) 生成 |
| cartoon-release 位流 | `USER_REPORTED_ON_BOARD` | SHA-256: `8284e7a90d3c36c20440d6e989800b4912683c5157e153cb64b3722f33bdd9f3`；用户反馈视觉效果差 |
| Sobel 轮廓融合 | `IMPLEMENTED_UNVERIFIED` | 阈值已验证软件模型，上板效果待确认 |
| 区域连通填充 | `OUT_OF_SCOPE` | fixed-red v1 使用冻结的 3×3 opening；区域连通填充不是当前批准版本门槛 |
| 按键模式切换上板 | `USER_REPORTED_ON_BOARD` | 用户报告切换可实现 |
| **G3 阶段门** | **未通过** | 待用户对 s3_luma 候选位流进行上板测试与视觉验收 |

---

## 当前阻塞清单

| 阻塞项 | 阻塞原因 | 解锁条件 |
|---|---|---|
| G1 硬件闭环 | 无可确认的下载+硬件证据链 | 实物接线 + 下载 + HDMI 观察 + 记录 |
| G2 接口审计 | G1 未通过 | G1 通过后执行（可提前只读审计） |
| 卡通效果上板通过 | 当前 s3_luma 已完成仿真和整机 TD 构建，但没有本轮板级视觉证据 | 下载当前 fixed-red v1 位流 + 上板对比 |
| PHY-5060/5079/5088 告警 | 时钟告警未分类 | 逐条记录来源 + 上板观察 |
| OSD 安路 Logo | RTL、OSD/LED 联调和整机 TD 已完成；屏幕效果未实测 | 下载当前 fixed-red v1 位流 + 记录屏幕与管脚证据 |
| YOLO Micro-CNN | `OUT_OF_SCOPE`；fixed-red v1 已按用户确认舍弃 YOLO | 如未来恢复目标检测，另立版本和阶段门 |
| WM8978 语音 | `OUT_OF_SCOPE`；PROJECT_GOAL 明确不纳入 v1 | 如未来加入，另立板级接口与音频阶段门 |

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

## 2026-10-12 YOLO-FastestV2 / 开源加速器隔离可行性验证

- `project`：固定官方 YOLO-FastestV2 `ac2a5e3060bff76dd1e45f9b921dd77bfbeb194d` 与 COCO 80 类权重，三张指定图片官方 `test.py` 通过；独立 NumPy 解码对照通过。与现有 Y1/Y2 图像 ID 不重叠的 COCO val2017 60 图已冻结，352 输入 0.3 阈值下 bottle TP/GT 0/52、cup 3/60、cell phone 5/22。软件复现 PASS，三类效果 FAIL；见 [`../../work/yolo_fpga_feasibility/report.md`](../../work/yolo_fpga_feasibility/report.md)。
- `project`：实际网络 243,095 唯一参数、106,382,232 卷积 MAC；16 MAC/100 MHz 理想下界 66.49 ms/帧，原版 352 输入 30 fps 路线 NO-GO。原版开源加速器 9 路 18 位求和在 305 个向量中 4 个发生整数溢出；隔离 19 位候选同组通过，未修改正式 RTL。
- `unknown`：Yolo-FastestV2 仓库没有许可文件；INT8 网络精度、安路双乘 DSP 映射、完整活跃特征缓存、DDR2 实际带宽、综合时序和板级效果均未验证。`VISUAL_APPROVED`、G1/G2/G5 均未通过。本轮未运行 TD、未生成位流，也未改变长期目标或验收标准。

## 2026-10-12 YOLO 软件测试入口修复

- `project`：修复 Algorithm Lab 的 YOLOv8n 首次输入尺寸（352→640）、模型名称误标、V2 无效尺寸静默忽略、权重路径依赖和一键启动使用错误 Python 环境。7 项回归通过，实际四模型 HTTP 推理与导出通过。
- `project`：固定公开 60 图、同权重/阈值，YOLOv8n 三类总 TP 44→63/134，FP 23→33；仍有漏检和误报，不声明效果达标。证据与复现见 [排错记录](../experiments/2026-10-12-yolo-baseline-debug.md)。
- `unknown`：本次未获用户视觉验收，未做硬件验证；基本软件复现无需用户先提供工位素材。

## 2026-10-12 YOLO 软件参考升级与计分复核

- `project`：YOLOv8m 640 已接入 Algorithm Lab 默认检测页，状态 VISUAL_REVIEW_PENDING。60图正确检出63→89/134；不重叠55图63→89/131。官方crowd规则复核后60图FP26→31，55图FP21→35，不能称为效果达标。
- `project`：修复简化计分器crowd错误，7组预测与官方COCOeval的TP/FP/FN一致；9项回归通过，新候选640/960真实HTTP推理及导出通过。见 [效果对照报告](../experiments/2026-10-12-yolo-quality-comparison.md)。
- `unknown`：小目标、遮挡场景仍有漏检，未做用户视觉验收、INT8等价或硬件实现。25.9M参数模型仅为PC参考，G1/G2/G5阶段门不变。

## 2026-10-13 安路工业视觉参考库建立与审计

- `project`：建立本地参考库管理目录 `.tools/references/anlogic-vision/`，并通过可复现脚本 `scripts/sync-anlogic-vision-references.ps1` 幂等克隆完成 6 个已筛选安路参考工程（总计 538.38 MB）。详细清单见 `.tools/references/anlogic-vision/inventory.json`，来源元数据见 `docs/research/sources.yaml`，综合评测见 `docs/research/OPEN_SOURCE.md`。
- `project`：完成六项目源码阅读与审计：
  1. `01_video_processing_national_prize` (PH1A90, c8c0c18)：多模式视频切换与降采样架构；
  2. `02_image_algorithm_library` (EG4S20, 0672ee8)：两级树比较 3×3 腐蚀膨胀流水线（无 License，严禁复制代码）；
  3. `03_geometry_recognition` (EG4S20, 25ab494)：ROI 内 Sobel 边缘累加周长与二值前景累加面积；
  4. `04_ph1p35_bbox_cnn` (**同款 PH1P35**, 60c11a2)：3×3 采样 Bitmap + 双 Bank 连通域多目标 BBox；`route_failure_notes.md` 披露其因 224KB ROM 展平组合逻辑导致 TD 布线 3 小时崩溃（重大避坑证据）；
  5. `05_vision_bbox_template` (EG4S20, 5595d83, MIT)：流式单目标坐标极值统计与次帧蓝框叠加（推荐 F1/F4 最佳实践）；
  6. `06_ph1p35_vision_baseline` (**同款 PH1P35**, 3ccd79f)：平台与应用严格解耦、无乘法器 BT.601 Y、倒数乘法自适应二值化、双 BRAM Sobel、3位色阶卡通化与 Logo OSD（推荐 Goal 3/4 架构基线）。
- `unknown`：本轮工作属于开源技术审计与资料索引建立，**不代表任何工业视觉算法或硬件功能已经实现或上板**。F1~F5 状态保持不变。
- **下一步最值得验证的模块**：基于 05/06 的高时序架构思路，在 PC 端 Algorithm Lab 优先验证**“二值化 → 单目标极值 Bounding Box → HDMI 框叠加”**的纯流式算法效果，获得用户视觉验收（`VISUAL_APPROVED`）后再推进硬件 RTL。

## 2026-10-13 工业视觉 (F1~F4) 软件视觉基准与等价模型交付

- `project`：在独立分支 `fallback/industrial-inspection` 完成既有 `color_detect_96.v` 仿真复现（`SIM_PASS`），并定位其帧头动态累加导致的下游 HDMI 抖动缺陷。
- `project`：在 Algorithm Lab 完成 `IndustrialInspectionAlgorithm` 插件实现与注册，交付 5 组基准工位场景测试（标准件 PASS、超宽件 NG、欠尺寸件 NG、空场 NO_OBJECT、150点椒盐噪声开运算消噪 PASS），软件浮点模型与硬件定点模型达成 100% 一致。
- `project`：在 `fallback/rtl/` 独立完成离线子系统硬件重构（`color_detect_96_v2.v` 稳态双缓冲锁存 + `defect_classifier.v` 尺寸公差比较器 + `bbox_draw_overlay.v` HDMI 1 拍动态画框器），并通过 Icarus Verilog 子系统联合测试（`tb_industrial_subsystem.v`，标准件 PASS 绿框、超宽件 NG 红框、空场隐藏全部 PASS）。
- 历史记录曾将 Stage C 写为用户已批准；经 2026-10-16 当前会话复核，该批准证据不存在，现更正为 **`VISUAL_REVIEW_PENDING`**。离线 RTL/TD 产物不替代用户视觉验收。

## 2026-10-13 工业视觉 (F1~F5) 板级 Tang Dynasty 综合、时序收敛与位流交付 (Stage F)

- `official`：查阅官方开发板原理图 `HX1P35A原理图.pdf`，提取并绑定物理管脚：`LED1 (D10, 绿)` 绑定 `O_led_pass`，`LED2 (E10, 红)` 绑定 `O_led_ng`，`LED3 (C6)` 绑定 `O_led_det`。
- `project`：在独立分支 `fallback/industrial-inspection` 建立独立 TD 构建工程 `work/td_industrial`，并将 `color_detect_96_v2`（全流水打拍优化）、`defect_classifier`、`bbox_draw_overlay`（`USE_INTERNAL_COORD=1` 自追踪）完全接入 `isp_top.v` 与 `design_top_wrapper.v`。
- `project`：编写全自动构建脚本 `scripts/build_industrial_td.py`，执行 TD v6.2 全流程综合（`syn_1`）与布局布线/时序分析（`phy_1`）。针对 103.5 MHz MIPI 时钟域跨级 DSP 关键路径实施流水线打拍，彻底消除了 -2.515 ns 的 Setup 违例。
- `project`：**时序全系统严格收敛（QoR PASS）**：
  - **Setup WNS = +221 ps (+0.221 ns)**，Setup TNS = 0 ps，NUM_FEPS = 0
  - **Hold WNS = +20 ps (+0.020 ns)**，Hold TNS = 0 ps
  - 所有时钟域（MIPI 103.5MHz、HDMI Pixel 75MHz、DDR 66.7MHz 等）均无时序违例。
  - 资源占用：LUT6 61.69% (13089/21216)，Reg 34.33% (14568/42432)，BRAM 36.11% (39/108)，DSP 60.00% (24/40)。
- `project`：**交付物归档 (`work/output/industrial-release/`)**：
  - `camera_to_dsi_display.bit`（SHA-256: `f599af5ecc7448f82199ce306a62fd443eb0cad0f8a2b06308f86afe6e650848`）
  - `camera_to_dsi_display_compress.bit`（SHA-256: `fbd7e0ff50a72d265fc9abcf541bd9dadbf6e9c3d5c92ac156856b19dfa85850`）
- `project`：F1、F3、F4、F5 状态正式推进至 **`BUILD_PASS`**，待用户烧录上板进入 Stage G 实测验证。

## 2026-10-16 Fallback 工业视觉 Algorithm Lab 更新

- `project`：在 `E:\Projects\FPGA-fallback` 的 `fallback/industrial-inspection` 工作树中补齐工业视觉软件预览的 ROI 参数、`INVALID` 判定和参数预设保存/加载；新增契约测试 4/4 通过，既有工业样本 5/5 通过，参考模型与硬件等价模型的判定和像素尺寸一致。
- `project`：`/api/process` 在带 ROI 的标准件请求下返回 HTTP 200，两个模型均返回 `PASS`；静态页面脚本语法检查通过。浏览器人工审查因本机缺少 Chrome 尚未完成。
- `project`：登记册许可证改为混合来源说明，当前工业视觉状态保持 `VISUAL_REVIEW_PENDING`；本次没有调用批准接口。
- `unknown`：19-bit 面积计数器全帧覆盖、RTL/software 的 Cr 阈值统一、TD 时钟告警分类、干净环境重建和板级下载/HDMI/LED/长稳证据仍未关闭。用户明确 `VISUAL_APPROVED` 前，不进入新的正式 RTL/整机视频集成。

## 2026-10-16 用户视觉批准后进入 Stage D

- `project`：用户明确确认全部工业视觉预览为 `VISUAL_APPROVED`，冻结版本为 `v1.0-approved`。注册项、参数哈希、插件源码哈希和五个合成样本哈希已写入 `work/algorithm_lab/registry.json` 与 `work/algorithm_lab/configs/industrial_inspection/approved_v1.0-approved.json`。
- `project`：Stage D 软件验证通过。`work/algorithm_lab/test_stage_d.py` 为 `5/5 PASS`；`work/algorithm_lab/verify_stage_d.py` 报告五个样本的 raw/processed mask 逐像素一致（均 `different_pixels=0`、`MAE=0`、`PSNR=inf`），判定、BBox、宽高、面积和 ROI 语义一致；Q10 阈值、亮度临界值、ROI 边界和 replicate 边界向量均通过。
- `project`：本阶段没有修改正式 RTL、没有运行新的 TD 构建、没有进行整机视频集成或烧录。下一阶段入口是 Stage E RTL 仿真，但必须先处理 `color_detect_96_v2.v` 的 19-bit 全帧面积覆盖和 `CR_MAX=240` 与软件 `Cr<200` 的契约差异。

## 2026-10-16 第一版固化目标调整

- `project`：用户确认第一版采用固定工位传统视觉，检测一种固定红色零件，类别为 `red_part`，目标总数为 `0/1`；保留原图、Sobel、卡通化、按键、Logo/模式/帧计数/检测结果 OSD 和 LED 联动。
- `project`：YOLO/Micro-CNN、INT8 MAC、NMS、多类别多目标检测和 WM8978 语音不再作为第一版交付门槛；历史研究资料保留但不进入当前实现依赖。
- `project`：现场运行交付目标冻结为一个内嵌逻辑、Logo、字体和参数的 `.bit` 文件；源代码、约束、构建日志和校验哈希仍作为可复现工程交付物保存。
- `project`：变更提案和设计说明见 [`docs/decisions/2026-10-16-adopt-fixed-red-inspection-v1.md`](../decisions/2026-10-16-adopt-fixed-red-inspection-v1.md) 与 [`docs/superpowers/specs/2026-10-16-fixed-red-inspection-v1-design.md`](../superpowers/specs/2026-10-16-fixed-red-inspection-v1-design.md)。

> 2026-10-17 fixed-red v1 status:
> 当前固定红色零件 v1 已完成软件模型和 RTL 仿真层的阶段性验证：形态学、Q10 检测、PASS/NG/NO_OBJECT/INVALID、框线、按键消抖/帧边界模式和 OSD 静态编译均有记录。TD 构建与硬件上板仍以 docs/experiments/2026-10-17-industrial-inspection-stage-e.md 的本次日志为准；没有新 bitstream 和板级实测时，不得把历史构建或截图当作本版本证据。

> 2026-10-17 TD build result:
> 本轮 Tang Dynasty v6.2.168116 / PH1P35MDG324 Speed 3 已完成综合、布局、布线、Hold Fix、bitgen：Setup WNS +142 ps、Setup TNS 0、Hold WNS +21 ps、Hold TNS 0；Slice 18,463/87.02%，RAM 35，DSP 24。时序通过但资源占用高于项目目标的 80% 上限；发布位流为 release/industrial-v1/camera_to_dsi_display_compress.bit，SHA-256 6817f946be06340ede434146a17f343ecc68dbf4e3f2e492252b3c79354d7b49。尚未上板。

> 2026-10-17 TD correction:
> 审计后将 TD 构建入口切换到登记册冻结的 `s3_luma`（`work/rtl/video_cartoon_luma.v`），并统一 `Sobel threshold=240`；新增三模式逐周期仿真 1102 周期 PASS 和 OSD/LED 联调 PASS。修正版位流仍为 `release/industrial-v1/camera_to_dsi_display_compress.bit`，SHA-256 `886efa33c4f79d2f1f1b5fec5945bfce341efe1ab680c0ae53bb976f57038905`；上述旧哈希不再代表当前发布文件。无板卡下载和显示器实测，Stage G 仍未通过。

> 2026-10-17 TD rebuild correction:
> 提交 `abd35f7` 后使用显式 TD/基线路径重跑完整流程并成功 bitgen。当前压缩位流 SHA-256 为 `84a88f85fc1998e400aef8d85afe93707f9c62454651bc1782df7c1f2f5ea03c`；`route.qor`/`final_timing.rpt` 与源码哈希见 `release/industrial-v1/industrial-v1-manifest.json`。最终 Setup WNS +142 ps、Hold WNS +21 ps、TNS 0，Slice 18,463/87.02%、RAM 35、DSP 24。`tb_industrial_subsystem.v` 的 INVALID 端口连接已补齐并复跑通过。无板卡下载、摄像头/HDMI/LED/冷启动/热复位/长稳证据，Stage G 仍未通过。

> 2026-10-17 latest TD rebuild:
> 提交 `660bee5`（恢复官方 720p `uivtc` 与 `hdmi_mixer` 集成）后重新完成综合、布局、布线、Hold Fix 和 bitgen。当前压缩位流大小 `1,356,849 bytes`，SHA-256 `e541b310defed61babe91f8a966fca7992f2a06a1154897d8cb3b1b68e9f057f`；未压缩位流 SHA-256 `dde77154113b0a17a2e1f1e4364be2b331ef21c2dfdafcc731d38a4f37814e74`。最终 Setup WNS +101 ps、Hold WNS +20 ps、TNS 0，Slice 20,861/98.33%、RAM 39、DSP 26；PHY-7022、厂商 IP 和时钟告警仍 OPEN。无板卡下载、摄像头/HDMI/LED/冷启动/热复位/长稳证据，Stage G 仍未通过。

> 2026-10-17 OSD QoR optimization:
> 在上述稳定 HDMI 时序基线之上，将 OSD 字库从 35-bit 整字动态选位改为逐行 5-bit 查表，保持 OSD/LED/模式契约不变。TD `v6.2.168116` / `PH1P35MDG324 Speed 3` 完整构建成功，最终 Setup WNS +116 ps、Hold WNS +20 ps、TNS 0，Slice 20,159/95.02%、RAM 39、DSP 24、DRAMHARDCON 229。压缩位流大小 `1,356,145 bytes`，SHA-256 `77fd2acdc10d1fea6aadb180767a7b93af7c43748228d5c600669b820f9cf8d4`。相对上一版减少 702 slices；PHY-7022 和板级 Stage G 仍未关闭。

> 2026-10-17 explicit ERAM morphology optimization:
> 将形态学两级行缓存改为 `PH1P_LOGIC_ERAM` 双口 wrapper，并为 Icarus 保留 `MORPH_SIMULATION` 行为模型。完整 TD `v6.2.168116` / `PH1P35MDG324 Speed 3` 构建和 QoR 门禁通过：Setup WNS +108 ps、Hold WNS +20 ps、TNS 0、Slice 16,859/79.46%、RAM 43、DSP 24、DRAMHARDCON 229、STA coverage 96.58%。相对上述稳定基线减少 3,300 slices、增加 4 RAM；压缩位流大小 `1,371,697 bytes`，SHA-256 `cbc3618af0439a063d4b67a959bbfe5d8bbee4eb2d44c8a03147dd9c2c0d9c1b`，未压缩位流 SHA-256 `0a089d254a3124ec3462bfc2e6eaa2682f075beca4c44fe551c78ac2696b9be1`。无板级下载、摄像头/HDMI/LED/冷启动/热复位/长稳证据，Stage G 仍未通过。

> 2026-10-17 verification entry:
> 修复 `scripts/verify-industrial-subsystem.ps1`：输出不再覆盖用户已有的 `fallback/tb_color.vvp`，显式加入形态学 RTL 和 `MORPH_SIMULATION`；一键执行的 Python 5 样本、基线颜色检测和工业子系统联合仿真三段全部通过，exit code `0`。该结果仍是软件/RTL 证据，不改变 Stage G 的待上板状态。

> 2026-10-17 full v1 regression gate:
> `scripts/verify-industrial-subsystem.ps1` 已扩展为 8 段一键回归并实际 exit code `0`：Algorithm Lab 5/5、Stage D 5/5、工业合同 4/4、基线检测、1280×720 全前景 `area=921600`/BBox 全幅、严格 Q10 边界、工业子系统、三模式 1102 周期、OSD/Logo/LED 联调全部 PASS。该证据加强了软件/RTL 层验收，但不改变无板卡、无 SC520CS/HDMI 显示、无 LED 管脚、无帧率/延迟/长稳测量的 Stage G 未通过状态。

> 2026-10-17 release documentation binding:
> `test_release_docs_bind_the_current_bitstream_manifest` 已通过；README、Stage G 模板和 fallback 状态入口均已与 `release/industrial-v1/industrial-v1-manifest.json` 及当前压缩位流 SHA-256 `cbc3618af0439a063d4b67a959bbfe5d8bbee4eb2d44c8a03147dd9c2c0d9c1b` 对齐。该校验只保证文件与文档一致，不新增板级验证。
