# Industrial Vision V2 current-source TD candidate

Status: `TD_PASS_CANDIDATE` — the current V2 worktree completed the official TD synthesis, physical design, STA and Bitgen flow in an isolated project. Hardware acceptance and final release gates remain open.

Target: `HX1P35A / PH1P35MDG324`  
TangDynasty: `v6.2.168116`  
Flow: official `DefaultFlow.tcl`  
Bitstream SHA-256: `a39394977f8902f975ae74a4b8926bec4873fac9fc2065c16da48e79f5980c7c`

Final QoR: Slice `18484/21216 (87.12%)`, RAM `43`, DSP `24`, DRAMHARDCON `229`, Setup WNS `+127 ps`, Hold WNS `+20 ps`, TNS `0/0`, violated endpoints `0/0`.

The initial Slice budget target of `<=85%` is not met. PHY-5016/5060/5079/5088 warning closure, byte-identical fixed-seed reproducibility, frozen V1 contract drift, hardware download/function evidence, reset/long-run, performance, and actuator acceptance are still open.
