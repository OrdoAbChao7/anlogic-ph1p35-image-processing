# FPGA Agent 与 MCP 开源方案技术评估报告

**评估日期**：2026-10-16  
**评估对象**：业界主流 FPGA AI 辅助工具、MCP 方案及测试框架  
**评估人员**：FPGA EDA 自动化架构师 / Antigravity Agent  

---

## 一、评估背景

在构建面向安路 PH1P35 开发板的 AI Agent 自动化开发闭环过程中，业界存在若干声称支持 FPGA 自动化、EDA 交互及 HDL 生成的开源/学术方案。为避免“重复造轮子”并防止引入不兼容或存在安全隐患的外部代码，本报告对五大代表性方案进行实证评估：

1. **AMD Ross Agent Skills** (`Xilinx/ross-ai-assistant`)
2. **FPGA MCP** (`wmm246/fpga-mcp`)
3. **AutoChip** (`shailja-thakur/AutoChip`)
4. **HDLAgent** (`masc-ucsc/hdlagent`)
5. **cocotb** (`cocotb/cocotb`)

---

## 二、逐项深度评估与实测结论

### 1. `wmm246/fpga-mcp` 深度评估（声称支持安路）

- **仓库声称**：支持 AMD Vivado、Intel Quartus 与 Anlogic TangDynasty 三家厂商，声称包含 157 个安路专用 Typed Tools，通过 TCP:9997 本地 Socket 与 TD 交互。
- **本地实测事实**（见本文前序章节运行日志）：
  1. **Tcl 命令虚假/未经验证**：
     查验其 `src/transports/anlogic.py` 与 `tool_defs/anlogic.py`，其调用的核心命令包括：
     - `create_project -name ... -dir ... -part ...`
     - `current_project`
     - `add_file <file>`
     - `get_part`
     - `get_top`
     - `run_synthesis`
     - `run_pnr`
     我们在真实安装的安路 **TangDynasty 6.2.1 build 168116** 控制台（`td_commands_prompt.exe`）中执行 `info commands` 导出全部 740 个原生命令：
     - `current_project`：**不存在**（返回 0）
     - `add_file`：**不存在**（返回 0，安路原生为 `add_files`）
     - `get_part`：**不存在**（返回 0）
     - `get_top`：**不存在**（返回 0）
     - `run_synthesis`：**不存在**（返回 0）
     - `run_pnr`：**不存在**（返回 0）
     该仓库作者显然将 Vivado/Quartus 的常见 Tcl 动词直接套用到了安路后端，从未在真实 TangDynasty 环境下实际运行过！其 CI 测试全部依赖 Mock Server 打桩，完全掩盖了真实不可用的问题。
  2. **TCP 服务端生命周期脆弱**：
     该方案要求在 TD 控制台中常驻运行 `source tcl/anlogic_server.tcl` 启动 TCP 服务。在 Windows 环境下，`td_commands_prompt.exe` 一旦遇到未定义命令或参数异常便会中断并挂起在 `td > ` 交互提示，无法以无头（Headless）服务稳定运行，极易造成 Agent 任务永久阻塞。
  3. **路径与编码陷阱**：
     未考虑 Windows PowerShell 写入 UTF-8 BOM 导致 TD 抛出 `invalid command name "锘縫uts"` 的底层兼容性问题。
  4. **安全与越权风险**：
     开放无限制的 `exec_tcl` 逃生舱，使得任何自然语言提示词都可能意外执行删除文件、破坏顶层约束或烧录未受检位流的危险动作。
- **裁决**：**REJECT（不接入）**。不可在生产和参赛工程中依赖其虚假实现。

---

### 2. AMD Ross Agent Skills (`Xilinx/ross-ai-assistant`)

- **架构特点**：
  - 采用模块化、基于 Markdown 指令的 Skill 设计（Skill Packs），将任务分解为时钟域检查、资源预算、时序收敛闭环、比特流交付等标准化动作。
  - 不试图把庞大的 EDA API 强行翻译成数百个细颗粒度 Python 函数，而是通过结构化方法论提示词（Methodology Prompts）指导 Agent 进行宏观决策，微观执行交给底层确定性脚本。
- **对本项目的借鉴价值**：
  - 本项目借鉴其 Skill 组织思路，在 `.agents/skills/fpga-dev-loop/SKILL.md` 中建立了 `doctor`、`test`、`build`、`report`、`diagnose` 标准技能流。
  - 坚决杜绝直接复制 Vivado 专属 Tcl（如 `report_timing_summary`、`get_pins`、`opt_design`），确保所有安路指令均经由项目已验证的 `DefaultFlow.tcl` 规范执行。
