# Cartoon Region Fill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不破坏 `s3_luma` 回退基线的前提下，实现并验证固定 8 级颜色量化、四连通局部区域填充和 Sobel 轮廓融合的卡通化候选。

**Architecture:** 新候选先在 Python 中生成参考输出和视觉证据，再用同一公式建立硬件等价模型；RTL 使用与现有 `video_cartoon` 相同的 RGB888/一像素/拍接口和流式 `3×3` 窗口，验证通过后才由 `scripts/build_industrial_td.py` 复制到 TD 工程。`s3_luma` 保留原文件、原登记和原发布位流，候选失败时直接回退。

**Tech Stack:** Python 3、NumPy、OpenCV（仅参考模型/预览）、Icarus Verilog、纯 Verilog、TangDynasty 6.2.168116。

**Spec:** `docs/superpowers/specs/2026-10-17-cartoon-region-fill-design.md`

## Global Constraints

- 量化固定为 `Q(v)=(v[7:5]<<5)|(v[7:5]<<2)|(v[7:5]>>1)`，逐通道 RGB888。
- 局部区域填充固定为 `N==S && S==W && W==E` 时 `F=N`，否则 `F=C`。
- Sobel 使用量化窗口亮度 `Y=(R+2*G+B)>>2`，阈值固定 `240`。
- 图像边界使用 causal `BORDER_REPLICATE`；窗口右下锚定当前采样，实际复制上/左边界；空白区不推进坐标；模式只在新帧首个有效像素生效。
- RTL 纯 Verilog、一像素/拍、无背压；旁带信号与 RGB 使用相同延迟，目标延迟 6 cycles，最终以波形冻结。
- 不修改 `work/rtl/video_cartoon_luma.v`、`work/algorithm_lab/configs/industrial_inspection/approved_v1.0-approved.json` 或用户已有的 `fallback/tb_color.vvp`。
- 未重新获得候选视觉 `VISUAL_APPROVED` 前，不把候选加入正式发布位流或替换 registry 的批准版本。
- 运行 TD 前必须有软件参考模型、硬件等价模型和 RTL 逐周期回归 PASS；没有板卡时不得声明 Stage G。

## Review Focus

- 量化边界 `31/32`、`63/64` 和纯色输入必须逐值一致；由 Task 1 的 `test_quantization_boundaries` 覆盖。
- 单像素孔洞只有四邻居完全同色时才填充，真实边界不能跨色填充；由 Task 1 的 `test_cross_fill_rule` 覆盖。
- 四边和四角必须复制最近像素，不能读到上一帧或未初始化 RAM；由 Task 1 和 Task 4 的 border tests 覆盖。
- 帧中途按键/请求不能改变当前帧，帧尾排空不能污染下一帧；由 Task 4 的 `test_mode_commit_and_flush` 覆盖。
- OSD 覆盖像素必须旁路算法，空白区输出和 `VS/HS/DE` 必须保持契约；由 Task 4 的 `test_overlay_and_blanking` 覆盖。

### Task 1: 建立区域填充软件参考模型的失败测试

**Files:**
- Create: `work/models/cartoon_region_fill_reference.py`
- Create: `work/tests/test_cartoon_region_fill.py`

**Interfaces:**
- Produces `quantize_rgb(rgb: np.ndarray) -> np.ndarray`，`local_fill(quantized: np.ndarray) -> np.ndarray`，以及 `filter_rgb(rgb: np.ndarray, threshold: int = 240) -> tuple[np.ndarray, np.ndarray, np.ndarray]`，返回 `(cartoon_rgb, edge_mask, filled_rgb)`。
- 输入必须是 `uint8` 的 `H×W×3` RGB；错误维度或类型抛出 `ValueError`。

- [ ] **Step 1: Write the failing tests**

  在 `work/tests/test_cartoon_region_fill.py` 添加：常量颜色量化、量化边界、中心单像素孔洞、四邻居不一致、四边角复制、常量图无边缘、水平/垂直阶跃 Sobel、输出 shape/dtype 和输入校验测试。测试直接断言规格中的 `Q(v)` 和四邻居规则。

