# 软件先行（Software-First）算法研发与验证规范

> Stage A–G是单个算法生命周期，不是主系统G1–G8。状态摘要见[STATUS](../project/STATUS.md)，系统前置见[PHASES](../project/PHASES.md)，可运行命令和现有脚本门禁局限见[工具链](toolchain.md)。历史登记的批准只覆盖绑定版本，不覆盖后续新效果。

> **执行原则**：本项目所有涉及图像处理、目标检测、神经网络推理、视觉增强、OSD 等具有可观察输出的算法，在进入 FPGA RTL 开发之前，**原则上都必须先在 PC 软件端提供可交互、可运行的视觉效果预览，并获得用户明确验收确认（VISUAL_APPROVED）**。  
> 未获确认前，严禁直接推进正式 RTL 综合或位流构建！

---

## 一、七阶段研发流程（Stage A – Stage G）

```text
[Stage A: 开源检索与基线评估]
       │
       ▼
[Stage B: 软件算法实现 (Python/OpenCV/NumPy/PyTorch)]
       │
       ▼
[Stage C: 视觉效果验收 (Algorithm Lab Web UI 交互 / 用户批准)] ── 否决 ──> 返回调整
       │  (必须获得 VISUAL_APPROVED)
       ▼
[Stage D: 硬件等价软件模型 (定点数、量化、LineBuffer边界、误差评估)]
       │
       ▼
[Stage E: RTL 实现与仿真 (Verilog/SV, TB, Icarus/Verilator, 零误差/容差比对)]
       │
       ▼
[Stage F: TangDynasty 构建 (综合、布局布线、时序收敛 WNS≥0)]
       │
       ▼
[Stage G: 真实硬件验收 (下载位流、摄像头/HDMI 实测、记录证据至 STATUS.md)]
```

### Stage A：开源检索与基线评估 (ALGORITHM_RESEARCH)
1. **开源搜寻**：搜索学术界与工业界成熟、高质量的开源算法或开源硬件工程（GitHub、Papers With Code 等）。
2. **三要素评估**：
   - 可复现性与测试覆盖率；
   - 许可证明确性（MIT/Apache/BSD 优先，GPL/无 License 仅供学习，禁止直接搬运代码）；
   - FPGA 移植复杂度与硬件开销估算（乘加器、BRAM 行缓存、时钟延迟）。
3. **输出要求**：记录开源参考来源至 `docs/research/OPEN_SOURCE.md` 与 `docs/research/sources.yaml`，确定视觉参考 baseline。

### Stage B：软件算法实现 (SOFTWARE_IMPLEMENTED)
1. **高层工具实现**：采用 Python、OpenCV、NumPy 或 PyTorch，快速实现高精度或标准版算法模型。
2. **输入输出保留**：支持单图、测试集图片及视频流；保留原始测试向量与参数配置。
3. **视觉参考 (Visual Reference)**：此版本代表该算法在 PC 上的理论最优或高质量效果基准，不拘泥于硬件位宽限制。

### Stage C：视觉效果验收 (VISUAL_REVIEW_PENDING → VISUAL_APPROVED)
1. **统一接入 Algorithm Lab**：将算法及其参数封装接入本地 `Algorithm Lab` 平台，严禁制作一次性、不兼容的独立脚本。
2. **直观多图对比**：在 Web UI 中提供原图、处理图、参数滑块、多候选方案并排对比。
3. **用户审查与批准门（强制门禁）**：
   - 必须由用户亲自观察并确认算法视觉效果；
   - 用户给出满意反馈后，方可由 Agent 在算法登记册中将状态置为 `VISUAL_APPROVED`；
   - **禁止**任何 Agent 自行标记 `VISUAL_APPROVED`；
   - 一旦批准，立即绑定并锁定代码 Commit、参数 JSON 与测试样本哈希。

### Stage D：硬件等价软件模型 (HARDWARE_MODEL_VERIFIED)
1. **硬件可行性转换**：
   - 定点化：浮点转整数（如 8-bit / 16-bit 定点乘加）；
   - 饱和截断：明确溢出饱和（`np.clip(..., 0, 255)`）与移位舍入；
   - 边界对齐：严格模拟硬件 Line Buffer 产生的边界填充（BORDER_REPLICATE 或 边框黑边）与流水线时钟停顿；
   - 吞吐契约：确保算法可在逐像素流式（Streaming Pixel）下工作，无需昂贵的大帧缓存（DDR 往返）。
2. **硬件等价预览 (Hardware-equivalent Preview)**：在 Algorithm Lab 中展示定点硬件等价效果。
3. **量化比对**：计算硬件等价模型与 Stage B 视觉参考模型的差异（PSNR/SSIM/MAE/像素差异图）。若出现不可接受的画质恶化（如严重色彩失真、噪点爆发），须在软件端重新调整量化与滤波方案。

### Stage E：RTL 实现与仿真 (RTL_SIM_PASS)
1. **硬件实现**：编写纯 Verilog 应用 RTL（保留既有厂商 SystemVerilog/加密 IP；测试平台方言按工具支持选择），遵循 `AGENTS.md` 编码规范。
2. **参考架构**：参考经过许可评估的开源流式结构（如通用 3×3 行缓存矩阵）。
3. **自动化 Testbench**：
   - 编写 Icarus Verilog (`iverilog` + `vvp`) 或 Verilator 仿真脚本；
   - 灌入真实测试图刺激向量；
   - 将 RTL 输出像素与 Stage D 的 Hardware Golden Model 逐像素比对；
   - 达成零误差或数学严格证明的容差后，方可标记 `RTL_SIM_PASS`。
   - **禁止**以“直接生成位流上板看有没有画面”作为首次功能验证手段。

