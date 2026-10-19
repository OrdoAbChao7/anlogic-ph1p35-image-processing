# Industrial V2 G8 硬件验收环境可用性检查

日期：2026-10-19  
工作区：`E:/Projects/FPGA-v2`

## 检查范围

本记录只检查当前开发环境是否具备执行 PH1P35 上板验收的下载入口和 USB/JTAG 设备；它不是硬件验收结果，也不能证明实验室没有板卡。

## 实际检查

1. 在 `E:/Projects/FPGA/.tools` 和 `E:/Projects/FPGA-v2/.tools` 中检索 Programmer、JTAG、download、USB、Anlogic 相关文件。结果只发现 TD 安装包和 Icarus 安装包，没有可执行的安路 Programmer 或下载 CLI。
2. 检查运行进程中的 `program`、`programmer`、`td`、`anlogic`、`jtag`。没有匹配的 Programmer/TD/JTAG 进程。
3. 使用 `Get-PnpDevice -PresentOnly` 检索 `JTAG`、`Anlogic`、`安路`、`USB Blaster`、`FTDI`、`Digilent`、`Xilinx`、`Altera`、`FPGA` 和 `Debug`。没有匹配的下载设备；仅返回系统的 Microsoft Kernel Debug Network Adapter。

## 当前工作树复核

本轮再次执行只读核查：

- `python -B -m work.fpga_loop doctor` 退出码 `1`，原因是 `No module named work.fpga_loop`。
- `scripts/fpga-loop.ps1` 和 `work/fpga_loop` 在 V2 工作树中均不存在。
- `Get-PnpDevice -PresentOnly` 的 JTAG/Anlogic/FPGA/USB-Blaster/FTDI/Xilinx/Altera 过滤结果为 `0`，串口设备查询结果为 `0`。

本复核没有下载、烧录、修改管脚或改变正式候选。

## 判定

- 当前环境：`HARDWARE_RUNNER_NOT_AVAILABLE`
- `hardware_function_matrix`：`NOT_RUN/BLOCKED`
- `performance_traceability`：`NOT_RUN/BLOCKED`
- `cold_reset_long_run`：`NOT_RUN/BLOCKED`
- `external_actuator_acceptance`：`NOT_RUN/BLOCKED`
- 没有执行 Bitstream 下载，没有摄像头/HDMI/LED/执行器实测，也没有改变正式候选状态。

具备板卡、SC520CS、HDMI、JTAG/Programmer 和安全的外部执行器隔离条件后，应按 `docs/goals/industrial-v2/HARDWARE_TEST_PLAN.md` 绑定同一 commit、Bitstream SHA-256 和现场环境，再逐项执行验收。
