# Industrial V2 G8：I2C clock-enable 复探

## 状态

`REJECTED_SYNTH_TIMING`。本次只验证隔离输入包中的 SC520 I2C clock-enable 版本；没有修改正式 V2 源码、正式 Bitstream 或 V1 基线。

## 变更与软件证据

候选源来自本机已完成 SC520 clockfix 副本中的 `uics500_cfg/uii2c.v`，SHA-256 为 `03157619967fd339847ec3ffd4b191f90363ed0112950e8efb87acf2e25e528f`。它将原 `posedge/negedge scl_clk` 事件改为 `I_clk` 域的 `scl_pos_en/scl_neg_en`，不改模块端口和事务语义。

隔离 Icarus 定向仿真通过：`busy` 正常结束、`bus_error=0`、读回 `8'h00`、SCL 转换 59 次。测试使用单字节写、重复起始读和低电平 ACK 模型。

## TD 探针

使用独立输入包、work project、release 目录、官方 `DefaultFlow.tcl` 和 `place seed=1` 启动完整 V2 构建。综合阶段日志出现：

```text
Setup WNS -1255ps
Setup TNS -14138ps
NUM_FEPS 22
```

TD 随后停在交互提示符，未进入有效的完整 P&R/STA/Bitgen；由本次探针启动的精确进程树被终止。没有生成可接纳的 Bitstream 或 route QoR，因此不能把该实现视为 TD 候选。

## 结论

- `RTL/SIM`：PASS（隔离定向场景）。
- `TD`：FAIL，综合时序未收敛，且没有完整物理实现证据。
- `hardware`：NOT_RUN。
- 正式候选包：保持不变。

该结果说明这份 clock-enable 源不能直接替换当前 V2 构建输入；后续处理时钟告警应继续以最小拓扑变更和完整 TD 证据为门槛。
