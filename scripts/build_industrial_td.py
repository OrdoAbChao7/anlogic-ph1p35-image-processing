#!/usr/bin/env python3
"""Automated build runner for Tang Dynasty (TD) 6.2 on PH1P35 Industrial Inspection Project.

Steps:
1. Verify work/td_industrial exists and top wrapper is patched with industrial inspection subsystem.
2. Prepare camera_to_dsi_display_Runs/syn_1 and phy_1 with settings.cfg and camera_to_dsi_display.prj.
3. Run synthesis via td_commands_prompt.exe.
4. Run physical design (opt_place -> opt_route -> bitgen) via td_commands_prompt.exe.
5. Check timing QoR (Setup/Hold WNS, TNS).
6. Copy generated bitstream to work/output/industrial-release/ and compute SHA-256.
"""

import hashlib
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TD_EXE = Path("E:/Projects/FPGA/.tools/td/app/bin/td_commands_prompt.exe")
FLOW_TCL = Path("E:/Projects/FPGA/.tools/td/app/doc/scripts/DefaultFlow.tcl")
ORIG_RUNS = Path("E:/Projects/FPGA/HX1P35A2026/lab_ex1_mipi_hdmi_SC520_original/lab_ex1_mipi_hdmi_SC520/lab_ex1_mipi_hdmi/td_project/camera_to_dsi_display_Runs")
WORK_PROJECT = ROOT / "work" / "td_industrial"
WORK_RUNS = WORK_PROJECT / "td_project" / "camera_to_dsi_display_Runs"
# Keep the one-file download artifact in the tracked release directory so a
# clean build and the README point to the same output.
RELEASE_DIR = ROOT / "release" / "industrial-v1"
TRACKED_RTL = ROOT / "fallback" / "rtl"
# The approved cartoon contract is s3_luma.  The TD project still receives the
# source under the module's historical filename, because the top-level wrapper
# instantiates the module as ``video_cartoon``.
TRACKED_VIDEO = ROOT / "work" / "rtl" / "video_cartoon_luma.v"
TRACKED_TOP = ROOT / "fallback" / "td_source" / "design_top_wrapper.v"
TRACKED_ISP = ROOT / "fallback" / "td_source" / "isp" / "isp_top.v"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()


