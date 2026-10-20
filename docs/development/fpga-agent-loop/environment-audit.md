# FPGA Agent 开发闭环：开发环境与工具链审计报告

**审计日期**：2026-10-16  
**主机环境**：Windows 11 (OS Build 26100)  
**目标器件**：安路科技 PH1P35MDG324 (开发板 HX1P35A)  
**审计人员**：FPGA EDA 自动化架构师 / Antigravity Agent  

---

## 1. 工具链现状与可用性矩阵

| 工具 / 组件 | 检测位置 / 命令 | 检测版本 | 运行状态 | 关键评估与约束 |
|---|---|---|---|---|
| **Python** | 系统 PATH / `python --version` | Python 3.13.7 (64-bit) | `PASS` | 运行正常，标准库与现代语法完备 |
| **pip** | `python -m pip --version` | pip 25.3 | `PASS` | 包管理器可用 |
| **Git** | 系统 PATH / `git --version` | 2.51.0.windows.1 | `PASS` | 分支与版本控制正常 |
| **PowerShell** | `$PSVersionTable.PSVersion` | 5.1.26100.7705 | `PASS` | Windows 原生脚本引擎可用 |
| **pytest** | `python -m pip show pytest` | pytest 8.4.2 | `PASS` | 已预装，可直接驱动自动化测试 |
| **NumPy** | `python -m pip show numpy` | 2.4.3 | `PASS` | 已预装，支持定点矩阵与图像运算 |
| **Icarus Verilog** | 本地工具目录 `.tools/iverilog/bin/iverilog.exe` | 14.0 (devel) | `PASS` | 本地独立绿色安装，不污染系统 PATH；经实际编译仿真运行验证，代码生成和 VVP 执行均正常 |
| **Icarus VVP** | 本地工具目录 `.tools/iverilog/bin/vvp.exe` | 14.0 (devel) | `PASS` | 正常运行，支持 1ps 精度仿真与 `$finish` |
| **GTKWave** | 本地工具目录 `.tools/iverilog/gtkwave-gtk3/` | GTKWave 3.x | `PASS` | 可供查看 VCD/FST 波形 |
| **Tang Dynasty (TD)** | 本地工具目录 `.tools/td/app/bin/td_commands_prompt.exe` | Release 6.2.1 Build 168116 | `PASS` | 经实测，命令行接口真实可运行，能解析脚本并执行 Tcl 命令与流程 |
| **TD License** | `.tools/td/app/license/Anlogic.lic` | Anlogic.lic 存在 | `PASS` | 包含 PH1 系列综合、实现及比特流生成授权 |
| **DefaultFlow.tcl** | `.tools/td/app/doc/scripts/DefaultFlow.tcl` | 官方标准流程脚本 | `PASS` | 包含 `read_design`, `opt_rtl`, `opt_gate`, `opt_place`, `opt_route`, `bitgen` 六阶段流 |
| **cocotb** | `python -m pip show cocotb` | 未安装 | `BLOCKED` (全局环境) | Python 3.13 Windows 环境缺乏预编译 C-VPI wheel，安装需 MSVC C++ 构建环境。根据强制工程约束“禁止随意改变系统 PATH 或全局 Python 环境”，HDL 仿真应优先采用原生 Python 驱动 Icarus Verilog（输入向量生成 + 周期采样对比 + 黄金模型自动化断言），确保零侵入、高可靠 |
| **Verilator** | 系统 PATH | 未安装 (Windows 原生) | `NOT_RUN` | 当前 Icarus Verilog 14.0 已能完全满足模块级与子系统级时序/流式仿真需求，暂无强依赖 |
| **FPGA MCP (wmm246)** | 远程评估与本地 TD 6.2.1 兼容性测试 | GitHub main | `FAIL` (安路兼容性) | 详见本文第 3 节深度评估，其宣称的 Tcl 命令与真实 TD 6.2.1 严重脱节 |

---

## 2. 现有项目资产与构建基线审计

### 2.1 核心硬件顶层与工程
- **当前重点路线**：`fallback/industrial-inspection`（传统工业视觉检测），核心处理模块为 `fallback/rtl/color_detect_96.v`。
- **独立 TD 工程入口**：`fallback/project/td_project/camera_to_dsi_display.al`。
- **原始参考工程**：`HX1P35A2026/` 及 `.tools/td/work/lab_ex1_mipi_hdmi_sc520/`。
- **时钟域架构**：
  - `MIPI_RX_BYTE_CLK`: 103.520 MHz
  - `HDMI_PIXEL_CLK`: 75.002 MHz
  - `ddr_usr_clk`: 66.667 MHz
  - `sys_clk_50m`: 50.000 MHz
  - `HDMI_SERIAL_CLK`: 375.094 MHz

