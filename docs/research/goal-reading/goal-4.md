# Goal 4：Sobel 和实时流水线

## 目标

使用 Line Buffer 和 `3×3` Window 实现实时 Sobel 边缘检测，并定义梯度位宽、绝对值、饱和、阈值和边界策略。

## 必读资料

- [Sobel](../algorithms/sobel.md)
- [Line Buffer](../algorithms/line-buffer.md)
- [FPGA Video Processing](../github/selected-projects/georgeyhere-video.md)
- [Galapple Sobel](../github/selected-projects/galapple-sobel.md)

## 输出

Line Buffer、Sobel、模式选择、控制同步、资源和延迟说明。

## 前置知识

完成 Goal 3 的像素流处理，掌握 BRAM、移位寄存器、3×3 窗口和同步信号延迟。

## 通过标准

仿真结果可解释，TD 时序通过，上板实时显示边缘结果。

## 可执行验收

测试方法、量化条件、依赖与证据要求统一见 [验收矩阵](../../verification/acceptance-matrix.md) 的 G4 项；本页阅读或理解目标达成不能代替该阶段验收。
