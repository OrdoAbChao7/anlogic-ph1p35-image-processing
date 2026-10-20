"""Algorithm Lab adapter for the Industrial Vision V2 telemetry OSD preview."""

from pathlib import Path
import sys
from typing import Any, Dict, Tuple

import numpy as np

from .base import BaseAlgorithm

_PROJECT_ROOT = Path(__file__).resolve().parents[3]
if str(_PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(_PROJECT_ROOT))
from work.models.v2.telemetry_osd_reference import render_telemetry_osd


class V2TelemetryOSDAlgorithm(BaseAlgorithm):
    algorithm_id = "v2_telemetry_osd"
    display_name = "Industrial V2 Live Telemetry OSD"
    category = "Inspection"
    description = ("Frame-stable HDMI telemetry preview; VIDEO/E2E remain N/A and "
                   "candidate mm values are marked provisional.")
    source_reference = "Industrial Vision V2 G3/G4/G5/G7 live telemetry contract"
    license = "Project code"

    _defaults = {
        "mode": "original", "frame_count": 1,
        "detected": True, "pass": True, "ng": False, "invalid": False,
        "width_px": 1280, "height_px": 720,
        "proc_valid": True, "proc_cycles": 4096,
        "motion_valid": True, "motion": True, "motion_count": 19200,
        "pass_count": 3, "ng_count": 1,
        "sort_pulse": False, "safe_enable": False,
        "dimension_valid": True, "shape_valid": True,
        "scale_provisional": True,
        "width_mm_q16_16": 60 << 16, "height_mm_q16_16": 20 << 16,
    }

    @staticmethod
    def _select(key: str, label: str, default: bool) -> dict:
        return {"id": key, "label": label, "type": "select",
                "default": default,
                "options": [{"label": "Yes", "value": True},
                            {"label": "No", "value": False}]}

    def get_parameter_specs(self) -> list[dict]:
        specs = [
            {"id": "mode", "label": "Display mode", "type": "select",
             "default": "original", "options": [
                 {"label": "Original", "value": "original"},
                 {"label": "Sobel", "value": "sobel"},
                 {"label": "Cartoon", "value": "cartoon"}]},
            {"id": "frame_count", "label": "Display frame count", "type": "int",
             "default": 1, "min": 0, "max": 4294967295, "step": 1},
        ]
        specs.extend(self._select(key, label, self._defaults[key]) for key, label in (
            ("detected", "Object detected"), ("pass", "PASS"), ("ng", "NG"),
            ("invalid", "Invalid input"), ("proc_valid", "PROC valid"),
            ("motion_valid", "Motion result valid"), ("motion", "Motion detected"),
            ("sort_pulse", "Sort request pulse"), ("safe_enable", "Actuator safe-enable"),
            ("dimension_valid", "Candidate dimensions valid"), ("shape_valid", "Shape valid"),
            ("scale_provisional", "Scale is provisional"),
        ))
        for key, label, maximum, default in (
            ("width_px", "Width px", 2047, 1280),
            ("height_px", "Height px", 2047, 720),
            ("proc_cycles", "PROC source-clock cycles", 0xFFFFFFFF, 4096),
            ("motion_count", "Motion pixel count", 0xFFFFFF, 19200),
            ("pass_count", "PASS count", 0xFFFF, 3),
            ("ng_count", "NG count", 0xFFFF, 1),
            ("width_mm_q16_16", "Candidate width Q16.16 mm", 0xFFFFFFFF, 60 << 16),
            ("height_mm_q16_16", "Candidate height Q16.16 mm", 0xFFFFFFFF, 20 << 16),
        ):
            specs.append({"id": key, "label": label, "type": "int",
                          "default": default, "min": 0, "max": maximum, "step": 1})
        return specs

    def _process(self, image_rgb: np.ndarray, params: Dict[str, Any]
                 ) -> Tuple[np.ndarray, Dict[str, Any]]:
        telemetry: Dict[str, Any] = dict(self._defaults)
        telemetry.update(params)
        return render_telemetry_osd(image_rgb, telemetry)

    def process_visual_reference(self, image_rgb: np.ndarray, params: Dict[str, Any]
                                 ) -> Tuple[np.ndarray, Dict[str, Any]]:
        image, metrics = self._process(image_rgb, params)
        metrics["model"] = "software visual-reference OSD"
        return image, metrics

    def process_hardware_equivalent(self, image_rgb: np.ndarray, params: Dict[str, Any]
                                    ) -> Tuple[np.ndarray, Dict[str, Any]]:
        image, metrics = self._process(image_rgb, params)
        metrics["model"] = "bounded telemetry text contract; RTL pixel behavior tested separately"
        return image, metrics
