# Goal 6：显示、统计与外设联动

## 目标

完成 OSD、帧计数、检测框、类别和总数显示，并接入板载按键、LED 和 WM8978 语音播报。

## 必读资料

- [比赛要求](../competition/topic2-requirements.md)
- [目标统计和尺寸判断](../algorithms/object-statistics.md)
- [hdl-util HDMI](../github/selected-projects/hdl-util-hdmi.md)

## 输出

Logo、模式、帧计数、BBox、类别、总数 OSD，按键去抖，LED 触发和 ROM→WM8978 播报链路。

## 前置知识

完成 Goal 5 的 YOLO-tiny 检测，并准备目标类别、空场、多目标样本和固定拍摄区域。

## 通过标准

模式和 OSD 同步；检测事件稳定更新；LED 和语音只对有效事件触发；无目标、重复触发、复位和异常输入行为有证据。

## 可执行验收

测试方法、量化条件、依赖与证据要求统一见 [验收矩阵](../../verification/acceptance-matrix.md) 的 G6 项；本页阅读或理解目标达成不能代替该阶段验收。
