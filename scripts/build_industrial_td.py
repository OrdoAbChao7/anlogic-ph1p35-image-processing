#!/usr/bin/env python3
"""Automated build runner for Tang Dynasty (TD) 6.2 on PH1P35 Industrial Inspection Project.

Steps:
1. Create or refresh the temporary work/td_industrial tree and verify the top wrapper is patched with industrial inspection subsystem.
2. Prepare camera_to_dsi_display_Runs/syn_1 and phy_1 with settings.cfg and camera_to_dsi_display.prj.
3. Run synthesis via td_commands_prompt.exe.
4. Run physical design (opt_place -> opt_route -> bitgen) via td_commands_prompt.exe.
5. Check timing QoR (Setup/Hold WNS, TNS).
6. Copy generated bitstream to release/industrial-v1/ and compute SHA-256.
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _env_or_repo_path(name: str, *relative_parts: str) -> Path:
    """Resolve an external input from the environment or this checkout.

    The repository must not encode the author's machine-specific worktree.  A
    missing external tool is reported by ``validate_inputs`` with the path the
    caller can override through the documented environment variable/CLI flag.
    """
    value = os.environ.get(name)
    if value:
        return Path(value).expanduser()
    return ROOT.joinpath(*relative_parts)


DEFAULT_TD_EXE = _env_or_repo_path(
    "FPGA_TD_EXE", ".tools", "td", "app", "bin", "td_commands_prompt.exe"
)
DEFAULT_FLOW_TCL = _env_or_repo_path(
    "FPGA_FLOW_TCL", ".tools", "td", "app", "doc", "scripts", "DefaultFlow.tcl"
)
DEFAULT_ORIG_RUNS = _env_or_repo_path(
    "FPGA_BASELINE_RUNS",
    "fallback", "td_package", "td_project", "camera_to_dsi_display_Runs"
)
DEFAULT_INPUT_PACKAGE = _env_or_repo_path(
    "FPGA_TD_INPUT_PACKAGE", "fallback", "td_package"
)
DEFAULT_WORK_PROJECT = ROOT / "work" / "td_industrial"
WORK_PROJECT = DEFAULT_WORK_PROJECT
WORK_RUNS = WORK_PROJECT / "td_project" / "camera_to_dsi_display_Runs"
# Keep the one-file download artifact in the tracked release directory so a
# clean build and the README point to the same output.
DEFAULT_RELEASE_DIR = ROOT / "release" / "industrial-v1"
FINAL_BITSTREAM_NAME = "camera_to_dsi_display_compress.bit"
TD_EXE = DEFAULT_TD_EXE
FLOW_TCL = DEFAULT_FLOW_TCL
RUN_FLOW_TCL = DEFAULT_FLOW_TCL
PLACE_SEED = None
ORIG_RUNS = DEFAULT_ORIG_RUNS
INPUT_PACKAGE = DEFAULT_INPUT_PACKAGE
RELEASE_DIR = DEFAULT_RELEASE_DIR
TRACKED_RTL = ROOT / "fallback" / "rtl"
# The formal release follows the approved v1 Cartoon contract: per-channel
# quantization, four-neighbour region fill, and Sobel contour fusion. The TD
# project receives the source under the historical filename because the
# top-level wrapper instantiates the module as ``video_cartoon``.
DEFAULT_TRACKED_VIDEO = TRACKED_RTL / "video" / "video_cartoon_region_fill.v"
TRACKED_VIDEO = DEFAULT_TRACKED_VIDEO
TRACKED_TOP = ROOT / "fallback" / "td_source" / "design_top_wrapper.v"
TRACKED_ISP = ROOT / "fallback" / "td_source" / "isp" / "isp_top.v"
TRACKED_VTC = ROOT / "fallback" / "td_source" / "uivtc_guarded.v"
TRACKED_MIXER = ROOT / "fallback" / "td_source" / "hdmi_mixer_guarded.v"
TRACKED_DDR_INTERFACE = ROOT / "fallback" / "td_package" / "user_source" / "hdl_source" / "mc_to_user_interface.v"
TRACKED_RTL_FILES = {
    "morph_open_96.v": TRACKED_RTL / "inspection" / "morph_open_96.v",
    "color_detect_96_v2.v": TRACKED_RTL / "inspection" / "color_detect_96_v2.v",
    "defect_classifier.v": TRACKED_RTL / "inspection" / "defect_classifier.v",
    "bbox_draw_overlay.v": TRACKED_RTL / "inspection" / "bbox_draw_overlay.v",
    "inspection_result_cdc.v": TRACKED_RTL / "inspection" / "inspection_result_cdc.v",
    "anlogic_logo_rom.v": TRACKED_RTL / "display" / "anlogic_logo_rom.v",
    "industrial_osd_overlay.v": TRACKED_RTL / "display" / "industrial_osd_overlay.v",
    "mode_controller.v": TRACKED_RTL / "control" / "mode_controller.v",
    "industrial_v2_result_cdc.v": TRACKED_RTL / "integration" / "industrial_v2_result_cdc.v",
    "industrial_v2_display_tracking.v": TRACKED_RTL / "integration" / "industrial_v2_display_tracking.v",
    "industrial_v2_feature_spine.v": TRACKED_RTL / "integration" / "industrial_v2_feature_spine.v",
    "motion_grid_adapter_96.v": TRACKED_RTL / "integration" / "motion_grid_adapter_96.v",
    "frame_stats_96.v": TRACKED_RTL / "integration" / "frame_stats_96.v",
    "temporal_tracker.v": TRACKED_RTL / "inspection" / "temporal_tracker.v",
    "trajectory_history.v": TRACKED_RTL / "inspection" / "trajectory_history.v",
    "frame_tag_monitor.v": TRACKED_RTL / "inspection" / "frame_tag_monitor.v",
    "latency_monitor.v": TRACKED_RTL / "inspection" / "latency_monitor.v",
    "motion_diff_160.v": TRACKED_RTL / "inspection" / "motion_diff_160.v",
    "dimension_calibrator.v": TRACKED_RTL / "inspection" / "dimension_calibrator.v",
    "tracking_overlay.v": TRACKED_RTL / "display" / "tracking_overlay.v",
    "awb_frame_gain_controller.v": TRACKED_RTL / "isp" / "awb_frame_gain_controller.v",
    "sort_event_controller.v": TRACKED_RTL / "control" / "sort_event_controller.v",
    "sort_safety_interlock.v": TRACKED_RTL / "control" / "sort_safety_interlock.v",
    "sort_pulse_generator.v": TRACKED_RTL / "control" / "sort_pulse_generator.v",
}
# These files intentionally override vendor snapshots only in the isolated TD
# work tree. The original package remains available as an untouched baseline.
TRACKED_SOURCE_OVERRIDES = {
    "vtc/uivtc.v": TRACKED_VTC,
    "hdmi_mixer.v": TRACKED_MIXER,
}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()


def portable_path(path: Path, external_name: str) -> str:
    """Return a repository-relative path or a stable external-input token."""
    try:
        return path.resolve().relative_to(ROOT.resolve()).as_posix()
    except ValueError:
        return f"<{external_name}>"


def describe_input(path: Path, external_name: str) -> dict:
    """Record enough metadata to detect drift in an external build input."""
    record = {
        "path": portable_path(path, external_name),
        "exists": path.exists(),
    }
    if path.is_file():
        record["size_bytes"] = path.stat().st_size
        record["sha256"] = sha256(path)
    return record


def build_input_provenance() -> dict:
    input_runs = selected_baseline_runs()
    baseline_files = {
        "syn_1/settings.cfg": input_runs / "syn_1" / "settings.cfg",
        "syn_1/camera_to_dsi_display.prj": input_runs / "syn_1" / "camera_to_dsi_display.prj",
        "phy_1/settings.cfg": input_runs / "phy_1" / "settings.cfg",
        "phy_1/camera_to_dsi_display.prj": input_runs / "phy_1" / "camera_to_dsi_display.prj",
    }
    return {
        "td_exe": describe_input(TD_EXE, "FPGA_TD_EXE"),
        "flow_tcl": describe_input(FLOW_TCL, "FPGA_FLOW_TCL"),
        "run_flow_tcl": describe_input(RUN_FLOW_TCL, "FPGA_FLOW_TCL_RUN"),
        "place_seed": PLACE_SEED,
        "input_package": describe_input(INPUT_PACKAGE, "FPGA_TD_INPUT_PACKAGE"),
        "baseline_files": {
            relative: describe_input(path, "FPGA_BASELINE_RUNS")
            for relative, path in baseline_files.items()
        },
    }


def parse_qor_metrics(content: str) -> dict:
    """Parse the route QoR fields required before a release can be copied."""
    fields = {
        "setup_wns_ps": "Setup WNS",
        "setup_tns_ps": "Setup TNS",
        "setup_violated_endpoints": "Num of violated S-EP",
        "hold_wns_ps": "Hold WNS",
        "hold_tns_ps": "Hold TNS",
        "hold_violated_endpoints": "Num of violated H-EP",
        "slices": "#slices",
        "slice_percent": "slices percentage",
        "rams": "#RAMs",
        "dsps": "#DSPs",
        "dramhardcon": "#DRAMHARDCON",
    }
    metrics = {}
    for key, label in fields.items():
        match = re.search(
            rf"\|\s*{re.escape(label)}\s*\|\s*([-+]?\d+(?:\.\d+)?)%?\s*\|",
            content,
            flags=re.IGNORECASE,
        )
        if match:
            value = float(match.group(1))
            metrics[key] = int(value) if value.is_integer() else value
    required = [
        "setup_wns_ps",
        "setup_tns_ps",
        "setup_violated_endpoints",
        "hold_wns_ps",
        "hold_tns_ps",
        "hold_violated_endpoints",
    ]
    missing = [key for key in required if key not in metrics]
    if missing:
        raise RuntimeError("QoR gate: missing required fields: " + ", ".join(missing))
    return metrics


def assert_qor_pass(metrics: dict) -> None:
    """Fail the build before release collection when routed timing is invalid."""
    failures = []
    if metrics["setup_wns_ps"] < 0:
        failures.append(f"setup WNS={metrics['setup_wns_ps']} ps")
    if metrics["setup_tns_ps"] != 0:
        failures.append(f"setup TNS={metrics['setup_tns_ps']} ps")
    if metrics["setup_violated_endpoints"] != 0:
        failures.append(f"setup violated endpoints={metrics['setup_violated_endpoints']}")
    if metrics["hold_wns_ps"] < 0:
        failures.append(f"hold WNS={metrics['hold_wns_ps']} ps")
    if metrics["hold_tns_ps"] != 0:
        failures.append(f"hold TNS={metrics['hold_tns_ps']} ps")
    if metrics["hold_violated_endpoints"] != 0:
        failures.append(f"hold violated endpoints={metrics['hold_violated_endpoints']}")
    if failures:
        raise RuntimeError("QoR gate failed: " + "; ".join(failures))


def select_final_bitstream(bit_files):
    """Return the single compressed bitstream intended for field download."""
    candidates = sorted(path for path in bit_files if path.name == FINAL_BITSTREAM_NAME)
    if len(candidates) != 1:
        names = ", ".join(path.name for path in sorted(bit_files)) or "<none>"
        raise RuntimeError(
            f"Release gate requires exactly one {FINAL_BITSTREAM_NAME}; generated files: {names}"
        )
    return candidates[0]


def parse_args(argv=None):
    parser = argparse.ArgumentParser(
        description="Build the PH1P35 fixed-red industrial-inspection TD project."
    )
    parser.add_argument(
        "--td-exe",
        default=str(DEFAULT_TD_EXE),
        help="Tang Dynasty command executable (or FPGA_TD_EXE).",
    )
    parser.add_argument(
        "--flow-tcl",
        default=str(DEFAULT_FLOW_TCL),
        help="Tang Dynasty DefaultFlow.tcl (or FPGA_FLOW_TCL).",
    )
    parser.add_argument(
        "--place-seed",
        type=int,
        default=None,
        help="Optional deterministic Tang Dynasty placement seed; the flow is copied into the isolated workspace.",
    )
    parser.add_argument(
        "--baseline-runs",
        default=str(DEFAULT_ORIG_RUNS),
        help="Legacy external camera_to_dsi_display_Runs directory (used if --input-package is incomplete).",
    )
    parser.add_argument(
        "--input-package",
        default=str(DEFAULT_INPUT_PACKAGE),
        help="Tracked TD source/configuration package; defaults to fallback/td_package (or FPGA_TD_INPUT_PACKAGE).",
    )
    parser.add_argument(
        "--release-dir",
        default=str(DEFAULT_RELEASE_DIR),
        help="Directory for the downloadable bitstream and provenance artifacts.",
    )
    parser.add_argument(
        "--video-rtl",
        default=str(TRACKED_VIDEO),
        help="Tracked video RTL source; defaults to the approved s4-region-fill implementation.",
    )
    parser.add_argument(
        "--work-project",
        default=str(DEFAULT_WORK_PROJECT),
        help="Isolated TD project workspace; defaults to work/td_industrial.",
    )
    parser.add_argument(
        "--manifest-only",
        action="store_true",
        help="Write a provenance manifest for existing release artifacts without running TD.",
    )
    return parser.parse_args(argv)


def configure(args):
    global TD_EXE, FLOW_TCL, RUN_FLOW_TCL, PLACE_SEED, ORIG_RUNS, INPUT_PACKAGE, RELEASE_DIR, TRACKED_VIDEO, WORK_PROJECT, WORK_RUNS
    TD_EXE = Path(args.td_exe).expanduser().resolve()
    FLOW_TCL = Path(args.flow_tcl).expanduser().resolve()
    RUN_FLOW_TCL = FLOW_TCL
    PLACE_SEED = args.place_seed
    if PLACE_SEED is not None and PLACE_SEED < 0:
        raise ValueError("--place-seed must be non-negative")
    ORIG_RUNS = Path(args.baseline_runs).expanduser().resolve()
    INPUT_PACKAGE = Path(args.input_package).expanduser().resolve()
    RELEASE_DIR = Path(args.release_dir).expanduser().resolve()
    TRACKED_VIDEO = Path(args.video_rtl).expanduser().resolve()
    WORK_PROJECT = Path(args.work_project).expanduser().resolve()
    WORK_RUNS = WORK_PROJECT / "td_project" / "camera_to_dsi_display_Runs"
    validate_build_isolation()


def validate_build_isolation():
    """Prevent a non-default video candidate from writing baseline outputs."""
    if TRACKED_VIDEO != DEFAULT_TRACKED_VIDEO:
        if WORK_PROJECT == DEFAULT_WORK_PROJECT:
            raise ValueError(
                "Candidate video RTL requires an isolated --work-project; "
                f"refusing to use {DEFAULT_WORK_PROJECT}"
            )
        if RELEASE_DIR == DEFAULT_RELEASE_DIR:
            raise ValueError(
                "Candidate video RTL requires an isolated --release-dir; "
                f"refusing to use {DEFAULT_RELEASE_DIR}"
            )


def assert_no_user_owned_artifacts(root: Path):
    """Fail if a user-owned simulation artifact enters a staged tree."""
    if not root.exists():
        return
    forbidden = [path for path in root.rglob("tb_color.vvp") if path.is_file()]
    if forbidden:
        joined = ", ".join(str(path) for path in forbidden)
        raise RuntimeError(f"User-owned artifact entered build tree: {joined}")


def package_is_complete() -> bool:
    required = [
        INPUT_PACKAGE / "user_source",
        INPUT_PACKAGE / "td_project" / "camera_to_dsi_display.sdc",
        INPUT_PACKAGE / "td_project" / "camera_to_dsi_display_Runs" / "syn_1" / "settings.cfg",
        INPUT_PACKAGE / "td_project" / "camera_to_dsi_display_Runs" / "syn_1" / "camera_to_dsi_display.prj",
        INPUT_PACKAGE / "td_project" / "camera_to_dsi_display_Runs" / "phy_1" / "settings.cfg",
        INPUT_PACKAGE / "td_project" / "camera_to_dsi_display_Runs" / "phy_1" / "camera_to_dsi_display.prj",
    ]
    return all(path.exists() for path in required)


def selected_baseline_runs() -> Path:
    if package_is_complete():
        return INPUT_PACKAGE / "td_project" / "camera_to_dsi_display_Runs"
    return ORIG_RUNS


def git_output(*args):
    try:
        return subprocess.check_output(
            ["git", *args], cwd=str(ROOT), text=True, stderr=subprocess.DEVNULL
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def source_manifest():
    source_paths = [
        TRACKED_VIDEO,
        TRACKED_TOP,
        TRACKED_ISP,
        *TRACKED_SOURCE_OVERRIDES.values(),
        TRACKED_DDR_INTERFACE,
        *TRACKED_RTL_FILES.values(),
    ]
    result = []
    for path in source_paths:
        if not path.exists():
            raise FileNotFoundError(f"Tracked source missing while writing manifest: {path}")
        result.append({
            "path": path.relative_to(ROOT).as_posix(),
            "sha256": sha256(path),
        })
    return result


def write_release_manifest(bit_files):
    artifacts = []
    for path in sorted(bit_files):
        if not path.exists():
            continue
        artifacts.append({
            "path": path.relative_to(ROOT).as_posix(),
            "size_bytes": path.stat().st_size,
            "sha256": sha256(path),
        })
    for name in ["route.qor", "final_timing.rpt"]:
        path = RELEASE_DIR / name
        if path.exists():
            artifacts.append({
                "path": path.relative_to(ROOT).as_posix(),
                "size_bytes": path.stat().st_size,
                "sha256": sha256(path),
            })
    manifest = {
        "project": "PH1P35 fixed-red industrial inspection v1",
        "target_device": "PH1P35MDG324",
        "git_commit": git_output("rev-parse", "HEAD"),
        "git_status": git_output("status", "--short"),
        "build_inputs": {
            "td_exe": portable_path(TD_EXE, "FPGA_TD_EXE"),
            "flow_tcl": portable_path(FLOW_TCL, "FPGA_FLOW_TCL"),
            "input_package": portable_path(INPUT_PACKAGE, "FPGA_TD_INPUT_PACKAGE"),
            "baseline_runs": portable_path(selected_baseline_runs(), "FPGA_BASELINE_RUNS"),
        },
        "build_input_hashes": build_input_provenance(),
        "sources": source_manifest(),
        "artifacts": artifacts,
    }
    manifest_path = RELEASE_DIR / "industrial-v1-manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"  Wrote provenance manifest: {manifest_path}")


def validate_inputs():
    required = {
        "Tang Dynasty executable": TD_EXE,
        "DefaultFlow.tcl": FLOW_TCL,
    }
    for label, path in required.items():
        if not path.exists():
            raise FileNotFoundError(
                f"{label} not found: {path}. Supply the location with the corresponding CLI option or environment variable."
            )
    if not package_is_complete():
        required = ["syn_1/settings.cfg", "phy_1/settings.cfg", "syn_1/camera_to_dsi_display.prj", "phy_1/camera_to_dsi_display.prj"]
        for name in required:
            path = ORIG_RUNS / name
            if not path.exists():
                raise FileNotFoundError(
                    f"TD input package is incomplete and legacy baseline file is missing: {path}"
                )


def setup_runs():
    print("[1/5] Setting up synthesis and physical design runs for Industrial Inspection...")

    # A candidate build may use a fresh workspace. Seed it from the tracked
    # TD project skeleton, but never copy an old synthesis/P&R run into the
    # candidate workspace. The default workspace is left untouched.
    if not WORK_PROJECT.exists():
        seed_root = INPUT_PACKAGE if package_is_complete() else ROOT / "work" / "td_industrial"
        if not seed_root.exists():
            raise FileNotFoundError(f"TD project input package missing: {seed_root}")
        shutil.copytree(
            seed_root,
            WORK_PROJECT,
            ignore=shutil.ignore_patterns(
                "camera_to_dsi_display_Runs",
                "*.log",
                "*.err.log",
                "*.out.log",
            ),
        )
        print(f"      seeded isolated TD workspace from {seed_root}")
    elif package_is_complete():
        shutil.copytree(
            INPUT_PACKAGE / "user_source",
            WORK_PROJECT / "user_source",
            dirs_exist_ok=True,
        )
        shutil.copy2(
            INPUT_PACKAGE / "td_project" / "camera_to_dsi_display.sdc",
            WORK_PROJECT / "td_project" / "camera_to_dsi_display.sdc",
        )
        print(f"      refreshed vendor source/configuration from {INPUT_PACKAGE}")

    # Refresh vendor-project application sources from the tracked RTL.
    for rtl_name, src in TRACKED_RTL_FILES.items():
        dst = WORK_PROJECT / "user_source" / "hdl_source" / rtl_name
        if not src.exists():
            raise FileNotFoundError(f"Tracked RTL missing: {src}")
        shutil.copy2(src, dst)
    for relative_name, src in TRACKED_SOURCE_OVERRIDES.items():
        dst = WORK_PROJECT / "user_source" / "hdl_source" / relative_name
        if not src.exists():
            raise FileNotFoundError(f"Tracked source override missing: {src}")
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
    if not TRACKED_VIDEO.exists():
        raise FileNotFoundError(f"Tracked video RTL missing: {TRACKED_VIDEO}")
    shutil.copy2(TRACKED_VIDEO, WORK_PROJECT / "user_source" / "hdl_source" / "video_cartoon.v")
    if not TRACKED_TOP.exists() or not TRACKED_ISP.exists():
        raise FileNotFoundError("Tracked TD top integration sources are missing")
    shutil.copy2(TRACKED_TOP, WORK_PROJECT / "user_source" / "hdl_source" / "design_top_wrapper.v")
    (WORK_PROJECT / "user_source" / "hdl_source" / "isp").mkdir(parents=True, exist_ok=True)
    shutil.copy2(TRACKED_ISP, WORK_PROJECT / "user_source" / "hdl_source" / "isp" / "isp_top.v")
    assert_no_user_owned_artifacts(WORK_PROJECT / "user_source")
    top_src = WORK_PROJECT / "user_source" / "hdl_source" / "design_top_wrapper.v"
    isp_src = WORK_PROJECT / "user_source" / "hdl_source" / "isp" / "isp_top.v"
    required_top = ["O_ind_result_toggle", "mode_controller", "industrial_osd_overlay", "inspection_result_cdc", "S_osd_out_data"]
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
    input_runs = selected_baseline_runs()
    shutil.copy2(input_runs / "syn_1" / "settings.cfg", syn_dir / "settings.cfg")
    shutil.copy2(input_runs / "phy_1" / "settings.cfg", phy_dir / "settings.cfg")

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
            <File Path="../../../user_source/hdl_source/inspection_result_cdc.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&amp;R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="63"/>
                </FileInfo>
            </File>
        """
    v2_extra_entries = """            <File Path="../../../user_source/hdl_source/industrial_v2_feature_spine.v">
                <FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="70"/></FileInfo>
            </File>
            <File Path="../../../user_source/hdl_source/motion_grid_adapter_96.v">
                <FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="71"/></FileInfo>
            </File>
            <File Path="../../../user_source/hdl_source/frame_stats_96.v">
                <FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="72"/></FileInfo>
            </File>
            <File Path="../../../user_source/hdl_source/frame_tag_monitor.v">
                <FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="73"/></FileInfo>
            </File>
            <File Path="../../../user_source/hdl_source/latency_monitor.v">
                <FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="74"/></FileInfo>
            </File>
            <File Path="../../../user_source/hdl_source/motion_diff_160.v">
                <FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="75"/></FileInfo>
            </File>
            <File Path="../../../user_source/hdl_source/dimension_calibrator.v">
                <FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="76"/></FileInfo>
            </File>
            <File Path="../../../user_source/hdl_source/awb_frame_gain_controller.v">
                <FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="77"/></FileInfo>
            </File>
            <File Path="../../../user_source/hdl_source/sort_event_controller.v">
                <FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="78"/></FileInfo>
            </File>
            <File Path="../../../user_source/hdl_source/sort_safety_interlock.v">
                <FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="79"/></FileInfo>
            </File>
            <File Path="../../../user_source/hdl_source/sort_pulse_generator.v">
                <FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="80"/></FileInfo>
            </File>
        """

    orig_syn_prj = (input_runs / "syn_1" / "camera_to_dsi_display.prj").read_text(encoding="utf-8")
    if "bbox_draw_overlay.v" not in orig_syn_prj:
        orig_syn_prj = orig_syn_prj.replace("        </Verilog>", extra_entries + "        </Verilog>")
    elif "inspection_result_cdc.v" not in orig_syn_prj:
        orig_syn_prj = orig_syn_prj.replace("        </Verilog>", extra_entries[extra_entries.index('            <File Path="../../../user_source/hdl_source/inspection_result_cdc.v">'): ] + "        </Verilog>")
    if "industrial_v2_feature_spine.v" not in orig_syn_prj:
        orig_syn_prj = orig_syn_prj.replace("        </Verilog>", v2_extra_entries + "        </Verilog>")
    (syn_dir / "camera_to_dsi_display.prj").write_text(orig_syn_prj, encoding="utf-8")

    orig_phy_prj = (input_runs / "phy_1" / "camera_to_dsi_display.prj").read_text(encoding="utf-8")
    if "bbox_draw_overlay.v" not in orig_phy_prj:
        orig_phy_prj = orig_phy_prj.replace("        </Verilog>", extra_entries + "        </Verilog>")
    elif "inspection_result_cdc.v" not in orig_phy_prj:
        orig_phy_prj = orig_phy_prj.replace("        </Verilog>", extra_entries[extra_entries.index('            <File Path="../../../user_source/hdl_source/inspection_result_cdc.v">'): ] + "        </Verilog>")
    if "industrial_v2_feature_spine.v" not in orig_phy_prj:
        orig_phy_prj = orig_phy_prj.replace("        </Verilog>", v2_extra_entries + "        </Verilog>")
    (phy_dir / "camera_to_dsi_display.prj").write_text(orig_phy_prj, encoding="utf-8")

    print(f"      syn_1 configured: {syn_dir}")
    print(f"      phy_1 configured: {phy_dir}")
    prepare_flow_tcl()


