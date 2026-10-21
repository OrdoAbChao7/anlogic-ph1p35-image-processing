# BOARD TEST — Industrial V2 timing-closed candidate

This procedure has **not** been executed. Nothing in this document is a measured
result. It is the intended acceptance path for the first board download.

## 0. Before touching the board

```powershell
Get-FileHash .\camera_to_dsi_display.bit -Algorithm SHA256
# must equal ADD2DC46403670C279CADCE2E051F79B83EA9F2BBD1F4E78E7FBB7EB5606BC8C
```

If the hash differs, stop. Do not download a bitstream whose identity is unknown.

## 1. Hardware

| Item | Expected |
|---|---|
| Board | HX1P35A carrier with PH1P35MDG324 |
| Camera | SC520CS via MIPI D-PHY (2 lane) |
| Display | HDMI sink accepting 1280x720p |
| Download path | Anlogic USB-JTAG / vendor download cable |
| Tool | Tang Dynasty 6.2.168116 (the version that produced this bitstream) |

**Pin-assignment caveat (inherited, unresolved):** the HX1P35A / HX1P35B pin
document discrepancy recorded in the frozen project's
`docs/research/known-gaps.md` was never closed. `pin.adc` is used unchanged
(`AEE8F1CB88042DB5155A24A9698766E8F85C0AE916BD6BA9691245799184F2AE`). If the
board silkscreen or vendor drawing disagrees with the ADC, treat the download as
a pin-assignment experiment, not a functional failure.

## 2. Download

1. Apply power to the board first, then connect the download cable.
2. Open Tang Dynasty on the build workstation.
3. Use the GUI download function (Tools → Download / Program) and select
   `camera_to_dsi_display.bit`.

The TD GUI download path is the only one verified to exist in this install; no
command-line download command was found in `app/doc/cmd` or
`app/doc/scripts`. If a CLI download command is available on the laboratory
workstation, record its exact spelling and first use it on a known-good
bitstream before trusting it here.

4. Expected: TD reports programming success and the board restarts without a
   configuration error LED.

## 3. Acceptance checklist

Record pass/fail per line, with a photograph or capture where relevant.

| # | Check | Expected | Result |
|---|---|---|---|
| B1 | Configuration | Download completes, no config-error indication | |
| B2 | MIPI link | Camera locks; no frame-gap storm in the OSD frame counter | |
| B3 | HDMI output | 1280x720p stable picture on the monitor | |
| B4 | OSD logo | Anlogic logo visible top-left (x<160, y<160) | |
| B5 | OSD text | 12 text lines visible starting at x=180, mode line shows `ORIGINAL` / `SOBEL` / `CARTOON` | |
| B6 | Mode switching | Buttons cycle display modes with no picture loss | |
| B7 | Detection | A red part on the conveyor is boxed; bbox overlays the part | |
| B8 | Verdict | OSD shows a PASS or NG verdict consistent with the part | |
| B9 | Counters | PASS/NG counters advance exactly once per classified part | |
| B10 | No-object | Removing the part yields `NO_OBJECT`, not a stale PASS | |
| B11 | LED state | Status LEDs follow the verdict | |
| B12 | Stability | 30 min continuous run, no picture loss, no frame-counter stall | |
| B13 | Thermal | Die temperature stable; no throttling artefact | |
| B14 | Reprogram | Power-cycle and reprogram twice; behaviour repeats | |

## 4. Known limitations of this bitstream

Carry these into the test record — they are not defects introduced by the
download, they are the declared configuration:

- **Frame AWB is OFF.** ISP gains are fixed at unity (Q8.8 256). Under strongly
  coloured or dim lighting the segmentation thresholds (`85<Cb<125`,
  `135<Cr<200`) may behave differently than a colour-balanced image would.
  This is the inherited "AWB-Lite" reduction, not a new regression.
- **Sort actuator is inhibited.** `I_arm = 1'b0`, so `O_safe_enable` stays
  inhibited and `O_sort_pulse` never fires. No actuator will move.
- **Calibration constants are provisional** (0.5 / 0.25 mm per pixel, 60.0 x 20.0
  mm nominal, ±2.0 mm). Width/height in mm and the dimension verdict are only as
  good as those numbers. Replace them with a real workcell calibration before
  trusting the millimetre readout.
- **Shape gate** requires BBox occupancy ≥ 78.1 % and aspect in [1.25, 1.75).
- **Timing margins**: HDMI +0.644 ns, MIPI +0.755 ns. Adding
  ChipWatcher debug instrumentation still requires a rebuild and re-timing.


## 5. If it fails

| Symptom | First thing to check |
|---|---|
| No configuration | Cable/JTAG wiring, board power sequencing, device ID in TD |
| Config OK, no HDMI | Monitor EDID/720p support; TMDS pin assignment vs ADC |
| HDMI OK, no camera image | MIPI lane polarity/termination; `S_cam_i2c_ready`; I2C pull-ups |
| Camera image but no boxes | Segmentation thresholds under the actual lighting; AWB is off |
| Boxes but wrong verdict | Provisional calibration constants, occupancy/aspect gates |
| Intermittent picture corruption | Suspect the pin-assignment caveat first, then the thin timing margin |

Do **not** mask a failure by relaxing constraints or by forcing `PASS`. If a
functional block is broken, report it with the observation, not with a
configuration change that hides it.
