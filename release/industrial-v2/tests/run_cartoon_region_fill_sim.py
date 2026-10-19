"""Run the cartoon region-fill RTL against its cycle-level golden vectors."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "work" / "models"))

from cartoon_region_fill_hardware_equivalent import write_vectors  # noqa: E402


def run(full_frame: bool = False, rtl: Path | None = None) -> None:
    width, height = (1280, 720) if full_frame else (16, 8)
    vector_name = "region-fill-full-frame.txt" if full_frame else "region-fill-small.txt"
    vectors = ROOT / "work" / "output" / "cartoon-region-fill-candidate" / vector_name
    write_vectors(vectors, width, height, frame_modes=(0, 1, 2), seed=520)

    tool_root = ROOT / ".tools"
    if not (tool_root / "iverilog" / "bin" / "iverilog.exe").exists():
        tool_root = Path("E:/Projects/FPGA/.tools")
    iverilog = tool_root / "iverilog" / "bin" / "iverilog.exe"
    vvp = tool_root / "iverilog" / "bin" / "vvp.exe"
    rtl = rtl or (ROOT / "work" / "rtl" / "video_cartoon_region_fill.v")
    sim = vectors.with_suffix(".vvp")
    subprocess.run(
        [
            str(iverilog),
            "-g2012",
            "-Wall",
            "-s",
            "tb_video_cartoon_region_fill",
            f"-Ptb_video_cartoon_region_fill.W={width}",
            f"-Ptb_video_cartoon_region_fill.H={height}",
            "-o",
            str(sim),
            str(ROOT / "work" / "tests" / "tb_video_cartoon_region_fill.v"),
            str(rtl),
        ],
        check=True,
    )
    result = subprocess.run(
        [str(vvp), str(sim), f"+VECTORS={vectors.as_posix()}"],
        check=False,
        capture_output=True,
        text=True,
    )
    print(result.stdout, end="")
    print(result.stderr, end="")
    if result.returncode:
        raise SystemExit(result.returncode)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--full-frame", action="store_true")
    parser.add_argument("--small", action="store_true")
    parser.add_argument("--rtl", type=Path)
    args = parser.parse_args()
    run(full_frame=args.full_frame, rtl=args.rtl)
