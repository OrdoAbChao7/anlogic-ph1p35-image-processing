# Industrial Vision V2 G2 跟踪软件模型

日期：2026-10-19（Asia/Shanghai）  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`

## 目标

建立与后续 RTL 一致的单目标帧结果状态机，明确中心距离门限、短暂丢失、重新进入、帧号缺口和 INVALID 优先级。

## TDD 证据

先加入 `work/tests/test_v2_tracker.py` 后运行：

```text
python -B -m pytest -q work/tests/test_v2_tracker.py
```

RED 结果：收集阶段因 `ModuleNotFoundError: No module named 'tracker_reference'` 失败。

实现 `work/models/v2/tracker_reference.py` 后重跑同一命令：

```text
......                                                                   [100%]
6 passed in 0.03s
```

## 已冻结的模型行为

- 首次有效检测发布 `TRACKING + ENTER`；静止目标的位移为 `0,0`。
- 位移在 `64×64 px/frame` 门限内时更新轨迹并输出有符号 `dx/dy`。
- 无检测先进入 `LOST`，默认连续 3 帧后发布一次 `EXIT + NO_OBJECT`。
- LOST 内恢复不重复 ENTER；超过门限的跳变先拒绝，再以新位置重新 ENTER。
- `INVALID` 清除现有关联且不更新中心；后续有效结果必须重新 ENTER。
- 帧 ID 不是上一帧加一时仅置 `frame_gap`，不虚构中间帧。

## 当前阶段

`SOFTWARE_PASS`。模型尚未替代完整 RTL、TD 或硬件证据；视觉审批按用户指令默认授权，但不改变这一分层结论。
