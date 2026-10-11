# PHASES — 阶段顺序、依赖与验收门

> 本文件定义 8 个阶段的依赖关系、输入输出接口、交付成果和验收标准入口。  
> 具体测试方法和通过条件见 [`../verification/acceptance-matrix.md`](../verification/acceptance-matrix.md)。  
> 各阶段实际状态见 [`STATUS.md`](STATUS.md)。  
> 开源参考候选见 [`../research/OPEN_SOURCE.md`](../research/OPEN_SOURCE.md)。

---

## 依赖关系

```
G1 (视频闭环)
  └─ G2 (接口/ISP 基线)
       ├─ G3 (卡通化 + 模式)
       │    ├─ G4 (Sobel 流水线)
       │    │    └─ G5 (YOLO 检测) ──┐
       │    │                        │
       │    └─ G6 (OSD + 外设) ──────┤
       │                             │
       └─────────────────────────────┘
                                     ↓
                                G7 (优化)
                                     ↓
                                G8 (冻结/发布)
```

> [!NOTE]
> G6 基础 OSD（安路 Logo、模式、帧计数）**不依赖 G5**，可在 G4 完成后推进。  
> G2 可在 G1 通过前执行只读接口审计。  
> 备选路线 F1–F5 独立于主线，不受上述依赖约束。

---

## G1：视频采集与显示闭环

**目标**：SC520CS → MIPI → ISP → DDR2 → HDMI 原始视频链路稳定运行

| 项目 | 内容 |
|---|---|
| 范围 | 原图直通；不接任何算法模块 |
| 非目标 | 图像处理、OSD、检测 |
| 前置依赖 | 无 |
| 开源参考 | `georgeyhere-video`（视频流结构参考）；`FHDO-ICLAB MIPI`（链路架构参考） |
| 输入 | SC520CS RAW10，1280×720 MIPI CSI-2 |
| 输出 | HDMI 720p 实时原图，DE/HSYNC/VSYNC 正常 |
| 关键接口 | MIPI → CSI-2 解包 → Demosaic → 96-bit RGB → DDR → HDMI |
| AGY 交付成果 | 构建日志、位流 SHA、告警台账、上板记录 |
| 仿真 | 不适用（依赖厂商 IP） |
| 综合/实现 | Setup/Hold WNS ≥ 0，TNS = 0；无未解释关键告警 |
| 上板操作 | 下载 + 冷启动 + 热复位（各 3 次）+ 连续观察 30 min |
| PASS 条件 | 每次均恢复实时画面；分辨率/帧率有依据；无花屏/撕裂/锁相丢失 |
| 证据路径 | `docs/evidence/goal-1/`，`docs/build/goal-1-sc520-lab1/` |

---

## G2：接口 / 时钟 / ISP 基线

**目标**：冻结 MIPI→HDMI 各段接口契约，形成可审计模块关系

| 项目 | 内容 |
|---|---|
| 范围 | 只读审计；不改动 RTL |
| 前置依赖 | G1 通过（可提前只读审计） |
| 输入 | Lab1 综合/布线报告、源码 |
| 输出 | `docs/architecture/sc520-interface-contract.md`（各接口字段、CDC、时钟域） |
| PASS 条件 | 每段接口可定位源文件；无 unknown 字段；延迟区分算法与帧缓存 |

---

## G3：卡通化与基础模式

**目标**：三种模式 RTL 经过软件黄金模型对比、上板视觉验收

| 项目 | 内容 |
|---|---|
| 范围 | 颜色量化 + Sobel 轮廓 + 区域填充 + 模式切换 |
| 前置依赖 | G1、G2 |
| 开源参考 | `georgeyhere-video`（FIFO 结构）；`galapple-sobel`（量化参考） |
| 输入 | 96-bit RGB 四像素/拍，DDR 前 ISP 输出 |
| 输出 | 96-bit RGB，模式选择后，DDR 前同一插入点 |
| 软件黄金模型 | `work/models/reference_model.py`（已有）；需扩展区域填充 |
| RTL | `work/rtl/video_cartoon_luma.v`（当前候选）；须与黄金模型逐像素比对 |
| PASS 条件 | SIM 无差异；上板三种模式可切换且视觉符合预期；边界行为有记录 |

---

## G4：Sobel 实时流水线

**目标**：可综合 Line Buffer + 3×3 窗口实时 Sobel，RTL/仿真均通过

| 项目 | 内容 |
|---|---|
| 范围 | 流式单像素或四像素输入，输出同步控制信号 |
| 前置依赖 | G3 |
| 开源参考 | `galapple-sobel`（窗口结构参考）；`georgeyhere-video`（Line Buffer 参考） |
| 输入 | 96-bit RGB 四像素/拍 |
| 输出 | 96-bit 边缘图，valid/DE/HSYNC/VSYNC 同步 |
| PASS 条件 | 窗口时序仿真；参考图逐像素比对；综合推断流式结构；上板 Sobel 模式 10 min |

---

## G5：YOLO Micro-CNN 检测

**目标**：INT8 量化裁剪模型，卷积/池化/NMS RTL 分阶段完成，GO/NO-GO 逐阶段评估

| 项目 | 内容 |
|---|---|
| 范围 | 固定模型版本；INT8 量化；全片上权重 |
| 前置依赖 | G3、G2 |
| 开源参考 | `Yolo-FastestV2`（模型结构参考）；`finn`（量化方法参考）；不直接移植代码 |
| 输入 | 视频分叉流或 DDR 帧缓存 ROI |
| 输出 | BBox 坐标、类别、置信度（帧边界稳定） |
| PASS 条件 | 权重可追溯；算子仿真通过；空场/单目标/多目标测试；资源报告有余量 |

---

## G6：OSD + 外设联动

**目标**：安路 Logo、模式、帧计数、检测框；按键 / LED / WM8978 联动

| 项目 | 内容 |
|---|---|
| 范围 | OSD 叠加；检测框仅在 G5 完成后叠入；基础 OSD 独立于 G5 |
| 前置依赖 | G4（基础 OSD）；G5（检测框部分） |
| PASS 条件 | OSD 与视频同步；检测结果不闪烁；有效事件才触发 LED/语音 |

---

## G7：优化与创新

**目标**：2–3 个可量化亮点，有基线对照

| 前置依赖 | G6 稳定版本 |
|---|---|
| 候选方向 | 全流水低延迟；Line Buffer/位宽资源优化；自适应阈值；INT8 卷积复用 |
| PASS 条件 | 每个亮点有量化改善 + 硬件演示；其他指标不退步 |

---

## G8：冻结 / 发布 / 答辩

**目标**：干净环境可重建，另一队员可按文档完整演示

| 前置依赖 | G1–G7 全部通过 |
|---|---|
| 测试规模 | 冷启动/热复位/下载各 10 次；连续运行 4 h；完整演示 3 次 |
| 交付物 | RTL、约束、IP 配置、构建说明、Bitstream + 哈希、PPT、演示视频、FAQ |

---

## 备选路线 F1–F5

独立于主线阶段，详见 [`../fallback-status.md`](../fallback-status.md)。

| 阶段 | 内容 | 状态 |
|---|---|---|
| F1 | `color_detect_96.v` 迁移与规范化 | `IMPLEMENTED_UNVERIFIED` |
| F2 | 形态学滤波（腐蚀/膨胀） | `PLANNED` |
| F3 | 几何特征与尺寸测量 | `PLANNED` |
| F4 | PASS/NG 缺陷判定器 | `PLANNED` |
| F5 | 独立 TD 工程交付包 | `IN_PROGRESS` |
