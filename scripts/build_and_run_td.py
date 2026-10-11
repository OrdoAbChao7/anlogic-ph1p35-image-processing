#!/usr/bin/env python3
"""Automated build runner for Tang Dynasty (TD) 6.2 on SC520 cartoon project.

Steps:
1. Verify work/td_cartoon exists and top wrapper is patched.
2. Prepare camera_to_dsi_display_Runs/syn_1 and phy_1 with settings.cfg and camera_to_dsi_display.prj.
3. Run synthesis via td_commands_prompt.exe.
4. Run physical design (opt_place -> opt_route -> bitgen) via td_commands_prompt.exe.
5. Check timing QoR (Setup/Hold WNS, TNS).
6. Copy generated bitstream to work/output/cartoon-release/ and compute SHA-256.
"""

import hashlib
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TD_EXE = ROOT / ".tools" / "td" / "app" / "bin" / "td_commands_prompt.exe"
FLOW_TCL = ROOT / ".tools" / "td" / "app" / "doc" / "scripts" / "DefaultFlow.tcl"
ORIG_RUNS = ROOT / "HX1P35A2026" / "lab_ex1_mipi_hdmi_SC520_original" / "lab_ex1_mipi_hdmi_SC520" / "lab_ex1_mipi_hdmi" / "td_project" / "camera_to_dsi_display_Runs"
WORK_PROJECT = ROOT / "work" / "td_cartoon" / "td_project"
WORK_RUNS = WORK_PROJECT / "camera_to_dsi_display_Runs"
RELEASE_DIR = ROOT / "work" / "output" / "cartoon-release"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()


def setup_runs():
    print("[1/5] Setting up synthesis and physical design runs...")
    syn_dir = WORK_RUNS / "syn_1"
    phy_dir = WORK_RUNS / "phy_1"
    syn_dir.mkdir(parents=True, exist_ok=True)
    phy_dir.mkdir(parents=True, exist_ok=True)

    # 1. Copy settings.cfg
    shutil.copy2(ORIG_RUNS / "syn_1" / "settings.cfg", syn_dir / "settings.cfg")
    shutil.copy2(ORIG_RUNS / "phy_1" / "settings.cfg", phy_dir / "settings.cfg")

    # 2. Patch prj files with video_cartoon.v
    cartoon_entry = """            <File Path="../../../user_source/hdl_source/video_cartoon.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&amp;R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="56"/>
                </FileInfo>
            </File>
"""

    orig_syn_prj = (ORIG_RUNS / "syn_1" / "camera_to_dsi_display.prj").read_text(encoding="utf-8")
    if "video_cartoon.v" not in orig_syn_prj:
        orig_syn_prj = orig_syn_prj.replace("        </Verilog>", cartoon_entry + "        </Verilog>")
    (syn_dir / "camera_to_dsi_display.prj").write_text(orig_syn_prj, encoding="utf-8")

    orig_phy_prj = (ORIG_RUNS / "phy_1" / "camera_to_dsi_display.prj").read_text(encoding="utf-8")
    if "video_cartoon.v" not in orig_phy_prj:
        orig_phy_prj = orig_phy_prj.replace("        </Verilog>", cartoon_entry + "        </Verilog>")
    (phy_dir / "camera_to_dsi_display.prj").write_text(orig_phy_prj, encoding="utf-8")

    print(f"      syn_1 configured: {syn_dir}")
    print(f"      phy_1 configured: {phy_dir}")


def run_step(step_name: str, step_dir: Path):
    print(f"\n[RUN] Starting {step_name} in {step_dir}...")
    t0 = time.time()
    tcl_path = FLOW_TCL.resolve().as_posix()
    cmd = [str(TD_EXE.resolve()), tcl_path]
    
    log_file = step_dir / "flow_exec.log"
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
            # Echo milestones to console
            stripped = line.strip()
            if any(k in stripped for k in ["start command", "finish command", "ERROR", "FATAL", "CRITICAL", "qor", "QoR", "WNS", "TNS"]):
                print(f"  [{step_name}] {stripped}")

        proc.wait()
        elapsed = time.time() - t0
        print(f"[{step_name}] Finished in {elapsed:.1f}s, exit code: {proc.returncode}")
        if proc.returncode != 0:
            raise RuntimeError(f"{step_name} failed with exit code {proc.returncode}. See log: {log_file}")


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

    # Copy timing report
    for rpt in ["route.qor", "final_timing.rpt"]:
        src = phy_dir / rpt
        if src.exists():
            shutil.copy2(src, RELEASE_DIR / rpt)
            print(f"  Copied report: {rpt}")


def main():
    print("=" * 60)
    print("Tang Dynasty Automated Build: SC520 Video Cartoon")
    print("=" * 60)

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

    print("\n" + "=" * 60)
    print("BUILD COMPLETE! Bitstream ready for download.")
    print("=" * 60)


if __name__ == "__main__":
    main()
