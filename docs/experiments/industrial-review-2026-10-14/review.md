# 工业检测分支第一轮审查（2026-10-14）

## 结论与范围

结论：发现会改变颜色分割、面积及帧边界行为的确定性 RTL 问题；当前分支不能作为已验证工业检测系统。证据等级均为 project（源码、Icarus 仿真），无 measured 硬件证据。本轮未修复 RTL、未修改厂商配置、未运行 TD 或生成位流。开始时 git status --short 为空。

审查输入：fallback/rtl/color_detect_96.v、fallback/tb_color_detect_96.v，以及 Lab3 isp_top.v、color_detect_96.v、box_draw_96.v、AWB 和格式转换连接。工具为仓库 .tools/iverilog/bin/iverilog.exe，版本 14.0 devel；vvp 同目录。

## 确认问题

| 编号 | 优先级 | 问题、触发与实际结果 | 位置 |
|---|---|---|---|
| I1 | P1 | RGB 的 8 位通道直接 $signed。R/G/B=127/40/40 时 Cb/Cr=113/171 命中；128/40/40 应为113/172，实际156/44，不命中。128以上通道被解释为负数。 | 两版 color_detect_96.v:22–29 |
| I2 | P1 | fallback 修过的四像素统计没有进入 Lab3 实例化源码。4个 R=100 像素应 area=4,xmin=0,xmax=3，Lab3 实际1,3,3。多个非阻塞赋值读取旧值并互相覆盖。 | Lab3 color_detect_96.v:55–73；isp_top.v:159；TD .al:310 |
| I3 | P1 | fallback 的19位面积容量仅524287；1280×720全帧921600个命中，实际397312（回绕）。Lab3 则因I2得到230400，掩盖溢出。完整容量至少20位，输出与下游也需同步检查。 | 两版 color_detect_96.v:9；fallback:55；isp_top.v:19,45 |
| I4 | P1 | 输出与累加器共用寄存器，SOF清零旧结果，valid_frame 从第一次SOF后持续为1，包括空场。不能提供稳定帧结果及目标存在/一次性有效事件语义。 | 两版 color_detect_96.v:48–53 |
| I5 | P1（条件成立时） | SOF与valid同拍时，检测器优先进入清零分支，丢首拍4像素且不推进坐标。该输入复现area=0而非4。实际AWB的SOF/valid契约须冻结，不能直接推定当前板卡必然以此方式出流。 | 两版 color_detect_96.v:48–53 |
| I6 | P1 | 绘框坐标计数不一致：SOF与valid同拍后x_grp=0（消费一组后应为1）；SOF与valid分离时不重置计数（复现x_grp=1，应为0）。两类帧头契约分别存在重复首组或未重置问题。 | Lab3 td_project/box_draw_96.v:28–35 |

I4边界说明：box_draw_96在帧头采样输入坐标；原图模式若检测器和画框器收到同拍SOF，非阻塞赋值使画框器可能采到清零前的上一帧累加结果。因此“检测器没有独立结果锁存”不等于已证明原图完全不能画框。切换到延迟不同的边缘支路时，帧头对应关系仍需串联验证；det_*输出本身依旧不稳定。valid_frame 若意为帧结果有效，须与目标存在分离；若意为脉冲，须能撤销。当前实现两者均未明确。

## 测试结果

- 原有 fallback/tb_color_detect_96.v 重编译、运行 PASS，仅覆盖单拍四个R=100像素。
- 新 tb_industrial_review.v：fallback 8项检查，2通过6失败；Lab3 1通过7失败。部分失败检查针对同一个根因，不表示分别有6/7个独立缺陷。两个运行均exit=1，完整输出见 fallback.log、lab3.log。
- 新 tb_box_review.v：两类SOF坐标行为均与消费/重置预期不符，exit=1；见box.log。
- 编译告警：检测器未声明time unit/precision。该告警与上述数值及状态缺陷无关，未屏蔽。
- 连续完整帧向量为230400拍，每拍4个R=100像素。颜色用例以源码同一组定点公式、无符号RGB及原阈值作预期，不更改阈值。

## 复现

在仓库根目录以PowerShell运行：

```powershell
$review = 'docs/experiments/industrial-review-2026-10-14'
.tools/iverilog/bin/iverilog.exe -g2012 -Wall -s tb -o "$review/audit.vvp" fallback/rtl/color_detect_96.v "$review/tb_industrial_review.v"
.tools/iverilog/bin/vvp.exe "$review/audit.vvp"
Remove-Item -LiteralPath "$review/audit.vvp"
```

Lab3复现将RTL参数替换为 HX1P35A2026/lab_ex1-3_SC520/lab_ex3_osd_SC520/lab_ex3_osd/user_source/hdl_source/isp/color_detect_96.v。绘框测试使用 -s tb_box、tb_box_review.v 和该工程 td_project/box_draw_96.v。

## 后续入口

先修复数值符号、面积容量及实际工程源码分歧；冻结SOF/valid/ready/last契约后修复帧统计与绘框坐标，做检测器+画框器串联回归。I_tlast当前未使用，无ready握手；是否出现早行尾或有效数据保持必须结合真实接口判定，本轮不认定为已证明的板级错误。多目标目前只有一个全局极值框，是能力边界而非本次新增缺陷。

完整工业链路的软件效果预览、用户VISUAL_APPROVED、硬件等价模型、综合时序和上板效果仍未通过；上述仿真不能证明实际工位检测性能。所有本轮.vvp已删除，保留可复用测试源和失败日志。
