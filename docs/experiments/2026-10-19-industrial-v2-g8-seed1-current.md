# V2 G8 current-source fixed-seed candidate

## 结果

当前 V2 工作树使用官方 TangDynasty `DefaultFlow.tcl` 和 `--place-seed 1` 完成隔离综合、布局布线、STA 与 Bitgen。候选通过最终 QoR，但重复固定 seed 构建仍产生不同 Bitstream，因此本记录关闭资源目标，不关闭可复现构建门禁。

## 构建输入

- Worktree: `E:/Projects/FPGA-v2`
- Source commit at build: `98801ed381934ba665573fd6c15026c18c33a289`
- Target: `HX1P35A / PH1P35MDG324`
- TangDynasty: `6.2.168116`
- Flow: `E:/Projects/FPGA/.tools/td/app/doc/scripts/DefaultFlow.tcl`
- Placement seed: `1`
- Isolated project: `work/td_industrial_v2_seed1_current/`

## Final QoR

| Metric | Result |
|---|---:|
| Slice | `17125 / 21216 (80.72%)` |
| RAM / DSP / DRAMHARDCON | `43 / 24 / 229` |
| Setup WNS / TNS / violated endpoints | `+104 ps / 0 / 0` |
| Hold WNS / TNS / violated endpoints | `+20 ps / 0 / 0` |
| Bitstream | `release/candidates/industrial-v2-seed1-current/camera_to_dsi_display_compress.bit` |
| Bitstream SHA-256 | `d6e6a7e12ef7558834904dcc8d2783d5fda827b7fe11c6e407b0119fc3ce1c0d` |

## Boundary

The run still reports the previously audited `PHY-5016` and `PHY-5060` clock warnings. No board, SC520CS, HDMI, cold-reset, long-run, physical performance, or actuator evidence is attached. The release package remains `CANDIDATE_ONLY`.
