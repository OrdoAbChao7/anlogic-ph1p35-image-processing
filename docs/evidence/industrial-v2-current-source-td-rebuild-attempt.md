# V2 current-source TD build

Date: `2026-10-19`  
Status: `TD_PASS_CANDIDATE`

## Command

```text
python -B scripts/build_industrial_td.py --td-exe E:/Projects/FPGA/.tools/td/app/bin/td_commands_prompt.exe --flow-tcl E:/Projects/FPGA/.tools/td/app/doc/scripts/DefaultFlow.tcl --input-package fallback/td_package --video-rtl fallback/rtl/video/video_cartoon_region_fill.v --release-dir release/candidates/industrial-v2-current --work-project work/td_industrial_v2_current
```

The build used the current V2 worktree and an isolated TD project. The TD executable and default Flow were supplied explicitly because `.tools` is external to this worktree.

## Observed result

- Synthesis completed and emitted an intermediate gate QoR report; its timing was `Setup WNS -1099 ps`, `TNS -6724 ps`, `26` setup endpoints, and `Hold WNS +114 ps`.
- Physical design completed after the initial process-status observation and produced `route.qor`, `final_timing.rpt`, a provenance manifest, and a Bitstream.
- Final route QoR: Slice `18484/21216 (87.12%)`, RAM `43`, DSP `24`, DRAMHARDCON `229`, Setup WNS `+127 ps`, Hold WNS `+20 ps`, TNS `0/0`, violated endpoints `0/0`.
- Bitstream: `release/candidates/industrial-v2-current/camera_to_dsi_display_compress.bit`, SHA-256 `a39394977f8902f975ae74a4b8926bec4873fac9fc2065c16da48e79f5980c7c`.

This is the current-source default-Flow candidate. The separate `industrial-v2-clock-detail-seed1` run remains a diagnostic warning-audit candidate and is not used as the default release artifact.

## Evidence boundary

This candidate does not change the hardware status. It is TD/STA/Bitgen evidence only; the resource target, PHY warning closure, fixed-seed reproducibility, hardware behavior, reset/long-run, performance and actuator gates remain open.
