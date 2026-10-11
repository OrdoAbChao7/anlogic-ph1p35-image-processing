# Goal 1：视频采集与显示闭环

## 目标

实现 `SC520CS → MIPI D-PHY → CSI-2 → DDR2 → HDMI → 显示器` 的稳定原始视频闭环。RAW10、1280×720 和 30fps 是方案目标，须由工程和上板证据确认。

## 必读资料

- [比赛要求](../competition/topic2-requirements.md)
- [安路官方资料索引](../anlogic/official-index.md)
- [PH1P35 资料](../anlogic/ph1p35.md)
- [MIPI CSI-2](../mipi-video/mipi-csi2.md)
- [HDMI 时序](../mipi-video/hdmi-timing.md)
- [视频链路一致性检查](../mipi-video/link-consistency.md)
- [SC520CS 当前目标](../camera/sc520cs.md)

## 选读资料

- [安路 PH1A 摄像头方案](../anlogic/camera-solution.md)
- [FHDO MIPI-HDMI](../github/selected-projects/fhdo-mipi-hdmi.md)

## 输出

完成官方工程审计、编译、下载、原图显示和硬件验收记录；保留可作为 ISP、算法和检测基线的输入输出证据。

## 前置知识

无。只需要准备 PH1P35 开发板、SC520CS 模组及匹配的 FPC、HDMI 显示器、下载器和工程资料；MIPI、HDMI、时钟和复位概念在本 Goal 中边做边学。

## 通过标准

工程可重复构建和下载；冷启动、重新下载、热复位均能恢复画面；视频格式、分辨率、刷新率和关键告警均有证据。软件构建不能替代上板通过。

## 可执行验收

测试方法、量化条件、依赖与证据要求统一见 [验收矩阵](../../verification/acceptance-matrix.md) 的 G1 项；本页阅读或理解目标达成不能代替该阶段验收。
