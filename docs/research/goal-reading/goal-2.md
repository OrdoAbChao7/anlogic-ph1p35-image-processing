# Goal 2：接口、时钟和 ISP 基线

## 目标

冻结 RAW10、Bayer、CSI-2 输出、拜耳解码、白平衡、DDR2 和 HDMI 的接口契约，理解顶层、时钟、复位、像素流、FIFO、帧缓存和控制路径。

## 必读资料

- [TD 工具资料](../anlogic/td-tool.md)
- [安路 IP 参考](../anlogic/ip-reference.md)
- [MIPI CSI-2](../mipi-video/mipi-csi2.md)
- [HDMI 时序](../mipi-video/hdmi-timing.md)

## 选读资料

- [hdl-util HDMI](../github/selected-projects/hdl-util-hdmi.md)
- [SimpleVOut](../github/selected-projects/simplevout.md)

## 输出

完成模块关系图、像素数据流、时钟复位树、ISP 插入点和接口表。

## 前置知识

会阅读简单 Verilog module、时序 always 块、计数器和状态机；理解时钟域和复位。

## 通过标准

每段接口的位宽、同步、吞吐率、CDC、背压和延迟均能定位到源文件、配置、报告或波形；未知项已记录到缺口表。

## 可执行验收

测试方法、量化条件、依赖与证据要求统一见 [验收矩阵](../../verification/acceptance-matrix.md) 的 G2 项；本页阅读或理解目标达成不能代替该阶段验收。
