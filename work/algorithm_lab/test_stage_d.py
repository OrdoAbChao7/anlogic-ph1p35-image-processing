"""Stage D contract, fixed-point, pixel, and boundary regression tests."""

import hashlib
import json
import sys
import unittest
from pathlib import Path

import cv2
import numpy as np

BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))

from plugins.industrial_inspection import IndustrialInspectionAlgorithm
from stage_d_contract import (
    FROZEN_PARAMS,
    FROZEN_VERSION,
    SAMPLE_SHA256,
    canonical_params_sha256,
    file_sha256,
)


REGISTRY_PATH = BASE_DIR / "registry.json"
SAMPLES_DIR = BASE_DIR / "samples"
PLUGIN_PATH = BASE_DIR / "plugins" / "industrial_inspection.py"


def load_registry_entry():
    registry = json.loads(REGISTRY_PATH.read_text(encoding="utf-8"))
    return next(item for item in registry if item["algorithm_id"] == "industrial_inspection")


def load_rgb(name: str) -> np.ndarray:
    image = cv2.imread(str(SAMPLES_DIR / name), cv2.IMREAD_COLOR)
    if image is None:
        raise AssertionError(f"missing sample: {name}")
    return cv2.cvtColor(image, cv2.COLOR_BGR2RGB)


class StageDContractTests(unittest.TestCase):
    def setUp(self):
        self.plugin = IndustrialInspectionAlgorithm()

    def test_approved_registry_freezes_model_params_and_inputs(self):
        entry = load_registry_entry()
        self.assertEqual(entry["status"], "VISUAL_APPROVED")
        self.assertEqual(entry["user_approved_version"], FROZEN_VERSION)
        self.assertEqual(entry["frozen_params"], FROZEN_PARAMS)
        self.assertEqual(entry["sample_image_hashes"], SAMPLE_SHA256)
        self.assertEqual(entry["model_sha256"], file_sha256(PLUGIN_PATH))
        self.assertEqual(entry["params_sha256"], canonical_params_sha256(FROZEN_PARAMS))
        self.assertEqual(entry["hardware_equivalent_contract"]["q10_shift"], 10)
        self.assertEqual(entry["hardware_equivalent_contract"]["q10_bias"], 131072)
        self.assertEqual(entry["hardware_equivalent_contract"]["morphology_border"], "replicate")

    def test_approved_samples_match_pixel_masks_and_measurement(self):
        expected = {
            "workpiece_empty_conveyor.png": "NO_OBJECT",
            "workpiece_noisy_speckles.png": "PASS",
            "workpiece_normal_pass.png": "PASS",
            "workpiece_oversized_ng.png": "NG",
            "workpiece_undersized_ng.png": "NG",
        }
        for name, verdict in expected.items():
            image = load_rgb(name)
            ref_trace = self.plugin.stage_d_trace(image, FROZEN_PARAMS, model="reference")
            hw_trace = self.plugin.stage_d_trace(image, FROZEN_PARAMS, model="hardware")
            self.assertTrue(np.array_equal(ref_trace["raw_mask"], hw_trace["raw_mask"]), name)
            self.assertTrue(np.array_equal(ref_trace["processed_mask"], hw_trace["processed_mask"]), name)
            for key in ("verdict", "detected", "x_min", "x_max", "y_min", "y_max",
                        "width_px", "height_px", "area_px", "roi"):
                self.assertEqual(ref_trace["metrics"][key], hw_trace["metrics"][key], f"{name}: {key}")
            self.assertEqual(ref_trace["metrics"]["verdict"], verdict, name)

    def test_hardware_trace_is_deterministic(self):
        image = load_rgb("workpiece_noisy_speckles.png")
        first = self.plugin.stage_d_trace(image, FROZEN_PARAMS, model="hardware")
        second = self.plugin.stage_d_trace(image, FROZEN_PARAMS, model="hardware")
        self.assertTrue(np.array_equal(first["raw_mask"], second["raw_mask"]))
        self.assertTrue(np.array_equal(first["processed_mask"], second["processed_mask"]))
        self.assertEqual(first["metrics"], second["metrics"])

    def test_q10_threshold_and_luma_boundary_vectors(self):
        image = np.array(
            [[[254, 0, 0], [255, 0, 0], [120, 80, 40], [150, 30, 30],
              [0, 255, 0], [0, 0, 255], [0, 0, 0], [60, 60, 60], [59, 59, 59]]],
            dtype=np.uint8,
        )
        red_params = dict(FROZEN_PARAMS, morphology_mode="none", min_area=1)
        reference = self.plugin.stage_d_trace(image, red_params, model="reference")
        hardware = self.plugin.stage_d_trace(image, red_params, model="hardware")
        expected_red = np.array([[0, 0, 1, 1, 0, 0, 0, 0, 0]], dtype=np.uint8)
        self.assertTrue(np.array_equal(reference["raw_mask"], expected_red))
        self.assertTrue(np.array_equal(hardware["raw_mask"], expected_red))
        self.assertTrue(np.array_equal(reference["raw_mask"], hardware["raw_mask"]))

        dark_params = dict(FROZEN_PARAMS, target_color="dark_part", morphology_mode="none", min_area=1)
        dark_reference = self.plugin.stage_d_trace(image, dark_params, model="reference")
        dark_hardware = self.plugin.stage_d_trace(image, dark_params, model="hardware")
        expected_dark = np.array([[0, 0, 0, 0, 0, 1, 1, 0, 1]], dtype=np.uint8)
        self.assertTrue(np.array_equal(dark_reference["raw_mask"], expected_dark))
        self.assertTrue(np.array_equal(dark_hardware["raw_mask"], expected_dark))

    def test_roi_edges_and_replicate_border_are_explicit(self):
        image = np.zeros((5, 7, 3), dtype=np.uint8)
        image[1:4, 2:5] = (120, 80, 40)
        params = dict(FROZEN_PARAMS, morphology_mode="none", min_area=1,
                      roi_x=2, roi_y=1, roi_width=3, roi_height=3)
        ref = self.plugin.stage_d_trace(image, params, model="reference")
        hw = self.plugin.stage_d_trace(image, params, model="hardware")
        self.assertEqual(ref["metrics"]["roi"], {"x": 2, "y": 1, "width": 3, "height": 3})
        self.assertEqual((ref["metrics"]["x_min"], ref["metrics"]["y_min"]), (2, 1))
        self.assertEqual((ref["metrics"]["width_px"], ref["metrics"]["height_px"]), (3, 3))
        self.assertEqual(ref["metrics"], hw["metrics"])
        self.assertTrue(np.array_equal(ref["processed_mask"], hw["processed_mask"]))

        one_pixel = np.zeros((3, 3), dtype=np.uint8)
        one_pixel[0, 0] = 1
        expected = np.array([[1, 1, 0], [1, 1, 0], [0, 0, 0]], dtype=np.uint8)
        self.assertTrue(np.array_equal(self.plugin.stage_d_morphology(one_pixel, "dilate_3x3"), expected))


if __name__ == "__main__":
    unittest.main(verbosity=2)
