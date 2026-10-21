# TIMING REPORT — Industrial V2 timing-closed candidate (r2)

Tool: Tang Dynasty 6.2.168116 · Device: PH1P35MDG324 · Speed 3
Flow: `industrial_v2_fixed_seed.tcl` (DefaultFlow + `set_param place seed 1`)
Build inputs: `INPUTS.sha256` (239 files, manifest SHA-256
`87683345FE2B38220F5FD2016CCF3E545A88DF97FB0AC4938747F16CF08BADA8`)

## Gate

| Metric | Value | Threshold | Verdict |
|---|---:|---|---|
| Setup WNS | **+0.644 ns** | ≥ 0 | PASS |
| Setup TNS | **0.000 ns** | = 0 | PASS |
| Setup violating endpoints | **0** | 0 | PASS |
| Hold WNS | **+0.021 ns** | ≥ 0 | PASS |
| Hold TNS | **0.000 ns** | = 0 | PASS |
| Hold violating endpoints | **0** | 0 | PASS |
| Slices | **18,233 / 21,216 (85.94 %)** | ≤ 20,000 | PASS |
| ERAM | 75 / 108 | within capacity | PASS |
| DSP | 32 / 40 | within capacity | PASS |
| Timing mode | final, slow + fast corners, CRPR enabled | required | PASS |
| STA coverage | 96.54 % | analysed below | PASS with notes |

Raw: `evidence/route_flow.status`, `evidence/route.qor`,
`evidence/camera_to_dsi_display_phy.ts`, `evidence/final_timing.rpt`.

## Stage progression

| Stage | Setup WNS | Setup TNS | Viol EP | Hold WNS | Notes |
|---|---:|---:|---:|---:|---|
| Gate (syn) | **+860 ps** | 0 | **0** | +114 ps | registers 16,685, LUTs 15,145 |
| Place | **+1,587 ps** | 0 | 0 | −298 ps | worst setup group is HDMI_SERIAL_CLK (2.666 ns) |
| Route | **+644 ps** | 0 | 0 | +21 ps | `fix_hold` closed hold |
| Bitgen | — | — | — | — | from `camera_to_dsi_display_pr.db` |

Synthesis alone already closes setup with positive slack and zero violations —
the previous r1 build was −1,101 ps with 4 violations at the same stage. Routing
cost 943 ps; `fix_hold` closed hold.

## Per-clock margins (Route, final)

| Clock | Period | Setup WNS | Setup TNS | Hold WNS | r1 Setup WNS |
|---|---:|---:|---:|---:|---:|
| clk0 `MIPI_RX_BYTE_CLK` | 9.660 ns | **+0.755** | 0 | +0.022 | +0.154 |
| clk1 `HDMI_PIXEL_CLK` | 13.333 ns | **+0.644** | 0 | +0.045 | +0.137 |
| clk2 `ddr2/usr_clk` | 15.000 ns | +2.628 | 0 | +0.021 | +1.428 |
| clk3 `pll_clk_24m` | 42.000 ns | +36.963 | 0 | +0.058 | +37.208 |
| clk4 `sys_clk_50m` | 20.000 ns | +15.829 | 0 | +0.096 | +14.865 |
| clk5 `HDMI_SERIAL_CLK` | 2.666 ns | +1.364 | 0 | +0.073 | +1.292 |
| clk6 `ddr2/mcu_clk` | 39.374 ns | +28.370 | 0 | +0.055 | +27.986 |
| clk7 `pll_clk_100m` | 10.000 ns | +8.129 | 0 | +0.058 | +8.376 |
| clk8/9 DDR MLCLK, clk10–13 local | — | 0.000 | 0 | 0.000 | 0.000 |

`clk8..clk13` carry fanout ≤ 6 and 0–1 endpoints; their 0.000 slack is
structural and they are excluded from the inter-domain analysis by
`set_clock_groups`.

## Critical paths

**MIPI (+0.755 ns, max level 10)** — `u_industrial_v2_feature_spine/u_motion_diff_160/motion_seen_reg`.
The `color_detect_96_v2` statistic cone that limited r1 at +0.154 ns is gone
from the list entirely; top MIPI paths are now:

