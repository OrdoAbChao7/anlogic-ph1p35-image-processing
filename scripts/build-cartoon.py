#!/usr/bin/env python3
"""Create a cartoon-enabled TD project from the original working SC520 project.

Steps:
1. Copy the entire original project to a working directory.
2. Patch design_top_wrapper.v to add button ports and insert video_cartoon.
3. Copy video_cartoon.v into the project.
4. Add button pin constraints to pin.adc.
5. Add video_cartoon.v to the .al project file.
6. Print instructions (or optionally run TD).

Usage:
    python scripts/build-cartoon.py [--run-td]
"""
import argparse
import shutil
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

ORIG_PROJECT = ROOT / "HX1P35A2026" / "lab_ex1_mipi_hdmi_SC520_original" / \
    "lab_ex1_mipi_hdmi_SC520" / "lab_ex1_mipi_hdmi"
CARTOON_RTL = ROOT / "work" / "rtl" / "video_cartoon.v"
WORK_DIR = ROOT / "work" / "td_cartoon"


def copy_project(dst: Path):
    """Copy the original project, skip heavy build artifacts."""
    if dst.exists():
        print(f"[WARN] Removing existing work copy: {dst}")
        shutil.rmtree(dst)
    # Copy entire project
    shutil.copytree(ORIG_PROJECT, dst, dirs_exist_ok=False)
    # Remove old build runs to force clean build
    runs_dir = dst / "td_project" / "camera_to_dsi_display_Runs"
    if runs_dir.exists():
        shutil.rmtree(runs_dir)
    print(f"[OK] Project copied to {dst}")


def patch_top_wrapper(dst: Path):
    """Modify design_top_wrapper.v to insert video_cartoon between hdmi_mixer
    and hdmi_tx, and add I_button2/I_button3 ports."""
    top_v = dst / "user_source" / "hdl_source" / "design_top_wrapper.v"
    text = top_v.read_text(encoding='utf-8')

    # === 1. Add I_button2, I_button3 ports to the module declaration ===
    # Find the line with "inout wire [1:0]  I_button,"  and add after it
    old_button = "    inout wire [1:0]  I_button,"
    new_button = (
        "    inout wire [1:0]  I_button,\n"
        "    inout wire        I_button2,   // SW: edge mode select (active low)\n"
        "    inout wire        I_button3,   // SW: cartoon mode select (active low)"
    )
    if "I_button2" not in text:
        text = text.replace(old_button, new_button)
        print("[OK] Added I_button2, I_button3 ports")
    else:
        print("[SKIP] I_button2/I_button3 ports already present")

    # === 2. Add internal wires for cartoon pipeline ===
    # Find the wire declarations for S_hdmi_out_* signals and add cartoon wires
    cartoon_wires = """
    // --- video_cartoon pipeline wires ---
    wire        S_cartoon_out_vsync;
    wire        S_cartoon_out_hsync;
    wire        S_cartoon_out_de;
    wire [23:0] S_cartoon_out_data;
    wire [1:0]  S_cartoon_mode;
"""
    if "S_cartoon_out_vsync" not in text:
        # Insert before the uivtc instantiation
        vtc_marker = "    uivtc #("
        text = text.replace(vtc_marker, cartoon_wires + "\n" + vtc_marker)
        print("[OK] Added cartoon wire declarations")

    # === 3. Insert video_cartoon instance between hdmi_mixer output and hdmi_tx input ===
    # Change hdmi_tx connections from S_hdmi_out_* to S_cartoon_out_*
    cartoon_instance = """
    // --- Cartoon / Edge / Raw mode filter ---
    // Inserted between hdmi_mixer output and hdmi_tx input.
    // Six-stage pipeline: line buffer, 3x3 window, Gaussian blur,
    // Sobel edge, color quantize, output mux.
    video_cartoon #(
        .WIDTH          ( 1280 ),
        .HEIGHT         ( 720  ),
        .EDGE_THRESHOLD ( 12'd160 )
    ) u_video_cartoon (
        .clk            ( S_hdmi_pixel_clk     ),
        .rst_n          ( S_hdmi_rst_n         ),
        .i_vs           ( S_hdmi_out_vsync     ),
        .i_hs           ( S_hdmi_out_hsync     ),
        .i_de           ( S_hdmi_out_de        ),
        .i_rgb          ( S_hdmi_out_data      ),
        .i_edge_req     ( ~I_button2           ),  // active-low button
        .i_toon_req     ( ~I_button3           ),  // active-low button
        .i_overlay      ( 1'b0                 ),  // no OSD overlay for now
        .i_overlay_rgb  ( 24'd0                ),
        .o_vs           ( S_cartoon_out_vsync  ),
        .o_hs           ( S_cartoon_out_hsync  ),
        .o_de           ( S_cartoon_out_de     ),
        .o_rgb          ( S_cartoon_out_data   ),
        .o_mode         ( S_cartoon_mode       )
    );

"""

    if "u_video_cartoon" not in text:
        # Insert just before hdmi_tx instantiation
        hdmi_tx_marker = "    hdmi_tx u_hdmi_tx("
        text = text.replace(hdmi_tx_marker, cartoon_instance + hdmi_tx_marker)
        print("[OK] Inserted video_cartoon instance")

        # Now rewire hdmi_tx inputs from S_hdmi_out_* to S_cartoon_out_*
        text = text.replace(
            ".I_video_in_vs      ( S_hdmi_out_vsync  )",
            ".I_video_in_vs      ( S_cartoon_out_vsync )"
        )
        text = text.replace(
            ".I_video_in_de      ( S_hdmi_out_de     )",
            ".I_video_in_de      ( S_cartoon_out_de    )"
        )
        text = text.replace(
            ".I_video_in_data    ( S_hdmi_out_data   )",
            ".I_video_in_data    ( S_cartoon_out_data  )"
        )
        print("[OK] Rewired hdmi_tx inputs to cartoon outputs")
    else:
        print("[SKIP] video_cartoon instance already present")

    top_v.write_text(text, encoding='utf-8')