- [ ] **Step 2: Run tests to verify they fail**

  Run: `python -m unittest work/tests/test_cartoon_region_fill.py -v`

  Expected: FAIL because `cartoon_region_fill_reference.py` does not exist。

- [ ] **Step 3: Implement the minimal reference API**

  在 `work/models/cartoon_region_fill_reference.py` 使用 NumPy 明确实现通道量化、`np.pad(..., mode="edge")` 的边界复制、四邻居填充和整数 Sobel；不使用浮点参与输出公式，返回 `uint8` cartoon/filled 和 `bool` 或 `uint8` edge mask，并保留可独立调用的中间函数。

- [ ] **Step 4: Run the tests to verify they pass**

  Run: `python -m unittest work/tests/test_cartoon_region_fill.py -v`

  Expected: all reference-model tests PASS。

- [ ] **Step 5: Commit**

  `git add work/models/cartoon_region_fill_reference.py work/tests/test_cartoon_region_fill.py && git commit -m "test: define cartoon region fill reference contract"`

### Task 2: 接入 Algorithm Lab 候选并生成 Stage B/C 预览

**Files:**
- Modify: `work/algorithm_lab/plugins/cartoon.py`
- Create: `work/algorithm_lab/configs/industrial_inspection/cartoon_region_fill_v1.json`
- Create: `work/tests/render_cartoon_region_fill_preview.py`
- Create: `work/algorithm_lab/test_cartoon_region_fill.py`

**Interfaces:**
- Consumes `cartoon_region_fill_reference.filter_rgb` from Task 1。
- Produces plugin variant `s4_region_fill` with hardware-equivalent output and metadata fields `variant`, `model_desc`, `edge_pixels`, `filled_pixels`, `line_buffer_rows`。
- Candidate JSON is not an approval registry entry and must not overwrite `approved_v1.0-approved.json`。

- [ ] **Step 1: Write the failing plugin contract test**

  Assert that `get_parameter_specs()` exposes `s4_region_fill`, default candidate settings are `quant_levels=8`, `sobel_threshold=240`, and `process_hardware_equivalent()` returns same-shape RGB output plus the required metadata without changing `s3_luma` behavior。

- [ ] **Step 2: Run the focused test to verify it fails**

  Run: `python -m unittest work/algorithm_lab/test_cartoon_region_fill.py -v`。

  Expected: FAIL because the plugin has no `s4_region_fill` branch。

- [ ] **Step 3: Implement the candidate branch and preview exporter**

  Add only the candidate variant to the existing plugin; reuse the reference model rather than duplicating formulas. The exporter renders the five industrial samples plus `sample_city.png` into a new unapproved output directory and writes image hashes, parameter JSON, and a `VISUAL_REVIEW_PENDING` report。

- [ ] **Step 4: Run software tests and produce the preview**

  Run: `python -m unittest work/algorithm_lab/test_cartoon_region_fill.py -v` and `python work/tests/render_cartoon_region_fill_preview.py`。

  Expected: tests PASS; preview report and images exist; no registry status is changed to `VISUAL_APPROVED` automatically。

- [ ] **Step 5: Human visual gate**

  Present the generated comparison to the user. Record a new candidate version and approval only after the user explicitly confirms `VISUAL_APPROVED`; if rejected, adjust the software model before any RTL work.

- [ ] **Step 6: Commit**

  `git add work/algorithm_lab/plugins/cartoon.py work/algorithm_lab/configs/industrial_inspection/cartoon_region_fill_v1.json work/tests/render_cartoon_region_fill_preview.py work/algorithm_lab/test_cartoon_region_fill.py && git commit -m "feat: add cartoon region fill software candidate"`

### Task 3: 固定硬件等价模型并建立 RTL Golden 输入

