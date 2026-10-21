# Industrial Vision V2 G5 RTL 分拣控制链

日期：2026-10-19（Asia/Shanghai）  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`

## 目标

实现不绑定任何未知 GPIO 的内部控制链：单目标事件控制器、安全互锁和固定脉宽虚拟执行器。

## TDD 证据

先只编译 testbench，得到预期 RED：

```text
error: Unknown module type: sort_event_controller
error: Unknown module type: sort_safety_interlock
error: Unknown module type: sort_pulse_generator
```

加入三个 RTL 模块后运行：

```text
E:/Projects/FPGA/.tools/iverilog/bin/iverilog.exe -g2012 -Wall -s tb_sort_control -o <temp>/v2-g5-sort-green.vvp fallback/sim/control/tb_sort_control.v fallback/rtl/control/sort_event_controller.v fallback/rtl/control/sort_safety_interlock.v fallback/rtl/control/sort_pulse_generator.v
E:/Projects/FPGA/.tools/iverilog/bin/vvp.exe <temp>/v2-g5-sort-green.vvp
```

结果：

```text
TB_SORT_CONTROL_PASS
```

## 行为结论

- PASS/NG 判定在一个 `target_enter` 生命周期内只计一次。
- 目标穿过固定 `TRIGGER_X` 或判定晚到但已在触发线后时，只产生一个 `sort_request`。
- tracking lost、INVALID、复位和未 arm 状态阻止动作；故障需显式 clear。
- `PULSE_CYCLES=3` 的虚拟动作脉冲宽度确定，busy 期间重复请求报告 rejected/timeout，不叠加脉冲。

状态：`RTL_PASS`。外部 GPIO、电气参数、机械执行器和真实闭环尚未验证。
