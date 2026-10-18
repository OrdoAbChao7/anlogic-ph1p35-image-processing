# Industrial Vision V2 G4 执行计划

> 执行规则：独立的软件/RTL 工作可在 G1 正式顶层阻塞时继续；本计划不修改 V1 冻结位流，不把独立仿真写成 TD 或硬件通过。

## Task 1：固定 ROI 帧差软件模型

- 先写 `work/tests/test_v2_motion.py`，覆盖首帧、静态帧、局部移动、阈值边界、frame gap、非法输入和 ROI 边界。
- 先运行测试确认缺少模型的 RED，再实现 `work/models/v2/motion_reference.py`。
- 通过条件：模型输出摘要字段稳定，历史更新和 frame gap 语义可审计。

## Task 2：固定 ROI 帧差 RTL

- 先写小尺寸参数化 `tb_motion_diff_160.v`，仅编译 testbench 收集 RED。
- 实现 `fallback/rtl/inspection/motion_diff_160.v`，使用固定地址历史存储、同坐标跨帧比较和帧末摘要；仿真宏下不依赖厂商库。
- 通过条件：RTL 对首帧、静止、移动、阈值、frame gap、复位、越界和帧边界输出与模型一致。

## Task 3：定向回归与资源记录

- 运行 G1-G4 相关 Python 模型和 RTL testbench。
- 运行 `work/tests` 全量以及 Stage D 检查，保留既有冻结基线失败。
- 增加独立资源估算/实现入口说明；未执行 TD 时写 `NOT_MEASURED`。

## Task 4：阶段记录

- 写 G4 实验记录和阶段总结。
- 更新 `STATUS.json`、`ROADMAP.md`、`TASKS.md`、`EVIDENCE_INDEX.md`、`RESOURCE_BUDGET.md`。
- G4 只有软件/独立 RTL 证据时标记 `BLOCKED`，下一步转入 G5。
