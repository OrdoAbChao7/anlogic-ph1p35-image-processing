# EXPERIMENTS

Every experiment is pre-registered before execution and records its own input
manifest, command line, raw logs and SHA-256. Experiments are isolated copies of
`work/awblite_baseline/`; the baseline itself is never modified.

---

## E1 — MIPI: BBox pre-computation pipeline in `dimension_calibrator`

| Field | Value |
|---|---|
| Status | **REGISTERED** → running |
| Directory | `work/e1_mipi_bbox_pipe/` |
| Target cone | `color_detect_96_v2.O_xmin_reg[0] → dimension_calibrator.O_shape_valid_reg`, slack −2.539 ns, 12.008 ns, 9 levels |

### Question
Does registering the BBox geometry/area arithmetic one cycle before
`I_result_valid` (which arrives exactly one cycle after the BBox commit) shorten
the worst MIPI path below 0 ns **without changing any published output or its
commit edge**?

### Verified premise (not an assumption)
`color_detect_96_v2` commits `O_xmin/O_xmax/O_ymin/O_ymax/O_area` at edge T.
`defect_classifier` toggles `O_result_toggle` at edge T+1 (it samples
`O_frame_sync` one cycle late). `ind_v2_toggle_d` delays the toggle by one more
register so `ind_result_event = toggle ^ toggle_d` is high during **cycle T+1
only**. `dimension_calibrator` therefore samples at edge T+2, and cycle T is a
free cycle where the final BBox is already present with `result_valid = 0`.

### Single change
Add a compile-time parameter `USE_BBOX_PIPELINE` (default **0**) to
`dimension_calibrator`. When 1, an extra register stage captures
`width_px, height_px, bbox_valid, width_product, height_product,
occupancy_product, aspect products` at every rising edge, and the
`I_result_valid` result stage consumes the registered copies. When 0 the module
elaborates to the frozen baseline expression exactly.
`industrial_v2_feature_spine` gains a matching parameter (default 0);
`design_top_wrapper` sets it to 1 for the production spine instance only.

### Semantic contract
- `O_valid/O_invalid/O_dimension_valid/O_shape_valid/O_width_mm_q16_16/
  O_height_mm_q16_16/O_occupancy_q8/O_aspect_q8` committed on **the same edge**
  as baseline (edge T+2 relative to the BBox commit at edge T).
- Same frame ID: every operand consumed belongs to the frame committed at edge T.
- Reset, `!I_calibration_valid`, inverted/zero BBox, `occupancy_min_q8 > 256`,
  `aspect_max_q8 = 16'hffff`, and dynamic (non-static) configuration paths keep
  their baseline behaviour.
- No new CDC: all new registers are on `I_clk` (= `S_csi_rx_clk` =
  `MIPI_RX_BYTE_CLK`).

### Verification (cheapest sufficient)
1. ModelSim 2020.1 cycle-differential, baseline vs candidate, using a bench that
   drives the **real producer timing** (BBox change at edge T, `I_result_valid`
   at cycle T+1). Must cover: normal, single-pixel BBox, full-frame BBox,
   inverted BBox, zero-area, `calibration_valid=0`, back-to-back results,
   reset mid-stream, and static vs dynamic configuration.
2. Matched module `opt_gate` A/B (same SDC, same settings, same wrapper).

### Exit rule (frozen)
Continue only if **all** hold:
- cycle-differential: 0 mismatches on all 8 outputs;
- module Gate critical-cone delay improves by **≥ 1.0 ns**;
- module `#slice*` grows by **≤ 10 %**;
- no new DSP/ERAM over-quota;
- no unexplained timing-unconstrained endpoints introduced.

Otherwise: record the measured reason, reject the candidate, do not retry the
same expression.

### Cost / backout
One deterministic regression + at most one matched Gate pair. Candidate stays in
`work/e1_mipi_bbox_pipe/`; baseline untouched.

### Results

**Step 1 — ModelSim 2020.1 cycle-differential: PASS.**
`work/e1_mipi_bbox_pipe/sim/` (`tb_e1_bbox_pipe_diff.v`, `transcript.log`).
Stimulus reproduces the real producer timing (BBox commit at edge T, result
event in cycle T+1). Six DUT instances compared per cycle: baseline RTL,
candidate with `USE_BBOX_PIPELINE=0`, candidate with `=1`, each in static and
dynamic configuration.

```
TB_E1_BBOX_PIPE_DIFF_PASS checks=1058 frames=528
PROVE_PIPELINE_IS_REAL base=100800000004000000000100 cand_pipe=160078000000280000c80180 (differ as expected)
Errors: 0, Warnings: 0
```

