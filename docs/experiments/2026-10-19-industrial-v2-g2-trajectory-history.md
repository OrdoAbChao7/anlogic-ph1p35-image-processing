# Industrial Vision V2 G2 轨迹历史

日期：2026-10-19（Asia/Shanghai）  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`

## 目标

为单目标跟踪提供固定深度 `HISTORY_DEPTH=8` 的像素中心历史，不使用整帧缓存；历史点按最新点在 index 0 的扁平数组输出，供后续 HDMI 叠加消费。

## TDD 证据

先运行只有 testbench 的编译，Icarus 报告：

```text
fallback/sim/inspection/tb_trajectory_history.v:20: error: Unknown module type: trajectory_history
```

实现 `fallback/rtl/inspection/trajectory_history.v` 后运行：

```text
iverilog -g2012 -Wall -s tb_trajectory_history -o work/tests/verification_outputs/v2_trajectory_history_green.vvp fallback/sim/inspection/tb_trajectory_history.v fallback/rtl/inspection/trajectory_history.v
vvp work/tests/verification_outputs/v2_trajectory_history_green.vvp
```

编译和仿真退出码均为 `0`，输出 `TB_TRAJECTORY_HISTORY_PASS`。

## 覆盖行为

- 新目标清除旧历史并插入首点；
- 最新点优先顺序；
- 深度 4 仿真中的饱和移位，证明深度 8 结构不依赖整帧存储；
- `I_push=0` 不改变历史；
- 异步复位清除点、有效掩码和计数。

## 分层判定

`G2 trajectory_history = RTL_PASS`。尚未接入正式顶层，TD、资源/时序和硬件仍未验证。
