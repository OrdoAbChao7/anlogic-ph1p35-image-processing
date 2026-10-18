# PH1P35 工业视觉 V2 G2 单目标跟踪实施计划

> **For agentic workers:** 使用 TDD；每个任务先写失败测试，再实现最小行为。当前执行方法为 Native，由主 Agent 在 `E:/Projects/FPGA-v2` 内执行。

**Goal:** 完成单目标跨帧关联、有限轨迹历史和独立像素叠加的 SOFTWARE_PASS/RTL_PASS，并保留 TD/硬件阶段门。

**Architecture:** 以已完成 CDC 的帧结果事件为输入；`temporal_tracker` 只处理帧级状态，`trajectory_history` 保存 8 点像素历史，`tracking_overlay` 在 HDMI 域使用扁平点数组绘制固定半径标记。暂不修改厂商视频边界或正式顶层。

**Tech Stack:** Python 3、pytest、纯 Verilog、Icarus Verilog 14、现有 fixed-red result contract。

**Spec:** `docs/superpowers/specs/2026-10-19-industrial-v2-g2-tracker-design.md`

## Global Constraints

- 只承诺单目标关联；不得宣称多目标跟踪。
- `I_invalid` 优先级高于 `I_detected`，无效坐标不得写入历史。
- `O_enter/O_exit` 为一次性事件；长时间 LOST 不重复退出。
- 帧标签跳变只报告 `O_frame_gap`，不补造帧。
- 不改变 MIPI/CSI-2/ISP/DDR2/HDMI/IO 边界；TD 和硬件未通过前不得晋级整机候选。
- 视觉审批按用户指令默认通过；资源/时序/硬件仍需真实证据。

### Task 1: 软件跟踪模型和状态合同

**Files:**
- Create: `work/models/v2/tracker_reference.py`
- Create: `work/tests/test_v2_tracker.py`
- Create: `docs/experiments/2026-10-19-industrial-v2-g2-tracker-model.md`

**Interfaces:**
- `TrackerConfig(max_step_x: int = 64, max_step_y: int = 64, max_lost_frames: int = 3)`。
- `FrameObservation(frame_id, detected, invalid, cx, cy)`。
- `TrackerState(state, track_valid, enter, exit, frame_gap, static, cx, cy, dx, dy, lost_frames)`。
- `TemporalTracker.update(observation) -> TrackerState`。

- [ ] **Step 1: Write the failing model tests**
  Cover static/enter, accepted motion, short dropout and recovery, lost-window exit/re-entry, jump rejection, frame gap, invalid precedence, and reset.
- [ ] **Step 2: Run the tests and confirm missing model failure**
  Run `python -B -m pytest -q work/tests/test_v2_tracker.py`; expected collection failure is missing `tracker_reference`.
- [ ] **Step 3: Implement the reference model**
  Keep the state machine and saturating lost counter explicit; use the same association rules as the spec.
- [ ] **Step 4: Run model tests**
  Expect all tracker behavior tests to pass.
- [ ] **Step 5: Commit**
  `feat(v2): define single-target tracker model`.

### Task 2: RTL temporal tracker

**Files:**
- Create: `fallback/rtl/inspection/temporal_tracker.v`
- Create: `fallback/sim/inspection/tb_temporal_tracker.v`
- Create: `docs/experiments/2026-10-19-industrial-v2-g2-temporal-tracker.md`

**Interfaces:**
- Module ports exactly mirror the frame observation and state outputs in the spec; coordinates are 11-bit and `O_dx/O_dy` are signed 12-bit.

- [ ] **Step 1: Add RTL testbench assertions**
  Drive the same sequence as the Python model, including one-cycle `I_frame_valid`, reset, jump, invalid and frame gap.
- [ ] **Step 2: Run RED compile**
  Compile with Icarus before the module exists; preserve missing-module failure.
- [ ] **Step 3: Implement sequential state machine**
  One state update per frame event; outputs pulse events and hold last valid center.
- [ ] **Step 4: Run GREEN RTL simulation**
  Expect `TB_TEMPORAL_TRACKER_PASS` and no assertion failures.
- [ ] **Step 5: Commit**
  `feat(v2): add frame-domain temporal tracker`.

### Task 3: RTL trajectory history

**Files:**
- Create: `fallback/rtl/inspection/trajectory_history.v`
- Create: `fallback/sim/inspection/tb_trajectory_history.v`
- Create: `docs/experiments/2026-10-19-industrial-v2-g2-trajectory-history.md`

**Interfaces:**
- `I_push`, `I_new_track`, `I_cx`, `I_cy`; outputs `O_x_flat`, `O_y_flat`, `O_valid_mask`, `O_count` with `HISTORY_DEPTH=8`.

- [ ] **Step 1: Write history TB**
  Cover clear-on-new-track, newest-first ordering, overflow saturation and ignored invalid push.
- [ ] **Step 2: Run RED compile**
  Expected missing-module failure.
- [ ] **Step 3: Implement shift-register history**
  Use bounded registers, no frame memory.
- [ ] **Step 4: Run GREEN history simulation**
  Expect `TB_TRAJECTORY_HISTORY_PASS`.
- [ ] **Step 5: Commit**
  `feat(v2): add bounded trajectory history`.

### Task 4: RTL trajectory overlay

**Files:**
- Create: `fallback/rtl/display/tracking_overlay.v`
- Create: `fallback/sim/display/tb_tracking_overlay.v`
- Create: `docs/experiments/2026-10-19-industrial-v2-g2-tracking-overlay.md`

**Interfaces:**
- Consume HDMI-domain `I_de/I_hsync/I_vsync/I_rgb`, `I_x/I_y`, `I_track_valid`, flattened 8-point history and output one-cycle delayed video signals.

- [ ] **Step 1: Write pixel-coordinate assertions**
  Test newest point, older point, invalid/hidden history and sync delay.
- [ ] **Step 2: Run RED compile**
  Expected missing-module failure.
- [ ] **Step 3: Implement fixed-radius point markers**
  Keep arithmetic bounded and combinational only over 8 points.
- [ ] **Step 4: Run GREEN overlay simulation**
  Expect `TB_TRACKING_OVERLAY_PASS`.
- [ ] **Step 5: Commit**
  `feat(v2): add tracking point overlay`.

### Task 5: G2 software/RTL gate and state update

**Files:**
- Modify: `docs/goals/industrial-v2/STATUS.json`
- Modify: `docs/goals/industrial-v2/ROADMAP.md`
- Modify: `docs/goals/industrial-v2/TASKS.md`
- Modify: `docs/goals/industrial-v2/EVIDENCE_INDEX.md`
- Modify: `docs/goals/industrial-v2/RESOURCE_BUDGET.md`
- Create: `docs/experiments/2026-10-19-industrial-v2-g2-summary.md`

- [ ] **Step 1: Run affected model and RTL tests**
  Run tracker, history, overlay tests and the existing G1 regressions.
- [ ] **Step 2: Run full Python/industrial regression**
  Record the known frozen-baseline failures without weakening assertions.
- [ ] **Step 3: Record G2 status**
  Mark software/RTL levels separately; TD/hardware remain `NOT_RUN/BLOCKED`.
- [ ] **Step 4: Commit evidence**
  `docs(v2): record g2 tracker evidence`.

## Self-review

- All G2 requirements map to Tasks 1–4: association state, lost/re-entry, frame gaps, trajectory storage and visual markers.
- Invalid results are tested before detected results and never enter history.
- The design does not claim multi-target, physical motion, TD, resource or hardware completion.
- The plan leaves top-level integration for a later all-feature fusion task so vendor video boundaries remain unchanged during isolated verification.