1057 contract-compliant checks (528 frames + idle cycles + all boundary cases:
1x1, inverted BBox, full-frame, area clamp, occupancy 199/200/201/256/257,
aspect min/max edges, calibration invalid, reset, 512-frame deterministic sweep)
plus 1 contract-sensitivity check proving the pre-computation register is real
(under deliberately non-compliant stimulus the pipelined candidate follows the
previous cycle's operands while the baseline follows the current cycle's).

**Step 2 — matched TD `opt_gate` A/B: PASS.**

Same device/speed/SDC/settings; `.prj` SHA-256 identical in both arms
(`2C151C96E6CBF7D028BAB836F15F001579518841A04CE51E128187ACFAE5B03B`);
`settings.cfg` identical (`5D80F006DDFEC5F0176407777EE71B5C73DE2C63B243AA08C5B7EDF63FD5AC35`).
Wrappers differ only by the `.USE_BBOX_PIPELINE(1)` parameter.
Full input manifest: `work/e1_mipi_bbox_pipe/td_gate/INPUTS.sha256`.

| Metric | Baseline | Candidate | Delta |
|---|---:|---:|---:|
| Setup WNS / TNS | −403 / −403 ps | **+2289 / 0 ps** | **+2692 ps** |
| Setup violating endpoints | 1 | 0 | −1 |
| Hold WNS / TNS | +502 / 0 ps | +502 / 0 ps | unchanged |
| Critical path delay | 9.999 ns | **7.176 ns** | **−2.823 ns** |
| Critical path logic levels | 8 (DSPMULT×2, ADDER×2) | 6 (DSPMULT×1) | −2 |
| Critical path endpoint | `xmax_r → O_shape_valid_reg` | `xmax_r → mult0.xa[17]` (stage-1 DSP input) | split |
| Area `#slice*` | 133 | 140 | +7 (**+5.26 %**) |
| LUTs (QoR) | 81 | 134 | +53 |
| Registers (QoR) | 68 | 115 | +47 |
| DSP / ERAM | 4 / 0 | 4 / 0 | unchanged |
| STA coverage | 95.54 % | 94.90 % | −0.64 pp |
| `no_clock`/`no_input_delay`/unconstrained messages | none | none | — |

Exit rule: path improved by 2.692 ns (≥1.0 ns required) ✓; `#slice*` +5.26 %
(≤10 % required) ✓; no new DSP/ERAM ✓; no unconstrained endpoints introduced ✓.

Baseline −403 ps exactly reproduces the frozen R4 module-Gate baseline, which
independently confirms the harness is the same measurement.

**Step 3 — full-top rebuild (E1 alone, no OSD change): PASS.**

`work/e1_mipi_bbox_pipe`, `run_flow_exit_e1.tcl` -> `industrial_v2_fixed_seed.tcl`
(DefaultFlow + `set_param place seed 1`), `syn_1` to `opt_gate`, then `phy_1`
`opt_place` -> `opt_route`. TD 6.2.168116, PH1P35MDG324 speed 3.

```
route_flow.status: Setup WNS 104ps TNS 0ps NUM_FEPS 0
                   Hold  WNS  21ps TNS 0ps NUM_FEPS 0
route.qor:  #slices 18359 (86.53%)  #RAMs 75  #DSPs 32  wire length 5,527,136
```

Per-clock (route, final):

| Clock | Period | Setup WNS | Setup TNS | Viol EP |
|---|---:|---:|---:|---:|
| clk0 MIPI_RX_BYTE_CLK | 9.660 ns | **+0.149** | 0 | 0 |
| clk1 HDMI_PIXEL_CLK | 13.333 ns | **+0.104** | 0 | 0 |
| clk2 ddr usr_clk | 15.000 ns | +1.190 | 0 | 0 |
| all others | — | ≥ +0.934 | 0 | 0 |

The `dimension_calibrator` cone is gone from the critical list entirely. The new
worst MIPI path is pre-existing logic inside `color_detect_96_v2`
(`stat_xmax_next -> acc_xmin`, 9.386 ns, 12 levels, 8 ADDERs), +0.149 ns.

**Caveat recorded deliberately:** the HDMI cone improved from −0.974 ns to
+0.104 ns even though E1 does not touch the OSD — that gain is placement
re-flow, not a structural fix, and is not credited to E1.

**Step 4 — E2 module Gate: PASS.**

`work/e2_osd_pipe/td_gate`, 13.333 ns HDMI clock, 100 % STA coverage in both
arms. Inputs: `work/e2_osd_pipe/td_gate/INPUTS.sha256`. Baseline OSD SHA-256
`233482A5...` matches the frozen AWB-Lite manifest; wrappers and `.prj` byte
identical between arms (module name differs only in the RTL file contents).

