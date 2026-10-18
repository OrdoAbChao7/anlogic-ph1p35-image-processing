# Industrial Vision V2 G3 延迟测量与可视化设计

日期：2026-10-19  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`

## 目标与边界

G3 只测量当前 FPGA 内部可追踪的帧事件间隔，并把物理显示器延迟明确保持为 `N/A`。不使用 HDMI 刷新率、帧计数或未经标签关联的近似值冒充端到端延迟；不改变厂商视频和时钟边界。

## 事件与单位

所有时间戳由同一 `I_clk` 的自由运行周期计数器产生，单位为 `clk cycles`。输入帧事件保存 `frame_id` 和 `timestamp`；结果发布、视频输出事件必须携带对应标签。

`PROC = result_timestamp - input_timestamp`，表示输入帧到检测结果发布的内部间隔。`VIDEO = video_timestamp - input_timestamp`，表示输入帧到视频域事件的内部间隔。`E2E` 需要受控光源与高速摄像/示波器，目前无物理测量，因此状态为 `N/A`，不产生伪数值。

## 模块边界

### `frame_tag_monitor`

保存最近输入帧标签，检查结果/视频标签是否匹配，并检测输入帧 ID 缺口、结果超时和标签错配。输出均为事件脉冲或保持的诊断状态，便于 OSD 标记 `TAG_GAP`/`TIMEOUT`。

### `latency_monitor`

在同一时钟域记录输入事件时间戳；当结果或视频事件匹配当前输入标签时发布对应 cycles 和 valid 脉冲。没有匹配标签时只报错，不输出有效延迟。`O_e2e_valid` 固定为 0，表示 `E2E=N/A`。

## 异常语义

- 首帧输入建立测量基准，不产生 gap。
- 输入帧 ID 不是上一帧加一时产生 `frame_gap`。
- 结果或视频标签与当前输入不一致时产生 `tag_mismatch`，不发布对应有效测量。
- 结果在 `TIMEOUT_CYCLES` 内未到达时产生一次 `timeout`，下一次有效输入可重新建立基准。
- 复位清除所有 pending 标签和计数器；物理 E2E 仍为 N/A。

## 验证

覆盖连续帧、固定延迟、结果/视频错配、输入跳帧、超时、复位、计数器回绕和 E2E 不可测标志。软件模型、RTL testbench 和后续 OSD 显示使用同一单位与标签规则。
