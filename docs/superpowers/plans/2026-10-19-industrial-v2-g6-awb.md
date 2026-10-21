# Industrial Vision V2 G6 执行计划

## Task 1：帧统计 AWB 软件模型

- TDD 覆盖定点增益、限幅、平滑、场景变化保护、暗/亮场、帧边界生效和红色检测兼容性。
- 输出当前帧使用增益与下一帧增益，避免把更新误当成当前帧中途改变。

## Task 2：RTL 定点增益控制器

- 先写统计边界 testbench 收集 RED。
- 实现 `awb_frame_gain_controller.v`，只在 `I_frame_stats_valid` 更新 Q8.8 增益。
- 软件与 RTL 使用相同整数均值、四舍五入、限幅、平滑和场景保护公式。

## Task 3：回归与审计记录

- 运行 G1-G6 相关模型/RTL 回归、全量 `work/tests` 和 Stage D。
- 保留当前 AWB/AE 路径的 project/unknown 边界，不修改传感器配置。

## Task 4：阶段记录

- 记录 AWB 审计、定点模型、RTL 证据、真实光照缺口和资源未测状态。
- G6 在无用户视觉样本、TD 和硬件光照实验时保持 `BLOCKED`，继续 G7。