| Metric | Baseline | Candidate | Delta |
|---|---:|---:|---:|
| Setup WNS / TNS | −657 / −3331 ps | **+3189 / 0 ps** | **+3846 ps** |
| Setup violating endpoints | 6 | 0 | −6 |
| Hold WNS / TNS | +502 / 0 ps | +502 / 0 ps | unchanged |
| Critical path delay | 13.926 ns | **10.080 ns** | **−3.846 ns** |
| Critical path levels | 14 | 10 | −4 |
| Critical path | `x_reg[3] -> O_rgb_reg[8]` | `logo_addr_s1[9] -> logo_pixel_s2[4]` | split |
| Area `#slice*` | 2698 | **2512** | **−186 (−6.9 %)** |
| LUTs | 3187 | 2789 | −398 |
| Registers | 201 | 327 | +126 |
| STA coverage | 100 % | 100 % | — |

Exit rule: WNS ≥ 0 ✓; `#slice*` growth ≤ 10 % ✓ (it shrank); no new
unconstrained endpoints ✓.

---

## E2 — HDMI: OSD overlay decision pipeline (registered, aligned)

| Field | Value |
|---|---|
| Status | **REGISTERED** — blocked on E1 completion |
| Directory | `work/e2_osd_pipe/` |
| Target cone | `u_industrial_osd/x_reg[2] → u_industrial_osd/O_rgb_reg[*]`, worst −0.974 ns, 14.066 ns, 14 levels, 69 % net |

### Question
Does splitting the OSD overlay decision into registered stages (coordinate/address
decode → ROM lookup + character select → glyph/colour select → RGB mux), with
`I_rgb/I_de/I_hsync/I_vsync` delayed by the same number of cycles, remove all 23
HDMI setup violations without shifting any output pixel?

### Explicitly NOT the rejected experiment
The rejected 2026-10-21 change only re-ordered the RGB mux (49 ps, +6.29 %
slices). This experiment inserts real pipeline stages and re-aligns the video
bus.

### Semantic contract
For every `(frame, x, y)` the emitted `O_rgb` must be byte-identical to baseline,
and `O_de/O_hsync/O_vsync` must keep their exact relationship to `O_rgb`
(constant additional latency only).

### Verification
ModelSim cycle-differential over ≥ 2 full frames of the default raster comparing
`O_rgb/O_de/O_hsync/O_vsync` cycle-by-cycle, **after** removing the constant
pipeline latency, plus an explicit assertion that the latency is constant.

### Exit rule (frozen)
- cycle-differential: 0 mismatches;
- module Gate: Setup WNS ≥ 0 with the 13.333 ns HDMI clock;
- `#slice*` growth ≤ 10 %;
- no new unconstrained endpoints.

### Results

**Step 1 — ModelSim 2020.1 cycle-differential: PASS.**

`work/e2_osd_pipe/sim/` (`tb_osd_pipe_diff.v`, `transcript.log`). Baseline and
candidate run side by side on the same production 1280x720 raster
(1650x750 total, 2 frames). Every cycle the candidate's
`{O_vsync, O_hsync, O_de, O_rgb}` is compared against the baseline's value from
exactly two cycles earlier, which asserts both pixel-content equality and a
constant latency delta.

```
TB_OSD_PIPE_DIFF_PASS checks=2475199 de_pixels=1843397 logo=50397 text_region=368660 vsync_rises=2
Errors: 0, Warnings: 0
```

Coverage: two full frames, 1,843,397 active pixels, 50,397 logo-region pixels,
368,660 pixels inside the text column band, four distinct `I_mode` values and
rotating pass/ng/invalid/dimension/shape snapshots across the frame boundary.

**Step 2 — matched TD `opt_gate` A/B: PASS.**

`work/e2_osd_pipe/td_gate`, 13.333 ns HDMI clock, 100 % STA coverage in both
arms. Inputs: `work/e2_osd_pipe/td_gate/INPUTS.sha256`. Baseline OSD SHA-256
`233482A5...` matches the frozen AWB-Lite manifest; wrappers and `.prj` byte
identical between arms.

| Metric | Baseline | Candidate | Delta |
|---|---:|---:|---:|
| Setup WNS / TNS | −657 / −3331 ps | **+3189 / 0 ps** | **+3846 ps** |
| Setup violating endpoints | 6 | 0 | −6 |
| Hold WNS / TNS | +502 / 0 ps | +502 / 0 ps | unchanged |
| Critical path delay | 13.926 ns | **10.080 ns** | **−3.846 ns** |
| Critical path levels | 14 | 10 | −4 |
| Critical path | `x_reg[3] -> O_rgb_reg[8]` | `logo_addr_s1[9] -> logo_pixel_s2[4]` | split |
| Area `#slice*` | 2698 | **2512** | **−186 (−6.9 %)** |
| LUTs | 3187 | 2789 | −398 |
| Registers | 201 | 327 | +126 |

