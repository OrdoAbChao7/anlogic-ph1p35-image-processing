# Industrial Vision V2 Resource Budget

## Frozen V1 baseline (`project`)

| Metric | Baseline | V2 control |
|---|---:|---:|
| Slice | 17,642 / 21,216 (83.15%) | Target <=85%; pause formal merge >90%; no normal release >=95% |
| RAM | 43 | Measure every candidate; no assumption of unused capacity |
| DSP | 24 / 40 | Measure every candidate; shared arithmetic preferred |
| Setup WNS | +103 ps | >=0; internal warning below +50 ps |
| Hold WNS | +20 ps | >=0 |
| Setup/Hold TNS | 0 / 0 | Must remain 0 / 0 |
| Hardware frame rate/latency | Not fully measured | Do not claim until measured |

Each feature gets an independent trial report before full integration. The final candidate is judged by the actual complete TD report, not the sum of trials.

## G1 measurement status

The mode, OSD and ROI changes have only software/RTL evidence. No TD synthesis or implementation report was produced, so Slice/RAM/DSP/WNS/TNS remain `NOT_MEASURED` for V2. The frozen V1 values above remain the only resource baseline and are not V2 results.

G2 tracker/history/overlay are also independent software/RTL units only. Their resource impact is `NOT_MEASURED` until an isolated TD trial is allowed by the baseline and top-level gates.

## G3 measurement status

G3 latency/frame-tag monitors are independent software/RTL units only. Their resource impact and timing are `NOT_MEASURED` until an isolated TD trial is allowed by the baseline and top-level gates. Physical HDMI/display E2E remains `N/A` without a controlled measurement setup.

## G4 measurement status

The independent G4 motion trial estimates one `160*120*8 = 153600-bit` history store. This is a logical capacity estimate, not a PH1P35 ERAM/Slice report. Slice/RAM/DSP/WNS/TNS remain `NOT_MEASURED` until a TD resource trial is authorized by the formal top-level and baseline gates.

## G5 measurement status

G5 adds internal event, safety and fixed-pulse control logic only. External GPIO and actuator resource/electrical impact are `NOT_MEASURED`; no pin or drive strength is inferred from this RTL.

## G6 measurement status

The independent frame-stat AWB controller uses arithmetic only; its Slice/DSP/timing impact is `NOT_MEASURED` until an isolated TD trial. Existing AWB IP/resource usage remains the frozen project baseline, not a G6 result.

## G7 measurement status

G7 uses arithmetic-only independent model/RTL candidates. Resource and timing impact are `NOT_MEASURED`; the Q16.16 calibration values are software/contract values until a physical reference and TD report freeze them.

## G8 measurement status

The formal seven-feature candidate now has a complete TD synthesis, placement, timing and Bitgen report. This is a `TD_PASS` candidate, not a released V2 package:

| Metric | Formal candidate | Gate interpretation |
|---|---:|---|
| Slice | 18,261 / 21,216 (86.07%) | Above the initial <=85% target; below the 90% pause threshold |
| RAM | 43 | Same count as the frozen V1 baseline; attribution is not isolated by feature |
| DSP | 24 | Same count as the frozen V1 baseline; attribution is not isolated by feature |
| Setup WNS/TNS | +100 ps / 0 | Timing pass; warning audit remains open |
| Hold WNS/TNS | +20 ps / 0 | Timing pass; warning audit remains open |
| Bitstream | `60aea582cff6fa2d5a03eaa5f1d9aab4bdc142371af86053d04f8acf40e9ebc1` | Candidate artifact only; no board acceptance |

Evidence: `docs/experiments/2026-10-19-industrial-v2-g8-formal-feature-td.md`, `release/candidates/industrial-v2-formal-feature-spine/route.qor`, and `release/candidates/industrial-v2-formal-feature-spine/final_timing.rpt`. The formal candidate does not close the release budget because PHY-5079/PHY-5088 warning review, hardware, long-run and physical performance evidence remain open.

A second isolated rebuild from the same source and TD input package produced Slice `18244/21216` (`85.99%`), Setup WNS `+127 ps`, Hold WNS `+20 ps`, TNS `0/0`, and Bitstream SHA-256 `f268aca98be49ccc4feef4c0d34a02976a57654740152d40f35a46e06025998f`. This confirms positive timing in the repeat run but also shows P&R variation; the two runs are retained as audit evidence and neither closes the reproducible-build or hardware gates by itself.

The fixed-seed follow-up is also not reproducible at Bitstream level. With `--place-seed 1`, two complete isolated TD builds both passed final QoR, but produced `09d2995c3cd149c442fa091be409a362b202243c29b74d624d40a073f076ef71` at Slice `17186/21216` (`81.00%`), Setup WNS `+103 ps`, and `42fd98c2c2643906f130a1ba8edb385ef0c34639466d1cdd9e45e05b6953dceb` at Slice `18260/21216` (`86.07%`), Setup WNS `+105 ps`. Both were RAM 43, DSP 24, DRAMHARDCON 229, and TNS `0/0`. The seed is therefore recorded as a reproducibility control input, not as a closed reproducibility gate. Evidence: `docs/evidence/industrial-v2-g8-fixed-seed-reproducibility.md`.
