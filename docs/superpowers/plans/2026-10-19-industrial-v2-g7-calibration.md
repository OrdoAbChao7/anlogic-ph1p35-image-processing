# Industrial Vision V2 G7 执行计划

## Task 1：标定与形状软件模型

- TDD 覆盖 X/Y 独立比例、Q16.16 换算、BBox inclusive、尺寸容差、occupancy/aspect 和非法标定。
- 输出 `px` 与 `mm` 的明确单位字段，禁止无标识数值。

## Task 2：RTL 定点换算与形状判定

- 先写参数化 `tb_dimension_calibrator.v` 收集 RED。
- 实现 `dimension_calibrator.v`，只在结果事件计算一次定点摘要。
- 软件与 RTL 共享整数除法、截断/饱和和边界公式。

## Task 3：回归与实验缺口

- 跑 G1-G7 相关软件/RTL、全量 `work/tests` 和 Stage D。
- 记录真实标定物、工位几何、旋转和光照实验尚未具备；默认视觉审批不替代这些物理输入。

## Task 4：阶段记录

- 更新 G7 总结、状态、证据索引和资源预算。
- G7 无真实标定数据和 TD 时保持 `BLOCKED`，继续 G8 的冻结/发布审计准备。
