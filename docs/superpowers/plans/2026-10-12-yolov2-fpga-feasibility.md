# YOLO-FastestV2 / FPGA Accelerator Feasibility Implementation Plan

> **For agentic workers:** Execute this plan in the current session; keep every model and RTL experiment isolated from the video project.

**Goal:** Reproduce the official pretrained detector, verify selected open RTL operators, and make an evidence backed PH1P35 research decision.

**Architecture:** A clean snapshot of each pinned upstream repository lives under `work/yolo_fpga_feasibility/upstream/`. Independent scripts and tests use the existing Windows Python environment and available simulator. The resource model consumes measured network layer shapes and the historical area report, with explicit assumptions.

**Tech Stack:** Python/PyTorch/OpenCV, Git, Icarus or available Verilog simulator, Markdown/JSON/CSV.

**Spec:** User attachment `D:/Dev/.codex/attachments/1d737e14-dcb2-4a0b-bc2c-53aa9ef5a4be/已粘贴的文本.txt`.

## Global Constraints

- Do not train a new network, edit protected project goals or video RTL, run TangDynasty, or generate a bitstream.
- Preserve existing uncommitted edits and upstream snapshots. Never treat generic synthesis as PH1P35 results.
- Distinguish Y1/Y2 exposed images from any final blind evaluation.

## Review Focus

- Cached checkpoint must match the upstream Git blob before loading.
- Official preprocessing, head decode, NMS, and coordinates must match the upstream test path.
- Packed signed multiplier and nine-product adder must be checked at `-128`/`127` boundaries.
- Partial INT32 sums and full-network storage must not be hidden inside a tile-only BRAM estimate.
- A PASS requires a saved command, input, version, and output log; any missing gate remains pending.

### Task 1: Reproduce official detector

- [ ] Pin clean upstream source and verify checkpoint SHA/Git blob.
- [ ] Run official smoke inference on three specified COCO IDs and compare an independent wrapper stage by stage.
- [ ] Evaluate frozen public split, timing, failure cases, and unfiltered detections.
- [ ] Export actual layer shape/MAC/liveness records.

### Task 2: Verify reference RTL operators

- [ ] Audit Apache license, dependencies, signed widths, stages, and Xilinx assumptions.
- [ ] Implement independent integer Golden Model and deterministic boundary/random vectors.
- [ ] Simulate original multiplier, adder, scaling, saturation, and a minimal chain; preserve failures.
- [ ] If needed, fix only an isolated candidate and rerun affected tests.

### Task 3: Budget and decision

- [ ] Verify the historical TD resource report fields.
- [ ] Calculate 16 MAC cycle limits, utilization sensitivity, tile buffers and INT32 partial sums.
- [ ] Separate DDR assumptions from measured facts and identify minimum TD follow-up experiment.
- [ ] Provide a Windows reproduction entry and evidence/decision report; update mutable status documents.
