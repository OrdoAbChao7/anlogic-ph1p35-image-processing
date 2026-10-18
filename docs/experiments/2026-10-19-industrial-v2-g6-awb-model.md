# Industrial Vision V2 G6 帧统计 AWB 软件模型

日期：2026-10-19（Asia/Shanghai）  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`

## 目标

建立只在帧统计边界更新的 Q8.8 R/G/B 增益模型，并保留现有严格 Q10 Cb/Cr 红色检测公式用于兼容性检查。

## TDD 证据

先运行测试，收集预期 RED：

```text
ModuleNotFoundError: No module named 'awb_reference'
```

实现 `work/models/v2/awb_reference.py` 后运行：

```text
python -B -m pytest -q work/tests/test_v2_awb.py
........                                                                 [100%]
8 passed in 0.03s
```

## 模型结论

- 增益使用 Q8.8，初值/绿色通道为 256，R/B 限幅 128–512。
- 当前帧使用旧增益，统计完成后产生下一帧增益；没有帧内中途改变。
- 平滑步长限制为每帧最多 8 个 Q8.8 单位，避免反馈振荡。
- 暗场、过亮场和相邻帧亮度跳变触发 `scene_protected` 并保持旧增益。
- 红色检测仍使用冻结的 `85<Cb<125`、`135<Cr<200` 严格开区间公式。

状态：`SOFTWARE_PASS`。视觉样本/用户确认按用户默认策略可继续，RTL、TD 和真实光照硬件数据尚未完成。
