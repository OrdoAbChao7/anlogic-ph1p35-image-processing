# SDD ledger — plan: docs/superpowers/plans/2026-10-19-industrial-v2-g3-latency.md

Setup: continue in `E:/Projects/FPGA-v2` on `goal/industrial-v2-advanced`; G1/G2 formal top/TD/hardware gates remain blocked, so G3 is limited to decoupled software/RTL.

Ruling: no `/bin/bash`/WSL relay is available for `sdd-workspace`; this plan-scoped ledger is manual under the same contract as earlier phases.

Task 1: software latency model complete (RED missing-module collection failure; GREEN 6 passed).

Task 2: RTL frame tag monitor complete (RED unknown-module compile failure; GREEN TB_FRAME_TAG_MONITOR_PASS; formal top/TD/hardware gates remain open).

Task 3: RTL latency monitor complete (RED unknown-module compile failure; GREEN TB_LATENCY_MONITOR_PASS; formal top/TD/hardware gates remain open).

Task 4: G3 evidence and status records complete (18 targeted Python tests passed; 10 RTL entries passed; full work/tests remains 64 passed / 8 baseline contract failures; Stage D registry/plugin SHA blocker retained).
