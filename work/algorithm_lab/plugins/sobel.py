"""Sobel Edge Detection plugin (OpenCV Gaussian+Sobel vs FPGA 3x3 Line Buffer Sobel)."""
from typing import Dict, Any, Tuple
import cv2
import numpy as np
from .base import BaseAlgorithm


class SobelAlgorithm(BaseAlgorithm):
    algorithm_id = "sobel"
    display_name = "Sobel Edge Detection (Sobel 边缘检测)"
    category = "Feature Extraction"
    description = "Software Gaussian blur + Float Sobel vs FPGA 3x3 line-buffer streaming integer Sobel."
    source_reference = "Sobel & Feldman 1968 / work/models/reference_model.py"
    license = "MIT"

    def get_parameter_specs(self) -> list[dict]:
        return [
            {
                "id": "edge_threshold",
                "label": "Edge Threshold (|Gx| + |Gy| >= T)",
                "type": "int",
                "default": 128,
                "min": 10,
                "max": 512,
                "step": 5
            },
            {
                "id": "output_mode",
                "label": "Output Mode",
                "type": "select",
                "default": "binary",
                "options": [
                    {"label": "Binary Edges (0 or 255)", "value": "binary"},
                    {"label": "Gradient Magnitude (0-255 Grad)", "value": "magnitude"}
                ]
            }
        ]

    def process_visual_reference(self, image_rgb: np.ndarray, params: Dict[str, Any]) -> Tuple[np.ndarray, Dict[str, Any]]:
        # High quality software baseline: Gaussian Blur 3x3 + Float Sobel sqrt(Gx^2 + Gy^2)
        gray = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2GRAY)
        blurred = cv2.GaussianBlur(gray, (3, 3), 1.0)
        gx = cv2.Sobel(blurred, cv2.CV_32F, 1, 0, ksize=3)
        gy = cv2.Sobel(blurred, cv2.CV_32F, 0, 1, ksize=3)
        mag = np.sqrt(gx**2 + gy**2)
        
        th = float(params.get("edge_threshold", 128))
        mode = params.get("output_mode", "binary")
        
        if mode == "binary":
            edge = np.where(mag >= th, 255, 0).astype(np.uint8)
        else:
            edge = np.clip(mag, 0, 255).astype(np.uint8)
            
        out_rgb = np.stack([edge, edge, edge], axis=-1)
        edge_density = float(np.mean(edge > 0))
        return out_rgb, {"mode": "Float Sobel with Gaussian", "edge_pixels_pct": f"{edge_density*100:.2f}%"}

    def process_hardware_equivalent(self, image_rgb: np.ndarray, params: Dict[str, Any]) -> Tuple[np.ndarray, Dict[str, Any]]:
        # FPGA streaming pipeline:
        # 1. Gray via fast integer shift (R>>2 + G>>1 + B>>2)
        # 2. 3x3 Line Buffer with replicate border
        # 3. Gx = (p02 + 2*p12 + p22) - (p00 + 2*p10 + p20)
        #    Gy = (p20 + 2*p21 + p22) - (p00 + 2*p01 + p02)
        # 4. Grad = abs(Gx) + abs(Gy) (Manhattan norm to save DSP multipliers)
        # 5. Compare with threshold or saturate to 255
        r = image_rgb[:, :, 0].astype(np.int32)
        g = image_rgb[:, :, 1].astype(np.int32)
        b = image_rgb[:, :, 2].astype(np.int32)
        gray = ((r >> 2) + (g >> 1) + (b >> 2)).astype(np.int32)

        # 3x3 convolution using trailing anchor (2,2) with border replication matching LineBuffer
        kx = np.array([[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]], dtype=np.float32)
        ky = np.array([[-1, -2, -1], [0, 0, 0], [1, 2, 1]], dtype=np.float32)
        gx = cv2.filter2D(gray.astype(np.float32), -1, kx, anchor=(2, 2), borderType=cv2.BORDER_REPLICATE)
        gy = cv2.filter2D(gray.astype(np.float32), -1, ky, anchor=(2, 2), borderType=cv2.BORDER_REPLICATE)
        
        grad = np.abs(gx) + np.abs(gy)
        th = float(params.get("edge_threshold", 128))
        mode = params.get("output_mode", "binary")

        if mode == "binary":
            edge = np.where(grad >= th, 255, 0).astype(np.uint8)
        else:
            edge = np.clip(grad, 0, 255).astype(np.uint8)

        out_rgb = np.stack([edge, edge, edge], axis=-1)
        edge_density = float(np.mean(edge > 0))
        return out_rgb, {"mode": "FPGA 3x3 Line-Buffer Manhattan |Gx|+|Gy|", "edge_pixels_pct": f"{edge_density*100:.2f}%"}
