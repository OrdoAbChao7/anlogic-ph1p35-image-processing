# Industrial Vision V2 G1 模式控制器

日期：2026-10-19  
证据类型：`project`（RTL 仿真）

## 目标

把 fixed-red v1 的“按住选择、松开回 Original”改成 V2 需求的“单击循环 Original → Sobel → Cartoon → Original”，并保持模式只在帧边界提交。

## 变更

- `fallback/rtl/control/mode_controller.v`：保留现有端口和三态编码；对 `I_key_edge_n` 做同步/去抖，稳定按下只产生一次 `pending_mode` 循环；`O_mode` 仅在 `I_frame_start` 更新。
- `I_key_cartoon_n` 仍完成同步/去抖但不再直接改变显示模式，作为后续 OSD/run-control 页的保留输入。
- `fallback/sim/control/tb_mode_controller.v`、`fallback/tb_mode_controller.v`：覆盖短抖动、单击、帧前不变、长按不重触发、两次/三次点击循环和保留键不改模式。

## TDD 证据

1. RED：更新测试后使用旧 RTL 编译成功但运行在 `Sobel frame commit` 断言失败，证明测试能够捕获旧的按住选择语义。
2. GREEN：修改 RTL 后同一测试命令输出 `TB_MODE_CONTROLLER_PASS`，退出码 `0`；加入 `timescale` 后无编译 warning。
3. 双入口回归：`fallback/sim/control/tb_mode_controller.v` 和 `fallback/tb_mode_controller.v` 均编译/运行退出码 `0`，输出 `TB_MODE_CONTROLLER_PASS`。

## 边界

- 本实验没有增加 OSD 页面或外部控制 IO；第二输入只保留为后续功能入口。
- 尚未执行 TD 构建和真实按键上板；不能把 RTL PASS 写成硬件通过。
