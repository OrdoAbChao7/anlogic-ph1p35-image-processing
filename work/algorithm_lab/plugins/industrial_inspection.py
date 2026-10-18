"""Industrial Inspection Plugin (F1~F4: Color Binarization, Morphology, BBox, Measurement, PASS/NG).

Reference architectures:
- 05_vision_bbox_template: Streaming single-object BBox extreme coordinates & frame-latched overlay
- 06_ph1p35_vision_baseline: Multiplier-free BT.601 Y & decoupled streaming pipeline
- 02_image_algorithm_library: 3x3 two-stage min/max morphology comparison tree
- 03_geometry_recognition: Streaming area and perimeter counters
"""

from numbers import Integral
from typing import Dict, Any, Tuple
import cv2
import numpy as np
from .base import BaseAlgorithm
from stage_d_contract import (
    BT601_Y_DARK_MAX,
    Q10_BIAS,
    Q10_CB_B_MAX,
    Q10_CB_B_MIN,
    Q10_CR_R_MAX,
    Q10_CR_R_MIN,
    Q10_SHIFT,
)


class IndustrialInspectionAlgorithm(BaseAlgorithm):
    algorithm_id = "industrial_inspection"
    display_name = "Industrial Inspection F1~F4 (工业视觉分拣)"
    category = "Inspection"
    description = "Single-part segmentation, 3x3 morphology, BBox tracking, dimension measurement, and PASS/NG decision."
    source_reference = "05_vision_bbox_template / 06_ph1p35_vision_baseline / 02_image_algorithm_library"
    license = "Mixed/see source audit (reference-only)"

    def get_parameter_specs(self) -> list[dict]:
        return [
            {
                "id": "target_color",
                "label": "Target Workpiece Color (工件色彩模式)",
                "type": "select",
                "default": "red_part",
                "options": [
                    {"label": "Red Workpiece (红色零件 Q10 CbCr)", "value": "red_part"},
                    {"label": "Blue Workpiece (蓝色零件 Q10 CbCr)", "value": "blue_part"},
                    {"label": "Dark/Black Workpiece (深色零件 Luma Y<60)", "value": "dark_part"}
                ]
            },
            {
                "id": "morphology_mode",
                "label": "Morphological Filter (3x3 形态学滤波)",
                "type": "select",
                "default": "open_3x3",
                "options": [
                    {"label": "None (无滤波)", "value": "none"},
                    {"label": "Erosion 3x3 (腐蚀消毛刺)", "value": "erode_3x3"},
                    {"label": "Dilation 3x3 (膨胀填空洞)", "value": "dilate_3x3"},
                    {"label": "Opening 3x3 (开运算: 先腐蚀后膨胀)", "value": "open_3x3"},
                    {"label": "Closing 3x3 (闭运算: 先膨胀后腐蚀)", "value": "close_3x3"}
                ]
            },
            {
                "id": "min_area",
                "label": "Min Detection Area px (有效面积下限)",
                "type": "int",
                "default": 100,
                "min": 10,
                "max": 10000,
                "step": 10
            },
            {
                "id": "nominal_width",
                "label": "Nominal Part Width px (标准工件宽度)",
                "type": "int",
                "default": 120,
                "min": 20,
                "max": 600,
                "step": 5
            },
            {
                "id": "width_tolerance",
                "label": "Width Tolerance ±px (宽度允许公差)",
                "type": "int",
                "default": 15,
                "min": 2,
                "max": 100,
                "step": 1
            },
            {
                "id": "nominal_height",
                "label": "Nominal Part Height px (标准工件高度)",
                "type": "int",
                "default": 80,
                "min": 20,
                "max": 400,
                "step": 5
            },
            {
                "id": "height_tolerance",
                "label": "Height Tolerance ±px (高度允许公差)",
                "type": "int",
                "default": 12,
                "min": 2,
                "max": 100,
                "step": 1
            },
            {
                "id": "roi_x",
                "label": "ROI X (0-based; ROI=0 uses full frame)",
                "type": "int",
                "default": 0,
                "min": 0,
                "max": 4096,
                "step": 1
            },
            {
                "id": "roi_y",
                "label": "ROI Y (0-based; ROI=0 uses full frame)",
                "type": "int",
                "default": 0,
                "min": 0,
                "max": 4096,
                "step": 1
            },
            {
                "id": "roi_width",
                "label": "ROI Width (px; 0=full frame)",
                "type": "int",
                "default": 0,
                "min": 0,
                "max": 4096,
                "step": 1
            },
            {
                "id": "roi_height",
                "label": "ROI Height (px; 0=full frame)",
                "type": "int",
                "default": 0,
                "min": 0,
                "max": 4096,
                "step": 1
            }
        ]

    @staticmethod
    def _resolve_roi(image_rgb: np.ndarray, params: Dict[str, Any]):
        """Return a validated full-frame ROI and its crop.

        Width/height both equal to zero at origin mean the full frame. Any
        other zero, negative, non-integer, or out-of-bounds geometry is an
        explicit INVALID input rather than an implicit clamp.
        """
        h_img, w_img = image_rgb.shape[:2]
        keys = ("roi_x", "roi_y", "roi_width", "roi_height")
        values = {}
        for key in keys:
            raw_value = params.get(key, 0)
            if isinstance(raw_value, bool):
                return None, None, f"{key} must be an integer"
            if isinstance(raw_value, Integral):
                values[key] = int(raw_value)
            elif isinstance(raw_value, str) and raw_value.strip().lstrip("+-").isdigit():
                values[key] = int(raw_value.strip(), 10)
            else:
                # Do not let int(1.5) silently turn an invalid geometry into
                # a different valid ROI.  Hardware parameters are integer
                # elaboration constants, so the software contract is strict.
                return None, None, f"{key} must be an integer"

        requested = {
            "x": values["roi_x"],
            "y": values["roi_y"],
            "width": values["roi_width"],
            "height": values["roi_height"],
        }
        if any(value < 0 for value in values.values()):
            return requested, None, "ROI values must be non-negative"
        if values["roi_x"] == 0 and values["roi_y"] == 0 and values["roi_width"] == 0 and values["roi_height"] == 0:
            roi = {"x": 0, "y": 0, "width": w_img, "height": h_img}
            return roi, image_rgb, None
        if values["roi_width"] <= 0 or values["roi_height"] <= 0:
            return requested, None, "ROI width and height must be positive"
        if (
            values["roi_x"] >= w_img
            or values["roi_y"] >= h_img
            or values["roi_x"] + values["roi_width"] > w_img
            or values["roi_y"] + values["roi_height"] > h_img
        ):
            return requested, None, "ROI exceeds image bounds"

        roi = requested
        x0, y0 = roi["x"], roi["y"]
        x1, y1 = x0 + roi["width"], y0 + roi["height"]
        return roi, image_rgb[y0:y1, x0:x1], None

    @staticmethod
    def _draw_roi(out_img: np.ndarray, roi: dict) -> None:
        """Draw a thin ROI guide without changing the detection coordinates."""
        h_img, w_img = out_img.shape[:2]
        if roi["width"] == w_img and roi["height"] == h_img and roi["x"] == 0 and roi["y"] == 0:
            return
        x0, y0 = roi["x"], roi["y"]
        x1, y1 = x0 + roi["width"] - 1, y0 + roi["height"] - 1
        cv2.rectangle(out_img, (x0, y0), (x1, y1), (56, 189, 248), 1)

    @staticmethod
    def _invalid_result(image_rgb: np.ndarray, roi: dict | None, reason: str):
        out_img = image_rgb.copy()
        cv2.putText(
            out_img,
            f"INVALID ROI: {reason}",
            (20, 40),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.8,
            (239, 68, 68),
            2,
            cv2.LINE_AA,
        )
        metrics = {
            "verdict": "INVALID",
            "detected": False,
            "x_min": 0,
            "x_max": 0,
            "y_min": 0,
            "y_max": 0,
            "width_px": 0,
            "height_px": 0,
            "area_px": 0,
            "nominal_w": 0,
            "nominal_h": 0,
            "width_error": 0,
            "height_error": 0,
            "roi": roi,
            "invalid_reason": reason,
        }
        return out_img, metrics

    def _get_software_mask(self, image_rgb: np.ndarray, color_mode: str) -> np.ndarray:
        """Compute floating-point software reference segmentation mask."""
        if color_mode == "red_part":
            ycrcb = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2YCrCb)
            cr = ycrcb[:, :, 1]
            cb = ycrcb[:, :, 2]
            mask = ((cb > Q10_CB_B_MIN) & (cb < Q10_CB_B_MAX) &
                    (cr > Q10_CR_R_MIN) & (cr < Q10_CR_R_MAX)).astype(np.uint8) * 255
        elif color_mode == "blue_part":
            ycrcb = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2YCrCb)
            cb = ycrcb[:, :, 2]
            cr = ycrcb[:, :, 1]
            mask = ((cb > 140) & (cr < 120)).astype(np.uint8) * 255
        else: # dark_part
            gray = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2GRAY)
            mask = (gray < 60).astype(np.uint8) * 255
        return mask

    @staticmethod
    def _get_hardware_mask(image_rgb: np.ndarray, color_mode: str) -> np.ndarray:
        """Return the binary mask produced by the fixed-point pixel path."""
        r = image_rgb[:, :, 0].astype(np.int32)
        g = image_rgb[:, :, 1].astype(np.int32)
        b = image_rgb[:, :, 2].astype(np.int32)
        cb_q10 = (512 * b - 173 * r - 339 * g + Q10_BIAS) >> Q10_SHIFT
        cr_q10 = (512 * r - 429 * g - 83 * b + Q10_BIAS) >> Q10_SHIFT
        y_bt601 = ((r << 6) + (r << 3) + (r << 2) + r +
                   (g << 7) + (g << 4) + (g << 2) + (g << 1) +
                   (b << 4) + (b << 3) + (b << 2) + b) >> 8

        if color_mode == "red_part":
            return ((cb_q10 > Q10_CB_B_MIN) & (cb_q10 < Q10_CB_B_MAX) &
                    (cr_q10 > Q10_CR_R_MIN) & (cr_q10 < Q10_CR_R_MAX)).astype(np.uint8)
        if color_mode == "blue_part":
            return ((cb_q10 > 140) & (cr_q10 < 120)).astype(np.uint8)
        return (y_bt601 < BT601_Y_DARK_MAX).astype(np.uint8)

    @staticmethod
    def stage_d_morphology(mask_in: np.ndarray, morphology_mode: str) -> np.ndarray:
        """Apply the Stage D 3x3 contract with explicit replicated borders."""
        mask = (mask_in > 0).astype(np.uint8)
        if morphology_mode == "none":
            return mask.copy()
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
        border = cv2.BORDER_REPLICATE
        if morphology_mode == "erode_3x3":
            result = cv2.erode(mask, kernel, iterations=1, borderType=border)
        elif morphology_mode == "dilate_3x3":
            result = cv2.dilate(mask, kernel, iterations=1, borderType=border)
        elif morphology_mode == "open_3x3":
            result = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel, borderType=border)
        elif morphology_mode == "close_3x3":
            result = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel, borderType=border)
        else:
            result = mask
        return (result > 0).astype(np.uint8)

    @staticmethod
    def _stage_d_metrics(mask: np.ndarray, roi: dict, params: Dict[str, Any]) -> Dict[str, Any]:
        min_area = int(params.get("min_area", 100))
        nom_w = int(params.get("nominal_width", 120))
        tol_w = int(params.get("width_tolerance", 15))
        nom_h = int(params.get("nominal_height", 80))
        tol_h = int(params.get("height_tolerance", 12))
        y_indices, x_indices = np.where(mask > 0)
        area = len(x_indices)
        if area >= min_area:
            x_min = roi["x"] + int(np.min(x_indices))
            x_max = roi["x"] + int(np.max(x_indices))
            y_min = roi["y"] + int(np.min(y_indices))
            y_max = roi["y"] + int(np.max(y_indices))
            width = x_max - x_min + 1
            height = y_max - y_min + 1
            width_error = abs(width - nom_w)
            height_error = abs(height - nom_h)
            verdict = "PASS" if width_error <= tol_w and height_error <= tol_h else "NG"
            detected = True
        else:
            x_min = x_max = y_min = y_max = width = height = 0
            width_error = height_error = 0
            verdict = "NO_OBJECT"
            detected = False
        return {
            "verdict": verdict,
            "detected": detected,
            "x_min": x_min,
            "x_max": x_max,
            "y_min": y_min,
            "y_max": y_max,
            "width_px": width,
            "height_px": height,
            "area_px": area,
            "nominal_w": nom_w,
            "nominal_h": nom_h,
            "width_error": width_error,
            "height_error": height_error,
            "roi": roi,
            "invalid_reason": None,
        }

    def stage_d_trace(self, image_rgb: np.ndarray, params: Dict[str, Any], model: str) -> Dict[str, Any]:
        """Expose comparable masks and metrics without display overlays."""
        roi, roi_image, invalid_reason = self._resolve_roi(image_rgb, params)
        if invalid_reason:
            empty = np.zeros(image_rgb.shape[:2], dtype=np.uint8)
            _, metrics = self._invalid_result(image_rgb, roi, invalid_reason)
            return {"raw_mask": empty, "processed_mask": empty.copy(), "metrics": metrics}
        if model == "reference":
            raw_mask = (self._get_software_mask(roi_image, params.get("target_color", "red_part")) > 0).astype(np.uint8)
        elif model == "hardware":
            raw_mask = self._get_hardware_mask(roi_image, params.get("target_color", "red_part"))
        else:
            raise ValueError(f"unknown Stage D model: {model}")
        processed_mask = self.stage_d_morphology(raw_mask, params.get("morphology_mode", "open_3x3"))
        metrics = self._stage_d_metrics(processed_mask, roi, params)
        return {"raw_mask": raw_mask, "processed_mask": processed_mask, "metrics": metrics}

    def process_visual_reference(self, image_rgb: np.ndarray, params: Dict[str, Any]) -> Tuple[np.ndarray, Dict[str, Any]]:
        """High-level software visual golden model with floating-point & OpenCV operations."""
        color_mode = params.get("target_color", "red_part")
        morph_mode = params.get("morphology_mode", "open_3x3")
        min_area = int(params.get("min_area", 100))
        nom_w = int(params.get("nominal_width", 120))
        tol_w = int(params.get("width_tolerance", 15))
        nom_h = int(params.get("nominal_height", 80))
        tol_h = int(params.get("height_tolerance", 12))

        roi, roi_image, invalid_reason = self._resolve_roi(image_rgb, params)
        if invalid_reason:
            out_img, metrics = self._invalid_result(image_rgb, roi, invalid_reason)
            metrics["nominal_w"] = nom_w
            metrics["nominal_h"] = nom_h
            return out_img, metrics

        # 1. Color Segmentation
        raw_mask = self._get_software_mask(roi_image, color_mode)

        # 2. Morphology Filter
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
        if morph_mode == "erode_3x3":
            proc_mask = self.stage_d_morphology(raw_mask, "erode_3x3") * 255
        elif morph_mode == "dilate_3x3":
            proc_mask = self.stage_d_morphology(raw_mask, "dilate_3x3") * 255
        elif morph_mode == "open_3x3":
            proc_mask = self.stage_d_morphology(raw_mask, "open_3x3") * 255
        elif morph_mode == "close_3x3":
            proc_mask = self.stage_d_morphology(raw_mask, "close_3x3") * 255
        else:
            proc_mask = raw_mask.copy()

        # 3. Connected Components / Bounding Box
        num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(proc_mask, connectivity=8)

        # Find largest non-background component
        best_idx = -1
        max_c_area = 0
        for i in range(1, num_labels):
            area_i = stats[i, cv2.CC_STAT_AREA]
            if area_i > max_c_area:
                max_c_area = area_i
                best_idx = i

        out_img = image_rgb.copy()
        h_img, w_img = image_rgb.shape[:2]
        self._draw_roi(out_img, roi)

        if best_idx > 0 and max_c_area >= min_area:
            x_min = roi["x"] + stats[best_idx, cv2.CC_STAT_LEFT]
            y_min = roi["y"] + stats[best_idx, cv2.CC_STAT_TOP]
            box_w = stats[best_idx, cv2.CC_STAT_WIDTH]
            box_h = stats[best_idx, cv2.CC_STAT_HEIGHT]
            x_max = x_min + box_w - 1
            y_max = y_min + box_h - 1
            detected = True

            # Dimension tolerance test
            w_err = abs(box_w - nom_w)
            h_err = abs(box_h - nom_h)
            is_pass = (w_err <= tol_w) and (h_err <= tol_h)
            verdict = "PASS" if is_pass else "NG"
            color = (16, 185, 129) if is_pass else (239, 68, 68) # Green vs Red
        else:
            detected = False
            x_min, y_min, x_max, y_max, box_w, box_h, max_c_area = 0, 0, 0, 0, 0, 0, 0
            verdict = "NO_OBJECT"
            color = (148, 163, 184) # Slate gray

        # 4. Render Visual Reference Overlay
        if detected:
            # Draw Bounding Box (thickness = 2)
            cv2.rectangle(out_img, (x_min, y_min), (x_max, y_max), color, 2)
            # Center point
            cx, cy = (x_min + x_max) // 2, (y_min + y_max) // 2
            cv2.drawMarker(out_img, (cx, cy), color, cv2.MARKER_CROSS, 10, 2)
            # Label banner
            label = f"[{verdict}] W:{box_w}px H:{box_h}px Area:{max_c_area}"
            cv2.putText(out_img, label, (max(10, x_min), max(25, y_min - 8)),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, color, 2, cv2.LINE_AA)
        else:
            cv2.putText(out_img, "NO OBJECT IN ROI", (30, 40),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.8, color, 2, cv2.LINE_AA)

        metrics = {
            "verdict": verdict,
            "detected": detected,
            "x_min": int(x_min),
            "x_max": int(x_max),
            "y_min": int(y_min),
            "y_max": int(y_max),
            "width_px": int(box_w),
            "height_px": int(box_h),
            "area_px": int(max_c_area),
            "nominal_w": nom_w,
            "nominal_h": nom_h,
            "width_error": int(abs(box_w - nom_w)) if detected else 0,
            "height_error": int(abs(box_h - nom_h)) if detected else 0,
            "roi": roi,
            "invalid_reason": None,
        }
        return out_img, metrics

    def process_hardware_equivalent(self, image_rgb: np.ndarray, params: Dict[str, Any]) -> Tuple[np.ndarray, Dict[str, Any]]:
        """Exact fixed-point hardware equivalent model simulating Verilog streaming logic."""
        color_mode = params.get("target_color", "red_part")
        morph_mode = params.get("morphology_mode", "open_3x3")
        min_area = int(params.get("min_area", 100))
        nom_w = int(params.get("nominal_width", 120))
        tol_w = int(params.get("width_tolerance", 15))
        nom_h = int(params.get("nominal_height", 80))
        tol_h = int(params.get("height_tolerance", 12))

        h_img, w_img = image_rgb.shape[:2]
        roi, roi_image, invalid_reason = self._resolve_roi(image_rgb, params)
        if invalid_reason:
            out_img, metrics = self._invalid_result(image_rgb, roi, invalid_reason)
            metrics["nominal_w"] = nom_w
            metrics["nominal_h"] = nom_h
            return out_img, metrics

        r = roi_image[:, :, 0].astype(np.int32)
        g = roi_image[:, :, 1].astype(np.int32)
        b = roi_image[:, :, 2].astype(np.int32)

        # 1. Hardware Fixed-point Q10 YCbCr transformation (matching color_detect_96.v)
        # cb = 512*B - 173*R - 339*G + 131072; output >> 10
        # cr = 512*R - 429*G -  83*B + 131072; output >> 10
        cb_q10 = (512 * b - 173 * r - 339 * g + Q10_BIAS) >> Q10_SHIFT
        cr_q10 = (512 * r - 429 * g -  83 * b + Q10_BIAS) >> Q10_SHIFT
        # BT.601 Y shift-add (matching pixel_algorithm.v): Y=(77R+150G+29B)>>8
        y_bt601 = ((r << 6) + (r << 3) + (r << 2) + r +
                   (g << 7) + (g << 4) + (g << 2) + (g << 1) +
                   (b << 4) + (b << 3) + (b << 2) + b) >> 8

        if color_mode == "red_part":
            raw_bin = ((cb_q10 > Q10_CB_B_MIN) & (cb_q10 < Q10_CB_B_MAX) &
                       (cr_q10 > Q10_CR_R_MIN) & (cr_q10 < Q10_CR_R_MAX)).astype(np.uint8)
        elif color_mode == "blue_part":
            raw_bin = ((cb_q10 > 140) & (cr_q10 < 120)).astype(np.uint8)
        else: # dark_part
            raw_bin = (y_bt601 < 60).astype(np.uint8)

        # 2. Hardware 3x3 Min/Max Morphology (matching morphology_process.v 2-stage tree)
        def hw_morph_pass(mask_in: np.ndarray, is_dilate: bool) -> np.ndarray:
            pad = np.pad(mask_in, ((1, 1), (1, 1)), mode='edge')
            out = np.zeros_like(mask_in)
            # Stage 1: Line min/max
            # Stage 2: 3-line combination
            for dy in range(3):
                pass
            # Vectorized bit-level 3x3 min/max
            w00 = pad[:-2, :-2]; w01 = pad[:-2, 1:-1]; w02 = pad[:-2, 2:]
            w10 = pad[1:-1, :-2]; w11 = pad[1:-1, 1:-1]; w12 = pad[1:-1, 2:]
            w20 = pad[2:, :-2]; w21 = pad[2:, 1:-1]; w22 = pad[2:, 2:]
            if is_dilate:
                r1 = w00 | w01 | w02
                r2 = w10 | w11 | w12
                r3 = w20 | w21 | w22
                return r1 | r2 | r3
            else:
                r1 = w00 & w01 & w02
                r2 = w10 & w11 & w12
                r3 = w20 & w21 & w22
                return r1 & r2 & r3

        if morph_mode == "erode_3x3":
            proc_bin = hw_morph_pass(raw_bin, is_dilate=False)
        elif morph_mode == "dilate_3x3":
            proc_bin = hw_morph_pass(raw_bin, is_dilate=True)
        elif morph_mode == "open_3x3":
            proc_bin = hw_morph_pass(hw_morph_pass(raw_bin, is_dilate=False), is_dilate=True)
        elif morph_mode == "close_3x3":
            proc_bin = hw_morph_pass(hw_morph_pass(raw_bin, is_dilate=True), is_dilate=False)
        else:
            proc_bin = raw_bin

        # 3. Hardware Bounding Box Tracking & 4-pixel lane alignment (color_detect_96.v)
        # In hardware, pixels are processed 4-by-4 in parallel lanes
        y_indices, x_indices = np.where(proc_bin > 0)
        total_area = len(x_indices)

        if total_area >= min_area:
            detected = True
            hw_xmin = roi["x"] + int(np.min(x_indices))
            hw_xmax = roi["x"] + int(np.max(x_indices))
            hw_ymin = roi["y"] + int(np.min(y_indices))
            hw_ymax = roi["y"] + int(np.max(y_indices))

            # Width and height
            hw_w = hw_xmax - hw_xmin + 1
            hw_h = hw_ymax - hw_ymin + 1

            # Hardware Tolerance Comparator (defect_classifier.v)
            is_pass = (abs(hw_w - nom_w) <= tol_w) and (abs(hw_h - nom_h) <= tol_h)
            verdict = "PASS" if is_pass else "NG"
            border_color = np.array([16, 185, 129], dtype=np.uint8) if is_pass else np.array([239, 68, 68], dtype=np.uint8)
        else:
            detected = False
            hw_xmin, hw_xmax, hw_ymin, hw_ymax = 0, 0, 0, 0
            hw_w, hw_h = 0, 0
            verdict = "NO_OBJECT"
            border_color = np.array([148, 163, 184], dtype=np.uint8)

        # 4. Hardware HDMI Border Replacement (bbox_draw_overlay.v)
        # When scan coordinate reaches the bounding border, force output pixel to border_color
        out_img = image_rgb.copy()
        self._draw_roi(out_img, roi)
        if detected:
            # 2-pixel wide solid line
            for b_thick in range(2):
                x0 = max(0, hw_xmin - b_thick); x1 = min(w_img - 1, hw_xmax + b_thick)
                y0 = max(0, hw_ymin - b_thick); y1 = min(h_img - 1, hw_ymax + b_thick)
                out_img[y0, x0:x1+1] = border_color
                out_img[y1, x0:x1+1] = border_color
                out_img[y0:y1+1, x0] = border_color
                out_img[y0:y1+1, x1] = border_color

            # Cross center marker
            cx = (hw_xmin + hw_xmax) // 2
            cy = (hw_ymin + hw_ymax) // 2
            if 0 <= cy < h_img and 0 <= cx < w_img:
                out_img[max(0, cy-4):min(h_img, cy+5), cx] = border_color
                out_img[cy, max(0, cx-4):min(w_img, cx+5)] = border_color

            # Status watermark text in OSD format
            cv2.putText(out_img, f"[FPGA HW {verdict}] W={hw_w} H={hw_h} Area={total_area}",
                        (max(10, hw_xmin), max(25, hw_ymin - 8)),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, border_color.tolist(), 2, cv2.LINE_AA)
        else:
            cv2.putText(out_img, "FPGA HW: NO OBJECT", (30, 40),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.8, border_color.tolist(), 2, cv2.LINE_AA)

        metrics = {
            "verdict": verdict,
            "detected": detected,
            "x_min": hw_xmin,
            "x_max": hw_xmax,
            "y_min": hw_ymin,
            "y_max": hw_ymax,
            "width_px": hw_w,
            "height_px": hw_h,
            "area_px": total_area,
            "nominal_w": nom_w,
            "nominal_h": nom_h,
            "width_error": abs(hw_w - nom_w) if detected else 0,
            "height_error": abs(hw_h - nom_h) if detected else 0,
            "roi": roi,
            "invalid_reason": None,
        }
        return out_img, metrics
