# PH1P35 工业视觉 V2 七项能力设计

## 目标

在冻结的 fixed-red v1 候选之上，建立隔离的 `industrial-v2-advanced` 开发线，并最终形成一个同时包含七项升级能力的 PH1P35 单 Bitstream 候选：交互/OSD 质量修复、单目标动态跟踪、内部处理延迟测量、固定 ROI 帧差运动检测、分拣事件控制、光照自适应/白平衡优化、标定尺寸与形状验证。

本设计不改变受保护的 `PROJECT_GOAL.md`、`PHASES.md`、`AGENTS.md` 或既有 fixed-red v1 冻结候选。V1 的固定红色零件、三种视频模式和 OSD/LED 基线继续作为回退点；历史 YOLO/Micro-CNN 与 WM8978 不恢复为本 V2 的实现依赖。

## 已确认边界与证据

- V1 基线：`fallback/industrial-inspection@256d99c1d0dc4dbae2ace8d0ff3a97f504d514c9`，冻结位流 SHA-256 为 `b483a1ffc30d0b7ae9e8ebef4f31f617d33a53d6784ded8007d5443c51ad80ef`。来源：`project`，`docs/evidence/industrial-v1-hx1p35a-pin-correction-freeze.md`。
- V1 资源/时序基线：Slice `17,642/21,216`、RAM `43`、DSP `24`、Setup WNS `+103 ps`、Hold WNS `+20 ps`、TNS `0`。来源：`project`，仅作为预算基线，不是 V2 结果。
- V1 真实板级证据目前仅为 `USER_REPORTED_ON_BOARD`，不升级为 `VERIFIED_ON_BOARD`。来源：`project`，同一冻结报告和 `docs/project/STATUS.md`。
- V2 Worktree：`E:/Projects/FPGA-v2`，分支 `goal/industrial-v2-advanced`，从 V1 提交创建；原工作区的未提交修改不纳入 V2 初始状态。
- 用户指令允许需要视觉审查的环节默认通过。该授权只关闭 Stage C 的等待，不替代软件预览、模型/RTL 回归、TD 报告、真实硬件、仪器或物理标定证据。

## 阶段和依赖

```text
V2-G0 基线保护/环境核查
  ├─ V2-G1 交互、OSD、ROI 质量
  ├─ V2-G2 单目标跟踪与轨迹
  ├─ V2-G3 内部延迟测量与可视化
  ├─ V2-G4 固定 ROI 帧差运动检测
  ├─ V2-G5 分拣事件控制（先内部/仿真，再外部 IO）
  ├─ V2-G6 光照自适应与白平衡优化
  └─ V2-G7 标定尺寸与形状验证
          ↓
      V2-G8 同一 Bitstream 融合、长稳、冻结与发布
```

G1/G2/G3/G4/G6/G7 的软件模型和独立 RTL 可以在不改变厂商视频边界的前提下并行准备；任何进入正式整机顶层的功能，都必须经过对应的硬件等价模型和 RTL 阶段门。V2-G8 只有在全部要求同时满足时才可发布；硬件、外部执行器、物理 E2E 延迟或标定条件缺失时保留 `BLOCKED`。

## 系统架构

保持 V1 的厂商 MIPI、CSI-2、ISP、DDR2、PLL、HDMI 和已核实管脚边界。新增能力分为四类：

1. **帧边界结果控制域**：`mode_controller`、检测结果快照、跟踪器、延迟统计、分拣事件和 OSD 页面状态只在约定帧事件更新。
2. **像素流域**：V1 的 Original/Sobel/Cartoon 和固定红色检测继续保持吞吐；帧差只在冻结的 ROI、明确的降采样/位宽方案和经过预算的存储结构中接入。
3. **跨时钟域**：多位检测结果、帧 ID、事件和计数使用已验证的快照+toggle、握手或异步 FIFO；禁止逐位同步。HDMI OSD、LED 与执行事件使用同一帧原子结果。
4. **参数与标定域**：阈值、白平衡增益、ROI、尺寸系数和形状门限由帧边界快照提供；缺少物理标定时只输出像素单位并显示 `N/A`，不能伪造毫米值。

### 主要模块边界

| 能力 | 建议模块 | 输入 | 输出 | 首要证据 |
|---|---|---|---|---|
| 交互/OSD/ROI | `mode_controller`、现有 OSD overlay、`roi_contract` | 按键、帧同步、V1 检测结果 | 帧边界模式、十进制 OSD、ROI 合同 | 模式/边界/文本回归 |
| 跟踪 | `temporal_tracker`、`trajectory_history`、`tracking_overlay` | 帧锁存 BBox、valid、帧号 | TRACKING/LOST/NO_OBJECT/INVALID、中心、方向、轨迹 | 软件/RTL 状态机比对 |
| 延迟 | `frame_tag_monitor`、`latency_monitor`、`performance_overlay` | 输入/输出帧事件、结果发布事件 | PROC/VIDEO/结果间隔、超时/丢帧标志 | 受控帧标签实验 |
| 帧差 | `motion_diff_roi`、ROI 历史存储 | 当前/历史 ROI 亮度、帧代次 | motion、计数、BBox、事件 | 8-bit 基准与资源试验 |
| 分拣 | `sort_event_controller`、`sort_pulse_generator`、`sort_safety_interlock` | 跟踪/判定/运动/复位 | 一次性 PASS/NG 事件、内部脉冲、安全状态 | 事件 TB + 虚拟执行器 |
| 光照/AWB | `frame_color_stats`、`awb_gain_controller` | RGB/亮度帧统计 | 帧边界增益、状态、饱和/异常标志 | 同场景开关对照 |
| 尺寸/形状 | `calibration_model.py`、`dimension_calibrator`、形状特征逻辑 | BBox、面积、标定参数 | px/mm 尺寸、比例、形状状态 | 标定重复性与 RTL 定点比对 |

