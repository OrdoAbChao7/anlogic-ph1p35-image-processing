# YOLO-FastestV2 / PH1P35 隔离可行性验证

结论和证据见 [report.md](report.md)。本目录仅是 PC 软件与开源 RTL 研究，不改 FPGA 视频工程。

在 Windows 上，从项目根目录运行：

```bat
work\yolo_fpga_feasibility\run_windows.bat
```

若 `upstream/` 尚未获取，先运行：

```bat
work\yolo_fpga_feasibility\run_windows.bat --bootstrap
```

脚本会校验固定 Git Commit、官方权重 SHA-256 和冻结 COCO 图片 SHA-256，依次运行官方三图 Smoke Test、独立后处理对照、352/160/128/96 评估、网络与活跃张量 profiling、Icarus RTL 回归、逐层预算。输出保存在 `results/`；数据清单在 `data/`。本地 upstream 原仓库和图片按 `.gitignore` 不纳入项目源代码，实际生成的 JSON/CSV/仿真日志保留供审计。

需要 Windows Python 虚拟环境 `work/y1_yolo/.venv`、Git、Icarus `E:\Projects\FPGA\.tools\iverilog\bin`。若虚拟环境不存在，可用兼容 Python 创建后安装 `torch torchvision opencv-python numpy tqdm torchsummary`，再用该环境直接运行 `reproduce.py`；本轮已验证版本分别为 Python 3.13.7、torch 2.14.0+cpu、torchvision 0.29.1+cpu、opencv-python 4.13.0、numpy 2.4.3、torchsummary 1.5.1。torch/torchvision 需要选彼此兼容的发行版本。Icarus 路径由 `check_rtl.py` 的 `SIM` 常量指定，移机时调整该路径后再运行。

原版加法树的失败是预期研究结果，回归入口若仿真成功会保留其 4 个溢出向量，并对隔离候选要求零不匹配。`Reproduction PASS` 表示证据链命令执行成功，不代表原版 RTL、目标识别或 PH1P35 硬件通过。
