# Industrial Vision V2 G3 RTL 延迟监视器

日期：2026-10-19（Asia/Shanghai）  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`

## 目标

为内部帧事件提供带 `frame_id` 的 `PROC`/`VIDEO` 延迟脉冲、帧缺口、标签错配和超时诊断。物理显示端到端延迟仍保持 `E2E=N/A`，不由 RTL 伪造。

## TDD 证据

先只编译测试平台，得到预期的 RED：

```text
fallback/sim/inspection/tb_latency_monitor.v:19: error: Unknown module type: latency_monitor
```

加入 `fallback/rtl/inspection/latency_monitor.v` 后运行：

```text
E:/Projects/FPGA/.tools/iverilog/bin/iverilog.exe -g2012 -Wall -s tb_latency_monitor -o <temp>/v2-g3-latency-green.vvp fallback/sim/inspection/tb_latency_monitor.v fallback/rtl/inspection/latency_monitor.v
E:/Projects/FPGA/.tools/iverilog/bin/vvp.exe <temp>/v2-g3-latency-green.vvp
```

结果：

```text
TB_LATENCY_MONITOR_PASS
```

## 行为结论

- 匹配的结果和视频事件分别发布 `O_proc_valid/O_proc_cycles`、`O_video_valid/O_video_cycles`。
- 延迟计数与 `LatencyModel` 一致：底层使用自由运行固定宽度计数器和输入时间戳，并扣除此前的结果/视频观测沿，只累计两次原子观测之间的空闲 `I_clk` 周期。
- 无活动帧、迟到帧或错标签事件只产生 `O_tag_mismatch`，不发布有效延迟。
- 输入帧号跳变产生一次 `O_frame_gap`；超时清除 pending，下一帧可重新建立测量。
- `O_e2e_valid=0` 且 `O_e2e_cycles=0`，表示当前没有物理显示链路测量，不代表零延迟。
- `COUNTER_WIDTH=4` 的回绕场景通过，验证固定宽度计数不会破坏后续测量。

状态：`RTL_PASS`。TD、综合、正式顶层接入、上板和物理 E2E 测量尚未完成。
