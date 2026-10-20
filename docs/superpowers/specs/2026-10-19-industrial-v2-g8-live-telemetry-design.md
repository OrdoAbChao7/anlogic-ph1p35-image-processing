# Industrial Vision V2 G8 telemetry and approved ISP AWB integration design

## Goal

Make the already implemented G3, G4, G5, and G7 source-domain results affect the final HDMI pixels through a frame-consistent consumer, and apply the G6 AWB controller's frame-stable gains to the shared ISP RGB stream as explicitly approved by the user. Source-list inclusion and module elaboration alone are not sufficient evidence that a feature survives synthesis.

## Architecture

Keep `industrial_v2_feature_spine` in the CSI/ISP result domain and extend the existing stable-payload toggle CDC for the missing `PROC` valid/cycle and motion-valid fields. Connect destination outputs into the HDMI-domain `industrial_osd_overlay` and make each selected field affect rendered text.

The OSD presents `PROC` in source-clock cycles. `VIDEO` and physical `E2E` remain explicitly `N/A` until tagged HDMI events and physical instrumentation are available. Pixel dimensions retain a `PX` label; candidate Q16.16 dimensions are visibly marked `CAL:PROV` and must not be described as calibrated measurements. Motion is shown as a frame-valid status plus a fixed-width hexadecimal sample count. PASS/NG totals, sort pulse, and safety-lock state are shown as status, not as proof of an external actuator. AWB applies the controller's Q8.8 RGB gains after vendor AWB to the shared RGB stream, captures one gain set per input frame, and uses registered channel products with elastic valid/ready flow control.

The fixed 12-row text contract is: mode; display-frame counter; target name; detection plus decimal `W/H PX`; verdict; `PROC:CYC` as eight hex digits or `N/A`; `VIDEO:N/A E2E:N/A`; motion validity and six hex count digits; four-hex-digit PASS/NG totals; sort/safe status; `CAL:PROV` with five decimal integer-mm digits when dimensions are valid (fractional Q16.16 bits are truncated for display); and height plus shape validity. `CAL:PROV` remains explicit because the top-level coefficients are candidates, not measured calibration.

For the fixed 1280×720 frame-statistics configuration, end-of-frame RGB totals and mean-luma computation are separated by two registers. The frame ID, RGB sums, pixel count, invalid flag, and mean luma publish together after this two-cycle statistics pipeline; the pixel stream itself is not stalled or retimed by this statistics-only delay. A Q35 reciprocal is exact over the legal RGB sum range and is checked against integer division in Python and RTL boundary vectors. Non-720p fixed configurations retain a constant-divisor implementation; runtime configurations keep the original variable-count arithmetic.

Do not guess a board GPIO or enable the sort actuator. Keep the existing safe default and leave physical actuator acceptance blocked. The approved G6 AWB pixel-path connection is in scope for this integrated G8 experiment; its physical lighting and board acceptance remain separately blocked.

## Frame and clock behavior

- Source telemetry is captured only on the existing source-result toggle; related values remain one atomic frame snapshot.
- Destination OSD fields update only at the destination frame boundary and stay stable for a complete displayed frame.
- `PROC` is valid only when the latency monitor reports a matched input/result frame tag; otherwise display `N/A`.
- `VIDEO` and `E2E` display `N/A` until their respective measurement contracts are implemented and evidenced.
- OSD keeps the existing one-pixel RGB/sync latency and fixed image dimensions.

## Verification

1. Python reference model renders the same telemetry strings over a test frame and is available through the existing Algorithm Lab.
2. CDC RTL simulation proves atomic transfer of `PROC` and motion-valid telemetry with existing frame/result fields, including reset, separated events, and invalid-value clearing.
3. OSD RTL simulation samples all 12 rows, `PROC` valid/invalid, `VIDEO:N/A`, `E2E:N/A`, motion/count maxima, PASS/NG maxima, safety, provisional calibration, five-digit candidate dimensions, and explicit `PX`/`MM` labels.
4. A formal-top contract test proves every selected CDC output reaches an OSD input, and no latency metric is fabricated when invalid.
5. AWB reference and RTL tests prove fixed-frame arithmetic equivalence, the 720p luma thresholds below/at/above an integer boundary, two-cycle frame-statistics alignment, gain rounding/saturation, per-frame gain stability, RGB/sync sideband alignment, and backpressure behavior; an isolated TD report identifies its timing/resource effect.
6. An isolated TangDynasty top build must pass timing/resource gates; the post-synthesis hierarchy and output cone must show the telemetry and AWB logic are consumed. No board download is part of this work package.

## Explicitly out of scope

- Assigning an unknown PH1P35 pin or claiming a real actuator action.
- Replacing provisional calibration constants with physical workcell calibration.
- Claiming HDMI-frame latency or physical end-to-end latency without tagged-event/measurement evidence.
