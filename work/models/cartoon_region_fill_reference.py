"""Integer reference for the streaming cartoon region-fill candidate.

The model intentionally mirrors the RTL contract: RGB888 input, independent
8-level channel quantization, four-neighbour local filling, and integer Sobel
fusion with replicated image borders.
"""

from __future__ import annotations

import numpy as np


def _validate_rgb(rgb: np.ndarray) -> np.ndarray:
    if not isinstance(rgb, np.ndarray) or rgb.dtype != np.uint8:
        raise ValueError("Expected RGB888 uint8 ndarray")
    if rgb.ndim != 3 or rgb.shape[2] != 3:
        raise ValueError("Expected RGB888 array with shape HxWx3")
    if rgb.shape[0] == 0 or rgb.shape[1] == 0:
        raise ValueError("Expected non-empty RGB image")
    return rgb


def quantize_rgb(rgb: np.ndarray) -> np.ndarray:
    """Quantize each RGB channel to eight fixed representative levels."""
    rgb = _validate_rgb(rgb)
    level = rgb >> 5
    return ((level << 5) | (level << 2) | (level >> 1)).astype(np.uint8)


def local_fill(quantized: np.ndarray) -> np.ndarray:
    """Fill a centre pixel only when all four neighbours share one colour."""
    quantized = _validate_rgb(quantized)
    padded = np.pad(quantized, ((1, 1), (1, 1), (0, 0)), mode="edge")
    north = padded[:-2, 1:-1]
    south = padded[2:, 1:-1]
    west = padded[1:-1, :-2]
    east = padded[1:-1, 2:]
    same_neighbours = (
        np.all(north == south, axis=2)
        & np.all(south == west, axis=2)
        & np.all(west == east, axis=2)
    )
    return np.where(same_neighbours[..., None], north, quantized).astype(np.uint8)


def _luma(quantized: np.ndarray) -> np.ndarray:
    return (
        (quantized[:, :, 0].astype(np.int32) >> 2)
        + (quantized[:, :, 1].astype(np.int32) >> 1)
        + (quantized[:, :, 2].astype(np.int32) >> 2)
    )


def sobel_edges(quantized: np.ndarray, threshold: int = 240) -> np.ndarray:
    """Return a 0/255 Sobel mask using replicated borders and integer maths."""
    quantized = _validate_rgb(quantized)
    if not isinstance(threshold, (int, np.integer)) or threshold < 0:
        raise ValueError("threshold must be a non-negative integer")
    y = _luma(quantized)
    padded = np.pad(y, ((1, 1), (1, 1)), mode="edge")
    gx = (
        -padded[:-2, :-2]
        + padded[:-2, 2:]
        - 2 * padded[1:-1, :-2]
        + 2 * padded[1:-1, 2:]
        - padded[2:, :-2]
        + padded[2:, 2:]
    )
    gy = (
        -padded[:-2, :-2]
        - 2 * padded[:-2, 1:-1]
        - padded[:-2, 2:]
        + padded[2:, :-2]
        + 2 * padded[2:, 1:-1]
        + padded[2:, 2:]
    )
    return ((np.abs(gx) + np.abs(gy)) >= int(threshold)).astype(np.uint8) * 255


def _causal_windows(quantized: np.ndarray) -> tuple[np.ndarray, ...]:
    """Return the RTL line-buffer window ending at each accepted pixel."""
    padded = np.pad(quantized, ((2, 0), (2, 0), (0, 0)), mode="edge")
    return (
        padded[:-2, :-2],
        padded[:-2, 1:-1],
        padded[:-2, 2:],
        padded[1:-1, :-2],
        padded[1:-1, 1:-1],
        padded[1:-1, 2:],
        padded[2:, :-2],
        padded[2:, 1:-1],
        padded[2:, 2:],
    )


def filter_rgb_streaming(
    rgb: np.ndarray, threshold: int = 240
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Return the hardware-equivalent causal-window result.

    The output at (y, x) uses the causal window [y-2:y, x-2:x], matching the
    existing line-buffer RTL and its fixed sideband latency.
    """
    quantized = quantize_rgb(rgb)
    a, b, c, d, e, f, g, h, i = _causal_windows(quantized)
    same_neighbours = (
        np.all(b == h, axis=2)
        & np.all(h == d, axis=2)
        & np.all(d == f, axis=2)
    )
    filled = np.where(same_neighbours[..., None], b, e).astype(np.uint8)

    def y_value(pixel: np.ndarray) -> np.ndarray:
        return (
            (pixel[:, :, 0].astype(np.int32) >> 2)
            + (pixel[:, :, 1].astype(np.int32) >> 1)
            + (pixel[:, :, 2].astype(np.int32) >> 2)
        )

    ya, yb, yc = y_value(a), y_value(b), y_value(c)
    yd, yf = y_value(d), y_value(f)
    yg, yh, yi = y_value(g), y_value(h), y_value(i)
    gx = -ya + yc - 2 * yd + 2 * yf - yg + yi
    gy = -ya - 2 * yb - yc + yg + 2 * yh + yi
    edge = ((np.abs(gx) + np.abs(gy)) >= int(threshold)).astype(np.uint8) * 255
    cartoon = filled.copy()
    cartoon[edge != 0] = 0
    return cartoon, edge, filled


def filter_rgb(
    rgb: np.ndarray, threshold: int = 240
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Return ``(cartoon_rgb, edge_mask, filled_rgb)`` for one RGB frame."""
    quantized = quantize_rgb(rgb)
    filled = local_fill(quantized)
    edge = sobel_edges(quantized, threshold=threshold)
    cartoon = filled.copy()
    cartoon[edge != 0] = 0
    return cartoon, edge, filled
