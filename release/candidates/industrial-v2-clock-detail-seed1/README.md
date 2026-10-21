# Industrial V2 clock-detail diagnostic candidate

This is a diagnostic TD candidate, not the final `release/industrial-v2/` package.

- Build commit: `73e4048c7830db069d800fe18e0d542692072d7d`
- Device: `PH1P35MDG324`
- TD: `6.2.168116`
- Placement seed: `1`
- Flow: official `DefaultFlow.tcl` with `analyze_clock -detail` inserted immediately after `route`
- Bitstream SHA-256: `d58a8640d9b3d3d6c19842053ee5159e723842152172c1583ad29602fadb2e3a`

## Measured TD result

- Slice: `17002 / 21216` (`80.14%`)
- RAM: `43`
- DSP: `24`
- DRAMHARDCON: `229`
- Setup WNS/TNS/violated endpoints: `+102 ps / 0 / 0`
- Hold WNS/TNS/violated endpoints: `+20 ps / 0 / 0`
- Bitstream size: `1,370,481 bytes`

The lower Slice result is a measured run only. Earlier same-seed runs produced different placement results, so this candidate does not close reproducibility or resource-budget gates.

## Clock audit result

`analyze_clock -detail` located the warning classes but did not prove them harmless:

- `u_uicfgcs520/u_i2c/scl_clk` has mixed clock/data fanout and is marked as a `clkin` non-clock sink case.
- `O_cam_24m_syn_3` has mixed clock/data fanout and is marked as a `clkout` non-clock sink case.
- A clock net from `O_cam_24m_dup_1...sclk_outnet` drives `u_uicfgcs520/u_i2c/scl_clk`.
- `PHY-5016` still reports PLL `clkc` driving an IO without location and not a clock-capable IO.

See `docs/evidence/industrial-v2-g8-clock-warning-detail-log.txt` and `docs/experiments/2026-10-19-industrial-v2-g8-clock-detail.md`.
