# G8 Live Telemetry Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make G3/G4/G5/G7 results observable in the same formal V2 HDMI output without overstating video latency, physical calibration, or actuator behavior.

**Architecture:** Preserve the existing source-domain feature spine and atomic result CDC. Add the missing matched `PROC` telemetry to the CDC, feed all selected destination-domain results into the OSD, and render frame-stable status text. As explicitly approved by the user, also apply the G6 AWB controller's frame-stable Q8.8 gains to the shared ISP RGB stream before HDMI conversion and source-domain consumers. Unknown GPIO and physical calibration remain blockers.

**Tech Stack:** Verilog-2001 RTL, Icarus Verilog, Python/pytest Algorithm Lab, Tang Dynasty 6.2.168116.

**Spec:** `docs/superpowers/specs/2026-10-19-industrial-v2-g8-live-telemetry-design.md`; parent contract: `docs/goals/industrial-v2/GOAL.md` and pasted task attachment.

## Global Constraints

- Never modify or overwrite frozen V1 artifacts.
- Keep one atomic source-result event across the CDC; do not synchronize multi-bit telemetry bitwise.
- `PROC` is source-clock cycles tied to a matched frame tag; `VIDEO` and physical `E2E` remain `N/A` without evidence.
- Label pixel dimensions `px`; label candidate physical dimensions as provisional, never as measured/calibrated.
- Do not invent GPIO assignments, change sensor initialization, or flash hardware.
- Preserve frame-boundary OSD updates and existing RGB/sync latency.
- Run TangDynasty only after software preview and RTL tests pass, in an isolated work project.

## Review Focus

- A source event arriving near the destination frame boundary must publish one complete payload, not mixed fields.
- Invalid latency values must render `N/A`, not stale numbers.
- Maximum motion count (19,200) and 16-bit PASS/NG counts must display without truncation.
- Uncalibrated candidate dimensions must remain visibly provisional and retain correct units.
- Safe-default `I_arm=0` must keep the actuator output low while status remains observable.

---

### Task 1: Software telemetry preview

**Files:**
- Create: `work/models/v2/telemetry_osd_reference.py`
- Create: `work/tests/test_v2_telemetry_osd.py`
- Modify: `work/algorithm_lab/app.py` and a focused plugin only if the existing plugin API requires registration.
- Create: `work/algorithm_lab/exports/g8_telemetry_osd/` generated preview/evidence.

**Interfaces:**
- Consumes a 1280x720 RGB frame plus frame-stable result values: mode, frame ID, pixel dimensions, PROC-valid/cycles, motion-valid/count, PASS/NG counts, sort/safety state, calibration/shape validity, and provisional-scale flag.
- Produces an RGB preview with the same fixed text rows and truthful `N/A`/unit labels specified by the design.

- [x] Write tests for valid/invalid PROC values, max counts, provisional calibration, and explicit px/mm labels.
- [x] Run the focused test and observe expected RED due to the missing reference model.
- [x] Implement the reference renderer and Algorithm Lab registration with the smallest existing plugin pattern.
- [x] Run the focused test (6 passed); render a preview at `work/algorithm_lab/exports/g8_telemetry_osd/telemetry_preview.png` and record the user-authorized default-pass visual approval as Stage C only.

### Task 2: Extend atomic result CDC for PROC

**Files:**
- Modify: `fallback/rtl/integration/industrial_v2_result_cdc.v`
- Modify: `fallback/sim/integration/tb_industrial_v2_result_cdc.v`

**Interfaces:**
- Add source inputs `I_src_proc_valid` and `I_src_proc_cycles[31:0]` and destination outputs `O_dst_proc_valid` and `O_dst_proc_cycles[31:0]`.
- Preserve existing one-toggle payload capture and destination publish sequencing.

- [x] Extend the CDC TB first; assert matched and invalid PROC payloads arrive atomically with the same frame ID and motion-valid status.
- [x] Run Icarus against the prior CDC and confirm RED on missing PROC ports.
- [x] Implement payload hold, two destination sampling registers, reset values, and publication; invalid PROC payloads are zeroed.
- [x] Re-run the CDC TB; `TB_INDUSTRIAL_V2_RESULT_CDC_PASS`.

### Task 3: Add frame-stable telemetry rows to the OSD

**Files:**
- Modify: `fallback/rtl/display/industrial_osd_overlay.v`
- Create or modify: `fallback/sim/display/tb_industrial_osd_telemetry.v`
- Modify: `work/tests/test_v2_osd_bcd.py` only for shared decimal/count contracts.

**Interfaces:**
- Add destination-domain inputs for PROC, motion/count, PASS/NG counts, sort/safety, calibration/shape, and candidate dimension values.
- Snapshot telemetry on the same frame boundary as dimensions; never convert changing telemetry in the pixel path.

- [x] Write pixel-sampling tests for PROC valid/invalid, maximum count, unit/provisional labels, maximum 11-bit pixel dimensions, and frame-boundary stability.
- [x] Run Icarus against the prior OSD and confirm RED on missing telemetry ports.
- [x] Implement bounded decimal/hex conversion and additional glyph-row selection using the current 5x7 font.
- [x] Verify the OSD pixel test plus existing BCD/Logo and row-wise font tests; RGB/sync one-cycle alignment is asserted.

