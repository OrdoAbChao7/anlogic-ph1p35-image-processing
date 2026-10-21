# V2 G8 TD candidate build attempt

## 结果

在独立工作树 `work/td_industrial_formal_display` 中使用原工作区提供的 Tang Dynasty 可执行文件和 `DefaultFlow.tcl`，尝试构建 formal display wiring candidate。构建越过输入校验并进入 `syn_1`，日志完成前端/部分映射阶段，最后停在：

```text
SYN-1001 : Stage 2.4 | Map Gate
SYN-3001 : Collect 10200 PI 7040 PO (119 timing unconstrained) for mapping
```

随后工具进程退出，但没有 `Finished in`、`exit code`、`route.qor`、`final_timing.rpt` 或 `.bit` 输出。因此本次结果标记为 `INCOMPLETE`，不作为 TD PASS、QoR PASS 或 Bitstream 证据。

## 输入和隔离范围

- TD executable: `E:/Projects/FPGA/.tools/td/app/bin/td_commands_prompt.exe`
- Flow: `E:/Projects/FPGA/.tools/td/app/doc/scripts/DefaultFlow.tcl`
- Input package: `fallback/td_package`
- Candidate project: `work/td_industrial_formal_display`
- Evidence extract: `docs/evidence/industrial-v2-g8-td-candidate-attempt-log.txt`

## 可审计观察

- `docs/evidence/industrial-v2-g8-td-candidate-attempt-log.txt` 保存了 `syn_1` 日志的关键摘录；原始隔离工作树在记录后清理。
- 日志未出现 `ERROR` 或 `FATAL`，但也没有综合完成标志。
- 日志包含 `SYN-5011` DDR PHY undriven-pin warning、`SYN-5025 Using 0 for all undriven pins and nets`，这些告警尚未分类关闭。
- 日志明确报告 `119 timing unconstrained`，因此不能据此推断时序收敛。
- `phy_1` 仅保留输入配置，未开始可验收的物理实现阶段。

## 后续动作

下一次 TD 尝试应使用可独立回收的进程日志和更长的外部等待窗口，并先审计 `Map Gate` 的资源/内存/约束状态；只有获得完整综合、实现、QoR、warning/CDC/constraint 报告，才进入 Bitgen 和发布包门禁。
