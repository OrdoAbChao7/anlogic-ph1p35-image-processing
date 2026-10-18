# SDD ledger — plan: docs/superpowers/plans/2026-10-19-industrial-v2-g4-motion.md

Setup: continue in `E:/Projects/FPGA-v2` on `goal/industrial-v2-advanced`; G1-G3 formal top/TD/hardware gates remain blocked, so G4 starts with decoupled software/RTL.

Ruling: no `/bin/bash`/WSL relay is available for `sdd-workspace`; this plan-scoped ledger is manual under the same contract as earlier phases.

Task 1: software motion model complete (RED missing-module collection failure; GREEN 8 passed).
Task 2: RTL motion monitor complete (RED unknown-module compile failure; GREEN TB_MOTION_DIFF_160_PASS).
Task 3: affected regression complete (26 targeted Python tests passed; 11 RTL entries passed; full work/tests 72 passed / 8 baseline contract failures; Stage D SHA blocker retained).
Task 4: pending.