def prepare_flow_tcl():
    """Derive an isolated flow script when a reproducible placement seed is requested."""
    global RUN_FLOW_TCL
    RUN_FLOW_TCL = FLOW_TCL
    if PLACE_SEED is None:
        return

    marker = "### Editable zone for opt_place ###"
    flow_text = FLOW_TCL.read_text(encoding="utf-8")
    if marker not in flow_text:
        raise RuntimeError(
            f"Cannot inject --place-seed: flow marker missing from {FLOW_TCL}"
        )
    injection = (
        f"{marker}\n"
        "  # Reproducible V2 candidate placement seed.\n"
        f"  set_param place seed {PLACE_SEED}"
    )
    derived = WORK_PROJECT / "industrial_v2_fixed_seed.tcl"
    derived.write_text(flow_text.replace(marker, injection, 1), encoding="utf-8")
    RUN_FLOW_TCL = derived
    print(f"      placement seed {PLACE_SEED} injected into {derived}")


def run_step(step_name: str, step_dir: Path):
    print(f"\n[RUN] Starting {step_name} in {step_dir}...")
    t0 = time.time()
    tcl_path = RUN_FLOW_TCL.resolve().as_posix()
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
        raise RuntimeError(f"QoR gate: route.qor not found at {qor_file}")

    content = qor_file.read_text(encoding="utf-8", errors="replace")
    metrics = parse_qor_metrics(content)
    assert_qor_pass(metrics)
    print("\n--- route.qor Summary ---")
    for line in content.splitlines():
        if any(k in line for k in ["WNS", "TNS", "Slack", "Slice", "LUT", "Register", "BRAM", "DSP", "RAM", "Clock"]):
            print(" ", line.strip())
    print("  QoR gate: PASS (timing WNS/TNS and violated endpoints are clean)")
    return metrics


