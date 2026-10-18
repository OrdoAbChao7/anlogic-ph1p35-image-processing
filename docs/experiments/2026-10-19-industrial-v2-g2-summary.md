# Industrial Vision V2 G2 阶段总结

日期：2026-10-19（Asia/Shanghai）  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`  
G2 commits：`61389bf`, `1919fab`, `1990aa9`, `099f932`, `d8fce6a`

## 已实现

- `temporal_tracker.v`：单目标中心距离门限、TRACKING/LOST/NO_OBJECT/INVALID、ENTER/EXIT、frame gap、位移和方向。
- `trajectory_history.v`：固定深度点历史，最新点优先，清轨迹和饱和移位。
- `tracking_overlay.v`：HDMI 域固定半径轨迹点叠加，隐藏状态和同步延迟。
- `work/models/v2/tracker_reference.py`：与 RTL 契约对应的 Python 状态机模型。

## 受影响验证

| 检查 | 结果 |
|---|---|
| 跟踪 Python 模型 + G1 ROI 模型 | `12 passed in 0.05s` |
| `tb_temporal_tracker` | compile/run `0`，`TB_TEMPORAL_TRACKER_PASS` |
| `tb_trajectory_history` | compile/run `0`，`TB_TRAJECTORY_HISTORY_PASS` |
| `tb_tracking_overlay` | compile/run `0`，`TB_TRACKING_OVERLAY_PASS` |
| G1 模式/OSD/ROI 回归 | 全部通过 |

覆盖静止、移动、短暂遮挡、丢失窗口、重新进入、跳变拒绝、INVALID、帧号缺口、历史深度溢出和轨迹隐藏。

## 全量门

- `python -B -m pytest -q work/tests`：`58 passed, 8 failed`；失败数与 G1 相同，仍是冻结提交与后续 release/path 契约漂移。
- `pwsh -File .\\scripts\\verify-industrial-subsystem.ps1`：前置 Algorithm Lab 样本和 Stage D 其余向量通过；仍因 registry `ef929f...` 与当前 plugin `08f929...` 的 SHA 不一致停止。
- 尚未运行 TD 综合、实现、Bitgen；尚无 V2 资源和时序报告。
- 尚未接入正式顶层，未进行板卡、摄像头、HDMI 或真实移动目标验收。

## 阶段判定

`V2-G2 = BLOCKED`，分层为：

- 软件模型：`SOFTWARE_PASS`；
- 独立 RTL：`RTL_PASS`；
- 正式顶层/TD：`NOT_RUN/BLOCKED`；
- 真实硬件轨迹：`NOT_RUN/BLOCKED`。

G2 只承诺单目标；没有多目标跟踪、物理移动演示或硬件帧率结论。G1 的基线一致性问题仍保留为共同阻塞，但不阻止继续准备解耦的 G3/G4 软件与 RTL 模块。
