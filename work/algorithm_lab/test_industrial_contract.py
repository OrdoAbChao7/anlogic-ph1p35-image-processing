"""Contract tests for the industrial inspection software-first preview."""

import sys
import unittest
import uuid
from pathlib import Path

import cv2
import numpy as np
from fastapi.testclient import TestClient

BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))

from plugins.industrial_inspection import IndustrialInspectionAlgorithm


class IndustrialInspectionContractTests(unittest.TestCase):
    def setUp(self):
        self.plugin = IndustrialInspectionAlgorithm()
        self.image = np.zeros((120, 180, 3), dtype=np.uint8)
        # This RGB value is inside the shared red_part YCrCb contract.
        self.image[30:80, 60:140] = (150, 30, 30)
        self.params = {
            "target_color": "red_part",
            "morphology_mode": "none",
            "min_area": 100,
            "nominal_width": 80,
            "width_tolerance": 2,
            "nominal_height": 50,
            "height_tolerance": 2,
        }

    def test_roi_offsets_bbox_back_to_full_frame_for_both_models(self):
        params = dict(self.params, roi_x=50, roi_y=20, roi_width=100, roi_height=80)
        ref_image, ref_metrics = self.plugin.process_visual_reference(self.image, params)
        hw_image, hw_metrics = self.plugin.process_hardware_equivalent(self.image, params)

        for metrics in (ref_metrics, hw_metrics):
            self.assertEqual(metrics["verdict"], "PASS")
            self.assertEqual((metrics["x_min"], metrics["y_min"]), (60, 30))
            self.assertEqual((metrics["width_px"], metrics["height_px"]), (80, 50))
            self.assertEqual(metrics["roi"], {"x": 50, "y": 20, "width": 100, "height": 80})

        self.assertEqual(ref_metrics["verdict"], hw_metrics["verdict"])
        self.assertGreater(int(np.count_nonzero(ref_image != self.image)), 0)
        self.assertGreater(int(np.count_nonzero(hw_image != self.image)), 0)

    def test_invalid_roi_is_reported_without_processing(self):
        params = dict(self.params, roi_x=150, roi_y=20, roi_width=100, roi_height=80)
        _, ref_metrics = self.plugin.process_visual_reference(self.image, params)
        _, hw_metrics = self.plugin.process_hardware_equivalent(self.image, params)

        self.assertEqual(ref_metrics["verdict"], "INVALID")
        self.assertEqual(hw_metrics["verdict"], "INVALID")
        self.assertEqual(ref_metrics["invalid_reason"], "ROI exceeds image bounds")
        self.assertEqual(hw_metrics["invalid_reason"], "ROI exceeds image bounds")
        self.assertFalse(ref_metrics["detected"])
        self.assertFalse(hw_metrics["detected"])

    def test_non_integer_roi_is_invalid_in_both_models(self):
        params = dict(self.params, roi_x=1.5, roi_y=20, roi_width=100, roi_height=80)
        _, ref_metrics = self.plugin.process_visual_reference(self.image, params)
        _, hw_metrics = self.plugin.process_hardware_equivalent(self.image, params)

        for metrics in (ref_metrics, hw_metrics):
            self.assertEqual(metrics["verdict"], "INVALID")
            self.assertEqual(metrics["invalid_reason"], "roi_x must be an integer")
            self.assertFalse(metrics["detected"])

    def test_full_frame_zero_roi_preserves_current_behavior(self):
        _, metrics = self.plugin.process_visual_reference(
            self.image, dict(self.params, roi_x=0, roi_y=0, roi_width=0, roi_height=0)
        )
        self.assertEqual(metrics["verdict"], "PASS")
        self.assertEqual(metrics["roi"], {"x": 0, "y": 0, "width": 180, "height": 120})


class ParameterPresetApiTests(unittest.TestCase):
    def test_parameter_preset_round_trip(self):
        from app import app

        client = TestClient(app)
        name = "contract_" + uuid.uuid4().hex[:10]
        params = {
            "target_color": "red_part",
            "morphology_mode": "open_3x3",
            "roi_x": 10,
            "roi_y": 20,
            "roi_width": 100,
            "roi_height": 80,
        }
        try:
            saved = client.post(
                "/api/params/save",
                json={"algorithm_id": "industrial_inspection", "name": name, "parameters": params},
            )
            self.assertEqual(saved.status_code, 200, saved.text)
            self.assertEqual(saved.json()["name"], name)

            listed = client.get("/api/params/industrial_inspection")
            self.assertEqual(listed.status_code, 200, listed.text)
            self.assertIn(name, [item["name"] for item in listed.json()["presets"]])

            loaded = client.post(
                "/api/params/load",
                json={"algorithm_id": "industrial_inspection", "name": name},
            )
            self.assertEqual(loaded.status_code, 200, loaded.text)
            self.assertEqual(loaded.json()["parameters"], params)
        finally:
            preset_path = BASE_DIR / "configs" / "industrial_inspection" / f"{name}.json"
            if preset_path.exists():
                preset_path.unlink()


if __name__ == "__main__":
    unittest.main()