def setup_runs():
    print("[1/5] Setting up synthesis and physical design runs for Industrial Inspection...")

    # Refresh vendor-project application sources from the tracked RTL.
    for rtl_name in ["morph_open_96.v", "color_detect_96_v2.v", "defect_classifier.v", "bbox_draw_overlay.v", "anlogic_logo_rom.v", "industrial_osd_overlay.v", "mode_controller.v"]:
        src = TRACKED_RTL / rtl_name
        dst = WORK_PROJECT / "user_source" / "hdl_source" / rtl_name
        if not src.exists():
            raise FileNotFoundError(f"Tracked RTL missing: {src}")
        shutil.copy2(src, dst)
    if not TRACKED_VIDEO.exists():
        raise FileNotFoundError(f"Tracked video RTL missing: {TRACKED_VIDEO}")
    shutil.copy2(TRACKED_VIDEO, WORK_PROJECT / "user_source" / "hdl_source" / "video_cartoon.v")
    if not TRACKED_TOP.exists() or not TRACKED_ISP.exists():
        raise FileNotFoundError("Tracked TD top integration sources are missing")
    shutil.copy2(TRACKED_TOP, WORK_PROJECT / "user_source" / "hdl_source" / "design_top_wrapper.v")
    (WORK_PROJECT / "user_source" / "hdl_source" / "isp").mkdir(parents=True, exist_ok=True)
    shutil.copy2(TRACKED_ISP, WORK_PROJECT / "user_source" / "hdl_source" / "isp" / "isp_top.v")
    top_src = WORK_PROJECT / "user_source" / "hdl_source" / "design_top_wrapper.v"
    isp_src = WORK_PROJECT / "user_source" / "hdl_source" / "isp" / "isp_top.v"
    required_top = ["O_ind_result_toggle", "mode_controller", "industrial_osd_overlay", "ind_toggle_meta", "S_osd_out_data"]
    required_isp = ["O_ind_invalid", "O_ind_result_toggle", "O_led_det"]
    for marker in required_top:
        if marker not in top_src.read_text(encoding="utf-8", errors="replace"):
            raise RuntimeError(f"TD top wrapper missing required integration marker: {marker}")
    for marker in required_isp:
        if marker not in isp_src.read_text(encoding="utf-8", errors="replace"):
            raise RuntimeError(f"TD ISP top missing required integration marker: {marker}")
    print("      synchronized tracked industrial RTL into TD source tree")
    print("      verified industrial top wrapper and ISP integration markers")
    syn_dir = WORK_RUNS / "syn_1"
    phy_dir = WORK_RUNS / "phy_1"
    syn_dir.mkdir(parents=True, exist_ok=True)
    phy_dir.mkdir(parents=True, exist_ok=True)

    # Clean previous run artifacts
    for ext in ["*.db", "*.bit", "*.bin", "*.qor", "*.log", "*.rpt"]:
        for f in syn_dir.glob(ext):
            try: f.unlink()
            except Exception: pass
        for f in phy_dir.glob(ext):
            try: f.unlink()
            except Exception: pass

    # 1. Copy settings.cfg
    shutil.copy2(ORIG_RUNS / "syn_1" / "settings.cfg", syn_dir / "settings.cfg")
    shutil.copy2(ORIG_RUNS / "phy_1" / "settings.cfg", phy_dir / "settings.cfg")

    # 2. Patch prj files with custom modules
    extra_entries = """            <File Path="../../../user_source/hdl_source/anlogic_logo_rom.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&amp;R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="55"/>
                </FileInfo>
            </File>
            <File Path="../../../user_source/hdl_source/mode_controller.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&amp;R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="56"/>
                </FileInfo>
            </File>
            <File Path="../../../user_source/hdl_source/morph_open_96.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&amp;R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="57"/>
                </FileInfo>
            </File>
            <File Path="../../../user_source/hdl_source/video_cartoon.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&amp;R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="58"/>
                </FileInfo>
            </File>
            <File Path="../../../user_source/hdl_source/color_detect_96_v2.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&amp;R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="59"/>
                </FileInfo>
            </File>
            <File Path="../../../user_source/hdl_source/defect_classifier.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&amp;R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="60"/>
                </FileInfo>
            </File>
            <File Path="../../../user_source/hdl_source/bbox_draw_overlay.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&amp;R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="61"/>
                </FileInfo>
            </File>
            <File Path="../../../user_source/hdl_source/industrial_osd_overlay.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&amp;R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="62"/>
                </FileInfo>
            </File>
        """

    orig_syn_prj = (ORIG_RUNS / "syn_1" / "camera_to_dsi_display.prj").read_text(encoding="utf-8")
    if "bbox_draw_overlay.v" not in orig_syn_prj:
        orig_syn_prj = orig_syn_prj.replace("        </Verilog>", extra_entries + "        </Verilog>")
    (syn_dir / "camera_to_dsi_display.prj").write_text(orig_syn_prj, encoding="utf-8")

    orig_phy_prj = (ORIG_RUNS / "phy_1" / "camera_to_dsi_display.prj").read_text(encoding="utf-8")
    if "bbox_draw_overlay.v" not in orig_phy_prj:
        orig_phy_prj = orig_phy_prj.replace("        </Verilog>", extra_entries + "        </Verilog>")
    (phy_dir / "camera_to_dsi_display.prj").write_text(orig_phy_prj, encoding="utf-8")

    print(f"      syn_1 configured: {syn_dir}")
    print(f"      phy_1 configured: {phy_dir}")


