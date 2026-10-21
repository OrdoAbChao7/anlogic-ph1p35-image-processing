# Industrial V2 — timing-closed board-test candidate (r2)

Device: Anlogic PH1P35MDG324, speed grade 3
Tool: Tang Dynasty 6.2.168116
Flow: `industrial_v2_fixed_seed.tcl` (TD DefaultFlow + `set_param place seed 1`)

> **r2 supersedes r1.** r1 (`../candidate-industrial-v2-timing-closed/`) passed at
> Setup +0.137 ns. r2 adds E4 and passes at **+0.644 ns** — 4.7x the margin on
> every clock, with fewer slices. r1 is kept only as a rollback reference because
> r2 changes the detector, which is the most safety-critical module.

## Status

| Level | State |
|---|---|
| RTL_VERIFIED | **YES** — E1, E2 and E4 each passed cycle-accurate ModelSim differentials against the frozen AWB-Lite baseline (0 mismatches) |
| TIMING_PASS | **YES** — full Route, Setup WNS **+0.644 ns**, TNS **0**, Hold WNS **+0.021 ns**, TNS **0**, 0 violating endpoints |
| BITSTREAM_READY | **YES** — generated from the routed database |
| READY_FOR_BOARD_TEST | **YES** — this package |
| HARDWARE_PASS | **NO** — never downloaded, no board connected |

## Bitstream

| File | Bytes | SHA-256 |
|---|---:|---|
| `camera_to_dsi_display.bit` | 1,789,539 | `E6BA3DA87DABF82907F3DB1B4FAC18A9E8350A43917F3D5E6DA64A0A35617C36` |
| `camera_to_dsi_display_compress.bit` | 1,504,689 | `1B7E853FAE95BE4E08029F37E5BAE7FD4C727F280D908BE6C56490FA5DCEE471` |

From `camera_to_dsi_display_pr.db`
`C4217862BBD77A400A70CA7A036AEAFAACD566CC64342B7946571CDFE7F6966E`,
the routed database of this build. `bitgen` exited 0 with empty stderr.

## Changes relative to the frozen AWB-Lite baseline

Five RTL files, three structural changes, each verified independently before
integration:

**E1 — MIPI BBox pre-computation** (`dimension_calibrator.v`,
`industrial_v2_feature_spine.v`, `design_top_wrapper.v`)
`USE_BBOX_PIPELINE` registers the BBox geometry/area operands in the free cycle
between the detector commit and the result event. Publication edge, frame
association, reset and all eight outputs unchanged (1,058-check differential).

**E2 — HDMI/OSD three-stage overlay pipeline** (`industrial_osd_overlay.v`)
Coordinate decode → character/logo ROM → glyph + RGB select, with
`I_rgb/I_de/I_hsync/I_vsync` delayed by the same three cycles. Every (x,y)
emits the identical pixel (2,475,199-cycle differential over two full frames).

**E4 — MIPI parallel four-pixel group statistics** (`color_detect_96_v2.v`)
The four-iteration serial accumulation loop becomes popcount + lowest/highest
set bit + one compare per statistic. Provably the same fixed point
(701,440-check differential: 691,200 AXI-Stream beats, 3 frames, 3 detections,
max_area 162,327, explicit X-guard).

No feature was disabled to obtain timing closure. AWB remains off exactly as in
the inherited AWB-Lite baseline (`FEATURE_MATRIX.md`).

## Contents

```
camera_to_dsi_display.bit          the bitstream
camera_to_dsi_display_compress.bit compressed variant
SHA256SUMS                         every file in this package
INPUTS.sha256                      239 build inputs (manifest 87683345...)
FEATURE_MATRIX.md                  what is enabled / reduced / inhibited
TIMING_REPORT.md                   route QoR, per-clock margins, coverage analysis
BOARD_TEST.md                      download and acceptance procedure
evidence/                          raw TD reports and the bitgen parameters
```

## Margins (vs r1)

| Clock | Period | r1 Setup WNS | **r2 Setup WNS** |
|---|---:|---:|---:|
| MIPI_RX_BYTE_CLK | 9.660 ns | +0.154 | **+0.755** |
| HDMI_PIXEL_CLK | 13.333 ns | +0.137 | **+0.644** |
| ddr2/usr_clk | 15.000 ns | +1.428 | **+2.628** |
| all others | — | ≥ +1.292 | **≥ +1.364** |

## Known limitations

- Margins are healthy but finite; ChipWatcher debug insertion still requires a
  rebuild and re-timing.
- STA coverage 96.54 %; the gap is fully enumerated in
  `evidence/check_timing_route.txt` and analysed in `TIMING_REPORT.md`.
- Nothing here is a hardware result.
