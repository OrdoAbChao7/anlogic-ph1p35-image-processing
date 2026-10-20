"""Software preview contract for the frame-stable Industrial V2 HDMI OSD."""

from __future__ import annotations

from typing import Any

import cv2
import numpy as np


LINE_COUNT = 12
LINE_WIDTH = 32
TEXT_X = 180
TEXT_Y = 22
TEXT_LINE_PITCH = 24


def _uint(value: Any, maximum: int, name: str) -> int:
    if isinstance(value, bool) or not isinstance(value, (int, np.integer)):
        raise ValueError(f"{name} must be an integer")
    value = int(value)
    if not 0 <= value <= maximum:
        raise ValueError(f"{name} must be in range 0..{maximum}")
    return value


def _flag(value: Any, name: str) -> bool:
    if not isinstance(value, (bool, np.bool_)):
        raise ValueError(f"{name} must be boolean")
    return bool(value)


def _hex(value: Any, digits: int, name: str) -> str:
    return f"{_uint(value, (1 << (4 * digits)) - 1, name):0{digits}X}"


def format_telemetry_lines(telemetry: dict[str, Any]) -> list[str]:
    """Return the fixed 12-row text contract shared with the RTL OSD."""
    mode = telemetry.get("mode", "original")
    mode_names = {"original": "ORIGINAL", "sobel": "SOBEL", "cartoon": "CARTOON"}
    if mode not in mode_names:
        raise ValueError("mode must be original, sobel, or cartoon")

    frame_count = _uint(telemetry.get("frame_count", 0), 0xFFFFFFFF, "frame_count")
    detected = _flag(telemetry.get("detected", False), "detected")
    passed = _flag(telemetry.get("pass", False), "pass")
    ng = _flag(telemetry.get("ng", False), "ng")
    invalid = _flag(telemetry.get("invalid", False), "invalid")
    width_px = _uint(telemetry.get("width_px", 0), 2047, "width_px")
    height_px = _uint(telemetry.get("height_px", 0), 2047, "height_px")
    proc_valid = _flag(telemetry.get("proc_valid", False), "proc_valid")
    proc_cycles = _uint(telemetry.get("proc_cycles", 0), 0xFFFFFFFF, "proc_cycles")
    motion_valid = _flag(telemetry.get("motion_valid", False), "motion_valid")
    motion = _flag(telemetry.get("motion", False), "motion")
    motion_count = _uint(telemetry.get("motion_count", 0), 0xFFFFFF, "motion_count")
    pass_count = _uint(telemetry.get("pass_count", 0), 0xFFFF, "pass_count")
    ng_count = _uint(telemetry.get("ng_count", 0), 0xFFFF, "ng_count")
    sort_pulse = _flag(telemetry.get("sort_pulse", False), "sort_pulse")
    safe_enable = _flag(telemetry.get("safe_enable", False), "safe_enable")
    dimension_valid = _flag(telemetry.get("dimension_valid", False), "dimension_valid")
    shape_valid = _flag(telemetry.get("shape_valid", False), "shape_valid")
    scale_provisional = _flag(telemetry.get("scale_provisional", True), "scale_provisional")
    width_mm_q16_16 = _uint(telemetry.get("width_mm_q16_16", 0), 0xFFFFFFFF,
                              "width_mm_q16_16")
    height_mm_q16_16 = _uint(telemetry.get("height_mm_q16_16", 0), 0xFFFFFFFF,
                               "height_mm_q16_16")

    if invalid:
        verdict = "INVALID"
    elif passed:
        verdict = "PASS"
    elif ng:
        verdict = "NG"
    else:
        verdict = "NO_OBJECT"

    if motion_valid:
        motion_text = f"MOTION:{int(motion)} COUNT:{motion_count:06X}"
    else:
        motion_text = "MOTION:N/A COUNT:N/A"

    if dimension_valid:
        calibration_text = "CAL:PROV" if scale_provisional else "CAL:CHECK"
        width_text = f"W:{width_mm_q16_16 >> 16:05d}MM"
        height_text = f"H:{height_mm_q16_16 >> 16:05d}MM"
    else:
        calibration_text = "CAL:PROV" if scale_provisional else "CAL:CHECK"
        width_text = "DIM:N/A"
        height_text = "H:N/A"

    lines = [
        f"MODE:{mode_names[mode]}",
        f"FRAME:{frame_count:010d}",
        "RED_PART",
        f"N:{int(detected)} W:{width_px:04d}PX H:{height_px:04d}PX",
        f"STATUS:{verdict}",
        f"PROC:CYC {proc_cycles:08X}" if proc_valid else "PROC:CYC N/A",
        "VIDEO:N/A E2E:N/A",
        motion_text,
        f"PASS:{pass_count:04X} NG:{ng_count:04X}",
        f"SORT:{int(sort_pulse)} SAFE:{int(safe_enable)}",
        f"{calibration_text} {width_text}",
        f"{height_text} SHAPE:{'VALID' if shape_valid else 'N/A'}",
    ]
    if len(lines) != LINE_COUNT or any(len(line) > LINE_WIDTH for line in lines):
        raise AssertionError("telemetry text exceeds the fixed OSD layout")
    return lines


def render_telemetry_osd(image_rgb: np.ndarray,
                         telemetry: dict[str, Any]) -> tuple[np.ndarray, dict[str, Any]]:
    """Render the OSD labels over an RGB frame and return auditable metrics."""
    if (not isinstance(image_rgb, np.ndarray) or image_rgb.dtype != np.uint8 or
            image_rgb.ndim != 3 or image_rgb.shape[2] != 3):
        raise ValueError("image_rgb must be an HxWx3 uint8 RGB image")
    output = image_rgb.copy()
    lines = format_telemetry_lines(telemetry)
    if image_rgb.shape[1] > TEXT_X and image_rgb.shape[0] > TEXT_Y:
        invalid = bool(telemetry.get("invalid", False))
        passed = bool(telemetry.get("pass", False))
        ng = bool(telemetry.get("ng", False))
        if invalid or ng:
            color = (239, 68, 68)
        elif passed:
            color = (16, 185, 129)
        else:
            color = (245, 158, 11)
        for index, line in enumerate(lines):
            y = TEXT_Y + index * TEXT_LINE_PITCH
            if y >= image_rgb.shape[0]:
                break
            cv2.putText(output, line, (TEXT_X, y), cv2.FONT_HERSHEY_PLAIN,
                        1.0, color, 1, cv2.LINE_8)
    return output, {
        "telemetry_lines": lines,
        "physical_calibration_claimed": False,
        "video_latency": None,
        "end_to_end_latency": None,
        "text_rows_rendered": min(LINE_COUNT,
                                   max(0, (image_rgb.shape[0] - TEXT_Y) // TEXT_LINE_PITCH + 1)),
    }
