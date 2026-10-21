# NEXT_ACTION

## Immediate: board download and acceptance (blocked on hardware access)

Use `release/candidate-industrial-v2-timing-closed-r2/`.

1. Verify
   `camera_to_dsi_display.bit` SHA-256 =
   `E6BA3DA87DABF82907F3DB1B4FAC18A9E8350A43917F3D5E6DA64A0A35617C36`.
2. Follow `BOARD_TEST.md` end to end and fill in the B1–B14 table. Record
   failures with the observed symptom; do not relax constraints or force `PASS`
   to make a check go green.
3. If anything behaves unexpectedly, `../candidate-industrial-v2-timing-closed/`
   (r1, Setup +0.137 ns, bitstream `ADD2DC46...`) is a drop-in rollback: it
   shares E1 and E2 and differs only in the detector implementation.
4. Replace the provisional calibration constants only after a real workcell
   calibration is captured, then rebuild and re-time.

## Timing margin status

Both critical clocks are now comfortably positive and the limiters are benign:

| Clock | WNS | Limiting endpoint | Nature |
|---|---:|---|---|
| MIPI 9.660 ns | +0.755 ns | `motion_diff_160/motion_seen_reg` | pre-existing counter logic |
| HDMI 13.333 ns | +0.644 ns | `industrial_osd/logo_pixel_s2_reg[21]` | the E2 pipeline boundary itself |

No further structural timing work is warranted before hardware results. In
particular:

- Do **not** start another margin experiment to chase the `motion_diff_160`
  counter path; it is a pre-existing design, it is not blocking, and every
  change there carries detector-adjacent risk.
- ChipWatcher debug insertion still requires a rebuild and a full re-route; at
  +0.644 ns there is room, but it must be measured, not assumed.

## If the board test fails

| Symptom | First thing to check |
|---|---|
| No configuration | Cable/JTAG wiring, power sequencing, device ID in TD |
| Config OK, no HDMI | Monitor 720p support; TMDS pin assignment vs `pin.adc` |
| HDMI OK, no camera image | MIPI lane polarity/termination; `S_cam_i2c_ready`; I2C pull-ups |
| Image but no boxes | Segmentation thresholds under the actual lighting; AWB is off |
| Boxes but wrong verdict | Provisional calibration constants; occupancy/aspect gates |
| Intermittent corruption | The HX1P35A/HX1P35B pin-document discrepancy first |

Re-open an experiment directory per change; never edit `work/awblite_baseline/`.
