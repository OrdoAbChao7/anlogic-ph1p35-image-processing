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
