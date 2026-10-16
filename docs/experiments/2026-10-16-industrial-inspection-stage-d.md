# 工业视觉 Stage D：硬件等价软件模型冻结与回归

## 结论

用户已明确确认工业视觉预览为 `VISUAL_APPROVED`，冻结版本为 `v1.0-approved`。本记录完成 Software-First Stage D：PC 软件参考模型与固定点硬件等价软件模型在批准样本、边界向量和 ROI 语义上通过回归。

本记录只证明软件模型一致性，不证明 RTL、TangDynasty、整机视频链路或 PH1P35 板级运行。

## 冻结输入

- 工作树：`E:\Projects\FPGA-fallback`，分支 `fallback/industrial-inspection`。
- 参数快照：`work/algorithm_lab/configs/industrial_inspection/approved_v1.0-approved.json`。
- 注册项：`work/algorithm_lab/registry.json`。
- 插件源码：`work/algorithm_lab/plugins/industrial_inspection.py`。
- 插件 SHA-256：`8341bb307de148a1e853c57bf512c6ae12d257cff6753b9aa11aa8580ac12205`。
- 参数 canonical JSON SHA-256：`8a0d117b5a8ba3e8db52c9e06034988c9b8f6d266c7d8be4be1abdcc638f5d88`。
- 参数：`red_part`、`open_3x3`、`min_area=100`、标称 `120×80 px`、宽高公差 `±15/±12 px`、零 ROI 表示全帧。

五个输入为合成工位样本，不能代表真实摄像头效果或现场检测精度；其 SHA-256 见注册项和报告。

## 硬件等价契约

- Q10 YCbCr：`Cb=(512B-173R-339G+131072)>>10`，`Cr=(512R-429G-83B+131072)>>10`。
- 红色目标使用严格区间 `85<Cb<125`、`135<Cr<200`；暗目标使用 `Y<60`。
- 3×3 形态学边界显式使用 `BORDER_REPLICATE`，与流式 line-buffer 边界语义绑定。
- ROI 在结果中偏移回整幅图坐标；原点处四个 ROI 参数均为零表示全帧；不完整、负值或越界 ROI 返回 `INVALID`。
- 目标面积、BBox、宽度、高度和 PASS/NG 判定采用整数结果；无目标返回 `NO_OBJECT`。

## 回归结果

执行：

```powershell
python -m unittest work/algorithm_lab/test_stage_d.py -v
python work/algorithm_lab/verify_stage_d.py
```

结果：

| 项目 | 结果 |
|---|---|
| Stage D 自动化测试 | `5/5 PASS` |
| 五个样本 raw mask | 全部 `different_pixels=0`、`MAE=0`、`PSNR=inf` |
| 五个样本 processed mask | 全部 `different_pixels=0`、`MAE=0`、`PSNR=inf` |
| 判定 / BBox / 面积 / 宽高 | 五个样本全部逐字段一致 |
| 样本判定 | 标准件 `PASS`、超大件 `NG`、欠尺寸件 `NG`、空场 `NO_OBJECT`、噪声样本 `PASS` |
| Q10 阈值向量 | `5/5` 边界语义通过 |
| ROI 与形态学边界 | ROI 四边、非法 ROI、3×3 replicate 边界通过 |

完整机器可读证据：`work/algorithm_lab/exports/stage_d/stage_d_report.json`。

## 未关闭项与下一入口

Stage D 通过后允许进入 Stage E 的 RTL 等价仿真准备，但当前不直接宣称 RTL 契约已通过。下一入口前仍需处理：

1. `fallback/rtl/color_detect_96_v2.v` 的 19-bit 面积输出无法覆盖 `1280×720` 全帧。
2. RTL `CR_MAX=240` 与软件模型严格 `Cr<200` 不一致。
3. 修复后需重新执行 RTL 仿真、Golden Model 比对，再决定是否进入 TD 构建。

本阶段没有运行新的 TD 构建、没有修改正式 RTL、没有进行整机视频集成或板级烧录。

## 后续阶段关闭记录

上述“未关闭项”是 2026-10-16 Stage D 形成时的入口条件，不代表当前 RTL 状态。随后在 Stage E/F 已完成：

- `color_detect_96_v2.v` 面积计数统一为 20 bit，1280×720 全前景回归得到 `area=921600`。
- RTL 阈值统一为 Q10 偏置 `131072` 的严格开区间 `85<Cb<125`、`135<Cr<200`，边界向量和 Python Golden 比对通过。
- `morph_open_96.v` 已接入四像素流式 3×3 Opening；连续帧、帧尾排空、非法 ROI 和工业样本回归通过。
- 后续正式证据见 [`2026-10-17-industrial-inspection-stage-e.md`](2026-10-17-industrial-inspection-stage-e.md)、[`industrial-v1-requirement-audit.md`](../evidence/industrial-v1-requirement-audit.md) 和发布 manifest；Stage G 仍未完成。
