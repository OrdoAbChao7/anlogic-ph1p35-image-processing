"""Algorithm Lab adapter for the Y1 FastestDet software visual reference."""
from __future__ import annotations

from typing import Any

import numpy as np

from .base import BaseAlgorithm


class FastestDetAlgorithm(BaseAlgorithm):
    algorithm_id = "fastestdet_y1"
    display_name = "FastestDet COCO 三类筛选（Y1）"
    category = "Detection"
    description = "官方 80 类预训练模型；仅展示 bottle、cup、cell phone。软件预览，未硬件化。"
    source_reference = "dog-qiuqiu/FastestDet@50473cd155cb088aa4a99e64ff6a4b3c24fa07e1"
    license = "BSD-3-Clause"

    def __init__(self):
        self._detector = None

    def get_parameter_specs(self) -> list[dict]:
        return [
            {"id": "confidence", "label": "置信度", "type": "float",
             "default": 0.25, "min": 0.05, "max": 0.95, "step": 0.05},
            {"id": "resolution", "label": "网络输入尺寸", "type": "select",
             "default": "352", "options": [
                 {"label": f"{size}×{size}", "value": str(size)}
                 for size in (352, 160, 128, 96)]},
        ]

    @property
    def detector(self):
        if self._detector is None:
            import sys
            from pathlib import Path
            y1 = (Path(__file__).resolve().parents[3] / "archive" / "legacy" /
                  "yolo" / "y1_yolo")
            sys.path.insert(0, str(y1))
            from fastestdet_runtime import FastestDet
            self._detector = FastestDet()
        return self._detector

    def detect_bgr(self, bgr: np.ndarray, params: dict[str, Any]):
        return self.detector.detect(
            bgr, int(params.get("resolution", 352)),
            float(params.get("confidence", 0.25)))

    def process_visual_reference(self, image_rgb: np.ndarray, params: dict[str, Any]):
        import cv2
        from fastestdet_runtime import draw
        bgr = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2BGR)
        detections, elapsed = self.detect_bgr(bgr, params)
        out = draw(bgr, detections)
        return cv2.cvtColor(out, cv2.COLOR_BGR2RGB), {
            "detections": detections, "forward_ms": elapsed,
            "model_classes": 80, "displayed_classes": 3}

    def process_hardware_equivalent(self, image_rgb: np.ndarray, params: dict[str, Any]):
        raise RuntimeError("Y1 has no hardware-equivalent detection model; Stage D is pending")
