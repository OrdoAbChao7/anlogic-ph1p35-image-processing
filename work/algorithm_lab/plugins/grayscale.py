"""Grayscale conversion algorithm plugin (Visual vs Hardware Integer)."""
from typing import Dict, Any, Tuple
import cv2
import numpy as np
from .base import BaseAlgorithm


class GrayscaleAlgorithm(BaseAlgorithm):
    algorithm_id = "grayscale"
    display_name = "Grayscale Conversion (灰度化)"
    category = "Preprocessing"
    description = "Standard ITU-R BT.601 float grayscale vs FPGA bit-shift integer approximation."
    source_reference = "ITU-R BT.601 / FPGA Video IP standard"
    license = "MIT"

    def get_parameter_specs(self) -> list[dict]:
        return [
            {
                "id": "method",
                "label": "Hardware Shift Scheme",
                "type": "select",
                "default": "shift_212",
                "options": [
                    {"label": "R>>2 + G>>1 + B>>2 (Fast, No Multiplier)", "value": "shift_212"},
                    {"label": "R*77 + G*150 + B*29 >> 8 (Standard Integer Multiplier)", "value": "mult_standard"}
                ]
            }
        ]

    def process_visual_reference(self, image_rgb: np.ndarray, params: Dict[str, Any]) -> Tuple[np.ndarray, Dict[str, Any]]:
        # High precision float: Y = 0.299*R + 0.587*G + 0.114*B
        gray_f = 0.299 * image_rgb[:, :, 0] + 0.587 * image_rgb[:, :, 1] + 0.114 * image_rgb[:, :, 2]
        gray = np.clip(np.round(gray_f), 0, 255).astype(np.uint8)
        out_rgb = np.stack([gray, gray, gray], axis=-1)
        return out_rgb, {"method": "Float BT.601", "mean_luma": float(np.mean(gray))}

    def process_hardware_equivalent(self, image_rgb: np.ndarray, params: Dict[str, Any]) -> Tuple[np.ndarray, Dict[str, Any]]:
        method = params.get("method", "shift_212")
        r = image_rgb[:, :, 0].astype(np.uint16)
        g = image_rgb[:, :, 1].astype(np.uint16)
        b = image_rgb[:, :, 2].astype(np.uint16)

        if method == "shift_212":
            # FPGA shift: (R>>2) + (G>>1) + (B>>2)
            gray = ((r >> 2) + (g >> 1) + (b >> 2)).astype(np.uint8)
        else:
            # FPGA multiplier: (77*R + 150*G + 29*B) >> 8
            gray = ((77 * r + 150 * g + 29 * b) >> 8).astype(np.uint8)

        out_rgb = np.stack([gray, gray, gray], axis=-1)
        return out_rgb, {"method": method, "mean_luma": float(np.mean(gray))}
