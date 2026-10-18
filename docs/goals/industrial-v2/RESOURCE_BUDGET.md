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
