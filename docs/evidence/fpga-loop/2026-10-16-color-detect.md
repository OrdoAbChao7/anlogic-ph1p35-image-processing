# FPGA Agent Development Loop：color_detect_96

## 结论

本记录保留 2026-10-16 最新一次 `color_detect_96` 独立模块验证的摘要。它证明该模块的 Golden Model 回归和独立 TD 综合/布局布线通过；不等于整机 SC520CS→HDMI 链路、现场硬件或完整比赛作品通过。

## 复现与输入

- 分支：`chore/fpga-agent-loop`
- RTL：`fallback/rtl/color_detect_96.v`
- RTL SHA-256：`ededb8ca13e9d21dca08263069f9116917b983d2ee9441a9883ea96d60be3913`
- 时钟约束：100 MHz
- 工具：Icarus Verilog 14.0；Tang Dynasty 6.2.1 build 168116

## 结果

- 仿真：8/8 通过，包括全黑、全白、无目标、单点、多命中、跨行、多行和随机帧。
- 综合/布局布线：退出码均为 0。
- Setup WNS：+220 ps；Hold WNS：+40 ps；Setup/Hold TNS 均为 0。
- Slice：425（2.0%）；RAM：0；DSP：16；告警数：0。
- 本记录对应的是独立模块 build，不包含整机位流下载和板卡验收。

原始运行目录已清理；需要重新生成时使用 `python -m work.fpga_loop run --module color_detect_96 --project fallback --build`，原始输出会进入被忽略的 `work/fpga_loop/runs/`。
