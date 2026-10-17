"""Frozen Stage D contract for the approved industrial inspection model."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any


FROZEN_VERSION = "v1.0-approved"

FROZEN_PARAMS = {
    "target_color": "red_part",
    "morphology_mode": "open_3x3",
    "min_area": 100,
    "nominal_width": 120,
    "width_tolerance": 15,
    "nominal_height": 80,
    "height_tolerance": 12,
    "roi_x": 0,
    "roi_y": 0,
    "roi_width": 0,
    "roi_height": 0,
}

SAMPLE_SHA256 = {
    "workpiece_empty_conveyor.png": "3da9a64327d35c12c215fadc0fd6b64072b7aa3ad899007ed6192fd3c1faf62e",
    "workpiece_noisy_speckles.png": "bb0c3bb1cb6aacd2197078b77b3f5d2d6fe50ce6c7e02bddf221e35cbb9ab361",
    "workpiece_normal_pass.png": "9c836cc414b1736fb9fbaecd20b9b0ca5021d7165aeafb59b4e5df91aaa8dd08",
    "workpiece_oversized_ng.png": "f7b3799ba9009ce1c9b86122f81b44263fca087ea0704c44872da80d6616d21a",
    "workpiece_undersized_ng.png": "f48c3216b417024229b02e9ca0eeb1f3126bb0a28db20b20b690d7e505705842",
}

Q10_SHIFT = 10
Q10_BIAS = 1 << (Q10_SHIFT + 7)
Q10_CB_B_MIN = 85
Q10_CB_B_MAX = 125
Q10_CR_R_MIN = 135
Q10_CR_R_MAX = 200
BT601_Y_DARK_MAX = 60
MORPHOLOGY_BORDER = "replicate"


def canonical_params_sha256(params: dict[str, Any]) -> str:
    payload = json.dumps(params, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()
