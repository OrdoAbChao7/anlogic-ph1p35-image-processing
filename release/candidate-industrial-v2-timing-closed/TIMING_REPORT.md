# TIMING REPORT — Industrial V2 timing-closed candidate

Tool: Tang Dynasty 6.2.168116 · Device: PH1P35MDG324 · Speed 3
Flow: `industrial_v2_fixed_seed.tcl` (DefaultFlow + `set_param place seed 1`)
Source-tree inputs: `INPUTS.sha256` (239 files, manifest SHA-256
`207B1AEF196FBD616AE51B788277A291A4976BCB63A2ACCC73F857A9F5C8FB89`)

## Gate

| Metric | Value | Threshold | Verdict |
|---|---:|---|---|
| Setup WNS | **+0.137 ns** | ≥ 0 | PASS |
| Setup TNS | **0.000 ns** | = 0 | PASS |
| Setup violating endpoints | **0** | 0 | PASS |
| Hold WNS | **+0.020 ns** | ≥ 0 | PASS |
| Hold TNS | **0.000 ns** | = 0 | PASS |
| Hold violating endpoints | **0** | 0 | PASS |
| Slices | **18,248 / 21,216 (86.01 %)** | ≤ 20,000 | PASS |
| ERAM | 75 / 108 | within capacity | PASS |
| DSP | 32 / 40 | within capacity | PASS |
| Timing mode | final, both corners (slow m40c / fast), CRPR enabled | required | PASS |
| STA coverage | 96.56 % | analysed below | PASS with notes |

Raw: `evidence/route_flow.status`, `evidence/route.qor`,
`evidence/camera_to_dsi_display_phy.ts`, `evidence/final_timing.rpt`.

## Stage progression

| Stage | Setup WNS | Setup TNS | Viol EP | Hold WNS | Notes |
|---|---:|---:|---:|---:|---|
| Gate (syn) | −1,101 ps | −4,282 ps | 4 | +1,114 ps | registers 16,685, LUTs 15,308 |
| Place | **+1,063 ps** | 0 | 0 | −281 ps | FMAX 116.320 MHz |
| Route | **+137 ps** | 0 | 0 | +20 ps | `fix_hold` closed hold |
| Bitgen | — | — | — | — | from `camera_to_dsi_display_pr.db` |

Place-to-route cost was 926 ps of routing delay; hold was corrected by the
flow's `fix_hold`.

## Per-clock margins (Route, final)

| Clock | Period | Setup WNS | Setup TNS | Hold WNS |
|---|---:|---:|---:|---:|
| clk0 `MIPI_RX_BYTE_CLK` | 9.660 ns | **+0.154** | 0 | +0.020 |
| clk1 `HDMI_PIXEL_CLK` | 13.333 ns | **+0.137** | 0 | +0.034 |
| clk2 `ddr2/usr_clk` | 15.000 ns | +1.428 | 0 | +0.020 |
| clk3 `pll_clk_24m` | 42.000 ns | +37.208 | 0 | +0.085 |
| clk4 `sys_clk_50m` | 20.000 ns | +14.865 | 0 | +0.078 |
| clk5 `HDMI_SERIAL_CLK` | 2.666 ns | +1.292 | 0 | +0.086 |
| clk6 `ddr2/mcu_clk` | 39.374 ns | +27.986 | 0 | +0.055 |
| clk7 `pll_clk_100m` | 10.000 ns | +8.376 | 0 | +0.083 |
| clk8/9 DDR MLCLK, clk10–13 local | — | 0.000 | 0 | 0.000 |

`clk8..clk13` carry fanout ≤ 6 and 0–1 endpoints; their 0.000 slack is
structural (single register or none), and they are excluded from the
`set_clock_groups` inter-domain analysis.

## Critical paths

**MIPI (+0.154 ns)** — `u_industrial_v2_feature_spine/u_motion_diff_160/O_motion_count_reg[9]`.
Pre-existing logic; the baseline's `dimension_calibrator` cone no longer appears
anywhere in the MIPI list. Remaining MIPI paths:

| Slack | Endpoint |
|---:|---|
| +0.154 | `motion_diff_160/O_motion_count_reg[9]` |
| +0.296 | `motion_diff_160/history_eram` |
| +0.324 | `color_detect_96_v2/acc_xmax_reg[0]` |
| +0.330 | `motion_diff_160/history_eram` |
| +0.352 | `dimension_calibrator/mult0_syn_61.xa[1]` (stage-1 DSP input) |
| +0.363 / +0.364 | `motion_diff_160/O_motion_count_reg[14]` |
| +0.368 | `motion_diff_160/processed_sample_count` |
| +0.395 | `color_detect_96_v2/acc_xmin_reg[0]` |

