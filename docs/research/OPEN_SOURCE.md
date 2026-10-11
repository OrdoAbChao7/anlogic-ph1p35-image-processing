# OPEN_SOURCE — 开源算法与 RTL 参考索引

> **使用规则**  
> - 适配等级 A：算法或验证代码可参考，接口须适配 PH1P35。  
> - 适配等级 B：模块结构可参考，需改接口和时序。  
> - 适配等级 C：仅供协议/架构学习。  
> - D：弱相关。  
> 无许可证或许可证不明的仓库：仅用于研究思想，**禁止直接复制代码**。  
> 所有候选须在 `docs/research/sources.yaml` 中有对应条目，并标注精确 commit / tag。

---

## 1. 已评估候选（旧有）

这些条目已在 `sources.yaml` 中登记，信息来源为 2026-09-21 批量研究。

| 仓库 | 适配等级 | 相关阶段 | License | 主要用途 |
|---|---|---|---|---|
| [georgeyhere/fpga-video-processing](https://github.com/georgeyhere/fpga-video-processing) | B | G3、G4 | 待确认 | Line Buffer、FIFO、Sobel、HDMI 教学型工程 |
| [Galapple/Image-processing---Verilog](https://github.com/Galapple/Image-processing---Verilog) | B | G4 | 待确认 | 4 行缓存、3×3 窗口、Sobel |
| [olivier-le-sage/camera-filters](https://github.com/olivier-le-sage/camera-filters) | B | G3 | 待确认 | 定点颜色处理（VHDL） |
| [hdl-util/hdmi](https://github.com/hdl-util/hdmi) | C | G1、G6 | MIT | HDMI/DVI 时序参考 |
| [cliffordwolf/SimpleVOut](https://github.com/cliffordwolf/SimpleVOut) | C | G1、G6 | ISC | 视频输出 + Overlay 结构参考 |
| [FHDO-ICLAB/MIPI-CSI-2-HDMI-Bridge](https://github.com/FHDO-ICLAB/MIPI-CSI-2-HDMI-Bridge) | C | G1 | 待确认 | MIPI 链路架构学习 |
| [circuitvalley/mipi_csi_receiver_FPGA](https://github.com/circuitvalley/mipi_csi_receiver_FPGA) | C | G1 | MIT | MIPI 协议参考（Legacy） |
| [gatecat/CSI2Rx](https://github.com/gatecat/CSI2Rx) | C | G1 | 待确认 | CSI-2 协议参考（VHDL） |
| [hdl-util/mipi-demo](https://github.com/hdl-util/mipi-demo) | C | G1 | 待确认 | MIPI CCS 示例 |

---

## 2. 新增候选评估（2026-10-11 详细研究）

评估时间：2026-10-11；研究方法：访问仓库主页、README、LICENSE、代码结构。

### [amd/mini-isp](https://github.com/amd/mini-isp)

| 项目 | 值 |
|---|---|
| Stars | 数十至百量级 |
| 最近 commit | 2025–2026 活跃 (`inferred`) |
| License | **MIT** ✅ |
| 主要语言 | SystemVerilog 54% / Python 40% |
| 相关 Goal | G2、G3、G4 |
| 适配等级 | B（架构参考） |

**核心模块**：decompanding、BLC、digital_color_gain、Malvar-He-Cutler 拜耳解码、CCM、Gamma LUT + Python 仿真框架。  
**仿真环境**：完善 ✅ Makefile 驱动 Verilator + Python 双轨比对。  
**许可证风险**：低 — MIT，无 Copyleft。  
**PH1P35 适配**：不可直接移植（SystemVerilog + AMD UltraScale+ 原语 + XDC 约束）。ISP 算法（拜耳解码、CCM、Gamma）为纯数学逻辑，可用 Verilog 重写。Python 仿真框架完全可复用。  
**建议用途**：① 参考 Malvar-He-Cutler 拜耳算法原理（G2 ISP 基线）；② 仿照 Python ↔ Verilator 双轨验证框架方法论；③ 禁止直接导入 SystemVerilog 或 XDC。

---

### [georgeyhere/FPGA-Video-Processing](https://github.com/georgeyhere/FPGA-Video-Processing)

| 项目 | 值 |
|---|---|
| Stars | 数十 |
| 最近 commit | 约 2019–2020（已停止维护） |
| License | **MIT** ✅ |
| 主要语言 | Verilog |
| 相关 Goal | G3、G4、G6 |
| 适配等级 | B（架构参考） |

**核心模块**：OV7670 接口、异步 FIFO、RGB→灰度、BRAM Line Buffer（3 行）、3×3 窗口、Gaussian + Sobel、BRAM 帧缓存、HDMI 输出。  
**仿真环境**：无独立 testbench（教学型）。  
**PH1P35 适配**：Line Buffer + 3×3 + Sobel 算法逻辑可参考，结构平台无关；摄像头（DVP）和帧缓存（BRAM，640×480）不可用于本项目。Xilinx 原语须替换为安路原语。  
**建议用途**：① Line Buffer + 3×3 窗口架构（G4 核心依据）；② Sobel 梯度位宽/饱和/阈值设计参考；③ 摄像头/帧缓存部分不参考。

---

### [maojinxiang/FPGA-ANLU-National-First-Prize](https://github.com/maojinxiang/FPGA-ANLU-National-First-Prize)

| 项目 | 值 |
|---|---|
| Stars | ~15 以下 |
| 最近 commit | 2025 年（竞赛提交） |
| License | **❌ 无 License** |
| 主要语言 | Verilog |
| 相关 Goal | G1、G3、G4、G6 |
| 适配等级 | B/C（**严禁代码复制**） |

**核心模块**：多图像处理模式（原图/灰度/二值化/Sobel/浮雕/热力图/腐蚀/膨胀/形态学等）、Line Buffer 邻域窗口、以太网/HDMI/SDRAM 分离工程。  
**仿真环境**：无独立 testbench。  
**许可证风险**：**高 ⚠️ — 无 License 文件，默认版权归作者，禁止复制代码。**  
**PH1P35 适配**：同安路赛题最贴近参考，但摄像头为 OV5640（DVP，非 MIPI），帧缓存为 SDRAM（非 DDR2），无 YOLO。  
**建议用途**：① 仅阅读不复制；② 多图像处理模式系统分层和切换逻辑参考；③ 形态学算法思路参考。

---

### [Xilinx/finn](https://github.com/Xilinx/finn)

| 项目 | 值 |
|---|---|
| Stars | ~1,100 |
| 最近 commit | 2025–2026 持续活跃 |
| License | **BSD-3-Clause** ✅ |
| 主要语言 | Python / C++ / Vitis HLS / Verilog |
| 相关 Goal | G5、G7 |
| 适配等级 | C（思想借鉴） |

**核心价值**：Streaming Dataflow 架构（逐层流式串联）；INT8/QAT via Brevitas 量化；BN Folding（折叠 BatchNorm 进卷积权重，消除硬件除法器）；逐层 BRAM 缓存特征图。  
**仿真环境**：有（Jupyter + Python），但依赖 Vitis HLS + Vivado，不可在安路环境运行。  
**PH1P35 适配**：完整框架不可在安路 TD 运行。量化方法论（Brevitas QAT + BN Folding）和 Streaming Dataflow 架构思想对 G5 极有价值。  
**建议用途**：① 研读数据流推理架构设计；② 使用 Brevitas 做量化感知训练获取权重；③ 禁止用 finn 生成 IP 导入安路工程。

---

### [dog-qiuqiu/Yolo-FastestV2](https://github.com/dog-qiuqiu/Yolo-FastestV2)

| 项目 | 值 |
|---|---|
| Stars | ~941 |
| 最近 commit | 约 2022–2023 |
| License | **MIT（待直接确认）** ⚠️ |
| 主要语言 | Python |
| 相关 Goal | G5、G7 |
| 适配等级 | C（思想借鉴） |

**核心模块**：ShuffleNetV2 Backbone、LightFPN、解耦检测头（Obj/Cls/Reg）、YOLOv5 风格锚框匹配、PyTorch 训练脚本、ONNX 导出。  
**PH1P35 适配**：无 FPGA/RTL 代码，纯 PyTorch。ShuffleNetV2 的 Depthwise Convolution + Channel Shuffle 在纯 RTL FPGA 中效率低。**注意：本项目目标是 YOLO-tiny（不同架构）**，不可直接替代，但轻量化思路（250k 参数、解耦头、轻量 FPN）是裁剪参考。  
**建议用途**：① 轻量 YOLO 设计思路参考；② Python 推理改造为 Golden Model；③ PyTorch→ONNX→权重提取工具链参考。

---

## 3. 开源优先工作流（每次实现前执行）

1. 明确当前模块需求、接口（位宽、速率、时钟域）和硬件约束（BRAM/DSP 预算）。
2. 查询本文件及 `sources.yaml`，确认是否有已评估候选。
3. 若无，按需在 GitHub 检索 3–5 个候选，更新本文件。
4. 高 Star 不能代替接口适配、许可证和验证。
5. 选定候选后，先运行候选仓库原有测试或软件参考。
6. 评估 PH1P35 接口差异：原语替换、位宽、时钟、复位、握手。
7. 将候选及精确 commit hash 写入 `sources.yaml`。
8. 记录：算法思想借鉴 / 架构参考 / 许可证允许复用代码（三选一）。
9. 再开始移植或新写 RTL。

---

## 4. 许可证状态汇总（2026-10-11 更新）

| 仓库 | License | 可复用代码 | 来源 |
|---|---|---|---|
| `amd/mini-isp` | **MIT** ✅ | 是（属性标注后，须重写为 Verilog） | `reference` |
| `georgeyhere/FPGA-Video-Processing` | **MIT** ✅ | 是（平台无关算法逻辑部分） | `reference` |
| `Xilinx/finn` | **BSD-3-Clause** ✅ | 是（软件代码，非 RTL 直接使用） | `reference` |
| `Yolo-FastestV2` | **MIT（待直接确认）** ⚠️ | 待确认后决定 | `reference` |
| `maojinxiang/FPGA-ANLU-National-First-Prize` | **❌ 无 License** | **禁止复制代码** | `reference` |
| `hdl-util/hdmi` | MIT | 是 | `reference` |
| `cliffordwolf/SimpleVOut` | ISC | 是 | `reference` |
| `Galapple/Image-processing---Verilog` | **待确认** | 仅思想借鉴 | `reference` |
| 其余旧有条目 | 待确认 | 默认仅思想借鉴 | `reference` |

> [!CAUTION]
> `maojinxiang/FPGA-ANLU-National-First-Prize` 无 License，禁止复制任何代码，仅供阅读参考架构思路。  
> 许可证未确认前，所有代码仅用于研究思想，禁止直接复制粘贴进入比赛工程。
