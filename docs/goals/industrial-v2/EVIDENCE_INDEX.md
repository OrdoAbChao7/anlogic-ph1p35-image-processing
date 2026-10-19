# Industrial Vision V2 Evidence Index

| Evidence | Path | Status |
|---|---|---|
| V1 freeze and Bitstream hash | `docs/evidence/industrial-v1-hx1p35a-pin-correction-freeze.md` | BASELINE |
| V1 TD warning audit | `docs/evidence/industrial-v1-td-warning-audit.md` | OPEN warnings retained |
| V2 design | `docs/superpowers/specs/2026-10-19-industrial-v2-advanced-design.md` | CREATED |
| V2 G0/G1 plan | `docs/superpowers/plans/2026-10-19-industrial-v2-g0-g1.md` | CREATED |
| V2 G0 baseline | `docs/experiments/2026-10-19-industrial-v2-g0-baseline.md` | ACTIVE; 46/8 pytest and frozen contract drift recorded; Stage D hash gate later repaired |
| V2 G1 mode/OSD/ROI | `docs/experiments/2026-10-19-industrial-v2-g1-*.md` | SOFTWARE_PASS/RTL_PASS; TD and hardware BLOCKED |
| V2 G1 summary | `docs/experiments/2026-10-19-industrial-v2-g1-summary.md` | BLOCKED with frozen contract drift; Stage D verification now PASS |
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
| V2 G8 strict release audit | `docs/experiments/2026-10-19-industrial-v2-g8-release-audit.json` | BLOCKED; same-bitstream package and visual approval PASS, hardware/reproducibility/warning gates open |
| V2 G8 full work/tests regression | `docs/evidence/industrial-v2-g8-full-tests-log.txt` | `python -B -m pytest -q work/tests` PASS: 130 passed; strict verifier now reruns the command |
| V2 G8 audit summary | `docs/experiments/2026-10-19-industrial-v2-g8-release-audit.md` | BLOCKED; candidate package exists, final hardware/reproducibility gates pending |
| V2 G8 feature spine | `docs/experiments/2026-10-19-industrial-v2-g8-feature-spine.md`, `fallback/rtl/integration/industrial_v2_feature_spine.v` | SIM_PASS; formal top/TD pending |
| V2 G8 ISP stream adapters | `docs/experiments/2026-10-19-industrial-v2-g8-stream-adapters.md`, `fallback/rtl/integration/motion_grid_adapter_96.v`, `fallback/rtl/integration/frame_stats_96.v` | SIM_PASS; formal CSI/ISP wiring pending |
| V2 G8 result CDC | `docs/experiments/2026-10-19-industrial-v2-g8-result-cdc.md`, `fallback/rtl/integration/industrial_v2_result_cdc.v` | SIM_PASS; formal display candidate connected, TD pending |
| V2 G8 formal display wiring candidate | `docs/experiments/2026-10-19-industrial-v2-g8-formal-display-wiring.md`, `fallback/rtl/integration/industrial_v2_display_tracking.v`, `fallback/td_source/design_top_wrapper.v` | STATIC/SIM PASS; source-side seven-feature integration, TD and hardware pending |
| V2 G8 TD candidate attempt | `docs/experiments/2026-10-19-industrial-v2-g8-td-candidate-attempt.md`, `docs/evidence/industrial-v2-g8-td-candidate-attempt-log.txt` | INCOMPLETE at `syn_1` Map Gate; no QoR/Bitstream |
| V2 G8 OSD BCD timing candidate | `docs/experiments/2026-10-19-industrial-v2-g8-osd-bcd-td.md`, `release/candidates/industrial-v2-osd-bcd/` | TD/QoR/Bitgen PASS for candidate; seven-feature integration and hardware pending |
| V2 G8 formal feature-spine TD candidate | `docs/experiments/2026-10-19-industrial-v2-g8-formal-feature-td.md`, `release/candidates/industrial-v2-formal-feature-spine/`, `fallback/td_source/design_top_wrapper.v`, `fallback/td_source/isp/isp_top.v` | formal seven-feature top, TD/STA/Bitgen PASS; warning and hardware gates pending |
| V2 G8 current-source candidate package | `release/industrial-v2/README.md`, `release/industrial-v2/manifest.json`, `release/industrial-v2/industrial-v2.bit`, `release/industrial-v2/route.qor`, `release/industrial-v2/final_timing.rpt` | one seven-feature fixed-seed Bitstream packaged as `CANDIDATE_ONLY`; official DefaultFlow TD/STA/Bitgen PASS; Slice target met, reproducibility and hardware gates open |
| V2 G8 fixed-seed current candidate | `release/candidates/industrial-v2-seed1-current/` | current-source TD/STA/Bitgen PASS; Slice 80.72%, Setup WNS +104 ps, Hold WNS +20 ps; repeated fixed-seed byte identity OPEN |
| V2 G8 fixed-seed current experiment | `docs/experiments/2026-10-19-industrial-v2-g8-seed1-current.md`, `docs/evidence/industrial-v2-g8-seed1-current-log.txt` | TD_PASS_CANDIDATE; resource target met; warning/reproducibility/hardware gates OPEN |
| V2 G8 clock warning audit | `docs/evidence/industrial-v2-g8-clock-warning-audit.md`, `docs/evidence/industrial-v2-g8-clock-warning-audit-log.txt`, `docs/evidence/industrial-v2-g8-clock-warning-detail-log.txt`, `docs/experiments/2026-10-19-industrial-v2-g8-clock-detail.md` | `analyze_clock -detail` completed; source/sink locations known; PHY-5016/5060/5079/5088 remain OPEN |
| V2 G8 I2C clock-enable candidate | `docs/experiments/2026-10-19-industrial-v2-g8-i2c-clock-enable-candidate.md`, `docs/evidence/industrial-v2-g8-i2c-clock-enable-log.txt`, `release/candidates/industrial-v2-i2c-ce/` | RTL/write-read PASS; TD/STA/Bitgen PASS; `scl_clk`/PHY-5016/PHY-5088 absent, but Slice 85.89% fails resource gate; not promoted |
| V2 G8 I2C clock-enable re-probe | `docs/experiments/2026-10-19-industrial-v2-g8-i2c-clockfix-reprobe.md`, `docs/evidence/industrial-v2-g8-i2c-clockfix-reprobe-log.txt` | directed RTL PASS; fresh V2 synthesis fails at Setup WNS -1255 ps/TNS -14138 ps; not promoted |
| V2 G8 MCLK ODDR-only candidate | `docs/experiments/2026-10-19-industrial-v2-g8-mclk-oddr.md`, `docs/evidence/industrial-v2-g8-mclk-oddr-log.txt`, `release/candidates/industrial-v2-mclk-oddr-seed1/` | TD/STA/Bitgen PASS; O_cam_24m/PHY-5079 lines absent in this run, but Slice 87.29% and remaining I2C/PHY warnings reject promotion |
| V2 G8 MCLK ODDR-only seed=2 candidate | `docs/experiments/2026-10-19-industrial-v2-g8-mclk-oddr-seed2.md`, `docs/evidence/industrial-v2-g8-mclk-oddr-seed2-log.txt`, `release/candidates/industrial-v2-mclk-oddr-seed2/` | TD/STA/Bitgen PASS; Setup +104 ps, Hold +20 ps, Slice 85.79%; O_cam_24m/PHY-5079 absent but I2C/PHY warnings remain; rejected by resource gate |
| V2 G8 fixed-seed reproducibility audit | `docs/evidence/industrial-v2-g8-fixed-seed-reproducibility.md` | three complete TD builds PASS QoR; Bitstream reproducibility OPEN |
| V2 G8 single-thread determinism probe | `docs/experiments/2026-10-19-industrial-v2-g8-thread-determinism.md`, `docs/evidence/industrial-v2-g8-thread-determinism-log.txt`, `release/candidates/industrial-v2-thread1-after-commit/`, `release/candidates/industrial-v2-thread1-after-commit-2/` | two independent single-thread fixed-seed TD/STA/Bitgen runs PASS QoR but produce different Bitstreams; resource 86.55%/86.18%; reproducibility and promotion OPEN |
| V2 G8 bounded calibration width trial | `docs/evidence/industrial-v2-g8-bounded-calibration-width.md`, `fallback/rtl/inspection/dimension_calibrator.v` | RTL/TD PASS; resource reduction not demonstrated; hardware pending |
| V2 Stage D hash repair | `docs/evidence/industrial-v2-stage-d-line-ending-repair.md`, `work/algorithm_lab/exports/stage_d/stage_d_report.json` | software hardware-equivalent verification PASS; hardware/TD pending |
| V2 current-source TD build | `docs/evidence/industrial-v2-current-source-td-rebuild-attempt.md`, `docs/evidence/industrial-v2-current-source-td-rebuild-attempt-log.txt`, `release/candidates/industrial-v2-current/` | official DefaultFlow TD/STA/Bitgen PASS; unseeded reference Slice 87.12%, warning/reproducibility/hardware gates OPEN |
