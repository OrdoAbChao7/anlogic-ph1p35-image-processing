# PH1P35 工业视觉 V2 G0/G1 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (recommended) or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不改变 fixed-red v1 冻结候选的前提下，完成 V2 基线保护、环境核查、交互/OSD/ROI 合同修复，并留下可复现的第一阶段证据。

**Architecture:** 从 `fallback/industrial-inspection@256d99c` 派生的 `goal/industrial-v2-advanced` Worktree 中工作。V2-G0 只建立证据、回归和回退点；V2-G1 保持 MIPI/CSI/DDR/HDMI 厂商边界不变，只修改模式控制、OSD 表达和固定 ROI 合同，所有结果在帧边界提交。

**Tech Stack:** Verilog、Icarus Verilog、Python 3、PowerShell、TangDynasty 6.2.168116（若本机入口可定位）、PH1P35MDG324、现有 `fallback/` RTL/仿真和 `scripts/verify-industrial-subsystem.ps1`。

**Spec:** `docs/superpowers/specs/2026-10-19-industrial-v2-advanced-design.md`

## Global Constraints

- 不修改 `AGENTS.md`、`docs/project/PROJECT_GOAL.md`、`docs/project/PHASES.md` 和 `docs/verification/acceptance-matrix.md` 的目标或验收标准。
- V1 冻结位流 `b483a1ffc30d0b7ae9e8ebef4f31f617d33a53d6784ded8007d5443c51ad80ef` 只读保存，不覆盖 `release/candidates/industrial-v1-hx1p35a-pin-correction/`。
- 不恢复 YOLO/Micro-CNN、WM8978 或未经确认的外部执行器管脚；V2 先在现有 fixed-red 视频边界上工作。
- 每个视觉算法按软件参考模型、硬件等价模型、RTL 仿真、TD 构建、真实硬件的顺序推进；用户已授权需要视觉审查的环节默认 `VISUAL_APPROVED`，但不得代替其他证据。
- 新增功能不得让主视频吞吐、同步、CDC、资源或时序失去可解释证据；Setup/Hold WNS 必须 `>=0`，TNS 必须 `0`，Slice 超过 `90%` 暂停正式整机合并。
- 当前 V2 Worktree 为 `E:/Projects/FPGA-v2`，分支为 `goal/industrial-v2-advanced`；不清理原工作区已有改动。

## Review Focus

- 基线来源混淆：V2 必须从 `256d99c` 的冻结提交开始，不能从两个已有脏工作区复制文件；由 Task 1 的提交/哈希检查固定。
- 模式输入语义改变造成重复触发或帧中切换：Task 2 的 RTL TB 必须覆盖短按、抖动、长按、同帧请求和帧边界提交。
- OSD 十进制转换引入像素路径除法或错拍：Task 3 必须覆盖 0、9、10、99、100、999 和帧/同步延迟，优先使用帧结果域预计算。
- ROI 合法性和边界复制不一致：Task 4 必须覆盖全帧、子窗口四边、半目标、ROI 外干扰和非法 ROI，并与现有 `BORDER_REPLICATE` 语义一致。
- 构建通过但告警、资源或硬件状态被过度表述：Task 5 必须保存命令、退出码、报告路径和 `NOT_RUN/BLOCKED` 状态，不把历史数值当作 V2 结果。

### Task 1: 建立 V2 Goal 状态、基线清单和回退制度

**Files:**
- Create: `docs/goals/industrial-v2/GOAL.md`
- Create: `docs/goals/industrial-v2/ROADMAP.md`
- Create: `docs/goals/industrial-v2/STATUS.json`
- Create: `docs/goals/industrial-v2/TASKS.md`
- Create: `docs/goals/industrial-v2/DECISIONS.md`
- Create: `docs/goals/industrial-v2/RESOURCE_BUDGET.md`
- Create: `docs/goals/industrial-v2/RISK_REGISTER.md`
- Create: `docs/goals/industrial-v2/BLOCKERS.md`
- Create: `docs/goals/industrial-v2/EVIDENCE_INDEX.md`
- Create: `docs/goals/industrial-v2/HARDWARE_TEST_PLAN.md`
- Create: `docs/goals/industrial-v2/ROLLBACK.md`
- Create: `docs/experiments/2026-10-19-industrial-v2-g0-baseline.md`

