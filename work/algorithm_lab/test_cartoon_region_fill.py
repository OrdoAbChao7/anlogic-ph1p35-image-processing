"""Algorithm Lab contract for the unapproved s4 region-fill candidate."""

import unittest
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from plugins.cartoon import CartoonAlgorithm


class CartoonRegionFillPluginTests(unittest.TestCase):
    def setUp(self):
        self.image = np.zeros((12, 16, 3), dtype=np.uint8)
        self.image[2:10, 3:13] = [220, 20, 20]
        self.image[5, 7] = [20, 20, 220]

    def test_region_fill_variant_is_exposed_with_frozen_defaults(self):
        algo = CartoonAlgorithm()
        variant_spec = next(
            spec for spec in algo.get_parameter_specs() if spec["id"] == "variant"
        )
        values = {option["value"] for option in variant_spec["options"]}
        self.assertIn("s4_region_fill", values)

        result, metrics = algo.process_hardware_equivalent(
            self.image,
            {
                "variant": "s4_region_fill",
                "quant_levels": "8",
                "sobel_threshold": 240,
                "smooth_passes": "0",
                "edge_source": "raw",
            },
        )
        self.assertEqual(result.shape, self.image.shape)
        self.assertEqual(result.dtype, np.uint8)
        self.assertEqual(metrics["variant"], "s4_region_fill")
        self.assertIn("filled_pixels", metrics)
        self.assertIn("edge_pixels", metrics)
        self.assertIn("line_buffer_rows", metrics)
        self.assertGreater(metrics["filled_pixels"], 0)

    def test_existing_s3_variant_remains_available(self):
        algo = CartoonAlgorithm()
        result, metrics = algo.process_hardware_equivalent(
            self.image,
            {
                "variant": "s3_luma",
                "quant_levels": "8",
                "sobel_threshold": 240,
                "smooth_passes": "1",
                "edge_source": "smoothed",
            },
        )
        self.assertEqual(result.shape, self.image.shape)
        self.assertEqual(metrics["variant"], "s3_luma")


if __name__ == "__main__":
    unittest.main()
