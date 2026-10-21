# CURRENT_STATE

Updated: 2026-10-21 (takeover session) — **TIMING_PASS + BITSTREAM_READY achieved**

## Shipped candidate (r2, supersedes r1)

`release/candidate-industrial-v2-timing-closed-r2/`

| Artifact | Value |
|---|---|
| Bitstream | `camera_to_dsi_display.bit`, 1,789,539 B |
| Bitstream SHA-256 | `E6BA3DA87DABF82907F3DB1B4FAC18A9E8350A43917F3D5E6DA64A0A35617C36` |
| Compressed variant | `1B7E853FAE95BE4E08029F37E5BAE7FD4C727F280D908BE6C56490FA5DCEE471` |
| Routed DB | `C4217862BBD77A400A70CA7A036AEAFAACD566CC64342B7946571CDFE7F6966E` |
| Build inputs | `INPUTS.sha256` (239 files) manifest `87683345FE2B38220F5FD2016CCF3E545A88DF97FB0AC4938747F16CF08BADA8` |
| Source tree | `work/e5_detect_parallel/` |

Also published at
`E:\Projects\FPGA-v2\release\candidates\industrial-v2-timing-closed-r2\`
(`SHA256SUMS` self-verified, 0 mismatches).

r1 (`...-timing-closed/`, Setup +0.137 ns, bitstream `ADD2DC46...`) is kept as a
rollback reference because r2 changes the detector.

## Version table

| Id | Path | Contents | Setup WNS/TNS | Slices | Status |
|---|---|---|---:|---:|---|
| V0 | `work/awblite_baseline/` | frozen AWB-Lite input package | −2.539 / −14.705 ns (24 EP) | 18,421 | reference only, fails |
| E1 | `work/e1_mipi_bbox_pipe/` | V0 + MIPI BBox pre-computation | +0.104 / 0 ns (0 EP) | 18,359 | superseded |
| E2 | `work/e2_osd_pipe/` | V0 + OSD overlay pipeline | module Gate +3,189 ps | module only | module Gate PASS |
| E3 | `work/e3_integrated/` | V0 + E1 + E2 | +0.137 / 0 ns (0 EP) | 18,248 | r1, rollback reference |
| E4 | `work/e4_detect_minmax/` | V0 + parallel group statistics | module Gate +2,786 ps | module only | module Gate PASS |
| **E5** | `work/e5_detect_parallel/` | **V0 + E1 + E2 + E4** | **+0.644 / 0 ns (0 EP)** | **18,233** | **shipped (r2)** |

Route, E5: Setup **+0.644 / 0 ps**, Hold **+0.021 / 0 ps**, 0 violating
endpoints, 18,233/21,216 slices (85.94 %), ERAM 75/108, DSP 32/40,
wire 4,912,048, STA coverage 96.54 %, TD 6.2.168116, `place seed 1`.

Per clock: MIPI **+0.755 ns**, HDMI **+0.644 ns**, DDR usr_clk +2.628 ns,
everything else ≥ +1.364 ns.

## Verified status ladder

| Level | State |
|---|---|
| RTL_VERIFIED | **YES** — E1: 1,058 checks; E2: 2,475,199 cycles; E4: 701,440 checks; all 0 mismatches |
| TIMING_PASS | **YES** — full Route, both corners, CRPR on, 0 violating endpoints |
| BITSTREAM_READY | **YES** — bitgen exit 0 from the routed DB, gated on a clean route.qor |
| READY_FOR_BOARD_TEST | **YES** — r2 package above |
| HARDWARE_PASS | **NO** — never downloaded; no board connected |

## Residual risks (do not lose these)

1. **Margins are healthy but finite**: MIPI +0.755 ns (9.660 ns), HDMI
   +0.644 ns (13.333 ns). Inserting ChipWatcher debug logic still requires a
   rebuild and re-timing.
2. **Unconstrained 99 kHz I2C clock** `u_uicfgcs520/u_i2c/scl_clk`
   (24 MHz / 240 = 10.08 µs). Analytical, not measured: adding
   `create_clock` to the imported routed DB and re-timing crashed TD with
   `0xC0000005`. Minidump preserved. Shipped artifacts re-hashed and intact.
3. **Unconstrained I/O**: MIPI/DDR hard-IP pads, TMDS pads, I2C, LEDs, buttons.
   Enumerated in `evidence/check_timing_route.txt`.
4. **DDR PLL frequency-mismatch report** from `check_timing` (constraint says
   half the PLL setting for clkc[0..3]). Vendor DDR PHY 2× output-clock
   reporting; unchanged from the frozen baseline.
5. **Pin assignment**: HX1P35A/HX1P35B document discrepancy never closed.
6. **Provisional calibration constants** (0.5/0.25 mm/px, 60x20 mm, ±2 mm).
7. **AWB off** (inherited AWB-Lite reduction), **sort actuator inhibited**.
8. **Vendor ERAM model unusable in sim**: `PH1P_LOGIC_ERAM` cannot elaborate
   under ModelSim Intel 2020.1 (`Unresolved reference to 'PH1P_PHY_GSR'`). All
   post-detector simulations use the RTL's own `MORPH_SIMULATION` branch.

## Constraints honesty

`camera_to_dsi_display.sdc` is byte-identical to the frozen baseline
(`390DFE5F...`). The only timing exceptions are the vendor DDR2 gray-counter
`set_max_delay -datapath_only` constraints, 100 % ignored by `set_clock_groups`.
No false path, no multicycle, no period change was added at any point.


## Established facts (re-verify if the tree changes)

- MIPI pre-computation window: exactly one cycle. `color_detect_96_v2` commits
  BBox/area at edge T; `defect_classifier` toggles `O_result_toggle` at T+1;
  `ind_v2_toggle_d` delays it so `ind_result_event` is high only in cycle T+1;
  the calibrator samples at edge T+2. Cycle T is free for pre-computation.
- Production spine instance: `USE_STATIC_CAL_CONFIG=1`,
  `STATIC_OCCUPANCY_MIN_Q8=200`, `STATIC_ASPECT_MIN_Q8=320`,
  `STATIC_ASPECT_MAX_Q8=448`, `I_calibration_valid=1'b1`,
  `ENABLE_V2_FRAME_AWB=0`, `USE_BBOX_PIPELINE=1` (E1/E3 only).
