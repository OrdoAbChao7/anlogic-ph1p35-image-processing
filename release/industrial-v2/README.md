# Industrial Vision V2 candidate package

Status: `CANDIDATE_ONLY`. This package contains one seven-feature V2 Bitstream and its TD reports. It is not hardware-accepted and must not be marked as the final release.

Target: `HX1P35A / PH1P35MDG324`  
TangDynasty: `v6.2.168116`  
Bitstream: `industrial-v2.bit`  
Placement seed: `1`;
SHA-256: `d6e6a7e12ef7558834904dcc8d2783d5fda827b7fe11c6e407b0119fc3ce1c0d`

The source-state build is recorded in `manifest.json` and `release/candidates/industrial-v2-seed1-current/`. This package uses the official `DefaultFlow.tcl` with placement seed `1`; no RTL, PLL, pin constraint, or timing exception was changed for this build.

Measured TD result: Slice `17125/21216 (80.72%)`, RAM `43`, DSP `24`, DRAMHARDCON `229`, Setup WNS `+104 ps`, Hold WNS `+20 ps`, TNS `0/0`, violated endpoints `0/0`.

Open gates remain: fixed-seed builds are not byte-identical across repeated runs, PHY-5016/5060/5079/5088 warning closure, frozen V1 contract drift, board download and hardware function matrix, cold/hot reset and long-run stability, physical performance, and external actuator acceptance. These gaps must not be interpreted as successful hardware validation.

See `manifest.json`, `DefaultFlow.tcl`, `route.qor`, `final_timing.rpt`, and `td-reports/` for provenance and build evidence.
