# Industrial Vision V2 G1 OSD Decimal Contract

日期：2026-10-19（Asia/Shanghai）  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`  
基线：`256d99c1d0dc4dbae2ace8d0ff3a97f504d514c9`

## 目标

将 HDMI OSD 的帧计数、检测框宽度和高度从十六进制显示改为帧边界快照的十进制显示，并保持原图/检测状态/LED 联合仿真契约。

## 测试先行

先在 `fallback/sim/display/tb_osd_led_joint.v` 增加第二帧帧数字和 `120x80` 尺寸数字的可见像素断言。

- RED：未修改 RTL 时，`vvp` 在 `tb_osd_led_joint.v:124` 报告 `decimal frame digit missing`。
- 调试结论：初版断言误称第二帧为 frame 12，并采样到十位空位的空白笔画；修正为第二帧个位数字 `2` 的已知亮点后，旧十六进制布局仍保持失败。

## 实现

修改 `fallback/rtl/display/industrial_osd_overlay.v`：

- 在 `I_vsync` 上升沿计算并锁存 10 位帧十进制数字、4 位宽度数字和 4 位高度数字。
- 像素组合路径只使用锁存后的 nibble 选择字符，不读取除法结果。
- 帧计数、宽度、高度与检测结果在同一帧边界更新，避免一帧内字段撕裂。
- 保持 `NO_OBJECT`、`PASS`、`NG`、`INVALID` 四态和 `120x80` 检测框尺寸测试。

## GREEN 结果

命令：

```text
E:\Projects\FPGA\.tools\iverilog\bin\iverilog.exe -g2012 -Wall -s tb_osd_led_joint -o work/tests/verification_outputs/v2_osd_green.vvp fallback/sim/display/tb_osd_led_joint.v fallback/rtl/inspection/defect_classifier.v fallback/rtl/display/anlogic_logo_rom.v fallback/rtl/display/industrial_osd_overlay.v
E:\Projects\FPGA\.tools\iverilog\bin\vvp.exe work/tests/verification_outputs/v2_osd_green.vvp
```

结果：

```text
PASS OSD status and four-state classifier LED joint contract
```

退出码为 `0`。编译仍提示 `anlogic_logo_rom.v` 继承 timescale 的既有 warning；本次未将该非功能性清理混入 OSD 行为修改。

## 判定

`G1 OSD decimal contract: SOFTWARE_PASS`。

当前只完成 RTL 仿真证据。TD 综合、实现时序、资源、Bitstream 和真实 HDMI 画面仍未验证；视觉审批按用户指令默认为通过，但不替代硬件证据。
