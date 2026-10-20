---
name: fpga-dev-loop
description: Drive automated FPGA verification, Python golden model comparisons, TangDynasty builds, QoR report parsing, and closed-loop RTL defect diagnosis for Anlogic PH1P35 FPGA projects.
---

# FPGA Agent Development Loop Skill

Use this skill when you need to:
1. Audit the local FPGA development environment, Python packages, Icarus Verilog, and TangDynasty tools.
2. Run RTL simulation against bit-exact Python Golden reference models (e.g. `color_detect_96.v`).
3. Run industrial Verilog regression test suites.
4. Execute safe, isolated TangDynasty (TD 6.2.1) synthesis and physical design without corrupting baselines.
5. Parse and inspect timing metrics (Setup/Hold WNS, TNS in ps/ns) and resource utilization (Slices, RAMs, DSPs).
6. Automatically diagnose simulation failures, pinpoint root causes, and evaluate minimal trial patches.

---

## 1. Fast CLI Commands

Always run these commands from the repository root:

### Environment Health Check
```powershell
.\scripts\fpga-loop.ps1 doctor
# or: python -m work.fpga_loop doctor
```

### RTL Functional Verification
```powershell
# Run dynamic frame simulation against bit-exact Python Golden Model
.\scripts\fpga-loop.ps1 test --module color_detect_96

# Also run all 9 established fallback Verilog regression testbenches
.\scripts\fpga-loop.ps1 test --module color_detect_96 --regressions
```

### Full Development Loop (Doctor -> Sim -> Gate -> Report)
```powershell
.\scripts\fpga-loop.ps1 run --module color_detect_96
```

### TangDynasty Timing & Resource Report Parsing
```powershell
.\scripts\fpga-loop.ps1 report
# or inspect specific run
.\scripts\fpga-loop.ps1 report --run-id <run_id>
```

---

## 2. Python API Usage

When writing test scripts or autonomous agent workflows:

```python
from work.fpga_loop.golden.color_detect_96_golden import ColorDetect96Golden
from work.fpga_loop.sim.iverilog_runner import ColorDetectSimulator
from work.fpga_loop.parsers.td_report_parser import TDReportParser
from work.fpga_loop.core.diagnostic import RTLDiagnoser

# 1. Simulate against golden model
sim = ColorDetectSimulator()
model = ColorDetect96Golden(img_width=16, img_height=4)
img = model.generate_single_pixel(x=7, y=2)
result = sim.run_single_frame_test(img, test_name="my_test")

if not result.passed:
    print(f"Mismatch: {result.error_message}")
    # 2. Automated diagnosis
    finding = RTLDiagnoser.diagnose_color_detect(result)
    print(f"Defect: {finding.defect_type}, Suggested fix: {finding.suggested_patch}")

# 3. Parse TD reports
report = TDReportParser.parse_directory(Path("work/td_cartoon/td_project/camera_to_dsi_display_Runs/phy_1"))
if report.timing:
    print(f"WNS: {report.timing.setup_wns_ps} ps, Slices: {report.utilization.slices}")
```

---

## 3. Mandatory Safety Constraints

- **Never bypass Stage Gates**: Bitstream generation is blocked unless RTL simulation passes.
- **Unit Integrity**: TangDynasty `route.qor` reports integer picoseconds (`ps`). `final_timing.rpt` reports nanoseconds (`ns`). Always verify units before comparing slacks.
- **No Hardware Overwrites**: Builds must be performed in isolated directories under `work/fpga_loop/runs/`.
- **Default No-Flash**: Automatic FPGA board flashing is strictly disabled by default.