def run_step(step_name: str, step_dir: Path):
    print(f"\n[RUN] Starting {step_name} in {step_dir}...")
    t0 = time.time()
    tcl_path = FLOW_TCL.resolve().as_posix()
    cmd = [str(TD_EXE.resolve()), tcl_path]

    log_file = step_dir / "flow_exec.log"
    has_error = False
    error_lines = []
    with log_file.open("w", encoding="utf-8", errors="replace") as lf:
        proc = subprocess.Popen(
            cmd,
            cwd=str(step_dir),
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace"
        )
        for line in proc.stdout:
            lf.write(line)
            lf.flush()
            stripped = line.strip()
            if "ERROR" in stripped or "FATAL" in stripped:
                has_error = True
                error_lines.append(stripped)
            if any(k in stripped for k in ["start command", "finish command", "ERROR", "FATAL", "CRITICAL", "qor", "QoR", "WNS", "TNS"]):
                print(f"  [{step_name}] {stripped}")

        proc.wait()
        elapsed = time.time() - t0
        print(f"[{step_name}] Finished in {elapsed:.1f}s, exit code: {proc.returncode}")
        if proc.returncode != 0 or has_error:
            raise RuntimeError(f"{step_name} encountered errors! Errors:\n" + "\n".join(error_lines) + f"\nSee full log: {log_file}")



def check_qor():
    print("\n[4/5] Checking Timing and Resource QoR...")
    qor_file = WORK_RUNS / "phy_1" / "route.qor"
    if not qor_file.exists():
        print(f"[WARN] route.qor not found at {qor_file}")
        return

    content = qor_file.read_text(encoding="utf-8", errors="replace")
    print("\n--- route.qor Summary ---")
    for line in content.splitlines():
        if any(k in line for k in ["WNS", "TNS", "Slack", "Slice", "LUT", "Register", "BRAM", "DSP", "RAM", "Clock"]):
            print(" ", line.strip())


def collect_release():
    print(f"\n[5/5] Collecting release artifacts into {RELEASE_DIR}...")
    RELEASE_DIR.mkdir(parents=True, exist_ok=True)
    phy_dir = WORK_RUNS / "phy_1"

    bit_files = list(phy_dir.glob("*.bit"))
    if not bit_files:
        raise FileNotFoundError(f"No .bit files generated in {phy_dir}")

    for bf in bit_files:
        dest = RELEASE_DIR / bf.name
        shutil.copy2(bf, dest)
        h = sha256(dest)
        size = dest.stat().st_size
        print(f"  Artifact: {dest.name}")
        print(f"    Size:    {size:,} bytes")
        print(f"    SHA-256: {h}")

    for rpt in ["route.qor", "final_timing.rpt"]:
        src = phy_dir / rpt
        if src.exists():
            shutil.copy2(src, RELEASE_DIR / rpt)
            print(f"  Copied report: {rpt}")


def main():
    print("=" * 70)
    print("Tang Dynasty Automated Build: PH1P35 Industrial Inspection Subsystem")
    print("=" * 70)

    if not TD_EXE.exists():
        raise FileNotFoundError(f"TD executable not found: {TD_EXE}")
    if not FLOW_TCL.exists():
        raise FileNotFoundError(f"DefaultFlow.tcl not found: {FLOW_TCL}")

    setup_runs()

    # Step 1: Synthesis
    run_step("Synthesis (syn_1)", WORK_RUNS / "syn_1")

    # Step 2: Physical Design & Bitgen
    run_step("Physical Design (phy_1)", WORK_RUNS / "phy_1")

    # Step 3: Check QoR
    check_qor()

    # Step 4: Collect Release Artifacts
    collect_release()

    print("\n" + "=" * 70)
    print("BUILD COMPLETE! Bitstream ready for on-board testing.")
    print("=" * 70)


if __name__ == "__main__":
    main()
