# Industrial Vision V2 candidate package

Status: `CANDIDATE_ONLY`. This package contains one seven-feature V2 Bitstream and its TD reports. It is not hardware-accepted and must not be marked as the final release.

Target: `HX1P35A / PH1P35MDG324`  
TangDynasty: `v6.2.168116`  
Bitstream: `industrial-v2.bit`  
SHA-256: `a39394977f8902f975ae74a4b8926bec4873fac9fc2065c16da48e79f5980c7c`

The source-state build is recorded in `manifest.json` and `release/candidates/industrial-v2-current/`. This package uses the official `DefaultFlow.tcl`; no RTL, PLL, pin constraint, or timing exception was changed for this build.

Measured TD result: Slice `18484/21216 (87.12%)`, RAM `43`, DSP `24`, DRAMHARDCON `229`, Setup WNS `+127 ps`, Hold WNS `+20 ps`, TNS `0/0`, violated endpoints `0/0`.

Open gates remain: the initial Slice budget target (`<=85%`) is exceeded, PHY-5016/5060/5079/5088 warning closure, byte-identical rebuild reproducibility, frozen V1 contract drift, board download and hardware function matrix, cold/hot reset and long-run stability, physical performance, and external actuator acceptance. These gaps must not be interpreted as successful hardware validation.

See `manifest.json`, `DefaultFlow.tcl`, `route.qor`, `final_timing.rpt`, and `td-reports/` for provenance and build evidence.