**Interfaces:**
- Consumes: V2 design、V1 freeze report、当前 Git/Worktree 状态、项目入口文档。
- Produces: 机器可读阶段状态、V1 哈希/资源/时序基线、V2 阶段依赖、风险、阻塞和回退路径。

- [ ] **Step 1: 写入 V2 Goal 入口和状态 schema**

  `STATUS.json` 使用 `ACTIVE` 总状态和 `NOT_STARTED/ACTIVE/SOFTWARE_PASS/RTL_PASS/TD_PASS/HARDWARE_PASS/BLOCKED/FAILED/RELEASED` 阶段状态；每阶段包含 `status`、`objective`、`prerequisites`、`completion`、`commands`、`evidence`、`unresolved`、`resource_baseline`、`best_candidate` 和 `next_action` 字段。

- [ ] **Step 2: 固化 V1 基线和三层回退候选**

  记录 V1 commit、冻结 `.bit` 路径、SHA-256、`17,642/21,216` Slice、RAM `43`、DSP `24`、Setup/Hold `+103/+20 ps` 和 TNS `0`，明确 `BASELINE_V1`、`LAST_GOOD_V2`、`EXPERIMENTAL` 不得互相覆盖。

- [ ] **Step 3: 写入 G0 实验记录和阻塞项**

  将原工作区脏状态、V2 Worktree 干净状态、TD/iverilog/Python/硬件枚举结果分别标为 `project` 或 `unknown`；缺少设备、测量仪器和外部执行器时写入 `BLOCKED_ON_HARDWARE`，不降低阶段门。

- [ ] **Step 4: 做文档自审**

  检查路径、状态枚举、哈希、资源单位和 V1/V2 目标没有混用；运行 JSON 解析和链接目标存在性检查。

- [ ] **Step 5: Commit**

  `git add docs/goals/industrial-v2 docs/experiments/2026-10-19-industrial-v2-g0-baseline.md docs/superpowers/specs/2026-10-19-industrial-v2-advanced-design.md docs/superpowers/plans/2026-10-19-industrial-v2-g0-g1.md`，提交 `docs(v2): establish industrial v2 goal baseline`。

### Task 2: 执行 G0 软件/RTL 回归和工具入口核查

**Files:**
- Modify: `docs/goals/industrial-v2/STATUS.json`
- Modify: `docs/goals/industrial-v2/EVIDENCE_INDEX.md`
- Modify: `docs/experiments/2026-10-19-industrial-v2-g0-baseline.md`
- Create: `docs/evidence/industrial-v2-g0/` 下的命令输出、哈希和报告索引（仅保存可复用证据）

**Interfaces:**
- Consumes: Task 1 状态文件、V1 freeze report、`scripts/verify-industrial-subsystem.ps1`、`scripts/build_industrial_td.py`。
- Produces: V2 基线的真实回归结果、工具可用性、TD 构建入口和首个阻塞根因。

- [ ] **Step 1: 核对工具版本和安全入口**

  运行 `python --version`、`python scripts/build_industrial_td.py --help`、Icarus/VVP 版本检查；若 `scripts/fpga-loop.ps1` 在冻结基线不存在，记录缺口，不从另一个脏 Worktree 静默复制第二套平台。

- [ ] **Step 2: 运行既有 Python 回归**

  运行 `python -B -m pytest -q work/tests`；保存退出码、测试数量和首个失败。测试生成物只能写入隔离输出目录，完成后清理临时缓存。

- [ ] **Step 3: 运行工业 RTL/Golden 回归**

  运行 `pwsh -File .\\scripts\\verify-industrial-subsystem.ps1`；保存 13 段或实际脚本版本对应的全部阶段输出，不用固定字符串代替断言。

- [ ] **Step 4: 做 V1 位流和报告审计**

  对冻结 `.bit` 重新计算 SHA-256，读取 `route.qor`、`final_timing.rpt` 和告警台账；只把 V1 历史结果写入 baseline，不把它写成 V2 构建结果。

- [ ] **Step 5: 判断 G0 门**

  软件/RTL 结果按实际 PASS/FAIL 记录；TD 或硬件缺失则阶段为 `BLOCKED` 或 `ACTIVE`，下一步只选择不依赖缺失条件的工作。

### Task 3: 把模式控制改为单击循环和帧边界提交

