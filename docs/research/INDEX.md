# 安路 PH1P35 题目二资料库

## 项目目标

完成 `SC520CS → MIPI CSI-2 → PH1P35 → 图像处理 → HDMI` 的实时数字图像处理系统，并逐步扩展到目标测量、缺陷判断和 OSD 展示。

## 资料分层

| 层级 | 内容 | 使用方式 |
|---|---|---|
| L1 | PH1P35、TD、比赛题目和安路官方 IP | 实现依据 |
| L2 | SC520CS、MIPI、RAW/Bayer、HDMI、DDR 原理资料 | 理解和排错 |
| L3 | 灰度、二值化、Sobel、Line Buffer、目标统计 | 算法依据 |
| L4 | GitHub 参考工程 | 学习结构和验证方法 |
| L5 | 本项目实验记录 | 当前工程事实 |

执行前同时查看 [方案与计划验收表](../verification/acceptance-matrix.md)，按测试条件与证据判断阶段是否通过。

## 当前 Goal 阅读入口

- [Goal 1：视频硬件闭环](goal-reading/goal-1.md)
- [Goal 2：FPGA 工程基础](goal-reading/goal-2.md)
- [Goal 3：灰度和二值化](goal-reading/goal-3.md)
- [Goal 4：Sobel 和实时流水线](goal-reading/goal-4.md)
- [Goal 5：目标统计](goal-reading/goal-5.md)
- [Goal 6：完整比赛应用](goal-reading/goal-6.md)
- [Goal 7：优化和创新](goal-reading/goal-7.md)
- [Goal 8：发布和答辩](goal-reading/goal-8.md)

## 资料入口

- [Y1 FastestDet 软件复现与硬件适配预研](../experiments/2026-10-12-y1-fastestdet.md)

- [2026-10-11 组员工程同步与卡通版审计](../setup/team-sync-2026-10-11.md)

- [比赛要求](competition/topic2-requirements.md)
- [安路官方资料索引](anlogic/official-index.md)
- [PH1P35 资料](anlogic/ph1p35.md)
- [TD 工具资料](anlogic/td-tool.md)
- [安路 IP 和参考设计](anlogic/ip-reference.md)
- [SC520CS 当前目标](camera/sc520cs.md)
- [RAW10 和 Bayer](camera/raw10-bayer.md)
- [MIPI CSI-2](mipi-video/mipi-csi2.md)
- [HDMI 时序](mipi-video/hdmi-timing.md)
- [DDR 帧缓存](mipi-video/ddr-framebuffer.md)
- [图像算法](algorithms/)
- [GitHub 参考工程总表及速查指引](github/repositories.md)
- [安路 FPGA 工业视觉开源参考库 (6 仓库)](OPEN_SOURCE.md#2026-10-13-安路-fpga-工业视觉参考工程专项已完整克隆与源码审计)
- [开源算法与 RTL 参考索引 (OPEN_SOURCE.md)](OPEN_SOURCE.md)
- [资料缺口](known-gaps.md)
- [质量检查规则](quality-check.md)

## 可信度标记

- `official`：安路官方或比赛正式资料。
- `project`：当前工程代码、配置或报告直接证明。
- `measured`：当前板卡或仪器实测；必须说明测量对象与条件。
- 历史 `verified` 标记应按实际证据区分为 `project` 或 `measured`，不能直接视为硬件验证。
- `reference`：第三方原理或参考工程，只能借鉴。
- `inferred`：根据多个来源推断，必须在硬件上验证。
- `unknown`：当前缺少可靠来源，不允许作为实现结论。

## Codex 使用规则

Codex 先读取本文件和 `sources.yaml`，再根据当前 Goal 读取对应清单。回答时要区分来源事实、工程事实和推断；如果资料库没有足够证据，应引用 [known-gaps.md](known-gaps.md)，不能自行补全关键硬件参数。
