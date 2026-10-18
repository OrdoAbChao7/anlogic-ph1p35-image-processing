# Industrial Vision V2 G7 阶段总结

日期：2026-10-19（Asia/Shanghai）  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`  
G7 commits：`e581f3e`, `a10a1bd`, `bd02e0a`

## 已实现

- `calibration_reference.py`：独立 X/Y 参考物标定、Q16.16 mm/pixel、尺寸容差和形状模型。
- `dimension_calibrator.v`：inclusive BBox 定点尺寸、occupancy、aspect、尺寸/形状有效性和未标定保护。
- 形状检查仅针对单目标轴对齐 BBox，不宣称多目标连通域或旋转不变测量。

## 受影响验证

| 检查 | 结果 |
|---|---|
| G1-G7 软件模型 | `49 passed in 0.15s` |
| G1-G7 RTL 定向回归 | 14 个入口全部 compile/run `0`，新增 `TB_DIMENSION_CALIBRATOR_PASS` |
| `python -B -m pytest -q work/tests` | `95 passed, 8 failed`；8 项仍为冻结 V1 release/path/旧入口契约漂移 |
| `python -B work/algorithm_lab/verify_stage_d.py` | exit `1`；Stage D 样本通过，registry `ef929f...` 与 plugin `08f929...` SHA 不一致 |

## 物理缺口

- 当前没有真实标定参考物、镜头距离、工位姿态、目标平面、光照和重复测量记录。
- 因此 Q16.16 只是可运行的定点合同，不能写成毫米级实测；OSD 若接入必须明确 `px` 或 `mm` 单位。
- TD 资源、时序、旋转误差、位置/光照/ROI 边界和真实零件统计尚未完成。

## 阶段判定

`V2-G7 = BLOCKED`，分层为：

- 软件模型：`SOFTWARE_PASS`；
- 独立 RTL：`RTL_PASS`；
- 正式 OSD/主判定/TD：`NOT_RUN/BLOCKED`；
- 真实标定和现场测量：`NOT_RUN/BLOCKED`。

G7 的软件/RTL 候选可以进入后续审计，但未获得物理标定证据前不得声称真实毫米测量或旋转补偿完成。