**Files:**
- Create: `work/models/cartoon_region_fill_hardware_equivalent.py` (or a clearly named extension beside the Task 1 model)
- Create: `work/tests/test_cartoon_region_fill_hardware_equivalent.py`
- Create: `work/tests/run_cartoon_region_fill_sim.py`
- Create: `work/tests/tb_video_cartoon_region_fill.v`

**Interfaces:**
- Consumes the Stage C-approved candidate parameters and Task 1 outputs。
- Produces a cycle-vector format compatible with existing `tb_video_cartoon.v`: packed RGB plus `VS/HS/DE`, mode, overlay and reset, with expected output delayed by the frozen RTL latency。

- [ ] **Step 1: Write failing fixed-point and cycle-contract tests**

  Pin integer formulas, `BORDER_REPLICATE`, fill rule, threshold 240, reset, frame flush, blanking, overlay bypass and mode-at-frame-start behavior. Include a small image with a one-pixel hole and two adjacent frames with different colors.

- [ ] **Step 2: Run the tests to verify they fail**

  Run: `python -m unittest work/tests/test_cartoon_region_fill_hardware_equivalent.py -v`

  Expected: FAIL because the hardware-equivalent model and cycle adapter are absent。

- [ ] **Step 3: Implement the fixed-point model and vector generator**

  Reuse Task 1 formulas but make every intermediate width explicit; generate both small vectors and a `1280×720` production vector without storing a full frame in RTL-facing logic. The testbench must compare RGB and all sidebands, not only cartoon pixels。

- [ ] **Step 4: Run the fixed-point tests**

  Run: `python -m unittest work/tests/test_cartoon_region_fill_hardware_equivalent.py -v`。

  Expected: all fixed-point and vector contract tests PASS。

- [ ] **Step 5: Commit**

  `git add work/models/cartoon_region_fill_hardware_equivalent.py work/tests/test_cartoon_region_fill_hardware_equivalent.py work/tests/run_cartoon_region_fill_sim.py work/tests/tb_video_cartoon_region_fill.v && git commit -m "test: freeze cartoon region fill hardware contract"`

### Task 4: 实现纯 Verilog 流式模块并通过逐周期仿真

**Files:**
- Create: `work/rtl/video_cartoon_region_fill.v`
- Modify: `work/tests/tb_video_cartoon_region_fill.v`
- Modify: `work/tests/run_cartoon_region_fill_sim.py`

**Interfaces:**
- Consumes the exact `video_cartoon` port contract from the design spec and Task 3 vector stream。
- Produces `o_rgb/o_vs/o_hs/o_de/o_mode` with target six-cycle latency and no backpressure。

- [ ] **Step 1: Run the existing RTL test first**

  Run: `python work/tests/run_cartoon_region_fill_sim.py --rtl work/rtl/video_cartoon_region_fill.v`

  Expected: FAIL because the RTL module is absent.

- [ ] **Step 2: Implement line buffers, window, quantizer, fill and Sobel**

  Use the existing luma module only as a structural reference; keep the new module independent. Use alternating line banks/shift registers, explicit coordinate reset at `VS`, replicated edge selection, named constants for threshold and latency, and equal sideband pipelines. Do not copy vendor PHY/DDR code or alter the baseline module.

- [ ] **Step 3: Run the small RTL/G​​olden regression**

  Run: `python work/tests/run_cartoon_region_fill_sim.py --small`

  Expected: Icarus exits 0 and reports zero RGB/sideband mismatches for reset, boundaries, hole fill, modes, overlay and blanking。

- [ ] **Step 4: Run the full-frame regression**

  Run: `python work/tests/run_cartoon_region_fill_sim.py --full-frame`

  Expected: `1280×720` continuous-frame run passes, including frame transition and pipeline flush。

- [ ] **Step 5: Commit**

  `git add work/rtl/video_cartoon_region_fill.v work/tests/tb_video_cartoon_region_fill.v work/tests/run_cartoon_region_fill_sim.py && git commit -m "feat: implement streaming cartoon region fill RTL"`

### Task 5: 接入候选 TD 构建并审计资源/时序