def copy_cartoon_rtl(dst: Path):
    """Copy video_cartoon.v into the project source tree."""
    target = dst / "user_source" / "hdl_source" / "video_cartoon.v"
    shutil.copy2(CARTOON_RTL, target)
    print(f"[OK] Copied video_cartoon.v -> {target}")


def patch_pin_constraints(dst: Path):
    """Add I_button2 and I_button3 pin assignments."""
    pin_adc = dst / "user_source" / "constraints_source" / "pin.adc"
    text = pin_adc.read_text(encoding='utf-8')
    button_lines = (
        "\nset_pin_assignment\t{ I_button2 }\t\t\t{ LOCATION = A4; IOSTANDARD = LVCMOS33; "
        "DRIVESTRENGTH = 8; PULLTYPE = PULLUP; }\n"
        "set_pin_assignment\t{ I_button3 }\t\t\t{ LOCATION = B4; IOSTANDARD = LVCMOS33; "
        "DRIVESTRENGTH = 8; PULLTYPE = PULLUP; }\n"
    )
    if "I_button2" not in text:
        text = text.rstrip() + "\n" + button_lines
        pin_adc.write_text(text, encoding='utf-8')
        print("[OK] Added I_button2 (A4), I_button3 (B4) to pin.adc")
    else:
        print("[SKIP] Button pins already in pin.adc")


def patch_al_project(dst: Path):
    """Add video_cartoon.v to the .al project file and fix project path."""
    al_file = dst / "td_project" / "camera_to_dsi_display.al"
    text = al_file.read_text(encoding='utf-8')

    # Fix project path to current location
    td_project_path = (dst / "td_project").as_posix()
    text = re.sub(
        r'Path="[^"]*"',
        f'Path="{td_project_path}"',
        text,
        count=1
    )

    # Add video_cartoon.v entry before </Verilog>
    cartoon_entry = """            <File Path="../user_source/hdl_source/video_cartoon.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&amp;R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="56"/>
                </FileInfo>
            </File>
"""
    if "video_cartoon.v" not in text:
        text = text.replace("        </Verilog>", cartoon_entry + "        </Verilog>")
        print("[OK] Added video_cartoon.v to .al project")
    else:
        print("[SKIP] video_cartoon.v already in .al")

    al_file.write_text(text, encoding='utf-8')
    print(f"[OK] Updated project path in .al")


def generate_td_tcl(dst: Path):
    """Generate a TCL script for batch TD build."""
    tcl = dst / "td_project" / "build_cartoon.tcl"
    al_path = (dst / "td_project" / "camera_to_dsi_display.al").as_posix()
    tcl_content = f"""# Auto-generated TCL for TD batch build of cartoon project
# Usage: td -cmd source build_cartoon.tcl

open_project "{al_path}"

run_synthesis -top design_top_wrapper
run_place
run_route
run_bitgen -compress

report_area -file cartoon_area.rpt
report_timing -setup -max_paths 20 -file cartoon_timing_setup.rpt
report_timing -hold  -max_paths 20 -file cartoon_timing_hold.rpt

close_project
exit
"""
    tcl.write_text(tcl_content, encoding='utf-8')
    print(f"[OK] Generated build TCL: {tcl}")
    return tcl


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-td', action='store_true',
                        help='Automatically run TD after patching')
    args = parser.parse_args()

    print("=" * 60)
    print("SC520 Cartoon Build Script")
    print("=" * 60)

    # Validate inputs
    if not ORIG_PROJECT.exists():
        raise FileNotFoundError(f"Original project not found: {ORIG_PROJECT}")
    if not CARTOON_RTL.exists():
        raise FileNotFoundError(f"Cartoon RTL not found: {CARTOON_RTL}")

    # Step 1: Copy project
    copy_project(WORK_DIR)

    # Step 2: Patch top wrapper
    patch_top_wrapper(WORK_DIR)

    # Step 3: Copy cartoon RTL
    copy_cartoon_rtl(WORK_DIR)

    # Step 4: Patch pin constraints
    patch_pin_constraints(WORK_DIR)

    # Step 5: Patch .al project file
    patch_al_project(WORK_DIR)

    # Step 6: Generate build TCL
    tcl_path = generate_td_tcl(WORK_DIR)

    print()
    print("=" * 60)
    print("DONE: Cartoon project prepared at:")
    print(f"  {WORK_DIR}")
    print()
    print("To build manually:")
    print(f'  1. Open TD 6.2')
    print(f'  2. Open project: {WORK_DIR / "td_project" / "camera_to_dsi_display.al"}')
    print(f'  3. Run synthesis, place, route, bitgen')
    print()
    print("Or batch build:")
    print(f'  td -cmd "source {tcl_path.as_posix()}"')
    print("=" * 60)

    if args.run_td:
        import subprocess
        td_exe = ROOT / ".tools" / "td" / "app" / "bin" / "td.exe"
        if not td_exe.exists():
            # Try finding TD in the path
            td_exe = Path("td")
        print(f"\n[RUN] Launching TD: {td_exe}")
        subprocess.run([str(td_exe), "-cmd", f"source {tcl_path.as_posix()}"],
                       cwd=str(WORK_DIR / "td_project"))


if __name__ == '__main__':
    main()
