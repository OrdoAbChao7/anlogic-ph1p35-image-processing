# SDD ledger — plan: docs/superpowers/plans/2026-10-19-industrial-v2-g6-awb.md

Setup: continue in `E:/Projects/FPGA-v2` on `goal/industrial-v2-advanced`; G1-G5 formal top/TD/hardware gates remain blocked.

Ruling: sensor AE/I2C and visual hardware approval are not inferred. The user's default visual approval allows Stage C to proceed, but does not create image samples or hardware evidence.

Task 1: software frame-stat AWB model complete (RED missing-module collection failure; GREEN 8 passed).
Task 2: RTL frame-stat AWB controller complete (RED unknown-module compile failure; GREEN TB_AWB_FRAME_GAIN_PASS).
Task 3: affected regression complete (42 targeted Python tests passed; 13 RTL entries passed; full work/tests 88 passed / 8 baseline contract failures; Stage D SHA blocker retained).
Task 4: G6 evidence and status records complete; phase remains BLOCKED at ISP/SC520CS/TD/hardware gates.
