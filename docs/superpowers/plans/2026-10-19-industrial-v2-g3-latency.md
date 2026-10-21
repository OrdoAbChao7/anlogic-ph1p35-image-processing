# PH1P35 工业视觉 V2 G3 延迟监视实施计划

> **For agentic workers:** 使用 TDD；在当前 G1/G2 正式 TD 阻塞期间只推进解耦的软件/RTL。当前执行方法为 Native。

**Goal:** 建立帧标签匹配和内部 PROC/VIDEO 延迟测量，明确 E2E=N/A，并完成软件/RTL 验证。

**Architecture:** `frame_tag_monitor` 负责帧 ID/gap/mismatch/timeout；`latency_monitor` 负责单 pending 输入帧的周期时间戳和 PROC/VIDEO 结果。两者使用同一时钟域和明确 cycles 单位，暂不接入正式顶层。

**Spec:** `docs/superpowers/specs/2026-10-19-industrial-v2-g3-latency-design.md`

## Global Constraints

- 不用刷新率或 OSD 帧号作为延迟值。
- 无物理测量时 `E2E` 必须为 `N/A`。
- 标签不匹配时不发布有效延迟。
- 所有事件和计数器必须有复位、回绕和超时语义。

### Task 1: 软件延迟模型

**Files:**
- Create: `work/models/v2/latency_reference.py`
- Create: `work/tests/test_v2_latency.py`
- Create: `docs/experiments/2026-10-19-industrial-v2-g3-latency-model.md`

- [ ] **Step 1: Write failing tests** for continuous tags, gap, mismatch, timeout, reset and E2E N/A.
- [ ] **Step 2: Run RED** with `python -B -m pytest -q work/tests/test_v2_latency.py`; expect missing module.
- [ ] **Step 3: Implement** a single-pending-frame reference model with explicit cycle timestamps.
- [ ] **Step 4: Run GREEN** and expect all model cases pass.
- [ ] **Step 5: Commit** `feat(v2): define latency measurement model`.

### Task 2: RTL frame tag monitor

**Files:**
- Create: `fallback/rtl/inspection/frame_tag_monitor.v`
- Create: `fallback/sim/inspection/tb_frame_tag_monitor.v`
- Create: `docs/experiments/2026-10-19-industrial-v2-g3-frame-tags.md`

- [ ] **Step 1: Write TB** for tag match, input gap, mismatch, timeout and reset.
- [ ] **Step 2: Run RED** compile without module.
- [ ] **Step 3: Implement** bounded tag state and one-cycle diagnostic pulses.
- [ ] **Step 4: Run GREEN** with `TB_FRAME_TAG_MONITOR_PASS`.
- [ ] **Step 5: Commit** `feat(v2): add frame tag monitor`.

### Task 3: RTL latency monitor

**Files:**
- Create: `fallback/rtl/inspection/latency_monitor.v`
- Create: `fallback/sim/inspection/tb_latency_monitor.v`
- Create: `docs/experiments/2026-10-19-industrial-v2-g3-latency-monitor.md`

- [ ] **Step 1: Write TB** for known cycle deltas, mismatch suppression, timeout, counter wrap and E2E N/A.
- [ ] **Step 2: Run RED** compile without module.
- [ ] **Step 3: Implement** free-running counter and timestamp subtraction with wrap-safe unsigned arithmetic.
- [ ] **Step 4: Run GREEN** with `TB_LATENCY_MONITOR_PASS`.
- [ ] **Step 5: Commit** `feat(v2): add internal latency monitor`.

### Task 4: G3 gate and evidence

**Files:**
- Modify: `docs/goals/industrial-v2/STATUS.json`
- Modify: `docs/goals/industrial-v2/ROADMAP.md`
- Modify: `docs/goals/industrial-v2/TASKS.md`
- Modify: `docs/goals/industrial-v2/EVIDENCE_INDEX.md`
- Create: `docs/experiments/2026-10-19-industrial-v2-g3-summary.md`

- [ ] **Step 1:** Run G3 model/RTL and G1/G2 regressions.
- [ ] **Step 2:** Run full Python/industrial gates and record unchanged baseline blockers.
- [ ] **Step 3:** Mark software/RTL pass separately from top/TD/hardware and E2E N/A.
- [ ] **Step 4:** Commit `docs(v2): record g3 latency evidence`.

## Self-review

- PROC, VIDEO and E2E are distinct; E2E cannot become valid without physical instrumentation.
- Frame gaps and mismatches are explicit failure outputs, not hidden corrections.
- The plan is independent of vendor video source edits and does not claim formal top-level integration.
