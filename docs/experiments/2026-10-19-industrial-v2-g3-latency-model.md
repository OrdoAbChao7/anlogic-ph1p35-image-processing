# Industrial Vision V2 G3 延迟软件模型

日期：2026-10-19（Asia/Shanghai）  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`

## 目标

建立带 `frame_id` 和自由运行周期时间戳的内部延迟模型，区分 `PROC`、`VIDEO` 和物理 `E2E`，并定义帧缺口、标签错配、超时和计数器回绕。

## TDD 证据

先运行测试，收集阶段因缺少 `latency_reference` 失败：

```text
ModuleNotFoundError: No module named 'latency_reference'
```

实现 `work/models/v2/latency_reference.py` 后：

```text
python -B -m pytest -q work/tests/test_v2_latency.py
......                                                                   [100%]
6 passed in 0.02s
```

## 模型结论

- 匹配标签的输入到结果/视频事件分别发布 PROC/VIDEO cycles；
- 输入帧 ID 缺口和结果标签错配只报诊断，不补帧、不发伪延迟；
- 超时清除陈旧 pending 标签，迟到结果不能被误计入；
- 时间戳按固定宽度回绕安全相减；
- `e2e_valid=False`、`e2e_cycles=None`，表示当前没有物理端到端测量。

状态：`SOFTWARE_PASS`。RTL、TD 和硬件测量尚未完成。
