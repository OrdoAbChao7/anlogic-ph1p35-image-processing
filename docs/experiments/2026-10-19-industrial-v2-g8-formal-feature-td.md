# Industrial Vision V2 G8 formal feature-spine TD candidate

## Scope

This experiment binds the seven V2 upgrades to the formal TD top-level candidate. The post-AWB four-pixel stream is exported from `fallback/td_source/isp/isp_top.v`; `fallback/td_source/design_top_wrapper.v` feeds that stream into the 160x120 motion sampler and frame-statistics adapter, runs the source-domain `industrial_v2_feature_spine`, and transports its staged atomic result through `industrial_v2_result_cdc` into the HDMI domain.

The source list and TD project patch are maintained by `scripts/build_industrial_td.py`. The feature spine includes tracking/history, latency/frame tags, fixed-grid motion difference, frame-statistics AWB control, candidate calibration/shape checking, and safe sort control. The sort arm input is held low because no official GPIO/electrical actuator contract is available.

Calibration constants are the software-contract candidate values (60 mm / 120 px, 20 mm / 80 px reference, Q16.16 scales `32768` and `16384`, occupancy minimum `200`, aspect range `320..448`). They are not physical workcell calibration evidence.

## Verification commands

```text
python -B -m pytest -q work/tests/test_v2_formal_feature_integration.py work/tests/test_v2_formal_display_wiring.py work/tests/test_v2_result_cdc_contract.py
E:/Projects/FPGA/.tools/iverilog/bin/iverilog.exe -g2012 -s industrial_v2_feature_spine ...
python -B scripts/build_industrial_td.py --td-exe E:/Projects/FPGA/.tools/td/app/bin/td_commands_prompt.exe --flow-tcl E:/Projects/FPGA/.tools/td/app/doc/scripts/DefaultFlow.tcl --input-package fallback/td_package --work-project work/td_industrial_v2_formal_feature_spine --release-dir release/candidates/industrial-v2-formal-feature-spine
```

The integration contract tests passed `7/7`; the independent feature-spine compile exited `0`. The full TD run completed synthesis, physical design, STA and compressed Bitgen with exit code `0`.

## TD/QoR evidence

| Item | Result |
|---|---|
| Device | `PH1P35MDG324` |
| TD version | `v6.2.168116` |
| Setup WNS | `+100 ps` |
| Setup TNS / failed endpoints | `0 / 0` |
| Hold WNS | `+20 ps` |
| Hold TNS / failed endpoints | `0 / 0` |
| Slices | `18261/21216 = 86.07%` |
| RAM / DSP | `43 / 24` |
| DRAMHARDCON | `229` |
| Bitstream size | `1,367,985 bytes` |
| Bitstream SHA-256 | `60aea582cff6fa2d5a03eaa5f1d9aab4bdc142371af86053d04f8acf40e9ebc1` |

Evidence files:

- `release/candidates/industrial-v2-formal-feature-spine/camera_to_dsi_display_compress.bit`
- `release/candidates/industrial-v2-formal-feature-spine/route.qor`
- `release/candidates/industrial-v2-formal-feature-spine/final_timing.rpt`
- `release/candidates/industrial-v2-formal-feature-spine/industrial-v1-manifest.json`

## Warnings and boundaries

TD reported `PHY-5079 CRITICAL-WARNING` for one clock net using local routing resources and `PHY-5088` clock-analyzer warnings for clock buffers driving non-clock sinks/other clock nets. Timing is positive, but the warning/CDC/constraint audit remains open and this is not a final release gate pass.

No board download, SC520CS camera run, HDMI visual run, physical calibration, cold-reset/long-stability test, performance measurement, or mechanical actuator test was performed. This is the best complete formal V2 candidate, not `RELEASED`.