模块名称仅在实际工程审计后冻结；不为适配设计文档而重写厂商生成源文件。

## 关键行为契约

### 交互、结果和 OSD

- KEY1 单击只产生一次模式请求；去抖后在 HDMI 帧边界提交。长按不连续触发。
- 空场隐藏旧框、轨迹和运动框；`INVALID` 禁止执行事件，并以明确颜色/文字显示。
- OSD 显示模式、十进制帧号、检测状态、类别/数量、跟踪状态、运动状态和可追溯的 `PROC/VIDEO/E2E` 字段；未测字段显示 `N/A`。
- OSD、LED 和分拣事件消费同一帧冻结的结果快照，禁止在扫描中途更新。

### 跟踪

V2 只承诺单目标关联。按冻结的中心距离/面积/速度门限选择当前检测与历史状态；连续无效帧进入 `LOST`，超过丢失窗口回到 `NO_OBJECT`。无效坐标不写入轨迹，重新进入必须产生新的进入事件。多目标场景标记为适用范围外，不得宣称多目标跟踪。

### 延迟

内部计数器明确绑定时钟域和单位；输入帧、DDR 显示帧和结果发布帧使用可追踪 tag 或受控实验关联。`PROC`、`VIDEO` 和物理 `E2E` 分开记录，不能用显示刷新率或帧计数代替物理端到端延迟。没有仪器时 `E2E=N/A`。

### 运动检测

首选 ROI 内 8-bit 亮度历史帧；先以 `160×120` 或经审计的实际 ROI 尺寸做资源试验，保留帧代次、首帧无历史和 DDR 读写冲突语义。任何 4-bit 或空间降采样替代必须与 8-bit 基线量化差异并经过用户可见效果审查。红色掩膜变化只能作为明确受限的备用方案，不能冒充通用灰度帧差。

### 分拣事件与外部控制

先完成内部事件和虚拟执行器闭环；每个有效目标只触发一次，`INVALID`、未完成判定、复位和丢失状态均为安全禁止。未经 HX1P35A 专用原理图、约束和驱动器电气参数确认，不新增物理 IO，不让 FPGA IO 直接驱动功率负载。没有真实执行器时，状态只能到 `SIM_PASS` 或 `RTL_PASS`。

### 光照自适应

先审计现有 AWB 是否已经生效，再在 FPGA 帧统计上实现轻量增益控制。增益有固定点位宽、上下限、平滑和更新门限，在帧边界更新；不将曝光寄存器写入或传感器自动曝光作为默认实现。没有 SC520CS 官方寄存器和板级验证，不修改传感器配置。

### 尺寸与形状

未完成固定工位标定时只输出 `px`；完成标定后同时保存距离、姿态、参考物、镜头、光照、系数和样本哈希，显示单位明确为 `mm`。形状验证至少采用面积/BBox 占比与宽高比等可解释特征，并说明单目标、姿态和遮挡适用边界；不以全局 BBox 冒充多目标分离或旋转不变测量。

## 资源、时序与发布门

- 初始 V1 Slice `83.15%`，V2 目标尽量不超过 `85%`；超过 `90%` 暂停正式整机合并，超过 `92%` 进入人工风险评估，达到 `95%` 禁止作为正常发布候选。
- Setup/Hold WNS 必须 `>=0`，TNS 必须 `0`；内部预警保留至少 `+50 ps` 的可解释余量。
- 每项新能力先做独立资源试验，再进入整机；不得把独立试验资源简单相加当成最终结果。
- 不得用虚假时钟、宽泛 false path、multicycle path、降低主视频吞吐或删除功能掩盖失败。
- `BUILD_PASS` 只代表实际 TD 流程、报告和位流证据；`HARDWARE_PASS` 还需要板卡、摄像头、显示器和原始测量记录。
- V2 始终保留 `BASELINE_V1`、`LAST_GOOD_V2` 和 `EXPERIMENTAL` 三类候选；任何失败不覆盖前两者。

## 验证策略

每项视觉能力依次执行：开源/许可证审计 → 软件参考模型 → Algorithm Lab 预览（本 Goal 默认视觉通过）→ 硬件等价模型 → RTL 仿真 → 独立/整机 TD → 真实硬件。验证覆盖边界、空场、复位、停顿、首帧、帧跳过、模式切换、非法参数、CDC 和资源/时序。

V2-G0 先执行 `doctor`、现有工业回归、Python 测试和 V1 构建/哈希/报告审计。G1 只解决可在当前软件/RTL边界验证的交互、OSD 和 ROI 合同；硬件相关阶段在设备缺失时保留阻塞并继续解耦软件/RTL工作。每个阶段的结果写入 `docs/goals/industrial-v2/STATUS.json` 与对应实验/证据目录。

## 冲突处理

本设计与旧 Goal 阅读文件中“YOLO-tiny/WM8978”描述存在项目历史冲突。冲突处理依据为用户已确认的 `PROJECT_GOAL.md` 变更记录：fixed-red v1 不包含 YOLO/Micro-CNN 和 WM8978。该设计也不修改旧阅读入口，只在 `docs/goals/industrial-v2/` 记录 V2 七项能力；任何需要改变正式目标或验收标准的方案另建提案并等待批准。
