# Industrial Vision V2 current-source TD candidate

Status: `TD_PASS_CANDIDATE` — the current V2 worktree completed the official TD synthesis, physical design, STA and Bitgen flow in an isolated project. Hardware acceptance and final release gates remain open.

Target: `HX1P35A / PH1P35MDG324`  
TangDynasty: `v6.2.168116`  
Flow: official `DefaultFlow.tcl`  
Bitstream SHA-256: `a39394977f8902f975ae74a4b8926bec4873fac9fc2065c16da48e79f5980c7c`

Final QoR: Slice `18484/21216 (87.12%)`, RAM `43`, DSP `24`, DRAMHARDCON `229`, Setup WNS `+127 ps`, Hold WNS `+20 ps`, TNS `0/0`, violated endpoints `0/0`.

The official default-Flow candidate above is retained as an unseeded reference. The fixed-seed candidate in `release/candidates/industrial-v2-seed1-current/` measures Slice `17125/21216 (80.72%)`, Setup WNS `+104 ps`, Hold WNS `+20 ps`, and Bitstream SHA-256 `d6e6a7e12ef7558834904dcc8d2783d5fda827b7fe11c6e407b0119fc3ce1c0d`. Fixed-seed repeated builds remain byte-different, so this is a resource-pass candidate rather than reproducibility closure.

PHY-5016/5060/5079/5088 warning closure, frozen V1 contract drift, hardware download/function evidence, reset/long-run, performance, and actuator acceptance are still open.
