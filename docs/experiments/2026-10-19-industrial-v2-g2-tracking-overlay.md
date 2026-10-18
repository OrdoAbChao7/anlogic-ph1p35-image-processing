# Industrial Vision V2 G2 轨迹叠加

日期：2026-10-19（Asia/Shanghai）  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`

## 目标

在 HDMI 像素域对帧稳定的有限轨迹历史绘制固定半径点标记，保持视频控制信号一拍延迟，并在 `track_valid=0` 时隐藏轨迹。

## TDD 证据

先编译 `fallback/sim/display/tb_tracking_overlay.v`，因缺少 RTL 模块失败：

```text
fallback/sim/display/tb_tracking_overlay.v:25: error: Unknown module type: tracking_overlay
```

实现 `fallback/rtl/display/tracking_overlay.v` 后运行：

```text
iverilog -g2012 -Wall -s tb_tracking_overlay -o work/tests/verification_outputs/v2_tracking_overlay_green.vvp fallback/sim/display/tb_tracking_overlay.v fallback/rtl/display/tracking_overlay.v
vvp work/tests/verification_outputs/v2_tracking_overlay_green.vvp
```

编译和仿真退出码均为 `0`，输出 `TB_TRACKING_OVERLAY_PASS`。

## 覆盖行为

- 最新历史点和旧历史点的固定半径标记；
- 非轨迹位置保留输入 RGB；
- `track_valid=0` 隐藏所有历史点；
- `DE=0` 输出黑色并保持一拍的 DE/HSYNC/VSYNC 语义；
- 第二个点与同步信号同时检查。

## 分层判定

`G2 tracking_overlay = RTL_PASS`。当前为独立模块，尚未接入正式 HDMI 顶层，未进行 TD、资源/时序或硬件验证。