**Files:**
- Modify: `fallback/rtl/control/mode_controller.v`
- Modify: `fallback/sim/control/tb_mode_controller.v`
- Modify: `fallback/tb_mode_controller.v`（若正式回归仍使用该入口）
- Modify: 当前顶层实例化 `mode_controller` 的连接文件（由静态搜索确定，保持端口边界可追溯）
- Create: `docs/experiments/2026-10-19-industrial-v2-g1-mode-controller.md`

**Interfaces:**
- Consumes: 现有 `I_clk/I_rst_n/I_key_edge_n/I_key_cartoon_n/I_frame_start` 接口、三态模式编码和现有顶层请求信号。
- Produces: 去抖后的单击事件、`ORIGINAL → SOBEL → CARTOON → ORIGINAL` 的 `O_mode`，只在 `I_frame_start` 更新；保留现有顶层兼容信号或在同一提交中完成全量连接迁移。

- [ ] **Step 1: 扩展失败测试**

  在 `tb_mode_controller.v` 增加短按边沿、长按保持、抖动、同一帧双键优先级、请求后到帧边界才更新、复位恢复 Original 的断言；旧的“按住直接选择”预期必须先显示为失败。

- [ ] **Step 2: 运行测试确认失败**

  运行 `iverilog -g2012 -Wall -s tb_mode_controller -o work/tests/verification_outputs/v2_mode_controller.vvp fallback/sim/control/tb_mode_controller.v fallback/rtl/control/mode_controller.v` 和 `vvp ...`；预期新增单击循环断言失败。

- [ ] **Step 3: 实现最小状态变化**

  在现有同步/去抖结构上增加一次性 press event 和 `pending_mode` 循环状态；不在按键时钟域直接改变可见模式，不改变三态编码和视频吞吐。

- [ ] **Step 4: 运行测试确认通过**

  重跑同一 Icarus 命令，并由 `scripts/verify-industrial-subsystem.ps1` 的模式阶段回归；预期新增断言和既有模式回归均 PASS。

- [ ] **Step 5: Commit**

  `git add fallback/rtl/control/mode_controller.v fallback/sim/control/tb_mode_controller.v fallback/tb_mode_controller.v docs/experiments/2026-10-19-industrial-v2-g1-mode-controller.md`，提交 `feat(v2): make mode selection single-click and frame-bound`。

### Task 4: 修复 OSD 数值表达和帧稳定快照

**Files:**
- Modify: `fallback/rtl/display/industrial_osd_overlay.v`
- Modify: `fallback/sim/display/tb_osd_led_joint.v`
- Modify: 顶层 OSD 结果快照连接文件（由静态搜索确定）
- Create: `docs/experiments/2026-10-19-industrial-v2-g1-osd.md`

**Interfaces:**
- Consumes: 现有 HDMI `I_vsync/I_hsync/I_de/I_rgb`、模式、检测状态、宽高和帧结果总线。
- Produces: 十进制宽高/帧号文本、`PASS/NG/NO_OBJECT/INVALID` 状态、空场隐藏旧框、与当前帧原子结果一致的 OSD 输出；不在像素关键路径做不可控除法。

- [ ] **Step 1: 扩展边界测试**

  覆盖宽高和帧计数的 `0/9/10/99/100/999`、状态互斥、空场清框、帧边界快照和 RGB/DE/HS/VS 固定延迟；保存期望字符坐标。

- [ ] **Step 2: 运行旧实现测试**

  运行 OSD/Logo/LED Icarus TB；预期十六进制或缺失尾部断言失败时保留首个 mismatch。

- [ ] **Step 3: 实现帧结果域十进制转换**

  使用可综合的固定宽度十进制编码/预计算寄存器，在帧结果提交时更新；同步保留 OSD 像素和控制信号延迟，不修改 Logo ROM 和 HDMI 物理边界。

- [ ] **Step 4: 运行最小和完整回归**

  重跑 OSD TB、`python -B -m pytest -q work/tests` 和工业回归；结果不满足时记录资源/时序风险，不以截图替代仿真。

### Task 5: 固定 ROI 合同并完成 G1 静态/软件/RTL 验证

