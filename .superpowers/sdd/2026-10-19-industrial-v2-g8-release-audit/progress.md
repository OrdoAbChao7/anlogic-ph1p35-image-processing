# SDD ledger — plan: docs/superpowers/plans/2026-10-19-industrial-v2-g8-release-audit.md

Setup: continue in `E:/Projects/FPGA-v2` on `goal/industrial-v2-advanced`; G1-G7 formal top/TD/hardware gates remain blocked.

Ruling: the user's default visual approval is recorded as `PASS` only for Stage C visual review. It cannot satisfy build, timing, hardware, long-stability, or actuator gates.

Task 1: release-gate model tests complete.
Task 2: repository release audit script complete.
Task 3: complete. `python -B scripts/verify_industrial_v2_release.py --strict` returned exit 1 with `release_status=BLOCKED`; V1 baseline SHA matched and visual approval was the only explicit PASS.
Task 4: complete as a candidate-only step. `industrial_v2_feature_spine` compiles and passes `TB_INDUSTRIAL_V2_FEATURE_SPINE_PASS`; it exposes the required frame-result, motion, statistics, calibration and safety boundaries.
Task 5: pending; add explicit CSI/ISP-to-grid/statistics adapters and result-to-HDMI CDC before formal top-level integration. Do not rerun TD or claim release until those contracts are reviewed.