### Stage F：TangDynasty 构建 (TD_BUILD_PASS)
1. **构建触发条件**：只有在 Stage C 获批、Stage D 硬件模型验证、Stage E 仿真全部 PASS 后，才允许触发 TD 综合。
2. **时序与报告**：检查综合/实现日志，确保无关键 Clock/CDC 告警，Setup/Hold WNS ≥ 0。
3. **产物归档**：记录生成 bitstream 的 SHA-256 哈希及资源消耗表。

### Stage G：真实硬件验收 (HARDWARE_VERIFIED)
1. **下载与测试**：用户或测试人员将 bitstream 下载至安路 PH1P35 开发板。
2. **实机闭环**：观察 SC520CS 摄像头输入并在 HDMI 显示器上的实际显示质量、帧率稳定性及外设联动行为。
3. **状态与证据**：将实测现象、照片/视频索引及位流哈希同步更新至 `docs/project/STATUS.md`。若实测视觉效果不佳，回退至 Stage B/C 重新调优。

---

## 二、算法全生命周期状态机

每个算法均具有独立的状态追踪标签：

| 状态标签 | 阶段 | 含义与判定依据 |
|---|---|---|
| `ALGORITHM_RESEARCH` | Stage A | 已确定开源参考源与方案调研，待软件实现 |
| `SOFTWARE_IMPLEMENTED`| Stage B | Python 高层算法已跑通，输出基准图片/视频 |
| `VISUAL_REVIEW_PENDING`| Stage C | 已接入 Algorithm Lab，等待用户审查视觉效果 |
| `VISUAL_APPROVED` | Stage C | **用户明确确认效果满意**，参数及样本哈希已冻结 |
| `HARDWARE_MODEL_VERIFIED` | Stage D | 定点数/LineBuffer 硬件等价模型完成并量化验证 |
| `RTL_SIM_PASS` | Stage E | 编写 RTL 并与硬件模型仿真比对一致 |
| `TD_BUILD_PASS` | Stage F | 成功完成 TD 综合实现，时序收敛，生成位流 |
| `HARDWARE_VERIFIED` | Stage G | 真实开发板 + 摄像头 + HDMI 连路实测通过 |
| `REJECTED` | — | 用户否决或硬件资源评估超标，废弃或待重构 |

> **强制门禁规则**：
> 1. `VISUAL_APPROVED` 仅能由用户授权，禁止 Agent 自动标记。
> 2. `HARDWARE_MODEL_VERIFIED` 是编写复杂 RTL 的前置条件。
> 3. 不具有视觉输出的底层硬件模块（如 I2C 控制器、FIFO、时钟分频）可采用标准波形与寄存器断言测试，无需强制视觉预览。

---

## 三、统一算法预览平台（Algorithm Lab）规范

为了防止每个算法自制互不兼容的孤岛脚本，项目统一建立并维护 `Algorithm Lab`：

1. **部署位置**：`work/algorithm_lab/`
2. **技术栈**：基于 Python 原生轻量高性能技术栈（FastAPI + 原生现代化前端 UI，或 Streamlit/Gradio 无缝扩展）。
3. **功能契约**：
   - **多格式输入**：支持拖拽上传本地图像（JPG/PNG/BMP/PGM）及视频（MP4/AVI），提供内置基准测试图快速加载；
   - **插件式算法架构**：所有算法模块必须实现统一 Python 抽象基类 `BaseAlgorithm`；
   - **三轨视觉对比**：
     - `Original`：原始输入；
     - `Visual Reference`（高精度软件基准）；
     - `Hardware-equivalent`（定点/流式硬件等价效果）；
     - `Diff Map`（定点化前后绝对误差热力图）；
   - **动态调参**：参数滑块调节，即时重新运算并刷新对比；
   - **一键导出实验**：支持导出当前处理图片、参数配置 JSON、以及包含测试图哈希的实验报告；
   - **候选横向比较（Tuning Collage）**：支持批量生成多参数对比画廊（例如 8/16/32 色阶对比、不同 Sobel 阈值对比）；
   - **一键启动**：提供 Windows 批处理启动脚本 `run_lab.bat`，开箱即用。

---

## 四、算法档案与参数冻结制度

所有算法的档案集中在 `work/algorithm_lab/registry.json`（并在项目文档保留镜像），包含字段：
```json
{
  "algorithm_id": "cartoon_v2",
  "display_name": "Luminance-Preserving Cartoonization",
  "category": "stylization",
  "source_reference": "amd/mini-isp & work/models/cartoon_luma_reference.py",
  "license": "MIT",
  "status": "VISUAL_APPROVED",
  "user_approved_version": "v1.1",
  "frozen_params": {
    "threshold": 240,
    "quant_bits": 3,
    "smooth_passes": 1
  },
  "sample_image_hash": "a1b2c3d4...",
  "software_model_path": "work/models/cartoon_luma_reference.py",
  "hardware_model_path": "work/algorithm_lab/plugins/cartoon.py",
  "rtl_source_path": "work/rtl/video_cartoon_luma.v",
  "testbench_path": "work/tests/tb_video_cartoon.v"
}
```

任何进入 RTL 开发的算法，其参数必须严格等于已批准版本中的 `frozen_params`。若需调整算法参数，必须回到 Algorithm Lab 重新预览并获得用户批准。
