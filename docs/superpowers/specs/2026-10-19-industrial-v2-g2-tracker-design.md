# Industrial Vision V2 G2 单目标跟踪与轨迹显示设计

日期：2026-10-19  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`  
上游：V1 fixed-red 原子检测结果快照；G1 模式/OSD/ROI 软件与 RTL 结果合同

## 目标与边界

G2 在不改变 MIPI、CSI-2、ISP、DDR2、HDMI 和已核实 IO 边界的前提下，实现可独立验证的单目标跨帧关联与轨迹显示。能力范围明确为单目标；多目标、遮挡恢复和物理移动演示不在本阶段宣称范围内。

当前只推进软件参考模型和独立 RTL。正式顶层接入、TD QoR 和真实硬件保留后续阶段门；不能把本阶段仿真解释为硬件通过。

## 帧结果接口

`temporal_tracker` 在一个已经完成 CDC 的结果时钟域工作，每个 `I_frame_valid` 只代表一帧已经发布的原子检测结果：

| 信号 | 位宽 | 语义 |
|---|---:|---|
| `I_frame_valid` | 1 | 帧结果提交脉冲 |
| `I_frame_id` | 16 | 单调递增帧标签；跳变被标记，不默默补帧 |
| `I_detected` | 1 | 本帧有候选目标 |
| `I_invalid` | 1 | 本帧结果/ROI 无效，优先级高于 detected |
| `I_cx/I_cy` | 11 | 检测器输出的像素中心 |

输出在同一 `I_frame_valid` 事件后寄存并保持到下一帧：

| 输出 | 语义 |
|---|---|
| `O_state` | `NO_OBJECT=0`, `TRACKING=1`, `LOST=2`, `INVALID=3` |
| `O_track_valid` | 当前结果可用于轨迹和叠加 |
| `O_enter/O_exit` | 一拍事件；新目标建立/丢失窗口耗尽 |
| `O_frame_gap` | 当前帧标签不是上一标签加一 |
| `O_static` | 当前有效目标 `dx=dy=0` |
| `O_cx/O_cy` | 最近一次有效中心 |
| `O_dx/O_dy` | 当前有效中心相对上一有效中心的有符号位移 |
| `O_lost_frames` | 连续未关联帧数，饱和在 `MAX_LOST_FRAMES` |

## 关联规则

- 参数默认 `MAX_STEP_X=64`、`MAX_STEP_Y=64`、`MAX_LOST_FRAMES=3`，单位为像素/帧；参数在模块实例化时固定，不在扫描中改变。
- 无历史目标且收到有效检测：建立新轨迹，`TRACKING + O_enter`。
- 有历史目标且中心位移在两个门限内：更新中心，`TRACKING`；从 `LOST` 恢复时不重复 `O_enter`。
- 有历史目标但位移超门限：拒绝该跳变，当前结果进入 `LOST`；下一次有效且仍超出旧中心的结果作为新目标建立并产生 `O_enter`。
- 无检测时，先进入 `LOST` 并保留最近中心；连续丢失达到窗口后进入 `NO_OBJECT` 并产生一次 `O_exit`。
- `I_invalid` 优先进入 `INVALID`，不写入中心和轨迹；后续有效检测从新目标建立。
- 帧标签跳变只产生 `O_frame_gap`，不伪造中间帧；有效检测仍按中心门限关联。

## 轨迹历史

`trajectory_history` 保存最近 `HISTORY_DEPTH=8` 个 `O_track_valid` 中心。`I_new_track` 清除旧轨迹并把新中心作为第一个点；随后每个有效中心右移插入。点用像素坐标，输出扁平化数组和有效掩码，便于 Verilog-2001/TD 兼容。

## 轨迹叠加

`tracking_overlay` 消费 HDMI 域的当前像素坐标和历史点，在每个点周围绘制固定半径标记；只在 `I_track_valid` 时显示，`NO_OBJECT/INVALID` 自动隐藏。视频同步信号保持一拍寄存延迟，轨迹颜色使用独立常量，不改原 BBox/OSD 状态色。

## 验证

软件模型和 RTL 必须覆盖：静止、匀速移动、停止后再次移动、短暂遮挡、超过丢失窗口、离开/重新进入、跳变拒绝、帧标签跳变、连续空帧、INVALID、复位和历史深度溢出。RTL 只接受真实 `I_frame_valid` 事件，禁止用仿真整帧数组冒充流式视频。

用户指定的视觉审批策略为默认通过，因此 Stage C 不阻塞本阶段；该授权不替代 TD、资源、时序和硬件证据。
