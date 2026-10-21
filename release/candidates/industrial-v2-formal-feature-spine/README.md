# Industrial Vision V2 formal feature-spine candidate

Status: `CANDIDATE_ONLY` — full TD synthesis, P&R, STA and Bitgen passed for the formal seven-feature integration. Hardware acceptance and final release audit are still open.

Target: `HX1P35A / PH1P35MDG324`  
TangDynasty: `v6.2.168116`

Artifacts:

- `camera_to_dsi_display_compress.bit` — SHA-256 `60aea582cff6fa2d5a03eaa5f1d9aab4bdc142371af86053d04f8acf40e9ebc1`
- `route.qor` — Setup WNS `+100 ps`, Hold WNS `+20 ps`, TNS `0`, failed endpoints `0`
- `final_timing.rpt`
- `industrial-v1-manifest.json` — provenance manifest emitted by the existing TD build entrypoint

Resource snapshot: Slice `18261/21216 (86.07%)`, RAM `43`, DSP `24`, DRAMHARDCON `229`.

The formal top now includes the V2 feature spine, motion-grid and frame-statistics adapters, tracking/latency/motion/AWB/calibration/sort RTL, and staged result CDC. Candidate calibration constants are software-contract values only; sort arm is held low pending official GPIO/electrical and actuator evidence.

The TD log reported `PHY-5079 CRITICAL-WARNING` and `PHY-5088` clock-analyzer warnings. No board, SC520CS, HDMI, cold-reset, long-stability, physical calibration, performance, or actuator acceptance is bound to this candidate. Do not treat it as the final V2 release.