### 2.2 现有 TD 构建脚本审计 (`scripts/build_and_run_td.py`)
1. **工具路径**：通过相对路径引用 `.tools/td/app/bin/td_commands_prompt.exe` 与 `DefaultFlow.tcl`，未硬编码外部绝对盘符。
2. **工程修改风险**：现有脚本在 `setup_runs()` 中直接修改了 `work/td_cartoon/` 目录下的 `.prj` 文件；若在非隔离环境下运行可能污染既有工程。
3. **产物覆盖风险**：旧脚本直接把产物写入固定目录 `work/output/cartoon-release/`，缺乏全局唯一的 `run-id` 与隔离构建沙盒。
4. **退出码与时序处理**：旧脚本能够检查 `proc.returncode`，但在解析 `route.qor` 时只做了文本打印，未做结构化提取和阈值校验。
5. **单位混淆陷阱**：在 TD 6.2.1 中，`route.qor` 输出的数值为整数皮秒（ps，如 `Setup WNS: 1389`），而 `final_timing.rpt` 输出为浮点纳秒（ns，如 `SWNS: 1.389ns`）。自动化解析器必须严格标准化单位（统一转为 ps 或 ns 并标注单位），严禁数值错位。

---

## 3. `wmm246/fpga-mcp` 深度技术评估

根据任务要求，我们对开源项目 `wmm246/fpga-mcp` 进行了针对性的代码审计与本地 TD 6.2.1 实测：

### 3.1 兼容性致命缺陷：Tcl 命令虚假/臆造
经查验其源代码 `src/transports/anlogic.py` 与 `tool_defs/anlogic.py`，该项目向 TangDynasty 发送的 Tcl 命令大量直接参照了 Vivado/Quartus 习惯进行“臆造”，未经真实 TD 环境测试：
- 其调用的 `current_project`、`add_file`、`get_part`、`get_top`、`run_synthesis`、`run_pnr` 在本地真实 TD 6.2.1 命令集（通过 `info commands` 导出 740 个原生命令）中**全部不存在（返回 0）**！
- 安路 TD 真实使用的文件管理命令为 `add_files`、`import_files`，工程流程由 `settings.cfg` 与 `DefaultFlow.tcl` 驱动，而非直接命令调用。
- 该项目在 CI 中仅使用 Mock Server 模拟了通信响应，掩盖了真实命令无法执行的本质。

### 3.2 架构缺陷：TCP 服务端常驻模式的高风险
- `wmm246/fpga-mcp` 依赖在 TD 交互式控制台中预先加载 `tcl/anlogic_server.tcl` 开启 TCP 9997 端口。
- 在 Windows 环境下，`td_commands_prompt.exe` 作为批量脚本执行工具，一旦遇到交互提示或未捕获错误即会阻塞在 `td > ` 控制台，无法作为无头 Daemon 可靠自愈。
- 开放任意 `exec_tcl` 接口存在严重越权风险，容易破坏版本受控的工程配置。

### 3.3 评估结论
**结论**：`wmm246/fpga-mcp` 当前无法直接用于安路 TD 6.2.1 的真实开发闭环。  
**技术路线决策**：采用**“原生 Python CLI + 独立沙盒 EDA Adapter + 结构化报告解析器”**路线。这不仅契合安路官方 `DefaultFlow.tcl` 规范，而且提供确定性、高安全性和零外部依赖。同时，我们将该稳定闭环封装为 Antigravity Agent Skill 和轻量级本地 MCP Tool，确保 Agent 与用户均可无缝使用。

---

## 4. 闭环建设行动方案

1. **第一步**：在 `work/fpga_loop/` 下建立纯 Python 黄金参考模型 (`color_detect_96_golden.py`) 与定点颜色空间转换算法。
2. **第二步**：建立基于 Icarus Verilog 14.0 的自动化测试框架，编写覆盖边界、溢出、多像素对齐、复位和持续帧时序的综合测试集。
3. **第三步**：实施受控错误注入，验证测试框架对逻辑错误的捕捉灵敏度。
4. **第四步**：开发隔离构建适配器 `td_adapter.py`，支持带 Run-ID 的沙盒构建与新鲜度（Freshness）校验。
5. **第五步**：开发高鲁棒性 TD 报告解析器，精准提取 Slice, LUT, FF, BRAM, DSP, Setup/Hold WNS, TNS 及关键警告。
6. **第六步**：构建统一 CLI 入口 `python -m fpga_loop` 与 PowerShell 脚本 `scripts/fpga-loop.ps1`。
7. **第七步**：建立标准 Agent Skill 接入文件，形成完整的诊断与迭代闭环。
