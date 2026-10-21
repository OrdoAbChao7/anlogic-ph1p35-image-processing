# Industrial Vision V2 Goal

## Objective

在 fixed-red v1 冻结候选之上，实现并验证七项升级：交互/OSD/ROI 质量、单目标动态跟踪、内部处理延迟可视化、固定 ROI 帧差运动检测、分拣事件与安全控制、光照自适应/白平衡、标定尺寸与形状验证。最终目标是同一 PH1P35 Bitstream 同时容纳这些能力；缺少硬件、执行器、仪器或标定条件时保留阻塞状态。

## Protected baseline

- Repository baseline: `fallback/industrial-inspection@256d99c1d0dc4dbae2ace8d0ff3a97f504d514c9`
- Frozen Bitstream: `release/candidates/industrial-v1-hx1p35a-pin-correction/camera_to_dsi_display_compress.bit`
- Frozen SHA-256: `b483a1ffc30d0b7ae9e8ebef4f31f617d33a53d6784ded8007d5443c51ad80ef`
- V2 Worktree: `E:/Projects/FPGA-v2`
- V2 Branch: `goal/industrial-v2-advanced`

## Status semantics

`SOFTWARE_PASS`、`RTL_PASS`、`TD_PASS` 和 `HARDWARE_PASS` 是分层证据，不可互相替代。总状态只有在七项能力同一 Bitstream、TD、硬件和发布证据全部满足时才可为 `RELEASED`。

## Visual approval rule

用户已授权需要实验室视觉审查的环节默认通过并可继续 Stage D；仍须保留预览输入、参数、软件/硬件等价模型和差异证据。该授权不关闭真实硬件、仪器测量、外部执行器和物理标定门。
