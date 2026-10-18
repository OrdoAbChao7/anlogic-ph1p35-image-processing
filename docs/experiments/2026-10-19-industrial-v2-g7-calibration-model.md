# Industrial Vision V2 G7 标定与形状软件模型

日期：2026-10-19（Asia/Shanghai）  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`

## 目标

建立 X/Y 独立 mm/pixel 标定、inclusive BBox 定点换算和有限形状合法性检查。模型将物理单位明确表示为 Q16.16，不在未标定时输出毫米结论。

## TDD 证据

先运行测试，收集预期 RED：

```text
ModuleNotFoundError: No module named 'calibration_reference'
```

实现 `work/models/v2/calibration_reference.py` 后运行：

```text
python -B -m pytest -q work/tests/test_v2_calibration.py
.......                                                                  [100%]
7 passed in 0.03s
```

## 模型结论

- 参考物 `120 px -> 60 mm`、`80 px -> 20 mm` 得到独立 X/Y Q16.16 比例。
- BBox 端点按 inclusive 计算；输出同时保留像素尺寸和 `mm_q16_16` 单位。
- occupancy 低于阈值或 aspect 超界可阻止一类稀疏/形状异常误判，但不等价于连通域分离。
- 非法/未标定输入输出 `UNCALIBRATED`，不声称毫米测量。

状态：`SOFTWARE_PASS`。真实参考物、工位几何、RTL、TD 和现场误差尚未完成。
