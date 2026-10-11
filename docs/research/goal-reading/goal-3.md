# Goal 3：基础模式与卡通化

## 目标

在确认 RAW10、Bayer 和 ISP 输出后，完成原图、Sobel 前置格式处理，并加入颜色量化和区域填充形成卡通化模式；由板载按键切换三种模式。

## 必读资料

- [SC520CS 当前目标](../camera/sc520cs.md)
- [RAW10 和 Bayer](../camera/raw10-bayer.md)
- [灰度和二值化](../algorithms/grayscale-threshold.md)
- [camera-filters](../github/selected-projects/camera-filters.md)

## 输出

RTL 模块、软件参考模型、Original/Edge/Cartoon 三种模式、按键控制和 OSD 状态契约。

## 前置知识

完成 Goal 1 的视频闭环，理解 RAW/Bayer/RGB 的格式转换，以及 valid、DE 和 pipeline latency。

## 通过标准

模型与 RTL 边界向量一致；三种模式像素和同步对齐；按键切换在约定帧边界生效；上板画面和 OSD 状态一致。

## 可执行验收

测试方法、量化条件、依赖与证据要求统一见 [验收矩阵](../../verification/acceptance-matrix.md) 的 G3 项；本页阅读或理解目标达成不能代替该阶段验收。
