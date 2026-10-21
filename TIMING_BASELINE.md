# TIMING_BASELINE — AWB-Lite full Route, TD 6.2.168116

Source of truth: `E:\Projects\FPGA\work\g8_r1_v2_integration\work\g8_r3_awb_lite_20261021\full_candidate\td_project\camera_to_dsi_display_Runs\phy_1\`
(`route_flow.status`, `route.qor`, `final_timing.rpt`, generated 2026-10-21 12:06).

## Global

| Metric | Value |
|---|---|
| Top | design_top_wrapper |
| Device / speed | PH1P35MDG324 / 3 |
| Timing mode | final, both corners, CRPR on |
| STA coverage | 96.67 % |
| Setup WNS / TNS | **−2.539 ns / −14.705 ns** |
| Setup violating endpoints | **24** |
| Hold WNS / TNS | +0.020 ns / 0.000 ns |
| Hold violating endpoints | 0 |
| Period check WNS | 6.860 ns |
| Slices | 18,421 / 21,216 (86.83 %) |
| RAMs (ERAM) | 75 / 108 |
| DSPs | 32 / 40 |
| Wire length | 5,233,152 |
| Place-stage WNS | −1.350 ns, 1 violated endpoint, FMAX 90.827 MHz |

## Per-clock (Route, final)

| Clock | Period | Setup WNS | Setup TNS | Setup viol EP | Hold WNS |
|---|---:|---:|---:|---:|---:|
| clk0 MIPI_RX_BYTE_CLK | 9.660 ns | **−2.539** | −2.539 | 1 | +0.020 |
| clk1 HDMI_PIXEL_CLK | 13.333 ns | **−0.974** | **−12.166** | **23** | +0.026 |
| clk2 ddr2/usr_clk | 15.000 ns | +2.100 | 0 | 0 | +0.020 |
| clk3 pll_clk_24m | 42.000 ns | +35.423 | 0 | 0 | +0.066 |
| clk4 sys_clk_50m | 20.000 ns | +15.713 | 0 | 0 | +0.077 |
| clk5 HDMI_SERIAL_CLK | 2.666 ns | +0.934 | 0 | 0 | +0.057 |
| clk6 ddr2/mcu_clk | 39.374 ns | +29.039 | 0 | 0 | +0.054 |

**All 24 setup violations are in exactly two cones** (confirmed against TNS arithmetic:
clk0 TNS −2.539 = the single −2.539 endpoint; clk1 TNS −12.166 over 23 endpoints).

## Cone 1 — MIPI (1 endpoint)

```
Slack        : -2.539 ns
Begin        : u_isp_top/u_color_detect_96_v2/O_xmin_reg[0]
End          : u_industrial_v2_feature_spine/u_dimension_calibrator/O_shape_valid_reg
Clock        : MIPI_RX_BYTE_CLK 9.660 ns
Data path    : 12.008 ns (cell 8.042 / net 3.966)
Logic levels : 9  (ADDER=4, DSPMULT=2, LUT4=1, LUT2=1, unknown=1)
Max fanout   : 5
```

Traced structure (from `final_timing.rpt`):

```
O_xmin_reg[0]
  -> dimension_calibrator sub0_syn_63..69   7 x ADDER   (width = xmax - xmin + 1)
  -> add1_syn_81                            1 x ADDER   (+1)                 [line 82-84]
  -> mult0_syn_59/60                        DSPMULT     (bbox_area = w*h)   [line 94]
  -> mult4_syn_59/60                        DSPMULT     (bbox_area * occ_min) [line 128]
  -> lt7_syn_143..146                      4 x ADDER   (>= comparator)     [line 130]
  -> O_shape_valid_reg
```

Root cause: two cascaded DSP multiplies plus an 11-bit subtractor and a 33-bit
compare in one 9.660 ns cycle. Not a routing-congestion artefact.

## Cone 2 — HDMI/OSD (23 endpoints)

All 23 share one startpoint: `u_industrial_osd/x_reg[2]` on HDMI_PIXEL_CLK.

```
Worst slack  : -0.974 ns   -> O_rgb_reg[12]
Data path    : 14.066 ns (cell 4.389 / net 9.677 = 69 % net)
Logic levels : 14 (LUT6=6, LUT5=3, LUT4=3, LUT3=1, LUT2=1)
Max fanout   : 24
Reported slacks of the 10 shown paths:
  -0.974 -0.859 -0.846 -0.796 -0.757 -0.661 -0.624 -0.615 -0.558 -0.552
```

Traced structure: `x_reg[2]` → `u_logo_rom/I_addr` → LUT chain (fanout-24 and
fanout-19 nets, 2.701 ns and 1.312 ns of pure routing) → `sel14` at
`industrial_osd_overlay.v(225)` = `text_char` → glyph/colour select → `O_rgb_reg`.

Root cause: the whole overlay decision (`anlogic_logo_rom` 6,388-entry
combinational 25-bit case + `text_char` 12x16 case + `glyph_row` + colour mux)
sits in a single combinational stage feeding `O_rgb`, on high-fanout nets that
the placer spreads across the die. Net delay 69 %.

## Not inherited as valid

- No bitstream from this build; `end_step=opt_route` in `phy_1/settings.cfg`.
- `STA coverage 96.67 %` leaves ~3.3 % unconstrained; the 2 unnamed
  timing-unconstrained endpoints reported in the isolated OSD Gate run are still
  unresolved (a `check_timing` CLI attempt crashed with 0xC0000005 on 2026-10-21
  and must not be blindly retried).
