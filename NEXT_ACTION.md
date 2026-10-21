# NEXT_ACTION

## Immediate: board download and acceptance (blocked on hardware access)

1. Verify `release/candidate-industrial-v2-timing-closed/camera_to_dsi_display.bit`
   SHA-256 = `ADD2DC46403670C279CADCE2E051F79B83EA9F2BBD1F4E78E7FBB7EB5606BC8C`.
2. Follow `release/candidate-industrial-v2-timing-closed/BOARD_TEST.md`
   end to end and fill in the B1–B14 table. Record failures with the observed
   symptom; do not relax constraints or force `PASS` to make a check go green.
3. Replace the provisional calibration constants only after a real workcell
   calibration is captured, then rebuild and re-time.

## If further timing margin is wanted (optional, not required for this delivery)

Margins are positive but thin. The measured limiters, in priority order:

1. **MIPI +0.154 ns** — `u_industrial_v2_feature_spine/u_motion_diff_160/O_motion_count_reg[9]`
   and `color_detect_96_v2/acc_xmin|acc_xmax` (the four-iteration serial
   min/max loop in `color_detect_96_v2.v`). A provably equivalent rewrite
   (popcount + lowest/highest-set-bit instead of the serial `for j = 0..3`
   chain) would lift 4 of the top MIPI paths at once. Requires an
   AXI-stream pixel differential against the frozen detector, a module Gate,
   and a full re-route. **Registered as E4 but not started.**
2. **HDMI +0.137 ns** — `industrial_osd/width_digits_reg[3]`, the frame-boundary
   BCD conversion. Runs once per frame with ~30 blank lines of budget; a
   two-cycle registered conversion would remove it from the critical list.
   **Not started.**
3. `video_cartoon/q_top_row` / `q_mid_row` at +0.157 … +0.412 ns — pre-existing
   cartoon cache paths.

Do not start any of these without first re-reading `CURRENT_STATE.md`: the
shipped bitstream must stay the reference build, and each change needs its own
isolated experiment directory, differential, Gate and full re-route.
