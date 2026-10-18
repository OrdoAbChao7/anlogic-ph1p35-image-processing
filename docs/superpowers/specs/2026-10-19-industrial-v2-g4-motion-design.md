# Industrial Vision V2 G4 固定 ROI 硬件帧差设计

日期：2026-10-19  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`

## 目标与边界

G4 实现与静态红色检测分离的跨帧运动检测。算法只比较连续帧同一空间采样点的 8-bit 亮度：

```text
motion = abs(Y_now - Y_prev) > threshold
```

本阶段先做可独立仿真和资源评估的固定 ROI 样本域，不修改 V1 摄像头、DDR、HDMI 和厂商 IP 边界。物理 HDMI 叠加、TD 资源和上板验收仍是后续门。

## 固定采样域

- 样本网格：`160 x 120`，每点 8-bit `Y`，历史容量 `160*120*8 = 153600 bit`。
- 上游适配契约：将固定工位 ROI 按明确规则降采样到该网格，每帧同一 `(x,y)` 必须映射到同一空间位置；本模块不复制完整 1280x720 帧。
- 本模块输入为一个样本/周期的 `frame_id/frame_start/frame_end/x/y/Y`，输出为帧末摘要和可选运动样本叠加事件；它不阻塞主 HDMI 流。
- 输出坐标使用 160x120 网格坐标。源视频坐标映射由后续 ROI/OSD 适配层负责，不能把网格坐标直接写成 HDMI 像素坐标。

## 帧与历史语义

- 首帧只建立历史，不发布有效运动判断：`summary_valid=1`、`motion_valid=0`、`motion=0`。
- 连续帧使用前一帧历史值比较；当前样本比较完成后写回同一地址，不能读同一帧刚写入的数据。
- `frame_id` 不是上一帧加一时产生 `frame_gap`。该帧仍刷新历史，但整帧 `motion_valid=0`，下一帧从该帧重新开始比较。
- 复位清除历史有效标志；帧中样本缺失、坐标越界或无合法帧边界时产生 `invalid`，不输出可用运动结论。
- 历史内存采用可综合单端口/推断 RAM 语义；仿真使用行为 RAM，平台原生 ERAM 映射保留为独立实现开关，不在无厂商库环境伪造 TD 通过。

## 输出摘要

帧末输出：`summary_valid`、`motion_valid`、`motion`、`motion_count`、网格坐标 `xmin/xmax/ymin/ymax`、`frame_gap`、`invalid`、`baseline_ready`。运动区域只由 `motion` 样本组成，静态帧不保留旧框。

## 验证门

软件模型和 RTL 必须覆盖：首帧、静态帧、阈值严格大于、局部移动、ROI 四边、空运动场、帧跳过、复位、越界和帧末摘要。软件与 RTL 使用同一阈值和边界公式。

G4 不能在本阶段宣称：完整 HDMI 实时接入、V2 TD 资源/时序通过、真实运动输入上板或物理 E2E 结果。
