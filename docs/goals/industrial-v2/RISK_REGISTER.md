# Industrial Vision V2 Risk Register

| ID | Risk | Evidence/state | Mitigation | Gate |
|---|---|---|---|---|
| R-001 | V1 baseline and current dirty worktrees can be mixed | Worktree audit 2026-10-19 | Use V2 Worktree from `256d99c`; bind every result to commit and manifest | G0 |
| R-002 | V1 resource is already 83.15% Slice | V1 freeze report | Independent resource trials, sharing, frame-domain computation and rollback | Every TD gate |
| R-003 | PHY/DDR/clock warnings remain open | V1 warning audit | Preserve warning ledger; do not close by positive WNS; require source/sink and hardware evidence | G0/G8 |
| R-004 | Hardware/download path may be unavailable | STATUS and bring-up records | Continue software/RTL work; keep hardware gates blocked | G0/G8 |
| R-005 | Mode/OSD updates can desynchronize video | Existing RTL and frame-boundary contract | Test sidebands and frame snapshots with every new register | G1 |
| R-006 | Frame-difference storage may exceed remaining RAM/timing | No V2 measurement yet | 8-bit ROI trial, then quantified lower-cost alternative only if equivalent | G4 |
| R-007 | External actuator pins/electrics are unknown | Project known gap | Internal virtual actuator first; no new IO until official/physical evidence | G5 |
| R-008 | Millimeter calibration inputs are absent | Project known gap | Output px only until repeatable fixed-workcell calibration | G7 |
| R-009 | Frozen V1 checkout contains later-worktree regression drift | G0 full pytest 52 passed / 8 failed; Stage D plugin SHA mismatch | Repair or formally scope the baseline before TD merge; keep V1 freeze immutable | G1/G8 |