**Files:**
- Modify: `fallback/td_source/isp/isp_top.v`
- Modify: `fallback/rtl/inspection/color_detect_96_v2.v` 或现有 ROI/形态学模块（仅在合同回归证明必要时）
- Modify: `fallback/sim/inspection/tb_color_detect_96_v2.v`
- Modify: `fallback/sim/inspection/tb_industrial_contract.v`
- Create: `work/models/v2/roi_contract.py`
- Create: `work/tests/test_v2_roi_contract.py`
- Create: `docs/experiments/2026-10-19-industrial-v2-g1-roi.md`

**Interfaces:**
- Consumes: V1 RGB/检测器流接口、冻结 `BORDER_REPLICATE` 和 `PASS/NG/NO_OBJECT/INVALID` 语义。
- Produces: 明确的 `ROI_X0/ROI_Y0/ROI_X1/ROI_Y1` 参数、全帧/子窗口/非法 ROI 行为、ROI 外屏蔽和与 OSD 坐标一致的结果。

- [ ] **Step 1: 写软件 ROI 合同测试**

  测试全帧 ROI、四边贴合、半目标、ROI 外红色干扰、空场和非法 ROI；明确边界复制和输出坐标公式。

- [ ] **Step 2: 运行测试确认缺口**

  运行 `python -B -m pytest -q work/tests/test_v2_roi_contract.py`，先记录基线失败或缺少模块，不降低断言。

- [ ] **Step 3: 只在检测顶层接入命名 ROI 常量**

  保持 V1 的默认全帧行为不变，新增参数只通过顶层显式传入；检测结果在帧尾锁存，ROI 非法时输出 `INVALID` 并禁止下游事件。

- [ ] **Step 4: 运行软件、RTL 和边界回归**

  运行 ROI Python 测试、`tb_color_detect_96_v2`、工业合同矩阵和完整工业脚本；预期面积、BBox、状态和边界复制与软件模型一致。

### Task 6: 记录 G1 阶段门和可回退候选

**Files:**
- Modify: `docs/goals/industrial-v2/STATUS.json`
- Modify: `docs/goals/industrial-v2/TASKS.md`
- Modify: `docs/goals/industrial-v2/EVIDENCE_INDEX.md`
- Modify: `docs/goals/industrial-v2/RESOURCE_BUDGET.md`
- Modify: `docs/goals/industrial-v2/RISK_REGISTER.md`
- Create: `docs/experiments/2026-10-19-industrial-v2-g1-summary.md`

**Interfaces:**
- Consumes: Task 2–5 的命令、测试、源码哈希和报告。
- Produces: G1 的 `SOFTWARE_PASS/RTL_PASS/TD_PASS/BLOCKED` 分层判定、资源差异、未关闭硬件条件和 `LAST_GOOD_V2` 指针。

- [ ] **Step 1: 运行受影响回归**

  修复后先重跑单模块测试，再重跑 `python -B -m pytest -q work/tests` 和工业回归；TD 只有在前序 RTL 全部通过且 TD 工具可定位时执行隔离构建。

- [ ] **Step 2: 解析 QoR 与告警**

  记录真实 V2 候选的 Slice/RAM/DSP、Setup/Hold WNS/TNS、STA coverage 和新增告警；V1 数值只作对照。

- [ ] **Step 3: 写阶段门结论**

  无板卡时 G1 只能是 `BLOCKED` 或分层 `RTL_PASS/TD_PASS`，不得写 `HARDWARE_PASS`；若测试失败，保留首个根因和回退到 V1 的命令。

- [ ] **Step 4: Commit**

  `git add docs/goals/industrial-v2 docs/experiments/2026-10-19-industrial-v2-g1-summary.md`，提交 `docs(v2): record g0-g1 evidence and gates`。

## 后续子计划入口

G0/G1 通过或明确阻塞后，分别创建并审查以下子计划：

- `V2-G2`: `temporal_tracker`、轨迹历史、单目标状态机和叠加；
- `V2-G3`: 帧 tag、内部处理/视频排队延迟和 OSD `PROC/VIDEO/E2E=N/A`；
- `V2-G4`: ROI 8-bit 帧差资源试验、首帧/跳帧/冲突和 motion overlay；
- `V2-G5`: 内部分拣事件、一次性触发和虚拟执行器；外部 IO 另设硬件门；
- `V2-G6`: AWB 审计、帧统计、固定点增益和光照对照；
- `V2-G7`: 物理标定、尺寸换算、形状特征和单目标边界；
- `V2-G8`: 同一 Bitstream 融合、资源/时序、长稳、冻结包和发布。
