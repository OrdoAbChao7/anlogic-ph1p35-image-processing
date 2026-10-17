"""Cycle-level golden helpers for the cartoon region-fill RTL candidate."""

from __future__ import annotations

from collections import deque
from pathlib import Path
from typing import Iterable

import numpy as np

from cartoon_region_fill_reference import filter_rgb


LATENCY_CYCLES = 6


def pack_rgb(pixel: Iterable[int]) -> int:
    values = [int(value) for value in pixel]
    if len(values) != 3 or any(value < 0 or value > 255 for value in values):
        raise ValueError("RGB pixel must contain three 8-bit channels")
    return (values[0] << 16) | (values[1] << 8) | values[2]


def build_expected_frame(rgb: np.ndarray, mode: int) -> np.ndarray:
    """Return the RGB frame expected at the module output for one mode."""
    if mode not in (0, 1, 2):
        raise ValueError("mode must be 0 (raw), 1 (edge), or 2 (cartoon)")
    cartoon, edge, _ = filter_rgb(rgb, threshold=240)
    if mode == 0:
        return rgb.copy()
    if mode == 1:
        return np.repeat(edge[:, :, None], 3, axis=2)
    return cartoon


def _make_frame(width: int, height: int, frame: int, rng: np.random.Generator) -> np.ndarray:
    yy, xx = np.indices((height, width))
    if frame % 3 == 0:
        return np.stack(
            [
                (xx * 17 + frame * 32) % 256,
                (yy * 39) % 256,
                ((xx + yy) * 11) % 256,
            ],
            axis=2,
        ).astype(np.uint8)
    if frame % 3 == 1:
        rgb = np.full((height, width, 3), (100, 150, 200), dtype=np.uint8)
        rgb[:, width // 2 :] = (255, 255, 255)
        return rgb
    rgb = rng.integers(0, 256, (height, width, 3), dtype=np.uint8)
    if width >= 3 and height >= 3:
        rgb[height // 2, width // 2] = (20, 20, 220)
    return rgb


def _validate_dimensions(width: int, height: int) -> None:
    if not isinstance(width, int) or not isinstance(height, int):
        raise ValueError("width and height must be integers")
    if width <= 0 or height <= 0 or width > 4095 or height > 4095:
        raise ValueError("width and height must be in the range 1..4095")


def generate_vectors(
    width: int,
    height: int,
    frame_modes: Iterable[int] = (0, 1, 2),
    seed: int = 520,
) -> list[tuple[int, int]]:
    """Generate input/expected pairs for ``tb_video_cartoon``."""
    _validate_dimensions(width, height)
    modes = tuple(int(mode) for mode in frame_modes)
    if not modes or any(mode not in (0, 1, 2) for mode in modes):
        raise ValueError("frame_modes must contain at least one mode in 0..2")

    rng = np.random.default_rng(seed)
    pipeline: deque[int] = deque([0] * LATENCY_CYCLES, maxlen=LATENCY_CYCLES)
    vectors: list[tuple[int, int]] = []

    def emit(
        rgb: int = 0,
        de: int = 0,
        vs: int = 0,
        hs: int = 0,
        request: int = 0,
        keep: int = 0,
        overlay: int = 0,
        wanted: int = 0,
        mode: int = 0,
        reset: int = 1,
    ) -> None:
        edge_req = request & 1
        toon_req = (request >> 1) & 1
        flags = (reset << 6) | (vs << 5) | (hs << 4) | (de << 3)
        flags |= (edge_req << 2) | (toon_req << 1) | keep
        stimulus = (flags << 48) | (rgb << 24) | overlay
        if not reset:
            pipeline.clear()
            pipeline.extend([0] * LATENCY_CYCLES)
        else:
            pipeline.appendleft(
                (vs << 28) | (hs << 27) | (de << 26) | (mode << 24) | (wanted if de else 0)
            )
        vectors.append((stimulus, pipeline[-1]))

    for _ in range(4):
        emit(reset=0)

    active_mode = 0
    for frame, mode in enumerate(modes):
        request = {0: 0, 1: 1, 2: 3}[mode]
        for _ in range(3):
            emit(vs=1, request=request, mode=active_mode)
        for _ in range(3):
            emit(request=request, mode=active_mode)

        rgb = _make_frame(width, height, frame, rng)
        expected = build_expected_frame(rgb, mode)
        active_mode = mode
        for y in range(height):
            for x in range(width):
                req_now = request if y < height // 2 else ((x + y + frame) & 3)
                keep = int(y == min(2, height - 1) and 1 <= x < min(4, width))
                overlay = 0x19E7A2
                raw = pack_rgb(rgb[y, x])
                wanted = pack_rgb(expected[y, x])
                if keep:
                    wanted = overlay
                emit(
                    raw,
                    de=1,
                    request=req_now,
                    keep=keep,
                    overlay=overlay,
                    wanted=wanted,
                    mode=mode,
                )
                if (x + 3 * y) % 17 == 3:
                    emit(request=req_now, mode=mode)
            for blank in range(5):
                emit(hs=int(1 <= blank < 3), request=req_now, mode=active_mode)

    for _ in range(12):
        emit(mode=active_mode)
    return vectors


def write_vectors(
    path: Path,
    width: int,
    height: int,
    frame_modes: Iterable[int] = (0, 1, 2),
    seed: int = 520,
) -> list[tuple[int, int]]:
    vectors = generate_vectors(width, height, frame_modes=frame_modes, seed=seed)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="ascii") as stream:
        for stimulus, expected in vectors:
            stream.write(f"{stimulus:014x} {expected:08x}\n")
    return vectors
