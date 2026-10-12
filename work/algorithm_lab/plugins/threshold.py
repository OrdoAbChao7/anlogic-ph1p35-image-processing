"""Thresholding binarization plugin (Visual Otsu/Adaptive vs FPGA Fixed Threshold)."""
from typing import Dict, Any, Tuple
import cv2
import numpy as np
from .base import BaseAlgorithm


class ThresholdAlgorithm(BaseAlgorithm):
    algorithm_id = "threshold"
    display_name = "Binarization / Threshold (二值化)"
    category = "Preprocessing"
    description = "Software Otsu/Dynamic threshold vs FPGA fixed integer comparator."
    source_reference = "Otsu 1979 / work/models/reference_model.py"
    license = "MIT"

    def get_parameter_specs(self) -> list[dict]:
        return [
            {
                "id": "threshold_value",
                "label": "FPGA Threshold Value (0-255)",
                "type": "int",
                "default": 128,
                "min": 0,
                "max": 255,
                "step": 1
            },
            {
                "id": "invert",
                "label": "Invert Binary Output",
                "type": "select",
                "default": "no",
                "options": [
                    {"label": "Normal (>= Threshold -> 255)", "value": "no"},
                    {"label": "Inverted (< Threshold -> 255)", "value": "yes"}
                ]
            }
        ]

    def process_visual_reference(self, image_rgb: np.ndarray, params: Dict[str, Any]) -> Tuple[np.ndarray, Dict[str, Any]]:
        # High quality software baseline: Automatic Otsu thresholding
        gray = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2GRAY)
        otsu_val, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY | cv2.THRESH_OTSU)
        if params.get("invert") == "yes":
            binary = 255 - binary
        out_rgb = np.stack([binary, binary, binary], axis=-1)
        white_pixels = int(np.sum(binary == 255))
        return out_rgb, {"otsu_computed_threshold": float(otsu_val), "foreground_ratio": float(white_pixels / binary.size)}

    def process_hardware_equivalent(self, image_rgb: np.ndarray, params: Dict[str, Any]) -> Tuple[np.ndarray, Dict[str, Any]]:
        # FPGA streaming comparator: Gray via shift -> compare with register
        r = image_rgb[:, :, 0].astype(np.uint16)
        g = image_rgb[:, :, 1].astype(np.uint16)
        b = image_rgb[:, :, 2].astype(np.uint16)
        gray = ((r >> 2) + (g >> 1) + (b >> 2)).astype(np.uint8)
        
        th = int(params.get("threshold_value", 128))
        invert = params.get("invert") == "yes"
        
        if not invert:
            binary = np.where(gray >= th, 255, 0).astype(np.uint8)
        else:
            binary = np.where(gray < th, 255, 0).astype(np.uint8)
            
        out_rgb = np.stack([binary, binary, binary], axis=-1)
        white_pixels = int(np.sum(binary == 255))
        return out_rgb, {"fpga_reg_threshold": th, "foreground_ratio": float(white_pixels / binary.size)}
