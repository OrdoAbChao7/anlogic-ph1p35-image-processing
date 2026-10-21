# Industrial Vision V2 G1 Fixed ROI Contract

日期：2026-10-19（Asia/Shanghai）  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`  
基线：`256d99c1d0dc4dbae2ace8d0ff3a97f504d514c9`

## 目标

冻结检测 ROI 的坐标语义、边界复制和非法配置行为，使软件模型、RTL 检测器和 OSD 使用同一套像素坐标约定。

## 合同

- ROI 使用半开区间 `[x0,x1) × [y0,y1)`；RTL 输出 BBox 使用包含端点。
- ROI 外像素在形态学 opening 前被屏蔽，不参与面积和 BBox。
- ROI 四边使用 `BORDER_REPLICATE`，因此贴边目标不会因窗口越界被静默裁掉。
- 非法 ROI、空 ROI 或小于 `min_area` 的结果不触发有效检测事件；非法 ROI 发布 `INVALID`。
- 当前 ISP 顶层显式固定为 `[0,1280) × [0,720)`，这是未完成物理标定前的工程默认值，不是现场标定结论。

## 测试先行

先加入 `work/tests/test_v2_roi_contract.py`，覆盖全帧、ROI 四边、半目标、ROI 外干扰、空场和非法 ROI。首次运行在收集阶段失败：

```text
ModuleNotFoundError: No module named 'roi_contract'
```

随后实现 `work/models/v2/roi_contract.py`，使用列表矩阵建立 3×3 erosion+dilation 的硬件等价参考模型。

## 软件 GREEN

命令：

```text
python -B -m pytest -q work/tests/test_v2_roi_contract.py
```

结果：`6 passed in 0.02s`，退出码 `0`。

## RTL GREEN

修改 `fallback/sim/inspection/tb_industrial_contract.v`，增加显式子窗口 `[8,24) × [4,12)` 的 ROI 检查：

- ROI 外红色干扰被屏蔽；
- 贴 ROI 左上边界的目标按 `BORDER_REPLICATE` 保持 `8×6`；
- 跨越 ROI 左边界的目标裁剪为 `4×6`，面积和 BBox 与软件模型一致；
- 原有空场、非法 ROI、间歇 valid、复位恢复和 full-frame 检查保持通过。

命令使用 `-DMORPH_SIMULATION` 的 Icarus 行为 RAM 分支，结果为：

```text
PASS ROI external interference masked
PASS ROI edge BORDER_REPLICATE
PASS ROI half-target clipping
PASS industrial detector/classifier contract: dimensions, status, LED, edge, gaps, reset, invalid ROI
```

退出码为 `0`。

另外运行 `python -B -m pytest -q work/tests/test_industrial_build_contract.py -k roi_parameters`，结果为 `1 passed, 26 deselected`。

## 判定

`G1 fixed ROI contract: SOFTWARE_PASS / RTL_PASS`。

当前只证明模型与仿真合同。TD 综合、实现 QoR、Bitstream 和真实摄像头/显示器验收仍未完成；物理 ROI 标定仍属于后续硬件阶段。
