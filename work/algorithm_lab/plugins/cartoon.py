"""Comprehensive Cartoonization plugin supporting multiple candidates, smooth passes, and quantization levels."""
from typing import Dict, Any, Tuple
import sys
from pathlib import Path
import cv2
import numpy as np
from .base import BaseAlgorithm

MODEL_ROOT = Path(__file__).resolve().parents[3] / "work" / "models"
if str(MODEL_ROOT) not in sys.path:
    sys.path.insert(0, str(MODEL_ROOT))
from cartoon_region_fill_reference import (  # noqa: E402
    filter_rgb as region_fill_filter_rgb,
    quantize_rgb as region_fill_quantize_rgb,
)


class CartoonAlgorithm(BaseAlgorithm):
    algorithm_id = "cartoon"
    display_name = "Cartoonization (卡通化算法套件)"
    category = "Stylization"
    description = "Compare bilateral/K-Means visual reference against FPGA hardware-equivalent models (Color Quantization + Sobel Overlay)."
    source_reference = "amd/mini-isp / work/models/cartoon_reference.py / work/models/cartoon_luma_reference.py"
    license = "MIT"

    def get_parameter_specs(self) -> list[dict]:
        return [
            {
                "id": "variant",
                "label": "Algorithm Model / Architecture",
                "type": "select",
                "default": "s3_luma",
                "options": [
                    {"label": "S3: Luminance Posterization (video_cartoon_luma.v, preserves tint)", "value": "s3_luma"},
                    {"label": "S4: 4-neighbour Region Fill + Sobel (candidate)", "value": "s4_region_fill"},
                    {"label": "S1: Direct Per-Channel Color Quant (video_cartoon.v)", "value": "s1_color"},
                    {"label": "S2: Contour Only (Sobel Inverted Mask)", "value": "s2_contour"}
                ]
            },
            {
                "id": "quant_levels",
                "label": "Quantization Levels",
                "type": "select",
                "default": "8",
                "options": [
                    {"label": "8 Levels (3-bit, 32 step) - Recommended for FPGA", "value": "8"},
                    {"label": "16 Levels (4-bit, 16 step)", "value": "16"},
                    {"label": "32 Levels (5-bit, 8 step)", "value": "32"}
                ]
            },
            {
                "id": "sobel_threshold",
                "label": "Sobel Edge Threshold (|Gx|+|Gy| >= T)",
                "type": "int",
                "default": 240,
                "min": 40,
                "max": 500,
                "step": 10
            },
            {
                "id": "smooth_passes",
                "label": "Smoothing Filter Passes (Pre-Quant)",
                "type": "select",
                "default": "1",
                "options": [
                    {"label": "1 Pass (3x3 Box/Gaussian)", "value": "1"},
                    {"label": "2 Passes (Double Smooth)", "value": "2"},
                    {"label": "0 Pass (No Smooth, Raw Pixels)", "value": "0"}
                ]
            },
            {
                "id": "edge_source",
                "label": "Edge Extraction Source",
                "type": "select",
                "default": "smoothed",
                "options": [
                    {"label": "Smoothed Stream (Less Noise)", "value": "smoothed"},
                    {"label": "Raw Input Stream (Sharper Edges)", "value": "raw"}
                ]
            }
        ]

    def _quantize_luma(self, y: np.ndarray, levels: int) -> np.ndarray:
        """Quantize luminance with bit-exact reproduction and stretch to 0..255."""
        if levels == 8:
            # 3-bit: level = y >> 5, q = (level << 5) | (level << 2) | (level >> 1)
            level = y >> 5
            return ((level << 5) | (level << 2) | (level >> 1)).astype(np.int16)
        elif levels == 16:
            # 4-bit: level = y >> 4, q = (level << 4) | level
            level = y >> 4
            return ((level << 4) | level).astype(np.int16)
        elif levels == 32:
            # 5-bit: level = y >> 3, q = (level << 3) | (level >> 2)
            level = y >> 3
            return ((level << 3) | (level >> 2)).astype(np.int16)
        return y.astype(np.int16)

    def _quantize_rgb_direct(self, rgb: np.ndarray, levels: int) -> np.ndarray:
        """Direct per-channel quantization."""
        if levels == 8:
            level = rgb >> 5
            return ((level << 5) | (level << 2) | (level >> 1)).astype(np.uint8)
        elif levels == 16:
            level = rgb >> 4
            return ((level << 4) | level).astype(np.uint8)
        elif levels == 32:
            level = rgb >> 3
            return ((level << 3) | (level >> 2)).astype(np.uint8)
        return rgb

    def process_visual_reference(self, image_rgb: np.ndarray, params: Dict[str, Any]) -> Tuple[np.ndarray, Dict[str, Any]]:
        # High quality visual reference:
        # Bilateral filter for edge-preserving smoothing + Canny / adaptive edge
        th = float(params.get("sobel_threshold", 240))
        levels = int(params.get("quant_levels", 8))
        
        # High-end bilateral filtering (classic visual cartoon standard)
        bgr = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2BGR)
        color_bilateral = cv2.bilateralFilter(bgr, d=9, sigmaColor=75, sigmaSpace=75)
        color_rgb = cv2.cvtColor(color_bilateral, cv2.COLOR_BGR2RGB)
        
        # Quantize in high precision
        step = 256 // levels
        quant_rgb = (color_rgb // step * step + step // 2).astype(np.uint8)
        
        # Adaptive edge
        gray = cv2.cvtColor(color_rgb, cv2.COLOR_RGB2GRAY)
        blurred = cv2.medianBlur(gray, 7)
        edges = cv2.adaptiveThreshold(blurred, 255, cv2.ADAPTIVE_THRESH_MEAN_C, cv2.THRESH_BINARY, 9, 2)
        
        # Merge edges
        res = quant_rgb.copy()
        res[edges == 0] = [0, 0, 0]
        
        return res, {
            "model": "Visual Gold (Bilateral Filter + Adaptive Threshold)",
            "levels": levels,
            "edge_method": "Adaptive Mean"
        }

    def process_hardware_equivalent(self, image_rgb: np.ndarray, params: Dict[str, Any]) -> Tuple[np.ndarray, Dict[str, Any]]:
        variant = params.get("variant", "s3_luma")
        levels = int(params.get("quant_levels", 8))
        th = int(params.get("sobel_threshold", 240))
        passes = int(params.get("smooth_passes", 1))
        edge_src = params.get("edge_source", "smoothed")

        if variant == "s4_region_fill":
            if levels != 8:
                raise ValueError("s4_region_fill requires quant_levels=8")
            out, edge_mask, filled = region_fill_filter_rgb(
                image_rgb, threshold=th
            )
            quantized = region_fill_quantize_rgb(image_rgb)
            return out, {
                "variant": variant,
                "model_desc": f"FPGA s4_region_fill (8 levels, Sobel Th={th})",
                "edge_pixels": int(np.count_nonzero(edge_mask)),
                "filled_pixels": int(np.count_nonzero(np.any(filled != quantized, axis=2))),
                "hardware_multiplier_needed": False,
                "line_buffer_rows": 3,
            }

        # 1. Smoothing filter: 3x3 Gaussian-like integer box: [1,2,1; 2,4,2; 1,2,1] >> 4
        kernel = np.array([[1, 2, 1], [2, 4, 2], [1, 2, 1]], dtype=np.float32)
        current = image_rgb.copy()
        
        for _ in range(passes):
            # LineBuffer trailing anchor (2,2) with border replicate
            smoothed = cv2.filter2D(current.astype(np.uint8), cv2.CV_16U, kernel, anchor=(2, 2), borderType=cv2.BORDER_REPLICATE)
            current = (smoothed >> 4).astype(np.uint8)

        smoothed_rgb = current.astype(np.int16)

        # 2. Edge computation
        if edge_src == "smoothed":
            gray_for_edge = ((smoothed_rgb[:, :, 0] >> 2) + (smoothed_rgb[:, :, 1] >> 1) + (smoothed_rgb[:, :, 2] >> 2)).astype(np.uint8)
        else:
            r0 = image_rgb[:, :, 0].astype(np.int32)
            g0 = image_rgb[:, :, 1].astype(np.int32)
            b0 = image_rgb[:, :, 2].astype(np.int32)
            gray_for_edge = ((r0 >> 2) + (g0 >> 1) + (b0 >> 2)).astype(np.uint8)

        kx = np.array([[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]], dtype=np.float32)
        gx = cv2.filter2D(gray_for_edge, cv2.CV_16S, kx, anchor=(2, 2), borderType=cv2.BORDER_REPLICATE)
        gy = cv2.filter2D(gray_for_edge, cv2.CV_16S, kx.T, anchor=(2, 2), borderType=cv2.BORDER_REPLICATE)
        edge_mask = (np.abs(gx) + np.abs(gy)) >= th

        # 3. Color generation depending on variant
        if variant == "s3_luma":
            # Y = (R + 2*G + B) >> 2
            y = ((smoothed_rgb[:, :, 0] + 2 * smoothed_rgb[:, :, 1] + smoothed_rgb[:, :, 2]) >> 2).astype(np.int16)
            q = self._quantize_luma(y, levels)
            # Offset color: color = clip(smooth + (q - y))
            delta = (q - y)[:, :, None]
            out = np.clip(smoothed_rgb + delta, 0, 255).astype(np.uint8)
            out[edge_mask] = 0
            desc = f"FPGA s3_luma ({levels} levels, Sobel Th={th})"
        elif variant == "s1_color":
            # Direct channel quantization
            out = self._quantize_rgb_direct(smoothed_rgb.astype(np.uint8), levels)
            out[edge_mask] = 0
            desc = f"FPGA s1_color ({levels} levels, Sobel Th={th})"
        else:  # s2_contour
            # Only edges on original or white
            edge_uint8 = np.where(edge_mask, 0, 255).astype(np.uint8)
            out = np.stack([edge_uint8, edge_uint8, edge_uint8], axis=-1)
            desc = f"FPGA s2_contour (Sobel Th={th})"

        return out, {
            "variant": variant,
            "model_desc": desc,
            "edge_pixels": int(np.sum(edge_mask)),
            "hardware_multiplier_needed": False,
            "line_buffer_rows": 3
        }
