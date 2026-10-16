"""Compare the real four-pixel detector RTL with the frozen Python HW model."""

from pathlib import Path
import subprocess
import sys

import numpy as np


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "work" / "algorithm_lab"))
from plugins.industrial_inspection import IndustrialInspectionAlgorithm


W, H = 16, 8
RED = np.array([150, 30, 30], dtype=np.uint8)


def pack_group(frame, y, group):
    pixels = frame[y, group * 4:group * 4 + 4]
    value = 0
    for pixel in pixels:
        value = (value << 24) | (int(pixel[0]) << 16) | (int(pixel[1]) << 8) | int(pixel[2])
    return value


def make_frames():
    first = np.zeros((H, W, 3), dtype=np.uint8)
    first[1:7, 2:14] = RED

    empty = np.zeros((H, W, 3), dtype=np.uint8)

    noisy = first.copy()
    noisy[0, 0] = RED
    noisy[7, 15] = RED

    border = np.zeros((H, W, 3), dtype=np.uint8)
    border[0:6, 0:8] = RED

    shifted = np.zeros((H, W, 3), dtype=np.uint8)
    shifted[2:8, 8:16] = RED

    hole = first.copy()
    hole[3:5, 6:10] = 0

    full = np.zeros((H, W, 3), dtype=np.uint8)
    full[:, :] = RED

    return [first, empty, noisy, border, shifted, hole, full]


def make_roi_boundary_frames():
    """A small object that touches every side of the selected ROI."""
    frame = np.zeros((H, W, 3), dtype=np.uint8)
    frame[2:4, 4:6] = RED
    return [frame]


def write_vectors(stimulus_path, expected_path, frames, params):
    model = IndustrialInspectionAlgorithm()
    with stimulus_path.open("w", encoding="ascii") as stimulus, expected_path.open("w", encoding="ascii") as expected:
        for frame in frames:
            trace = model.stage_d_trace(frame, params, "hardware")
            metrics = trace["metrics"]
            expected.write(
                f"{metrics['area_px']} {metrics['x_min']} {metrics['x_max']} "
                f"{metrics['y_min']} {metrics['y_max']} "
                f"{int(metrics['detected'])} {int(metrics['verdict'] == 'INVALID')}\n"
            )
            for y in range(H):
                for group in range(W // 4):
                    stimulus.write(
                        f"1 {int(group == W // 4 - 1)} {int(y == 0 and group == 0)} "
                        f"{pack_group(frame, y, group):024x}\n"
                    )
                    if group == 1 and y % 2 == 0:
                        stimulus.write("0 0 0 000000000000000000000000\n")
            # Allow the morphology pipeline to drain before the next SOF.
            for _ in range(180):
                stimulus.write("0 0 0 000000000000000000000000\n")


def run_case(name, roi, frames=None):
    output = ROOT / "work" / "output" / "industrial-golden"
    output.mkdir(parents=True, exist_ok=True)
    stimulus = output / f"{name}.stimulus.txt"
    expected = output / f"{name}.expected.txt"
    params = {
        "target_color": "red_part",
        "morphology_mode": "open_3x3",
        "min_area": 1,
        "roi_x": roi[0], "roi_y": roi[1],
        "roi_width": roi[2], "roi_height": roi[3],
    }
    if frames is None:
        frames = make_frames() if roi == (0, 0, 0, 0) else [make_frames()[0]]
    write_vectors(stimulus, expected, frames, params)

    tool_root = ROOT / ".tools"
    if not (tool_root / "iverilog" / "bin" / "iverilog.exe").exists():
        tool_root = Path("E:/Projects/FPGA/.tools")
    iverilog = tool_root / "iverilog" / "bin" / "iverilog.exe"
    vvp = tool_root / "iverilog" / "bin" / "vvp.exe"
    sim = output / f"{name}.vvp"
    subprocess.run([
        str(iverilog), "-g2012", "-DMORPH_SIMULATION", "-Wall", "-s", "tb_color_detect_golden",
        f"-Ptb_color_detect_golden.ROI_X={roi[0]}",
        f"-Ptb_color_detect_golden.ROI_Y={roi[1]}",
        f"-Ptb_color_detect_golden.ROI_W={roi[2]}",
        f"-Ptb_color_detect_golden.ROI_H={roi[3]}",
        f"-Ptb_color_detect_golden.EXPECTED_FRAMES={len(frames)}",
        "-o", str(sim), str(ROOT / "fallback" / "tb_color_detect_golden.v"),
        str(ROOT / "fallback" / "rtl" / "morph_open_96.v"),
        str(ROOT / "fallback" / "rtl" / "color_detect_96_v2.v"),
    ], check=True)
    result = subprocess.run(
        [str(vvp), str(sim), f"+STIMULUS={stimulus.as_posix()}", f"+EXPECTED={expected.as_posix()}"],
        check=False, capture_output=True, text=True,
    )
    print(result.stdout, end="")
    print(result.stderr, end="")
    if result.returncode:
        raise SystemExit(result.returncode)


if __name__ == "__main__":
    run_case("full_frame_roi", (0, 0, 0, 0))
    run_case("roi_boundary", (4, 2, 2, 2), make_roi_boundary_frames())
    run_case("invalid_roi", (1, 0, 0, 0))
    print("PASS industrial RTL/Python golden comparison")
