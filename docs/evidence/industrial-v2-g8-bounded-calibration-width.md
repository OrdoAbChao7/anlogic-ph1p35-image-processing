# Industrial V2 G8：标定算术定宽试验

## 结论

将 `dimension_calibrator` 中原本统一使用的 64-bit 中间量改为按接口契约计算的定宽中间量后，Python 参考模型、Icarus 仿真和完整 TangDynasty 流程均通过。该次物理实现没有证明 Slice 占用下降，因此本试验只能作为“可综合的定宽实现”记录，不能作为资源预算已改善的证据，也不替换当前最佳形式候选。

## 输入与变更

- RTL：`fallback/rtl/inspection/dimension_calibrator.v`
- 回归：`work/tests/test_v2_calibration.py`
- 坐标：`COORD_WIDTH + 1`
- 包围框面积：`2 * PIXEL_WIDTH`
- 尺寸乘定标系数：`PIXEL_WIDTH + 32`
- 占空比乘积：`20 + 9`
- 长宽比乘积：`PIXEL_WIDTH + 9`
- 约束：保留尺寸乘积的高位溢出检查，并使用与实际乘积宽度一致的切片。

## 验证记录

### 软件与 RTL

- `python -m pytest -q work/tests/test_v2_calibration.py`：`8 passed`
- Icarus dimension calibrator testbench：`TB_DIMENSION_CALIBRATOR_PASS`
- Icarus industrial V2 feature-spine testbench：`TB_INDUSTRIAL_V2_FEATURE_SPINE_PASS`
- 第一次 TD 试验曾因旧的 `[63:32]` 切片超出定宽信号范围而在综合报错；修复后重新执行，未再出现该错误。

### TangDynasty

- TD：`6.2.168116`
- Flow：`DefaultFlow.tcl` 的隔离 fixed-seed 派生流程
- placement seed：`1`
- 结果：完整综合、布局布线、时序和 Bitgen 通过
- Bitstream SHA-256：`e269eacbae8e605c2217ef3ec2958291785e2ef9afbd2daa0a8bd1ae105dd450`
- Bitstream size：`1,371,633 bytes`
- Slice：`18,432 / 21,216`（`86.88%`）
- RAM：`43`
- DSP：`24`
- DRAMHARDCON：`229`
- Setup：WNS `+102 ps`，TNS `0`，violated endpoints `0`
- Hold：WNS `+20 ps`，TNS `0`，violated endpoints `0`

TD 输出的关键摘录保存在 `docs/evidence/industrial-v2-g8-bounded-calibration-width-log.txt`；生成的 TD 工作目录和未采用的候选目录已在提取指标后清理。

## 与当前候选的关系

本次结果的 Slice 占用高于当前形式候选的 `86.07%`，且固定种子实验已显示物理实现对布局结果敏感。因此不更新 `release/candidates/industrial-v2-formal-feature-spine/`，不创建 `release/industrial-v2/`，也不宣称资源预算已通过。硬件、SC520CS 输入、HDMI 画面、长稳和外设验收仍未执行。
