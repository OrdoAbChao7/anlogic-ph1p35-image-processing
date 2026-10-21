# Industrial Vision V2 G3 阶段总结

日期：2026-10-19（Asia/Shanghai）  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`  
G3 commits：`845e73e`, `517f611`, `b8fe2f2`, `49748ef`, `47e2feb`

## 已实现

- `work/models/v2/latency_reference.py`：定义带 `frame_id` 的 PROC/VIDEO 延迟、frame gap、tag mismatch、timeout、回绕和 E2E=N/A。
- `fallback/rtl/inspection/frame_tag_monitor.v`：检查输入、结果、视频标签关联以及帧缺口、超时和错配。
- `fallback/rtl/inspection/latency_monitor.v`：在同一时钟域以固定宽度时间戳发布 PROC/VIDEO 延迟脉冲；观测沿不重复计入；物理 E2E 保持 N/A。

## 受影响验证

| 检查 | 结果 |
|---|---|
| G1/G2/G3 软件模型（latency/tracker/ROI） | `18 passed in 0.06s` |
| G1/G2/G3 RTL 定向回归 | 10 个入口全部 compile/run `0`，包含 `TB_LATENCY_MONITOR_PASS`、`TB_FRAME_TAG_MONITOR_PASS`、G1 模式/OSD/ROI 和 G2 tracker/history/overlay |
| ROI full/boundary RTL | `PASS color_detect_96_v2 full-frame area=921600 bbox=0,0,1279,719`；`PASS strict Q10 Cb/Cr open-interval boundary vectors`；使用 `-DMORPH_SIMULATION` |
| `python -B -m pytest -q work/tests` | `64 passed, 8 failed`；失败仍为冻结 V1 与当前仓库的 release/path/旧入口契约漂移 |
| `python -B work/algorithm_lab/verify_stage_d.py` | exit `1`；5 个样本的 metrics/mask 通过，registry `ef929f...` 与当前 plugin `08f929...` SHA 不一致 |

## 阶段判定

`V2-G3 = BLOCKED`，分层为：

- 软件模型：`SOFTWARE_PASS`；
- 独立 RTL：`RTL_PASS`；
- 正式顶层/TD：`NOT_RUN/BLOCKED`；
- 物理 HDMI/显示器 E2E：`NOT_RUN/BLOCKED`。

G3 只承诺内部带标签的处理/视频事件测量，不把 HDMI 刷新率或屏幕观感写成端到端延迟。G1/G2 的正式顶层前置、V2 TD 资源/时序和上板条件仍未关闭；这些阻塞不妨碍继续 G4 的解耦软件/RTL 研发。
