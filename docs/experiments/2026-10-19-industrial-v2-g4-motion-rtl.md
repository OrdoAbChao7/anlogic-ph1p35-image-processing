# Industrial Vision V2 G4 RTL 固定 ROI 帧差

日期：2026-10-19（Asia/Shanghai）  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`

## 目标

实现参数化固定网格 `motion_diff_160.v`：按同一 `(x,y)` 比较当前/历史 8-bit 亮度，帧末输出运动计数、网格域 Bounding Box、frame gap、首帧基线和非法帧诊断。

## TDD 证据

先只编译测试平台，得到预期 RED：

```text
fallback/sim/inspection/tb_motion_diff_160.v:32: error: Unknown module type: motion_diff_160
```

加入 `fallback/rtl/inspection/motion_diff_160.v` 后运行：

```text
E:/Projects/FPGA/.tools/iverilog/bin/iverilog.exe -g2012 -Wall -s tb_motion_diff_160 -o <temp>/v2-g4-motion-green.vvp fallback/sim/inspection/tb_motion_diff_160.v fallback/rtl/inspection/motion_diff_160.v
E:/Projects/FPGA/.tools/iverilog/bin/vvp.exe <temp>/v2-g4-motion-green.vvp
```

结果：

```text
TB_MOTION_DIFF_160_PASS
```

## 覆盖与结论

- 首帧只写历史，不输出 `motion_valid`；连续静态帧不产生持续假运动。
- 严格使用 `abs(Y_now-Y_prev) > threshold`，覆盖阈值等于和大于两种边界。
- 局部移动产生 4 个样本的运动计数和正确网格框；ROI 边界坐标可表示。
- 帧号跳过时刷新历史并抑制该帧结论，下一连续帧重新开放比较。
- 越界/缺样本在帧末产生 `invalid`，复位后重新进入首帧语义。
- 历史容量按默认参数为 `160*120*8 = 153600 bit`，约 19.2 Ki-bit 原始数据。原始模块里程碑只完成独立 RTL 仿真；后续计数器位宽 TD A/B 见单独记录，160×120 历史 RAM 的独立映射归因仍未测量。

原始独立模块状态：`RTL_PASS`。后续正式顶层计数器 A/B 记录在下方；HDMI 显示和真实运动硬件仍未验收。

后续资源跟进：计数器位宽窄化及受控 TD A/B 已单独记录在 [`2026-10-19-industrial-v2-g4-motion-count-width-ab.md`](2026-10-19-industrial-v2-g4-motion-count-width-ab.md)。该结果补充了正式顶层的 G4 资源对照，但不构成上板、视觉或长稳验收。