- `731FF493...` is the SHA-256 of `R1-input-manifest.json` (shared R1 baseline),
  not a cross-version misreference. `IDENTITY_UNRESOLVED` is closed.
- Warning profile of the shipped build is byte-identical to the baseline:
  SYN-5013 x789, HDL-5317 x79, SYN-5011 x54, HDL-5007 x38, HDL-5314 x20,
  HDL-5323 x7, SYN-5041 x6, HDL-5373 x5, HDL-5001 x5, SYN-5025 x3, HDL-5106 x2,
  SYN-5065 x1, HDL-5369 x1.

## Rejected directions (do not repeat)

| Direction | Measured result | Verdict |
|---|---|---|
| AWB D=N−M×G reformulation | Gate WNS still −2.588 ns, DSP cost up | rejected |
| Static Q8=200 occupancy comparator | +0.837 ns < 1.0 ns gate; `#slice*` +57.1 % | rejected |
| OSD RGB mux reorder (no pipeline) | +49 ps; `#slice*` +6.29 % | rejected |
| Blind `RAM_STYLE` on cartoon cache | repeated `SYN-5041` | rejected |
| Synchronous palette ROM (isolated) | unresolved `HDL-5314`/`SYN-5025`/`SYN-5105`, 2 unexplained ERAMs | not integrated |

## Tool / process state

- Worktree `E:\Projects\FPGA-ds-timing`, branch `ds/industrial-v2-timing-closure`.
- No TD process running.
- `check_timing` succeeds on a routed DB; it crashes (0xC0000005) on a Gate DB
  and on any attempt to *modify* constraints after `import_db`. Do not retry
  those two variants.
- Runners: `run_full_route.ps1 -Exp <dir> [-RequireClean]`, `assemble_e3.sh`.
  Experiment dirs are full copies of `work/awblite_baseline/`; never edit the
  baseline.
