# SDD ledger — plan: docs/superpowers/plans/2026-10-19-industrial-v2-g5-sort.md

Setup: continue in `E:/Projects/FPGA-v2` on `goal/industrial-v2-advanced`; G1-G4 formal top/TD/hardware gates remain blocked.

Ruling: external actuator and GPIO are unknown; this plan only authorizes internal event logic, virtual actuator behavior and independent RTL evidence.

Task 1: software sort event, safety and virtual pulse models complete (RED missing-module collection failure; GREEN 8 passed).
Task 2: RTL sort event/safety/pulse chain complete (RED unknown-module compile failure; GREEN TB_SORT_CONTROL_PASS).
Task 3: affected regression complete (34 targeted Python tests passed; 12 RTL entries passed; full work/tests 80 passed / 8 baseline contract failures; Stage D SHA blocker retained).
Task 4: pending.