**Files:**
- Modify: `scripts/build_industrial_td.py` only through a tracked candidate selector or explicit `--video-rtl` option
- Create: `work/tests/test_cartoon_region_fill_build_contract.py`
- Create: `docs/experiments/2026-10-17-cartoon-region-fill-stage-e.md`
- Create: candidate build output under an isolated run directory, not over `release/industrial-v1`

**Interfaces:**
- Consumes Task 4 RTL and the existing fallback TD source/constraints。
- Produces isolated TD reports, bitstream hash, source hash, warning audit and resource comparison against current `s3_luma` baseline。

- [ ] **Step 1: Write the build contract test**

  Assert candidate selection is explicit, source path is `work/rtl/video_cartoon_region_fill.v`, baseline default remains `video_cartoon_luma.v`, and the user-owned `fallback/tb_color.vvp` is never staged or copied as a release source。

- [ ] **Step 2: Run the contract test to verify it fails**

  Run: `python work/tests/test_cartoon_region_fill_build_contract.py`

  Expected: FAIL until the build script supports an isolated candidate input。

- [ ] **Step 3: Add isolated candidate build support**

  Add a command-line selector or copy-only override; default invocation must remain unchanged. Candidate runs must write outside `release/industrial-v1` and preserve the baseline manifest。

- [ ] **Step 4: Run the contract and candidate TD build**

  Run the focused contract, then the documented TangDynasty candidate build with the installed TD version and current device. Capture setup/hold WNS/TNS, slices, RAM, DSP, coverage, warnings and bitstream SHA-256。

  Expected: contract PASS; build result is recorded as PASS or FAIL with raw reports. Positive timing alone is insufficient if resource or warning gates fail。

- [ ] **Step 5: Commit evidence without promoting the candidate**

  Add the experiment and contract only. Do not replace the published `.bit`, manifest, approved registry entry or `s3_luma` source until all later gates pass。

### Task 6: 回归、状态记录与候选发布决策

**Files:**
- Modify: `docs/experiments/2026-10-17-cartoon-region-fill-stage-e.md`
- Modify: `docs/project/STATUS.md` only with measured evidence
- Modify: `docs/research/known-gaps.md` only to add/close evidence-backed gaps
- Modify: `docs/evidence/industrial-v1-requirement-audit.md` only if candidate status changes

**Interfaces:**
- Consumes all software, RTL and TD evidence from Tasks 1–5。
- Produces a clear candidate status: `VISUAL_REVIEW_PENDING`, `SIM_PASS`, `BUILD_PASS`, `FAILED_RESOURCE_TIMING`, or `VERIFIED_ON_BOARD` only when the matching evidence exists。

- [ ] **Step 1: Run the complete affected verification set**

  Run the reference tests, Algorithm Lab tests, hardware-equivalent tests, small/full RTL regressions and existing industrial build contracts. Existing `s3_luma` and fixed-red tests must remain green。

- [ ] **Step 2: Audit the evidence against the spec**

  Check exact formula hashes, vector inputs, source commit, TD version/device, raw reports, resource/timing thresholds and warnings. Record unresolved hardware and clean-rebuild gaps as open。

- [ ] **Step 3: Decide promotion**

  Promote only if Stage C approval, Stage D/E/F evidence and resource/timing gates all pass. Otherwise retain `s3_luma` as the published baseline and document the candidate failure or pending gate。

- [ ] **Step 4: Commit the evidence update**

  `git add docs/experiments/2026-10-17-cartoon-region-fill-stage-e.md docs/project/STATUS.md docs/research/known-gaps.md docs/evidence/industrial-v1-requirement-audit.md && git commit -m "docs: record cartoon region fill verification"`

## Execution Order

Run Tasks 1–2 first and stop for the new visual `VISUAL_APPROVED` gate. After approval, run Tasks 3–4 in sequence, then Task 5 in an isolated TD output directory, and finally Task 6. Never enter Task 5 with a failing RTL/G​​olden regression, and never promote the candidate solely because software or RTL tests pass.