Exit rule: WNS ≥ 0 ✓; `#slice*` growth ≤ 10 % ✓ (it shrank); no new
unconstrained endpoints ✓.


---

## E3 — Integrate E1 + E2, full rebuild, bitgen

| Field | Value |
|---|---|
| Status | **COMPLETE — TIMING_PASS + BITSTREAM_READY** |
| Directory | `work/e3_integrated/` (assembled by `assemble_e3.sh`) |
| Inputs | 239 files, `INPUTS.sha256` manifest `207B1AEF...5C8FB89` |

E1 and E2 were each validated independently before integration; the integrated
tree changes exactly four source files relative to the frozen baseline
(`dimension_calibrator.v`, `industrial_v2_feature_spine.v`,
`design_top_wrapper.v`, `industrial_osd_overlay.v`) and nothing else —
`assemble_e3.sh` fails closed if `isp_top.v`, `motion_diff_160.v`, the SDC or
`pin.adc` differ from the baseline.

### Full Route

| Metric | Baseline (V0) | E1 only | **E3** |
|---|---:|---:|---:|
| Setup WNS / TNS | −2.539 / −14.705 ns | +0.104 / 0 ns | **+0.137 / 0 ns** |
| Setup violating endpoints | 24 | 0 | **0** |
| Hold WNS / TNS | +0.020 / 0 ns | +0.021 / 0 ns | **+0.020 / 0 ns** |
| Slices | 18,421 | 18,359 | **18,248 (86.01 %)** |
| ERAM / DSP | 75 / 32 | 75 / 32 | **75 / 32** |
| Wire length | 5,233,152 | 5,527,136 | **5,127,376** |
| STA coverage | 96.67 % | 96.67 % | 96.56 % |

Per clock: MIPI **+0.154 ns**, HDMI **+0.137 ns**, DDR usr_clk +1.428 ns, all
others ≥ +1.292 ns. Place already reported +1,063 ps (FMAX 116.32 MHz); routing
cost 926 ps and `fix_hold` closed hold.

### Bitgen

`bitgen -bit camera_to_dsi_display.bit` on `camera_to_dsi_display_pr.db`,
exit 0, empty stderr, `.bitgen.end.f` present.

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `camera_to_dsi_display.bit` | 1,789,539 | `ADD2DC46403670C279CADCE2E051F79B83EA9F2BBD1F4E78E7FBB7EB5606BC8C` |
| `camera_to_dsi_display_compress.bit` | 1,503,089 | `8F031B67A5F739C6BD5D42CB7180B293B1E8664BD9F1C7F0E2940169974F47AA` |

### Constraint-coverage probe

`check_timing -file ... -verbose` on the routed DB succeeded (exit 0) and
enumerated the whole 3.44 % coverage gap: 1 unconstrained generated clock
(`u_uicfgcs520/u_i2c/scl_clk`, 24 MHz/240 ≈ 99.2 kHz), 34 inputs / 65 outputs
without I/O delay (hard-IP pads and housekeeping), 4 benign dummy nodes,
0 invalid constraints, 0 combinational loops, 0 unconstrained internal paths at
either critical clock.

A follow-up probe that *added* `create_clock` for `scl_clk` to the imported
routed DB crashed TD with `0xC0000005`. That variant is recorded as a TD defect
and must not be retried; the shipped artifacts were re-hashed afterwards and are
unchanged.

### Deliverable

`release/candidate-industrial-v2-timing-closed/` with `README.md`,
`TIMING_REPORT.md`, `FEATURE_MATRIX.md`, `BOARD_TEST.md`, `INPUTS.sha256`,
`SHA256SUMS` and `evidence/`.

---

## Rejected earlier (inherited, do not repeat)

| Direction | Evidence |
|---|---|
| AWB `D = N − M×G` | Gate WNS −2.588 ns, DSP cost up |
| Static Q8=200 occupancy comparator | +0.837 ns (< 1.0 ns gate), `#slice*` +57.1 % |
| OSD RGB mux reorder | +49 ps, `#slice*` +6.29 % |
| Blind `RAM_STYLE` on cartoon cache | repeated `SYN-5041` |
| Synchronous palette ROM (isolated) | promising but `HDL-5314`/`SYN-5025`/`SYN-5105` and 2 unexplained ERAMs unresolved; `check_timing` CLI crashed 0xC0000005 |
