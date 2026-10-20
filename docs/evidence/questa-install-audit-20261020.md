# Questa/ModelSim 本机审计

审计时间：2026-10-20 13:47 +08:00  
工作区：`E:\Projects\FPGA`  
范围：本机工具、安装介质、许可、PH1 仿真模型；未修改工程代码，未启动 TD 构建。

## 结论

当前项目规定的模块及整合 RTL 回归使用 Icarus Verilog；TD 用于 FPGA 综合/实现。因此 ModelSim/Questa 不是当前项目验证与构建流程的必要前置。若要使用 TD 的 Project Simulation，或仿真 PH1 器件/IP 模型，则需要外部 ModelSim/Questa，并先编译 PH1 库。

本机未发现可安装的 Questa/ModelSim 介质或已配置的仿真许可；未启动安装器。管理员权限要求未触达。

## 本机检查

| 检查 | 命令/路径 | 结果 |
|---|---|---|
| 已安装模拟器 | `Get-Command vsim.exe,vlog.exe,vlib.exe`; `where.exe vsim`; 查询 HKLM/HKCU 卸载项；递归检查 Program Files、`D:\Program Files`、`E:\Projects\FPGA\.tools` | 无命令、无匹配可执行文件、无 ModelSim/Questa 注册项 |
| 安装包/脚本 | 在 `$env:USERPROFILE\Downloads`、Desktop、`D:\BaiduNetdiskDownload`、`D:\temp_extract`、`E:\Projects\FPGA\.tools`、`scripts` 按 `modelsim|questa|vsim|quartus|altera.*fpga|intel.*fpga|mentor.*sim` 搜索 `.exe/.msi/.zip/.7z/.rar/.tar/.gz/.bat/.cmd/.ps1` | 无匹配项；下载目录里曾发现的 `仿真工具ModelSim软件的安装教程.pdf` 是教程，不是介质 |
| 许可配置 | 检查 `SALT_LICENSE_FILE`、`LM_LICENSE_FILE`、`MGLS_LICENSE_FILE`、`QUESTA_LICENSE_FILE`、`MODEL_TECH`、`MTI_HOME`、`QUESTA_HOME` 的 Process/User/Machine 值；检查 `E:\Projects\FPGA\.tools\td\app\license\Anlogic.lic` 特征 | 仿真器变量均未设置；仅有 Anlogic TD 许可文件，不含 Questa/ModelSim/Intel Starter 标记 |
| PH1 模型 | `E:\Projects\FPGA\.tools\td\app\sim_release\ph1p` | 82 个 HDL 源文件（78 `.v`、4 `.sv`）；未找到 `.lib/.qdb/.qpg/.qll/.dll` 或 `modelsim.ini` 预编译库 |
| 工程流程引用 | `rg -n -i 'modelsim|questa|vsim|vlog|vlib|simulation library compiler|iverilog|Icarus' docs/development/toolchain.md docs/development/agent-workflow.md docs/verification/acceptance-matrix.md scripts work/fpga_loop work/integration` | 当前流程引用 Icarus；`work/integration/test.ps1` 调用 `iverilog.exe` 和 `vvp.exe`，未发现 ModelSim/Questa 为项目脚本前置 |

前一轮对 C: 的全盘 `vsim.exe` 搜索也无结果。D: 的常见安装目录无结果；`D:\Dev` 有访问受限子目录，故不将该目录表述为全盘穷尽。

## 厂商要求与证据

- 安路官方 [FAQ](https://tech.anlogic.com/Cn/Index/index/cate/32/tp/1/p/2.html) 说明 TD 不内置仿真器；TD 安装目录含器件行为模型，可用 ModelSim 编译成器件库后调用。
- 本地安路《TangDynasty 工程仿真指南 TD6.0 V1.0》（`E:\Projects\FPGA\.tools\td\app\doc\SWUG\SWUG107_Design_Simulation_User_Guide.pdf`）第 5–6 页列出 PH1 支持 ModelSim 2020、Questa Advanced Simulation 2020；第 7、9–11 页说明 Simulation Libraries Compiler、Questasim 选择及 PH1 库编译。此版本表不等于对其他 Questa 版本或 Starter 版的实测兼容结论。
- Siemens 官方 [Software Center](https://www.siemens.com/en-us/support/siemens-software-center/) 提供 Siemens 软件的下载、安装与激活；需要 Siemens Account。此机器没有本地安装包或可验证的 Questa 许可。

## 阻塞与下一步

若需要 PH1 的 TD 联合仿真，请由许可持有人通过 Siemens 官方渠道取得适用于本机的 Windows 安装介质及有效许可，并由用户本人审阅/接受适用条款。之后提供安装包路径和许可文件路径；无需提供账户密码。若安装或许可证组件要求管理员提升权限，应停在该提示并由用户处理。

在上述条件满足前，不安装、不改 PATH/许可配置，也不尝试编译 PH1 仿真库。当前 Icarus/TD 工作流可继续使用，无需等待 Questa。
