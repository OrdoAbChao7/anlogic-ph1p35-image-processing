# Industrial Vision V2 G5 分拣事件与外部控制设计

日期：2026-10-19  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`

## 目标与边界

G5 先实现内部“检测—判定—一次性事件—安全脉冲”的控制闭环。没有 HX1P35A 当前板级原理图、IO 约束和外部执行器电气资料前，不声明真实机械分拣或新增 GPIO 已完成。

## 事件定义

- `target_enter` 开始一个单目标生命周期；只有生命周期内的第一次有效 PASS/NG 判定计数。
- `verdict_valid && !verdict_invalid` 才能分类；PASS/NG 计数各自只增加一次。
- 触发方向固定为 `center_x` 增大方向；当目标中心从 `< TRIGGER_X` 到 `>= TRIGGER_X`，且已有有效判定且未触发时，产生一个 `sort_request`。
- 若目标在判定完成时已经位于触发线之后，也允许产生一次请求；这避免判定晚于穿线时静默丢失，但仍要求目标生命周期有效。
- `target_exit`、`tracking_lost`、`invalid` 清理/阻止未完成生命周期的动作；丢失目标不会补发触发。
- 重新触发必须经过新的 `target_enter`，禁止由边界抖动重复触发同一目标。

## 模块边界

### `sort_event_controller.v`

帧域状态机，输出 enter/PASS/NG/一次性 sort_request、PASS/NG 累计值和 control fault 事件。它不直接驱动 GPIO。

### `sort_safety_interlock.v`

复位默认禁止、显式 arm 才允许；INVALID、tracking lost、外部 fault 进入锁存故障，只有 clear_fault 才能恢复允许状态。该模块输出 request allowed，不假设任何空闲引脚电平。

### `sort_pulse_generator.v`

把获准请求变为固定宽度、固定有效电平的内部脉冲。默认 `PULSE_CYCLES=3`，busy 期间或安全禁止期间的请求产生 rejected/timeout 诊断，不叠加脉冲。

## 虚拟执行器

软件模型和 RTL testbench 只观察 `pulse/accepted/rejected/timeout`，把 accepted 脉冲视为虚拟推杆动作。板级电压、电流、隔离、机械延迟和管脚必须由后续官方原理图/实测关闭，不能由该模型替代。

## 验证门

覆盖 PASS/NG、连续帧去重、目标返回/重新进入、INVALID、tracking lost、复位安全、脉冲宽度、busy 拒绝、fault clear 和一次性触发。没有外部执行器时，G5 只能达到软件/RTL/虚拟执行器通过。
