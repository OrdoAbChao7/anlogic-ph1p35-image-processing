# Industrial Vision V2 G5 分拣事件软件模型

日期：2026-10-19（Asia/Shanghai）  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`

## 目标

建立单目标生命周期内的 PASS/NG 计数、固定触发线、一次性请求、安全互锁和虚拟固定脉宽执行器模型。该模型不代表真实 GPIO 或机械执行器。

## TDD 证据

先运行测试，收集预期 RED：

```text
ModuleNotFoundError: No module named 'sort_reference'
```

实现 `work/models/v2/sort_reference.py` 后运行：

```text
python -B -m pytest -q work/tests/test_v2_sort.py
........                                                                 [100%]
8 passed in 0.03s
```

## 模型结论

- 同一 `target_enter` 生命周期内 PASS/NG 只计一次，连续帧不会重复计数。
- 目标中心穿越 `TRIGGER_X` 或判定完成时已在触发线后，只产生一次 `sort_request`。
- `target_exit`/`tracking_lost` 后必须重新 `target_enter` 才能再次执行；INVALID 不计数、不触发。
- 安全互锁要求显式 arm，故障锁存后必须 clear；复位后默认 safe hold。
- 虚拟执行器输出固定脉宽，busy 或禁止状态下的请求产生 rejected/timeout，不叠加脉冲。

状态：`SOFTWARE_PASS`。RTL、TD、板载 IO 和真实机械闭环尚未完成。
