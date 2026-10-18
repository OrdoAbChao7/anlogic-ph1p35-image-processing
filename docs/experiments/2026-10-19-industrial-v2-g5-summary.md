# Industrial Vision V2 G5 阶段总结

日期：2026-10-19（Asia/Shanghai）  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`  
G5 commits：`aa31cdb`, `d2c1c18`, `5929031`

## 已实现

- `sort_event_controller.v`：单目标生命周期、PASS/NG 去重计数、固定触发线和一次性请求。
- `sort_safety_interlock.v`：复位/未 arm/INVALID/tracking lost/外部故障的安全禁止和故障清除。
- `sort_pulse_generator.v`：固定 3-cycle 内部脉冲、busy 拒绝和 timeout 诊断。
- Python 软件模型与 RTL testbench 都只覆盖内部事件和虚拟执行器，不绑定未知管脚。

## 受影响验证

| 检查 | 结果 |
|---|---|
| G1-G5 软件模型 | `34 passed in 0.10s` |
| G1-G5 RTL 定向回归 | 12 个入口全部 compile/run `0`，新增 `TB_SORT_CONTROL_PASS` |
| `python -B -m pytest -q work/tests` | `80 passed, 8 failed`；8 项仍为冻结 V1 release/path/旧入口契约漂移 |
| `python -B work/algorithm_lab/verify_stage_d.py` | exit `1`；Stage D 样本通过，registry `ef929f...` 与 plugin `08f929...` SHA 不一致 |

## 外部控制边界

- 当前没有已核实的 HX1P35A 扩展 IO、执行器型号、电压/电流/隔离参数或机械延迟标定。
- 因此 `sort_request`、`pulse` 和 `accepted` 只代表内部/虚拟事件；没有 GPIO 接线、真实推杆/舵机响应或闭环实验。
- 不能把本阶段写成“真实机械分拣完成”，也不能猜测输出有效电平或空闲引脚。

## 阶段判定

`V2-G5 = BLOCKED`，分层为：

- 软件模型：`SOFTWARE_PASS`；
- 独立 RTL：`RTL_PASS`；
- 虚拟执行器：`PASS`；
- 正式顶层/TD：`NOT_RUN/BLOCKED`；
- 板载 IO/真实机械闭环：`NOT_RUN/BLOCKED`。

G5 已完成内部控制语义和安全边界，但真实执行器适配必须等待官方原理图、约束、电气参数和可重复实验条件。