def collect_release():
    print(f"\n[5/5] Collecting release artifacts into {RELEASE_DIR}...")
    RELEASE_DIR.mkdir(parents=True, exist_ok=True)
    assert_no_user_owned_artifacts(RELEASE_DIR)
    phy_dir = WORK_RUNS / "phy_1"

    final_bitstream = select_final_bitstream(list(phy_dir.glob("*.bit")))

    # Remove stale alternate bitstreams so the formal release is unambiguous.
    for stale in RELEASE_DIR.glob("*.bit"):
        if stale.name != FINAL_BITSTREAM_NAME:
            stale.unlink()

    dest = RELEASE_DIR / FINAL_BITSTREAM_NAME
    shutil.copy2(final_bitstream, dest)
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

    write_release_manifest([dest])


def write_existing_release_manifest():
    print(f"\n[manifest] Collecting provenance for existing artifacts in {RELEASE_DIR}...")
    RELEASE_DIR.mkdir(parents=True, exist_ok=True)
    assert_no_user_owned_artifacts(RELEASE_DIR)
    final_bitstream = select_final_bitstream(list(RELEASE_DIR.glob("*.bit")))
    write_release_manifest([final_bitstream])


def main(argv=None):
    args = parse_args(argv)
    configure(args)
    print("=" * 70)
    print("Tang Dynasty Automated Build: PH1P35 Industrial Inspection Subsystem")
    print("=" * 70)

    if args.manifest_only:
        write_existing_release_manifest()
        return

    validate_inputs()

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
