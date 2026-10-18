# Industrial Vision V2 G4 阶段总结

日期：2026-10-19（Asia/Shanghai）  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`  
G4 commits：`a3fcef3`, `9f6371e`, `a14d9f3`

## 已实现

- `work/models/v2/motion_reference.py`：固定 ROI 8-bit 亮度帧差模型。
- `fallback/rtl/inspection/motion_diff_160.v`：参数化 160×120 采样网格历史、跨帧同坐标比较、帧末计数和网格框输出。
- 首帧、静态帧、严格阈值、帧跳过、复位和非法坐标均有测试。

## 受影响验证

| 检查 | 结果 |
|---|---|
| G1-G4 软件模型 | `26 passed in 0.08s` |
| G1-G4 RTL 定向回归 | 11 个入口全部 compile/run `0`，新增 `TB_MOTION_DIFF_160_PASS` |
| `python -B -m pytest -q work/tests` | `72 passed, 8 failed`；8 项仍为冻结 V1 release/path/旧入口契约漂移 |
| `python -B work/algorithm_lab/verify_stage_d.py` | exit `1`；样本 metrics/mask 通过，registry `ef929f...` 与当前 plugin `08f929...` SHA 不一致 |

## 资源与边界

- 默认历史容量：`160*120*8 = 153600 bit`，即 19200 bytes / 18.75 KiB（二进制）或约 19.2 kB（十进制），未计 RAM 分块、控制逻辑和工具映射开销。
- 当前实现是独立 RTL 试验，尚未接入正式视频适配器、TD 工程或 HDMI OSD；因此 Slice/RAM/DSP/WNS/TNS 为 `NOT_MEASURED`。
- 输出坐标是 160×120 网格坐标，不是未经适配的 1280×720 HDMI 像素坐标。

## 阶段判定

`V2-G4 = BLOCKED`，分层为：

- 软件模型：`SOFTWARE_PASS`；
- 独立 RTL：`RTL_PASS`；
- 正式顶层/TD：`NOT_RUN/BLOCKED`；
- HDMI/真实运动硬件：`NOT_RUN/BLOCKED`。

G4 已证明真实跨帧数据比较的独立模块语义，但不能据此宣称完整实时视频接入、资源通过或上板运动显示。G1-G3 的共同正式顶层和 TD 阻塞继续保留。
