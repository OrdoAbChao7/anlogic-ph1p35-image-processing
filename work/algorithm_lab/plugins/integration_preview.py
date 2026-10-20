"""Integration preview: traditional color-range detection + Sobel for the
first-integration (B1) pixel contract, before any RTL is written.

Follows the software-first protocol: a float visual reference and an integer
hardware-equivalent model for the same algorithm so the two can be diffed.
"""

from typing import Dict, Any, Tuple

import cv2
import numpy as np

from .base import BaseAlgorithm

COLOR_LABEL = "COLOR_RANGE"
DETECTOR_KIND = "COLOR_RANGE"

STATUS_INIT = "INIT"
STATUS_VALID = "VALID"
STATUS_EMPTY = "EMPTY"
STATUS_STALE = "STALE"
STATUS_ERROR = "ERROR"

MODE_RAW = 0
MODE_EDGE = 1
MODE_TOON = 2
MODE_NAMES = {MODE_RAW: "RAW", MODE_EDGE: "EDGE", MODE_TOON: "TOON"}

SOBEL_KERNEL_X = np.array([[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]], dtype=np.int32)
SOBEL_KERNEL_Y = np.array([[-1, -2, -1], [0, 0, 0], [1, 2, 1]], dtype=np.int32)


def rgb_to_ycbcr(image_rgb: np.ndarray, integer: bool = False):
    """Return (Y, Cr, Cb) for an HxWx3 uint8 RGB image.

    integer=True uses the JPEG fixed-point form with arithmetic shifts so the
    result matches two's-complement hardware.
    """
    r = image_rgb[:, :, 0]
    g = image_rgb[:, :, 1]
    b = image_rgb[:, :, 2]
    if integer:
        r = r.astype(np.int32)
        g = g.astype(np.int32)
        b = b.astype(np.int32)
        y = (77 * r + 150 * g + 29 * b) >> 8
        cr = ((128 * r - 107 * g - 21 * b) >> 8) + 128
        cb = ((-43 * r - 85 * g + 128 * b) >> 8) + 128
    else:
        y = 0.299 * r + 0.587 * g + 0.114 * b
        cr = 0.5 * r - 0.418688 * g - 0.081312 * b + 128.0
        cb = -0.168736 * r - 0.331264 * g + 0.5 * b + 128.0
    return y, cr, cb


def color_mask(
    image_rgb: np.ndarray,
    cb_min: int = 85,
    cb_max: int = 125,
    cr_min: int = 135,
    cr_max: int = 200,
    integer: bool = False,
) -> np.ndarray:
    """Boolean mask for 85 < Cb < 125 and 135 < Cr < 200 (background-separable)."""
    _, cr, cb = rgb_to_ycbcr(image_rgb, integer=integer)
    return (cb > cb_min) & (cb < cb_max) & (cr > cr_min) & (cr < cr_max)


def global_box(mask: np.ndarray):
    """Single global bounding box over the whole mask, or None when empty."""
    ys, xs = np.where(mask)
    if xs.size == 0:
        return None
    return {
        "xmin": int(xs.min()),
        "ymin": int(ys.min()),
        "xmax": int(xs.max()),
        "ymax": int(ys.max()),
        "area": int(mask.sum()),
    }


def sobel_edges(image_rgb: np.ndarray, threshold: int = 80, integer: bool = False) -> np.ndarray:
    """|Gx| + |Gy| thresholded to a 0/255 uint8 edge image."""
    gray = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2GRAY)
    if integer:
        src = gray.astype(np.int32)
        gx = cv2.filter2D(src, cv2.CV_32S, SOBEL_KERNEL_X, borderType=cv2.BORDER_REPLICATE)
        gy = cv2.filter2D(src, cv2.CV_32S, SOBEL_KERNEL_Y, borderType=cv2.BORDER_REPLICATE)
    else:
        src = gray.astype(np.float32)
        gx = cv2.Sobel(src, cv2.CV_32F, 1, 0, ksize=3, borderType=cv2.BORDER_REPLICATE)
        gy = cv2.Sobel(src, cv2.CV_32F, 0, 1, ksize=3, borderType=cv2.BORDER_REPLICATE)
    mag = np.abs(gx) + np.abs(gy)
    return (mag >= threshold).astype(np.uint8) * 255


def result_text(
    box,
    present: bool,
    mode: int,
    capture_frame_id: int,
    result_frame_id: int,
    frame_age: int,
    status: str,
) -> list:
    """ASCII OSD lines matching the first-integration layout (y >= 176 region)."""
    lines = ["MODE " + MODE_NAMES.get(mode, "RAW")]
    lines.append("DET " + status)
    if present and box is not None:
        lines.append("BOX (%d,%d)-(%d,%d)" % (box["xmin"], box["ymin"], box["xmax"], box["ymax"]))
        lines.append("AREA %d px" % box["area"])
    else:
        lines.append("BOX --")
        lines.append("AREA 0 px")
    lines.append("CAP %d RESULT %d AGE %d" % (capture_frame_id, result_frame_id, frame_age))
    lines.append("CLASS " + COLOR_LABEL)
    lines.append("OBJECTS -- (disabled)")
    return lines


