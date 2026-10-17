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
        │    │    └─ G5 (固定红色零件检测) ──┐
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

## G5：固定红色零件检测

**目标**：固定 ROI 内单个红色零件的流式分割、形态学、BBox、尺寸和 PASS/NG 判定完成，并接入统一视频流

| 项目 | 内容 |
|---|---|
| 范围 | 固定摄像头/物距/光照/背景/ROI；一种红色零件；目标总数 `0/1`；不使用 YOLO/Micro-CNN |
| 前置依赖 | G3、G2 |
| 开源参考 | `05_vision_bbox_template`、`06_ph1p35_vision_baseline`、`02_image_algorithm_library`；仅借鉴架构和算法，不直接复制无许可证 RTL |
| 输入 | ISP/DDR 输出的 RGB 流，固定 ROI |
| 输出 | `red_part`、目标总数 `0/1`、BBox、面积、宽高、`PASS/NG/NO_OBJECT/INVALID` |
| PASS 条件 | 软件/RTL 逐像素和边界回归通过；空场/标准件/超差件/非法 ROI 通过；检测结果帧边界稳定；资源和时序有余量 |

---

## G6：OSD + 外设联动

**目标**：安路 Logo、模式、帧计数、检测框、类别、总数和尺寸；按键 / LED 联动

| 项目 | 内容 |
|---|---|
| 范围 | OSD 叠加；基础 OSD 独立于 G5；检测框和状态在 G5 完成后叠入；WM8978 不属于第一版范围 |
| 前置依赖 | G4（基础 OSD）；G5（检测框、类别、总数和尺寸） |
| PASS 条件 | OSD 与视频同步；检测结果不闪烁；模式按键在帧边界生效；有效检测才触发 LED |

---

## G7：优化与创新

**目标**：2–3 个可量化亮点，有基线对照

| 前置依赖 | G6 稳定版本 |
|---|---|
| 候选方向 | 全流水低延迟；Line Buffer/位宽资源优化；固定阈值稳定化；检测和 OSD 流水线复用 |
| PASS 条件 | 每个亮点有量化改善 + 硬件演示；其他指标不退步 |

---

## G8：冻结 / 发布 / 答辩

**目标**：干净环境可重建，另一队员可按文档完整演示

| 前置依赖 | G1–G7 全部通过 |
|---|---|
| 测试规模 | 冷启动/热复位/下载各 10 次；连续运行 4 h；完整演示 3 次 |
| 交付物 | RTL、约束、IP 配置、构建说明、Bitstream + 哈希、PPT、演示视频、FAQ |

---

## 工业视觉实现载体 F1–F5

这些模块是 G5/G6 的实现载体，位于独立 Fallback 工作树，详见 [`../fallback-status.md`](../fallback-status.md)。

| 阶段 | 内容 | 状态 |
|---|---|---|
| F1 | `color_detect_96.v` 迁移与规范化 | `SIM_PASS / BUILD_PASS，行为缺口开放` |
| F2 | 形态学滤波（腐蚀/膨胀） | `软件 Stage D 通过，RTL 待统一契约` |
| F3 | 几何特征与尺寸测量 | `SIM_PASS / BUILD_PASS，待整机` |
| F4 | PASS/NG 缺陷判定器 | `SIM_PASS / BUILD_PASS，待整机` |
| F5 | 独立 TD 工程交付包 | `TD_BUILD_PASS，复现性与告警开放` |
