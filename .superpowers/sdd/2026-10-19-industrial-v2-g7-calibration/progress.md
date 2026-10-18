# SDD ledger — plan: docs/superpowers/plans/2026-10-19-industrial-v2-g7-calibration.md

Setup: continue in `E:/Projects/FPGA-v2` on `goal/industrial-v2-advanced`; G1-G6 formal top/TD/hardware gates remain blocked.

Ruling: no real workcell calibration sample or physical geometry is inferred. The implementation is a fixed-point candidate and must retain `NOT_CALIBRATED` until evidence exists.

Task 1: software calibration and shape model complete (RED missing-module collection failure; GREEN 7 passed).
Task 2: RTL dimension/shape checker complete (RED unknown-module compile failure; GREEN TB_DIMENSION_CALIBRATOR_PASS).
Task 3: affected regression complete (49 targeted Python tests passed; 14 RTL entries passed; full work/tests 95 passed / 8 baseline contract failures; Stage D SHA blocker retained).
Task 4: pending.