def annotate_frame(
    image_rgb: np.ndarray,
    box=None,
    mode: int = MODE_RAW,
    text_lines=None,
    color: Tuple[int, int, int] = (255, 255, 0),
) -> np.ndarray:
    """Draw the yellow box (if any) and the ASCII info block on a copy."""
    out = np.array(image_rgb, copy=True)
    if box is not None:
        cv2.rectangle(out, (box["xmin"], box["ymin"]), (box["xmax"], box["ymax"]), color, 2)
    lines = list(text_lines) if text_lines else []
    if not lines or not lines[0].startswith("MODE"):
        lines.insert(0, "MODE " + MODE_NAMES.get(mode, "RAW"))
    y = 176
    for line in lines:
        if y >= out.shape[0] - 4:
            break
        cv2.putText(out, line, (8, y), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1, cv2.LINE_AA)
        y += 16
    return out


def annotate_with_previous_frame(frames, integer: bool = False):
    """Draw frame N's box on frame N+1 (the previous-frame draw contract)."""
    annotated = []
    prev_box = None
    for frame in frames:
        annotated.append(annotate_frame(frame, box=prev_box))
        prev_box = global_box(color_mask(frame, integer=integer))
    return annotated


class FrameResultTracker:
    """Confirm/clear hysteresis, one-shot events, and display snapshots.

    Distinct capture frames only: a repeated capture_frame_id is idempotent and
    never emits a second event. Display commits never create events.
    """

    def __init__(self, confirm_frames: int = 3, clear_frames: int = 3, min_area: int = 100, max_age: int = 30):
        self.confirm_frames = int(confirm_frames)
        self.clear_frames = int(clear_frames)
        self.min_area = int(min_area)
        self.max_age = int(max_age)
        self.epoch = 0
        self.last_frame_id = None
        self.last_display_frame_id = None
        self.confirm_count = 0
        self.clear_count = 0
        self.active = False
        self.armed = True
        self.event_counter = 0
        self.events = []
        self.current = self._snapshot(0, STATUS_INIT, False, None, 0, MODE_RAW, 0)

    def update(
        self,
        capture_frame_id: int,
        present: bool,
        area: int = 0,
        mode: int = MODE_RAW,
        box=None,
        frame_age: int = 0,
        stale: bool = False,
    ):
        if self.last_frame_id is not None and capture_frame_id == self.last_frame_id:
            return None
        self.last_frame_id = capture_frame_id

        if stale:
            self.current = self._snapshot(capture_frame_id, STATUS_STALE, False, None, 0, mode, frame_age)
            return None

        present = bool(present) and int(area) >= self.min_area
        event = None
        if present:
            self.clear_count = 0
            if not self.active:
                self.confirm_count += 1
                if self.armed and self.confirm_count >= self.confirm_frames:
                    self.active = True
                    self.armed = False
                    self.event_counter += 1
                    event = {
                        "event_id": self.event_counter,
                        "epoch": self.epoch,
                        "capture_frame_id": capture_frame_id,
                        "result_frame_id": capture_frame_id,
                        "mode": mode,
                        "area": int(area),
                        "box": dict(box) if box else None,
                    }
                    self.events.append(event)
            status = STATUS_VALID
        else:
            self.confirm_count = 0
            if self.active:
                self.clear_count += 1
                if self.clear_count >= self.clear_frames:
                    self.active = False
                    self.armed = True
                    self.clear_count = 0
            status = STATUS_EMPTY

        self.current = self._snapshot(capture_frame_id, status, present, box, area, mode, frame_age)
        return event

    def on_display(self, display_frame_id: int):
        self.last_display_frame_id = display_frame_id
        snap = dict(self.current)
        snap["display_frame_id"] = display_frame_id
        return snap

    def snapshot(self):
        return dict(self.current)

    def _snapshot(self, capture_frame_id, status, present, box, area, mode, frame_age):
        snap = {
            "epoch": self.epoch,
            "capture_frame_id": int(capture_frame_id),
            "result_frame_id": int(capture_frame_id),
            "draw_source_frame_id": int(capture_frame_id),
            "mode": int(mode),
            "result_status": status,
            "target_present": bool(present),
            "count_valid": False,
            "xmin": 0,
            "ymin": 0,
            "xmax": 0,
            "ymax": 0,
            "area": 0,
            "detector_kind": DETECTOR_KIND,
            "color_label": COLOR_LABEL,
            "object_count": 0,
            "frame_age": int(frame_age),
        }
        if present and box is not None:
            snap["xmin"] = int(box.get("xmin", 0))
            snap["ymin"] = int(box.get("ymin", 0))
            snap["xmax"] = int(box.get("xmax", 0))
            snap["ymax"] = int(box.get("ymax", 0))
            snap["area"] = int(area)
        return snap