| Slack | Endpoint |
|---:|---|
| +0.755 / +0.777 | `motion_diff_160/motion_seen_reg` |
| +0.780 | `dimension_calibrator/mult0_syn_61` (stage-1 DSP input) |
| +0.791 / +0.813 / +0.992 | `motion_diff_160/O_motion_count_reg` |
| +0.946 / +0.968 | `motion_diff_160/motion_count_accum` |

**HDMI (+0.644 ns, max level 13)** — `u_industrial_osd/logo_pixel_s2_reg[21]`,
i.e. the registered logo-ROM output. That is the intended pipeline boundary, not
a long chain. Remaining HDMI paths:

| Slack | Endpoint |
|---:|---|
| +0.644 | `industrial_osd/logo_pixel_s2_reg[21]` |
| +0.959 / +1.153 / +1.294 | `video_cartoon/q_mid_row` |
| +1.013 / +1.118 / +1.271 / +1.295 | `industrial_osd/logo_pixel_s2_reg` |

## Constraint honesty

`evidence/camera_to_dsi_display_exception.timing` lists **all** timing
exceptions:

```
set_max_delay ... -datapath_only 9.360   (DDR2 primary_addr_gray -> sync_r1)
set_max_delay ... -datapath_only 13.033  (same)
```

Both are vendor DDR2-IP CDC constraints and both are 100 % ignored by
`set_clock_groups`.

**No false path, no multicycle relaxation and no clock-period change** was added
at any point. `camera_to_dsi_display.sdc` is byte-identical to the frozen
baseline (`390DFE5FA12669AFC5E8DB01E893300132605FFB6BFB962EC40DA5BE022B068F`).

## STA coverage 96.54 % — full enumeration

`evidence/check_timing_route.txt`, produced by
`check_timing -file ... -verbose` on the routed database (TD exit 0):

```
1. no clock .................... 1
2. clock definition ............ 0
3. dummy node .................. 4   (DSP mul9_mode/mul9_signed, one pad TI pin, one LSLICE, 2 DDR PLL resets)
4. invalid constraint .......... 0
5. PLL/buffer clock constraints  7   (DDR PHY 2x output-clock reporting, vendor IP)
6. combinational loops ......... 0
7. soft fifo max-delay ......... 0
8. no-path constraints ......... 0
9. shadowed/ignored exceptions . 2   (the DDR gray-counter max_delay above)
10. no input delay ............. 34
11. no output delay ............ 65
12. partial input delay ........ 1
```

**The single unconstrained clock** is `u_uicfgcs520/u_i2c/scl_clk`, generated in
`uics500_cfg/uii2c.v` from `S_24m_clk`:

```
CLK_DIV = 23809524/100000 - 1 = 239  ->  SCL_DIV = 119
scl_clk toggles every 120 x 41.99 ns  ->  period ~= 10.08 us  (~99.2 kHz)
```

It clocks only the I2C byte-shift engine inside the camera configuration block.
Its register-to-register budget is ~1000x the MIPI budget and it is itself
derived from a register inside the constrained 24 MHz domain. It is **not** a
critical unconstrained path.

An attempt to add `create_clock` for it to the imported routed database and
re-time crashed TD with `0xC0000005` (minidump retained in the r1 workspace).
The `check_timing` report above predates that probe and is intact; the shipped
bitstream and routed database were re-hashed afterwards and are unchanged. The
99 kHz figure is therefore an analytical derivation from the RTL constants, not
a measured STA number.

**The 99 unconstrained I/O ports** are MIPI D-PHY pads, DDR2 pins, TMDS pads
(hard IP / hard serializer), plus `O_cam_rst`, `O_cam_scl`, `IO_cam_sda`,
`O_led1..3`, `I_button[1:0]`. None carries unconstrained internal synchronous
logic at either critical clock.

## Warnings

Synthesis warning profile is byte-for-byte identical to the frozen baseline;
none was introduced and none was suppressed.
