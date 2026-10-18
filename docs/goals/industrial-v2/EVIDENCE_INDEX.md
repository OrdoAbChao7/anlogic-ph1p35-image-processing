# Industrial Vision V2 Evidence Index

| Evidence | Path | Status |
|---|---|---|
| V1 freeze and Bitstream hash | `docs/evidence/industrial-v1-hx1p35a-pin-correction-freeze.md` | BASELINE |
| V1 TD warning audit | `docs/evidence/industrial-v1-td-warning-audit.md` | OPEN warnings retained |
| V2 design | `docs/superpowers/specs/2026-10-19-industrial-v2-advanced-design.md` | CREATED |
| V2 G0/G1 plan | `docs/superpowers/plans/2026-10-19-industrial-v2-g0-g1.md` | CREATED |
| V2 G0 baseline | `docs/experiments/2026-10-19-industrial-v2-g0-baseline.md` | ACTIVE; 46/8 pytest and Stage D SHA drift recorded |
| V2 G1 mode/OSD/ROI | `docs/experiments/2026-10-19-industrial-v2-g1-*.md` | SOFTWARE_PASS/RTL_PASS; TD and hardware BLOCKED |
| V2 G1 summary | `docs/experiments/2026-10-19-industrial-v2-g1-summary.md` | BLOCKED with 52/8 full pytest and Stage D SHA mismatch |
| V2 G2 tracker model | `docs/experiments/2026-10-19-industrial-v2-g2-tracker-model.md` | SOFTWARE_PASS |
| V2 G2 temporal tracker | `docs/experiments/2026-10-19-industrial-v2-g2-temporal-tracker.md` | RTL_PASS |
| V2 G2 trajectory history | `docs/experiments/2026-10-19-industrial-v2-g2-trajectory-history.md` | RTL_PASS |
| V2 G2 tracking overlay | `docs/experiments/2026-10-19-industrial-v2-g2-tracking-overlay.md` | RTL_PASS |
| V2 G2 summary | `docs/experiments/2026-10-19-industrial-v2-g2-summary.md` | BLOCKED; top/TD/hardware pending |
| V2 G3 latency model/frame tags/monitor | `docs/experiments/2026-10-19-industrial-v2-g3-*.md` | SOFTWARE_PASS/RTL_PASS; top/TD/hardware pending |
| V2 G3 summary | `docs/experiments/2026-10-19-industrial-v2-g3-summary.md` | BLOCKED; internal latency only |
| V2 G4 motion model/RTL | `docs/experiments/2026-10-19-industrial-v2-g4-*.md` | SOFTWARE_PASS/RTL_PASS; top/TD/hardware pending |
| V2 G4 summary | `docs/experiments/2026-10-19-industrial-v2-g4-summary.md` | BLOCKED; 160x120 history QoR not measured |
| V2 G5 sort model/RTL | `docs/experiments/2026-10-19-industrial-v2-g5-*.md` | SOFTWARE_PASS/RTL_PASS/virtual actuator; GPIO pending |
| V2 G5 summary | `docs/experiments/2026-10-19-industrial-v2-g5-summary.md` | BLOCKED; no real mechanical closure |
| V2 G6 AWB audit/model/RTL | `docs/experiments/2026-10-19-industrial-v2-g6-*.md` | SOFTWARE_PASS/RTL_PASS; ISP/TD/hardware pending |
| V2 G6 summary | `docs/experiments/2026-10-19-industrial-v2-g6-summary.md` | BLOCKED; no real lighting data |
| V2 G7 calibration model/RTL | `docs/experiments/2026-10-19-industrial-v2-g7-*.md` | SOFTWARE_PASS/RTL_PASS; physical calibration pending |
| V2 G7 summary | `docs/experiments/2026-10-19-industrial-v2-g7-summary.md` | BLOCKED; NOT_CALIBRATED |
| V2 G8 release audit design/plan | `docs/superpowers/specs/2026-10-19-industrial-v2-g8-release-audit-design.md`, `docs/superpowers/plans/2026-10-19-industrial-v2-g8-release-audit.md` | CREATED |
| V2 G8 strict release audit | `docs/experiments/2026-10-19-industrial-v2-g8-release-audit.json` | BLOCKED; V1 SHA PASS, visual approval PASS only |
| V2 G8 audit summary | `docs/experiments/2026-10-19-industrial-v2-g8-release-audit.md` | BLOCKED; TD/hardware/package pending |
| V2 G8 feature spine | `docs/experiments/2026-10-19-industrial-v2-g8-feature-spine.md`, `fallback/rtl/integration/industrial_v2_feature_spine.v` | SIM_PASS; formal top/TD pending |
| V2 G8 ISP stream adapters | `docs/experiments/2026-10-19-industrial-v2-g8-stream-adapters.md`, `fallback/rtl/integration/motion_grid_adapter_96.v`, `fallback/rtl/integration/frame_stats_96.v` | SIM_PASS; formal CSI/ISP wiring pending |
| V2 G8 result CDC | `docs/experiments/2026-10-19-industrial-v2-g8-result-cdc.md`, `fallback/rtl/integration/industrial_v2_result_cdc.v` | SIM_PASS; formal display candidate connected, TD pending |
| V2 G8 formal display wiring candidate | `docs/experiments/2026-10-19-industrial-v2-g8-formal-display-wiring.md`, `fallback/rtl/integration/industrial_v2_display_tracking.v`, `fallback/td_source/design_top_wrapper.v` | STATIC/SIM PASS; source-side seven-feature integration, TD and hardware pending |
| V2 G8 TD candidate attempt | `docs/experiments/2026-10-19-industrial-v2-g8-td-candidate-attempt.md`, `work/td_industrial_formal_display/td_project/camera_to_dsi_display_Runs/syn_1/flow_exec.log` | INCOMPLETE at `syn_1` Map Gate; no QoR/Bitstream |