- **裁决**：**ADOPT METHODOLOGY（借鉴其技能方法论，自主实现安路专用版）**。

---

### 3. AutoChip & HDLAgent

- **AutoChip (`shailja-thakur/AutoChip`)**：
  - 基于大模型自动编写 Verilog 代码并通过 Icarus Verilog 编译错误反馈进行多轮修复。
  - 局限性：只关注可编译性（Compilation），缺乏硬件等价的黄金参考模型（Golden Reference Model）进行周期级/数值级比对，极易陷入“语法通过但功能全错”的陷阱。
- **HDLAgent (`masc-ucsc/hdlagent`)**：
  - 聚焦 LLM 辅助 RTL 生成与 Testbench 生成。
  - 局限性：学术研究偏向单模块纯组合逻辑或简单计数器，缺乏对 96-bit 4 像素高吞吐流式视频流水线、Line Buffer 延迟对齐与帧边界协议的处理能力。
- **对本项目的借鉴价值**：
  - 吸收其“受控错误反馈与最小修复”思想，在 `work/fpga_loop/core/diagnostic.py` 中实现了 `RTLDiagnoser`。
  - 区别与创新：本项目强制要求**黄金模型全像素比对**作为通过标准，而不是只要编译无 error 就草率宣布通过。
- **裁决**：**INTEGRATE LESSONS（吸收反馈修复循环，强化黄金模型门禁）**。

---

### 4. cocotb (`cocotb/cocotb`)

- **架构特点**：基于 Python 协程驱动 HDL 仿真器（通过 VPI/VHPI 动态链接库），允许直接用 Python 编写 Testbench。
- **当前环境局限**：
  - 本机为 Windows 11 + Python 3.13 64-bit。目前 PyPI 尚未提供适用于 Python 3.13 Windows 的预编译 wheel，安装需要本地配置 MSVC C++ 编译工具链以编译 C-VPI 拓展。
  - 根据项目《强制工程约束》第 3.1 节：“不允许为了安装仿真工具而随意改变系统 PATH 或全局 Python 环境”。
- **替代与落地策略**：
  - 采用我们实现的 `IverilogRunner` + `tb_color_detect_harness.v` 方案。
  - 该方案使用 Icarus Verilog 14.0 原生执行，Python 负责生成向量、比对输出和管理用例。经实测，单帧仿真耗时仅 0.09s，全套 10 个测试仅 1.34s，零外部 C++ 编译依赖，稳定可靠。
- **裁决**：**NATIVE PYTHON + IVERILOG RUNNER（当前最优解）**。

---

## 三、最终落地架构决策矩阵

| 功能层面 | 选定方案 | 废弃方案 | 核心选型依据 |
|---|---|---|---|
| **EDA 适配层** | 原生 `td_adapter.py`（基于 `DefaultFlow.tcl`） | `wmm246/fpga-mcp` | 真实兼容 TD 6.2.1，拒绝虚假 Tcl，零未受控命令暴露 |
| **仿真与黄金模型** | Python `ColorDetect96Golden` + `iverilog_runner.py` | 纯 Verilog 硬编码测试 / 繁重 cocotb 安装 | 位精确、Q10 定点全覆盖、Windows 原生零侵入运行 |
| **测试断言与覆盖** | `pytest` + 10 维边界/随机/故障注入场景 | 粗略视觉截图对比 | 严格数值匹配，支持 VCD 波形故障溯源 |
| **时序与报告提取** | `TDReportParser` 结构化提取 | 简单字符串 grep / Vivado parser | 严格区分 ps 与 ns，提取真实 WNS/TNS 与资源利用率 |
| **Agent 交互接口** | Antigravity Skill (`.agents/skills/`) + FastMCP | 外部不可靠常驻 Socket | 确定性 CLI 引擎与 AI 解耦，提供坚实 Truth 基础 |

---

## 四、结论与交付物

本项目已成功建立完全可运行、完全可验证、零外部虚假依赖的 **FPGA Agentic Development Loop**：
- 统一自动化 CLI：`python -m work.fpga_loop`
- Windows 单命令入口：`.\scripts\fpga-loop.ps1`
- 官方 Agent 技能规范：`.agents/skills/fpga-dev-loop/SKILL.md`
- 本地 FastMCP 扩展：`work/fpga_loop/mcp/server.py`