**HDMI (+0.137 ns)** — `u_industrial_osd/width_digits_reg[3]` (frame-boundary
BCD conversion, one update per frame). The overlay RGB cone that produced all 23
baseline violations is gone. Remaining HDMI paths:

| Slack | Endpoint |
|---:|---|
| +0.137 | `industrial_osd/width_digits_reg[3]` |
| +0.157 / +0.176 / +0.229 / +0.267 / +0.320 / +0.344 / +0.412 | `video_cartoon/q_top_row`, `q_mid_row` |
| +0.240 | `video_cartoon/bank1_n_syn_160` |

## Constraint honesty

`evidence/camera_to_dsi_display_exception.timing` lists **all** timing
exceptions in the design:

```
set_max_delay ... -datapath_only 9.360   (DDR2 primary_addr_gray -> sync_r1)
set_max_delay ... -datapath_only 13.033  (same)
```

Both are vendor DDR2-IP CDC constraints; both are 100 % ignored by
`set_clock_groups`, so they contribute nothing to the reported WNS.

**There are no false paths, no multicycle relaxations and no clock-period
changes.** `camera_to_dsi_display.sdc` is byte-identical to the frozen baseline
(`390DFE5FA12669AFC5E8DB01E893300132605FFB6BFB962EC40DA5BE022B068F`).

## STA coverage 96.56 % — full enumeration

`evidence/check_timing_route.txt` was produced successfully by
`check_timing -file ... -verbose` against the routed database (TD exited 0).

```
1. no clock .................... 1
2. clock definition ............ 0
3. dummy node .................. 4  (DSP mul9_mode/mul9_signed, one pad TI pin, one LSLICE, 2 DDR PLL resets)
4. invalid constraint .......... 0
5. PLL/buffer clock constraints  7  (DDR PHY 2x output-clock reporting, vendor IP)
6. combinational loops ......... 0
7. soft fifo max-delay ......... 0
8. no-path constraints ......... 0
9. shadowed/ignored exceptions . 2  (the DDR gray-counter max_delay above)
10. no input delay ............. 34
11. no output delay ............ 65
12. partial input delay ........ 1
```

**The single unconstrained clock** is `u_uicfgcs520/u_i2c/scl_clk`, generated in
`uics500_cfg/uii2c.v` by a divider from `S_24m_clk`:

```
CLK_DIV = 23809524/100000 - 1 = 239   ->  SCL_DIV = 119
scl_clk toggles every 120 x 41.99 ns  ->  period ~= 10.08 us  (~99.2 kHz)
```

It clocks only the I2C byte-shift engine inside the camera configuration block.
At 99.2 kHz its register-to-register budget is ~1000x the MIPI 9.660 ns budget,
and it is itself derived from a register inside the constrained 24 MHz domain.
It is **not** a critical unconstrained path.

An attempt to *add* `create_clock -name scl_clk -period 10.080` to the imported
routed database and re-time it crashed TD with `0xC0000005` (minidump preserved
at `work/e3_integrated/.../phy_check/minidump-20261021-180444.dmp`). The
`check_timing` report above was obtained **before** that probe and is intact; the
shipped bitstream and routed database were never touched by the crashed process
(hashes re-verified after the crash). The 99 kHz figure is therefore an
analytical derivation from the RTL constants, not a measured STA number.

**The 99 unconstrained I/O ports** are:

- MIPI D-PHY pads `IO_rx_{clk,data}_pad_{p,n}` — timed inside the hard D-PHY IP.
- DDR2 pins `ddr_{dq,dqs_p,dqs_n,dm,addr,ba,ck_p,ck_n,cke,cs_n,cas_n,...}` —
  timed inside the vendor DDR PHY.
- Housekeeping: `O_cam_rst`, `O_cam_scl`, `IO_cam_sda`, `O_led1..3`,
  `I_button[1:0]`.
- TMDS pads `O_tmds_{ch0,ch1,ch2,clk}_p` — driven by the hard serializer;
  the fabric side is constrained by `HDMI_SERIAL_CLK` at 2.666 ns and passes at
  +1.292 ns.

None of these carries unconstrained internal synchronous logic at the two
critical clocks.

## Warnings

Synthesis warning profile is **byte-for-byte identical** to the frozen baseline:
`SYN-5013 x789, HDL-5317 x79, SYN-5011 x54, HDL-5007 x38, HDL-5314 x20,
HDL-5323 x7, SYN-5041 x6, HDL-5373 x5, HDL-5001 x5, SYN-5025 x3, HDL-5106 x2,
SYN-5065 x1, HDL-5369 x1`. No warning was introduced and none was suppressed.
`SYN-5041`/`SYN-5025`/`HDL-5314` are the pre-existing vendor-IP and cartoon-cache
notes recorded in the frozen baseline audit.
