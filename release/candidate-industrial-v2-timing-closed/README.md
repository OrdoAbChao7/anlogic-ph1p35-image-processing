# Industrial V2 — timing-closed board-test candidate

Device: Anlogic PH1P35MDG324, speed grade 3
Tool: Tang Dynasty 6.2.168116
Flow: `industrial_v2_fixed_seed.tcl` (TD DefaultFlow + `set_param place seed 1`)

## Status

| Level | State |
|---|---|
| RTL_VERIFIED | **YES** — E1 and E2 each passed cycle-accurate ModelSim differentials against the frozen AWB-Lite baseline (0 mismatches) |
| TIMING_PASS | **YES** — full Route, Setup WNS **+0.137 ns**, TNS **0**, Hold WNS **+0.020 ns**, TNS **0**, 0 violating endpoints in both checks |
| BITSTREAM_READY | **YES** — `camera_to_dsi_display.bit` generated from the routed database |
| READY_FOR_BOARD_TEST | **YES** — this package |
| HARDWARE_PASS | **NO** — never downloaded, no board connected in this session |

## Bitstream

| File | Bytes | SHA-256 |
|---|---:|---|
| `camera_to_dsi_display.bit` | 1,789,539 | `ADD2DC46403670C279CADCE2E051F79B83EA9F2BBD1F4E78E7FBB7EB5606BC8C` |
| `camera_to_dsi_display_compress.bit` | 1,503,089 | `8F031B67A5F739C6BD5D42CB7180B293B1E8664BD9F1C7F0E2940169974F47AA` |

Both were produced by `bitgen -bit camera_to_dsi_display.bit` from
`camera_to_dsi_display_pr.db` (SHA-256 `7BCFEED69B469230B1515C6DA226917DD1C6CD65ACDD100C176B79D15F7B99B1`),
the routed database of the build that reported +0.137 ns. `bitgen` exited 0 with
empty stderr; `.bitgen.end.f` is present. See `evidence/.bitgen_param.f` for the
exact bitgen options.

**Use the uncompressed file** unless the download tool specifically needs the
compressed variant.

## What changed relative to the frozen AWB-Lite baseline

Only three RTL files, in two structurally separate changes:

**E1 — MIPI (`dimension_calibrator.v`, `industrial_v2_feature_spine.v`,
`design_top_wrapper.v`)**
Adds `USE_BBOX_PIPELINE` (default 0). The production spine sets it to 1, which
registers the BBox geometry/area operands one clock before `I_result_valid`
arrives and lets the result stage consume the registered copies. Publication
edge, frame association, reset, invalid/zero-geometry handling and all eight
outputs are unchanged — proven by a 1,058-check cycle-differential that also
demonstrates the pipeline register is real (not folded).

**E2 — HDMI/OSD (`industrial_osd_overlay.v`)**
Splits the overlay decision into three register stages (coordinate decode →
character/logo ROM → glyph + RGB select) and delays `I_rgb/I_de/I_hsync/I_vsync`
by the same three cycles. Every `(x,y)` emits the identical pixel; only the
constant latency changed — proven by 2,475,199 cycle comparisons over two full
1280x720 frames.

No feature was disabled to obtain timing closure. AWB remains off exactly as in
the inherited AWB-Lite baseline (see `FEATURE_MATRIX.md`).

## Contents

```
camera_to_dsi_display.bit          the bitstream
camera_to_dsi_display_compress.bit compressed variant
SHA256SUMS                         every file in this package
INPUTS.sha256                      239 build inputs (sources, constraints, project, flow)
FEATURE_MATRIX.md                  what is enabled / reduced / inhibited
TIMING_REPORT.md                   route QoR, per-clock margins, coverage analysis
BOARD_TEST.md                      download and acceptance procedure
evidence/                          raw TD reports and the bitgen parameters
```

## Known limitations

- Margins are positive but thin: **+0.137 ns** on HDMI (13.333 ns) and
  **+0.154 ns** on MIPI (9.660 ns). Sign-off is at both slow and fast corners
  with CRPR enabled, so the pass is real, but there is little headroom for
  follow-on changes.
- STA coverage is 96.56 %. The 3.44 % is fully enumerated in
  `evidence/check_timing_route.txt` and analysed in `TIMING_REPORT.md`; no
  unconstrained internal path exists at either critical clock.
- Nothing here is a hardware result.
