# Industrial Vision V2 G3 帧标签监视器

日期：2026-10-19（Asia/Shanghai）  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`

## TDD 证据

先编译 testbench，Icarus 因模块缺失失败：

```text
fallback/sim/inspection/tb_frame_tag_monitor.v:18: error: Unknown module type: frame_tag_monitor
```

实现 `fallback/rtl/inspection/frame_tag_monitor.v` 后运行同一 testbench：

```text
iverilog -g2012 -Wall -s tb_frame_tag_monitor -o work/tests/verification_outputs/v2_frame_tag_green.vvp fallback/sim/inspection/tb_frame_tag_monitor.v fallback/rtl/inspection/frame_tag_monitor.v
vvp work/tests/verification_outputs/v2_frame_tag_green.vvp
```

编译和仿真退出码均为 `0`，输出 `TB_FRAME_TAG_MONITOR_PASS`。

## 覆盖行为

- 首个输入标签建立 pending；
- 连续输入 ID、跳帧 `frame_gap`；
- 结果/视频标签匹配与错配；
- 两类事件都匹配后清除 pending；
- `TIMEOUT_CYCLES=3` 超时只发一次并丢弃陈旧标签；
- 复位后恢复首帧语义。

状态：`RTL_PASS`。该模块尚未接入正式顶层和 OSD。
