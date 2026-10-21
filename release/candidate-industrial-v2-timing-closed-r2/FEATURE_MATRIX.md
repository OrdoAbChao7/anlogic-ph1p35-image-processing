# Feature Matrix — Industrial V2 AWB-Lite

Status: draft, to be frozen when the shipped build is selected.
Sources: `design_top_wrapper.v` spine instance parameters and the RTL feature gates.

## Build configuration (as elaborated)

| Parameter | Value | Effect |
|---|---|---|
| `ENABLE_V2_FRAME_AWB` | **0** | Frame AWB controller not instantiated; gains forced to `16'd256` (Q8.8 = 1.0, unity). This is the "AWB-Lite" reduction. |
| `USE_FIXED_AWB_PIXEL_COUNT` | 1 | Fixed pixel count 921600 (only relevant if AWB were enabled). |
| `USE_STATIC_CAL_CONFIG` | 1 | Calibration constants folded at elaboration. |
| `STATIC_SCALE_X_Q16_16` | 32768 | 0.5 mm/pixel. **Provisional** software-contract value. |
| `STATIC_SCALE_Y_Q16_16` | 16384 | 0.25 mm/pixel. **Provisional**. |
| `STATIC_NOMINAL_WIDTH_Q16_16` | 3932160 | 60.0 mm nominal width. **Provisional**. |
| `STATIC_NOMINAL_HEIGHT_Q16_16` | 1310720 | 20.0 mm nominal height. **Provisional**. |
| `STATIC_TOLERANCE_*_Q16_16` | 131072 | ±2.0 mm tolerance. **Provisional**. |
| `STATIC_OCCUPANCY_MIN_Q8` | 200 | BBox occupancy must be ≥ 200/256 = 78.1 %. |
| `STATIC_ASPECT_MIN_Q8` / `MAX` | 320 / 448 | Aspect (w/h·256) in [1.25, 1.75). |
| `USE_BBOX_PIPELINE` | 1 (E1/E3 only) | Register BBox geometry one cycle ahead of the result event. Purely a timing change; outputs identical. |
| `I_arm` | `1'b0` | Sort actuator safety interlock never armed; `O_safe_enable` stays inhibited. |
| `I_external_fault` / `I_clear_fault` | `1'b0` | No external fault input wired. |

## Functional capability

| Capability | Enabled | Notes |
|---|---|---|
| SC520CS MIPI D-PHY/CSI capture | YES | 2-lane, 1280x720 |
| ISP (demosaic, AWB apply, colour pipeline) | YES | AWB gain fixed at unity (see above) |
| Original / Sobel / Cartoon display modes | YES | |
| Red-part segmentation (`85<Cb<125`, `135<Cr<200`) | YES | Frozen Stage D thresholds |
| 3x3 morphological opening | YES | |
| BBox (xmin/xmax/ymin/ymax), centre, area | YES | 11-bit coords, 20-bit area |
| PASS / NG / NO_OBJECT / INVALID classification | YES | `defect_classifier`, nominal 120x80 px ± tolerance |
| Dimensional validity in mm (Q16.16) | YES | Uses provisional calibration constants |
| Shape validity (occupancy + aspect) | YES | |
| Temporal tracking + trajectory overlay | YES | 8-deep history |
| Motion detection (160x120 fixed grid) | YES | |
| Frame tagging / latency telemetry | YES | |
| OSD: logo, mode, frame, dimensions, verdict, counters | YES | |
| Sort actuator output | **INHIBITED** | `I_arm=0`, interlock held safe |
| Frame-level AWB (7th V2 feature) | **OFF** | AWB-Lite reduction |

## Explicitly NOT a reduction

`PASS` is never forced true. The verdict still comes from
`defect_classifier` (width/height window + area) and the shape/dimension checks.
With AWB off the detector operates on the un-gained ISP output; the red-part
segmentation thresholds are unchanged.

## Not verified on hardware

Nothing in this table is a hardware result. Board download, MIPI lock, HDMI
output, detection accuracy and long-run stability are all still unverified.
