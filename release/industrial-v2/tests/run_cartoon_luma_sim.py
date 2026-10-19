"""Run the approved s3_luma model against the streaming RTL for all modes."""

from collections import deque
import argparse
from pathlib import Path
import subprocess
import sys
import numpy as np


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "work" / "models"))


def pack(pixel):
    return (int(pixel[0]) << 16) | (int(pixel[1]) << 8) | int(pixel[2])


def run(full_frame=False):
    # The small case is the fast per-cycle regression.  The full-frame case
    # reuses the same TB and golden path to exercise the production line-buffer
    # depth, 1280x720 row/column rollover, and frame-boundary mode commits.
    width, height = (1280, 720) if full_frame else (16, 8)
    vector_name = "luma-full-frame.txt" if full_frame else "luma-small.txt"
    vectors = ROOT / "work" / "output" / "cartoon-tests" / vector_name
    vectors.parent.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(520)
    pipeline = deque([0] * 6, maxlen=6)
    active_mode = 0
    cycles = 0

    from cartoon_luma_reference import filter_rgb

    with vectors.open("w", encoding="ascii") as out:
        def emit(rgb=0, de=0, vs=0, hs=0, request=0, keep=0,
                 overlay=0, wanted=0, mode=0, reset=1):
            nonlocal cycles
            edge_req = request & 1
            toon_req = (request >> 1) & 1
            flags = (reset << 6) | (vs << 5) | (hs << 4) | (de << 3)
            flags |= (edge_req << 2) | (toon_req << 1) | keep
            stimulus = (flags << 48) | (rgb << 24) | overlay
            if not reset:
                pipeline.clear()
                pipeline.extend([0] * 6)
            else:
                pipeline.appendleft(
                    (vs << 28) | (hs << 27) | (de << 26)
                    | (mode << 24) | (wanted if de else 0)
                )
            out.write(f"{stimulus:014x} {pipeline[-1]:08x}\n")
            cycles += 1

        for _ in range(4):
            emit(reset=0)

        modes = [0, 1, 2] if full_frame else [0, 1, 2, 0, 2, 1]
        for frame, mode in enumerate(modes):
            request = {0: 0, 1: 1, 2: 3}[mode]
            for _ in range(3):
                emit(vs=1, request=request, mode=active_mode)
            for _ in range(3):
                emit(request=request, mode=active_mode)

            yy, xx = np.indices((height, width))
            if frame % 3 == 0:
                rgb = np.stack(
                    [(xx * 17 + frame * 32) % 256,
                     (yy * 39) % 256,
                     ((xx + yy) * 11) % 256], axis=2
                ).astype(np.uint8)
            elif frame % 3 == 1:
                rgb = np.full((height, width, 3), (100, 150, 200), dtype=np.uint8)
                rgb[:, width // 2:] = (255, 255, 255)
            else:
                rgb = rng.integers(0, 256, (height, width, 3), dtype=np.uint8)

            toon, edge = filter_rgb(rgb, threshold=240)
            active_mode = mode
            for y in range(height):
                for x in range(width):
                    req_now = request if y < height // 2 else ((x + y + frame) & 3)
                    keep = int(y == 2 and 3 <= x < 7)
                    overlay = 0x19E7A2
                    raw = pack(rgb[y, x])
                    if mode == 0:
                        wanted = raw
                    elif mode == 1:
                        wanted = int(edge[y, x]) * 0x010101
                    else:
                        wanted = pack(toon[y, x])
                    if keep:
                        wanted = overlay
                    emit(raw, de=1, request=req_now, keep=keep,
                         overlay=overlay, wanted=wanted, mode=mode)
                    stall_period = 4093 if full_frame else 17
                    if (x + 3 * y) % stall_period == 3:
                        emit(request=req_now, mode=mode)
                for blank in range(5):
                    emit(hs=int(1 <= blank < 3), request=req_now, mode=mode)

        for _ in range(12):
            emit(mode=active_mode)

    tool_root = ROOT / ".tools"
    if not (tool_root / "iverilog" / "bin" / "iverilog.exe").exists():
        tool_root = Path("E:/Projects/FPGA/.tools")
    iverilog = tool_root / "iverilog" / "bin" / "iverilog.exe"
    vvp = tool_root / "iverilog" / "bin" / "vvp.exe"
    sim = vectors.with_suffix(".vvp")
    subprocess.run([
        str(iverilog), "-g2012", "-Wall", "-s", "tb_video_cartoon",
        f"-Ptb_video_cartoon.W={width}", f"-Ptb_video_cartoon.H={height}",
        "-o", str(sim), str(ROOT / "work" / "tests" / "tb_video_cartoon.v"),
        str(ROOT / "work" / "rtl" / "video_cartoon_luma.v")
    ], check=True)
    result = subprocess.run(
        [str(vvp), str(sim), f"+VECTORS={vectors.as_posix()}"],
        check=False, capture_output=True, text=True
    )
    print(result.stdout, end="")
    print(result.stderr, end="")
    if result.returncode:
        raise SystemExit(result.returncode)
    print(f"PASS approved s3_luma all-mode contract ({cycles} cycles)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run the approved s3_luma streaming regression.")
    parser.add_argument(
        "--full-frame",
        action="store_true",
        help="exercise three complete 1280x720 frames with the same streaming testbench",
    )
    run(full_frame=parser.parse_args().full_frame)
