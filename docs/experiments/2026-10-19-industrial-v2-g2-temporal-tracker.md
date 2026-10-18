# Industrial Vision V2 G2 RTL Temporal Tracker

日期：2026-10-19（Asia/Shanghai）  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`

## 目标

将 G2 软件模型的单目标帧结果状态机实现为可综合 Verilog，输入为一拍一帧的原子检测结果，不接触像素视频流。

## TDD 证据

先创建 `fallback/sim/inspection/tb_temporal_tracker.v` 并只编译 testbench：

```text
fallback/sim/inspection/tb_temporal_tracker.v:32: error: Unknown module type: temporal_tracker
```

同时发现并修正 testbench 的方向编码宽度：9 个方向状态必须使用 4 bit，避免 Icarus 常量截断 warning。

实现 `fallback/rtl/inspection/temporal_tracker.v` 后运行：

```text
iverilog -g2012 -Wall -s tb_temporal_tracker -o work/tests/verification_outputs/v2_temporal_tracker_green.vvp fallback/sim/inspection/tb_temporal_tracker.v fallback/rtl/inspection/temporal_tracker.v
vvp work/tests/verification_outputs/v2_temporal_tracker_green.vvp
```

结果：编译退出码 `0`，仿真退出码 `0`，输出 `TB_TEMPORAL_TRACKER_PASS`。

## 覆盖行为

- 首次检测、静止目标、位移和 4-bit 方向编码；
- 两帧短暂丢失、恢复且不重复 ENTER；
- 丢失窗口耗尽后的单次 EXIT；
- 跳变拒绝和新位置重新 ENTER；
- INVALID 优先级、中心保持和帧号缺口；
- 复位后历史清除。

## 分层判定

`G2 temporal_tracker = RTL_PASS`（软件模型为 `SOFTWARE_PASS`）。尚未接入正式顶层，未进行 TD、资源/时序或真实硬件验证。
