# Tracked TangDynasty build input package

This directory contains the tracked vendor/IP source snapshot and project
configuration used to rebuild the industrial-v1 TangDynasty project. It is the
default TD input package for `scripts/build_industrial_td.py`; the application
RTL is kept separately under `fallback/rtl/` and `fallback/td_source/` and is
synchronized into the temporary TD project by the build script.

## Contents

- `user_source/`: generated IP configuration, memory/data files, and vendor
  source files used by the build.
- `td_project/camera_to_dsi_display.sdc`: timing constraints.
- `td_project/camera_to_dsi_display_Runs/syn_1/`: synthesis settings and
  project source list.
- `td_project/camera_to_dsi_display_Runs/phy_1/`: implementation settings and
  project source list.

Generated databases, logs, temporary run directories, and bitstreams are not
stored here. The build script creates those under `work/td_industrial/` and
publishes release artifacts under `release/industrial-v1/`.

The TangDynasty executable, flow Tcl script, and the target device installation
remain external tool inputs. Pass them explicitly when the tool is not on the
default path, for example:

```powershell
$env:FPGA_TD_EXE = "<TD_INSTALL>\app\bin\td_commands_prompt.exe"
$env:FPGA_FLOW_TCL = "<TD_INSTALL>\app\doc\scripts\DefaultFlow.tcl"
python scripts/build_industrial_td.py `
  --td-exe $env:FPGA_TD_EXE `
  --flow-tcl $env:FPGA_FLOW_TCL
```

The package is a snapshot of the vendor/project input state. The complete
application source set is the repository combination of this package,
`fallback/rtl/`, `fallback/td_source/`, and the approved
`fallback/rtl/video/video_cartoon_region_fill.v` formal entry.
Its contents do not imply that the HX1P35A board pin assignment has been confirmed; the
HX1P35A/HX1P35B document discrepancy remains tracked in
`docs/research/known-gaps.md`.
