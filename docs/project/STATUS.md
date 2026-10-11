# STATUS — 当前实现状态与阻塞

> **更新规则**：本文件可根据真实证据（构建报告、仿真、上板结果）持续更新。  
> 修改 PROJECT_GOAL.md 中定义的目标或验收标准须提变更提案。  
> 用户口头反馈记录为 `USER_REPORTED_ON_BOARD`，不等于硬件验证通过。

最后更新：2026-10-11（本次文档整理）

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
| **G5** | YOLO-tiny 检测 | `PLANNED` | Micro-CNN GO 评估完成；PE RTL 有基础结构 |
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
| `video_cartoon_luma.v`（s3_luma 亮度量化） | `SIM_PASS` | 5329 周期小尺寸 + 1188032 周期全尺寸通过；见 staged-cartoon 实验记录 |
| cartoon-release 位流 | `USER_REPORTED_ON_BOARD` | SHA-256: `8284e7a90d3c36c20440d6e989800b4912683c5157e153cb64b3722f33bdd9f3`；效果差 |
| Sobel 轮廓融合 | `IMPLEMENTED_UNVERIFIED` | 阈值已验证软件模型，上板效果待确认 |
| 区域连通填充 | `PLANNED` | 未实现 |
| 按键模式切换上板 | `USER_REPORTED_ON_BOARD` | 用户报告切换可实现 |
| **G3 阶段门** | **未通过** | 卡通效果上板不满足、区域填充未实现 |

---

## 当前阻塞清单

| 阻塞项 | 阻塞原因 | 解锁条件 |
|---|---|---|
| G1 硬件闭环 | 无可确认的下载+硬件证据链 | 实物接线 + 下载 + HDMI 观察 + 记录 |
| G2 接口审计 | G1 未通过 | G1 通过后执行（可提前只读审计） |
| 卡通效果上板通过 | 已有位流效果差；新候选待下载 | 新 s3_luma 构建通过 + 上板对比 |
| PHY-5060/5079/5088 告警 | 时钟告警未分类 | 逐条记录来源 + 上板观察 |
| OSD 安路 Logo | RTL 未实现 | 设计 + 仿真 + 集成 |
| YOLO Micro-CNN | 模型未固定；权重未量化 | 固定模型版本 → 量化 → 算子仿真 |
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