### Task 4: Connect top-level consumers and strengthen the gate

**Files:**
- Modify: `fallback/td_source/design_top_wrapper.v`
- Modify: `fallback/td_source/isp/isp_top.v`
- Modify: `fallback/rtl/integration/industrial_v2_feature_spine.v`
- Modify: `fallback/rtl/integration/frame_stats_96.v`
- Modify: `fallback/rtl/isp/awb_frame_gain_controller.v`
- Modify: `work/tests/test_v2_formal_feature_integration.py`
- Modify: `work/tests/test_v2_awb.py`
- Create/modify: `fallback/sim/isp/tb_axis_gain_rgb96.v`
- Create/modify: `fallback/sim/isp/tb_awb_frame_gain_fixed.v`
- Create/modify: `fallback/sim/integration/tb_frame_stats_fixed_luma.v`
- Leave: `release/industrial-v2/tests/` frozen candidate snapshot unchanged.

**Interfaces:**
- Connect latency monitor `PROC` fields to CDC source inputs.
- Connect CDC destination fields, including existing motion/count/sort/calibration fields, to OSD inputs.
- Keep `VIDEO`/`E2E` invalid until real tagged/physical measurements exist.
- Connect controller gains to the post-vendor-AWB ISP RGB stream and keep one gain snapshot per input frame; retain the existing shared stream for HDMI and source-domain analysis.
- Specialize frame-size arithmetic for the fixed 1280×720 raster while preserving generic configurations and exact software/RTL AWB behavior.
- Register the 12 RGB gain products so multiplication is not in the same combinational path as frame-statistics accumulation; verify two-stage latency, throughput, sidebands, frame stability, and elastic backpressure.
- Pipeline fixed-raster statistics after frame end: first register channel totals, then apply the exact 720p Q35 reciprocal and publish all result fields together; retain generic-divider configurations.

- [x] Add a static top-level test that fails if any required result output terminates at an unused wire.
- [x] Run the focused test to confirm RED on current top-level.
- [x] Wire the existing signals and explicit provisional-calibration indicator to the OSD consumer.
- [x] Preserve the release test snapshot unchanged; its README defines it as frozen, while root `work/tests` is the current regression entry.
- [x] Run top-level contract tests, focused Icarus benches, and the full `work/tests` regression after the final fixed-luma retime (162 passed; evidence recorded in Task 5).
- [x] User authorized default Stage-C visual approval for all lab previews; AWB software-reference contract and tests exist.
- [x] Before allowing an internal PROC result, provide an independently frame-associated result ID; a depth-4 SOF/result queue and full-raster latency regression now prove tag association through 921600 cycles. This is simulation evidence only; HDMI video/E2E remains N/A because the top still ties off the video event.

### Task 5: Isolated TD validation and evidence

**Files:**
- Create: `docs/experiments/2026-10-19-industrial-v2-g8-live-telemetry.md`
- Modify: `docs/goals/industrial-v2/STATUS.json`, `ROADMAP.md`, `BLOCKERS.md`, and `EVIDENCE_INDEX.md`.
- Create a candidate under `release/candidates/industrial-v2-g8-live-telemetry/` only if the isolated TD run passes; failed attempts remain under `work/` and are not promoted.

- [x] Run the formal top using the documented TD version and isolated work project; synthesis/elaboration completed, placement stopped at `PHY-9053` for slice overuse; no flash or Bitstream.
- [x] Extend the isolated TD A/B through fix5–fix8; fix8 improved gate timing and DSP to 40/40 but still stops at `PHY-9053` with 22420/21216 placed slices; no route, Bitstream, or candidate.
- [x] Confirm telemetry/OSD/AWB/frame-statistics hierarchy rows and resource changes; inspect timing and warnings. SHA-256 comparison confirms all 30 tracked application source copies match; the failed flow did not emit the broader release provenance manifest.
- [x] Re-run strict release audit: expected exit 1, 7/13 PASS and 6/13 BLOCKED; keep G8 blocked. The audit evaluates the existing packaged candidate, not fix4–fix8.
- [x] Keep frozen V1, the existing formal candidate, and its release package unchanged; no fix4–fix8 candidate was produced.
- [x] Resolve the four fix4 read-only review findings at RTL/SIM level: sticky fixed-frame invalidity, per-domain reset release, associated result tags/full-frame timeout, and AWB update-to-next-SOF cadence.
- [ ] Connect a real frame-tagged HDMI output event before reporting video/E2E latency; retain N/A. Source audit found the 4-slot DDR writer/reader has no frame-ID or write-complete sideband, so VSYNC must not be paired with the latest input frame ID by assumption; see `docs/experiments/2026-10-20-industrial-v2-g3-ddr-output-frame-tag-audit.md`.

## Self-review

- Tasks 1–4 separately prove model appearance, CDC correctness, OSD pixels, and actual top-level consumers.
- No task promotes module elaboration or a Bitgen result to physical/hardware acceptance.
- AWB gain application is now within this plan by user direction; board GPIO and physical calibration remain blocked and are not inferred.
