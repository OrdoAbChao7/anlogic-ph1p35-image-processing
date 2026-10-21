# Industrial Vision V2 G5 执行计划

## Task 1：内部分拣事件软件模型

- 用 TDD 覆盖生命周期去重、PASS/NG 计数、触发线、判定晚到、INVALID、丢失和重新进入。
- 增加安全互锁和固定脉宽虚拟执行器模型。

## Task 2：RTL 控制链

- 先写综合约束范围内的 `sort_event_controller.v`、`sort_safety_interlock.v`、`sort_pulse_generator.v` testbench 并收集 RED。
- 实现内部事件与安全边界，不接未知 GPIO。
- 通过条件：PASS/NG、一次性触发、故障锁存/清除和脉冲周期都通过 RTL 仿真。

## Task 3：回归与外部边界记录

- 跑 G1-G5 软件/RTL 定向回归、`work/tests` 全量和 Stage D。
- 记录当前无 HX1P35A 外部执行器/IO 证据，虚拟执行器不升级为硬件通过。

## Task 4：阶段记录

- 更新 G5 实验记录、阶段状态、证据索引和资源预算。
- G5 在没有板级资料和实际动作实验时保持 `BLOCKED`，继续 G6。
