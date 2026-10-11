# Goal 5：YOLO-tiny 硬件检测

## 目标

固定 INT8 量化裁剪后的 YOLO-tiny 版本，完成卷积、池化、量化/激活、BRAM 特征图缓存、候选框解码和 NMS 硬件流水线，输出目标位置、类别和总数。

## 必读资料

- [目标统计和尺寸判断](../algorithms/object-statistics.md)
- [灰度和二值化](../algorithms/grayscale-threshold.md)
- [比赛要求](../competition/topic2-requirements.md)
- [FPGA Video Processing 参考工程](../github/selected-projects/georgeyhere-video.md)

## 输出

模型与量化说明、算子 RTL、BRAM 布局、NMS、BBox、类别和帧结束更新逻辑。

## 前置知识

完成 Goal 3 的二值图像输出，理解像素坐标、帧边界和帧内累加器。

## 通过标准

模型/RTL 算子结果在约定容差内一致；空场景、单目标、多目标、边界框和连续帧检测通过；资源、吞吐、延迟和检测效果有报告。

## 可执行验收

测试方法、量化条件、依赖与证据要求统一见 [验收矩阵](../../verification/acceptance-matrix.md) 的 G5 项；本页阅读或理解目标达成不能代替该阶段验收。
