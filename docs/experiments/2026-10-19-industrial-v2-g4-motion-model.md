# Industrial Vision V2 G4 固定 ROI 帧差软件模型

日期：2026-10-19（Asia/Shanghai）  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`

## 目标

建立 8-bit 固定 ROI 采样网格的跨帧亮度差参考模型，固定公式为 `abs(Y_now-Y_prev) > threshold`，并定义首帧、帧跳过、非法输入和运动框语义。

## TDD 证据

先运行测试，收集预期 RED：

```text
ModuleNotFoundError: No module named 'motion_reference'
```

实现 `work/models/v2/motion_reference.py` 后运行：

```text
python -B -m pytest -q work/tests/test_v2_motion.py
........                                                                 [100%]
8 passed in 0.03s
```

## 模型结论

- 首帧只建立历史，不输出有效运动结论。
- 连续帧逐点比较相同网格坐标，严格使用 `>` 阈值；运动计数和网格域 Bounding Box 只来自当前帧差异点。
- 静态帧不产生持续运动，当前帧始终在比较后成为下一帧历史。
- 帧号跳变刷新历史但抑制该帧运动结论，下一连续帧重新开放比较。
- 非法尺寸/像素输入不破坏既有历史；复位恢复首帧语义。

状态：`SOFTWARE_PASS`。RTL、TD、HDMI 叠加和真实硬件尚未完成。