class IntegrationPreviewAlgorithm(BaseAlgorithm):
    algorithm_id = "integration_preview"
    display_name = "Integration Preview (集成预览: 颜色检测 + Sobel)"
    category = "Integration"
    description = (
        "First-integration (B1) preview: original / Sobel modes, traditional "
        "color-range detection with one global bounding box, previous-frame box "
        "drawn on the next displayed frame, and one-shot confirm/clear events."
    )
    source_reference = (
        "docs/development/integration-plan.md / "
        "docs/experiments/2026-10-16-lab3-integration-audit.md"
    )
    license = "MIT"

    def get_parameter_specs(self) -> list:
        return [
            {
                "id": "mode",
                "label": "Mode",
                "type": "select",
                "default": "raw",
                "options": [
                    {"label": "RAW (原图)", "value": "raw"},
                    {"label": "EDGE (Sobel 边缘)", "value": "edge"},
                ],
            },
            {"id": "cb_min", "label": "Cb min", "type": "int", "default": 85, "min": 0, "max": 255, "step": 1},
            {"id": "cb_max", "label": "Cb max", "type": "int", "default": 125, "min": 0, "max": 255, "step": 1},
            {"id": "cr_min", "label": "Cr min", "type": "int", "default": 135, "min": 0, "max": 255, "step": 1},
            {"id": "cr_max", "label": "Cr max", "type": "int", "default": 200, "min": 0, "max": 255, "step": 1},
            {
                "id": "sobel_threshold",
                "label": "Sobel threshold",
                "type": "int",
                "default": 80,
                "min": 10,
                "max": 512,
                "step": 5,
            },
            {"id": "min_area", "label": "Min area (px)", "type": "int", "default": 100, "min": 0, "max": 100000, "step": 10},
            {
                "id": "draw_box",
                "label": "Draw box / OSD",
                "type": "select",
                "default": "yes",
                "options": [
                    {"label": "Yes", "value": "yes"},
                    {"label": "No", "value": "no"},
                ],
            },
        ]

    def _mode_code(self, mode: str) -> int:
        return MODE_EDGE if mode == "edge" else MODE_RAW

    def _params(self, params: Dict[str, Any]):
        return {
            "mode": params.get("mode", "raw"),
            "cb_min": int(params.get("cb_min", 85)),
            "cb_max": int(params.get("cb_max", 125)),
            "cr_min": int(params.get("cr_min", 135)),
            "cr_max": int(params.get("cr_max", 200)),
            "sobel_threshold": int(params.get("sobel_threshold", 80)),
            "min_area": int(params.get("min_area", 100)),
            "draw_box": params.get("draw_box", "yes") == "yes",
        }

    def _render(self, image_rgb: np.ndarray, p, integer: bool) -> Tuple[np.ndarray, Dict[str, Any]]:
        mask = color_mask(image_rgb, p["cb_min"], p["cb_max"], p["cr_min"], p["cr_max"], integer=integer)
        box = global_box(mask)
        present = box is not None and box["area"] >= p["min_area"]
        mode_code = self._mode_code(p["mode"])

        if p["mode"] == "edge":
            edges = sobel_edges(image_rgb, p["sobel_threshold"], integer=integer)
            base = cv2.cvtColor(edges, cv2.COLOR_GRAY2RGB)
        else:
            base = image_rgb

        if p["draw_box"]:
            status = STATUS_VALID if present else STATUS_EMPTY
            lines = result_text(box if present else None, present, mode_code, 0, 0, 0, status)
            out = annotate_frame(base, box if present else None, mode=mode_code, text_lines=lines)
        else:
            out = np.array(base, copy=True)

        metrics = {
            "algorithm": self.algorithm_id,
            "model": "hardware_equivalent" if integer else "visual_reference",
            "mode": p["mode"],
            "present": bool(present),
            "area": int(box["area"]) if box else 0,
            "xmin": int(box["xmin"]) if box else 0,
            "ymin": int(box["ymin"]) if box else 0,
            "xmax": int(box["xmax"]) if box else 0,
            "ymax": int(box["ymax"]) if box else 0,
            "detector_kind": DETECTOR_KIND,
            "color_label": COLOR_LABEL,
        }
        if integer:
            metrics["hw_approx"] = True
        return out, metrics

    def process_visual_reference(self, image_rgb: np.ndarray, params: Dict[str, Any]) -> Tuple[np.ndarray, Dict[str, Any]]:
        return self._render(image_rgb, self._params(params), integer=False)

    def process_hardware_equivalent(self, image_rgb: np.ndarray, params: Dict[str, Any]) -> Tuple[np.ndarray, Dict[str, Any]]:
        return self._render(image_rgb, self._params(params), integer=True)
