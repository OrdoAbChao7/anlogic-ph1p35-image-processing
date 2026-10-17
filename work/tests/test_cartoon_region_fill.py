"""Contract tests for the software cartoon region-fill candidate."""

import sys
import unittest
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "work" / "models"))


class CartoonRegionFillReferenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from cartoon_region_fill_reference import filter_rgb, local_fill, quantize_rgb

        cls.filter_rgb = staticmethod(filter_rgb)
        cls.local_fill = staticmethod(local_fill)
        cls.quantize_rgb = staticmethod(quantize_rgb)

    def test_quantization_boundaries_are_fixed_eight_levels(self):
        values = np.array([0, 31, 32, 63, 64, 255], dtype=np.uint8)
        rgb = np.repeat(values[:, None, None], 3, axis=2)
        result = self.quantize_rgb(rgb)[:, 0, 0]
        np.testing.assert_array_equal(result, [0, 0, 36, 36, 73, 255])

    def test_cross_fill_replaces_only_a_single_pixel_hole(self):
        red = np.array([220, 20, 20], dtype=np.uint8)
        blue = np.array([20, 20, 220], dtype=np.uint8)
        rgb = np.tile(red, (3, 3, 1))
        rgb[1, 1] = blue
        quantized = self.quantize_rgb(rgb)
        filled = self.local_fill(quantized)
        np.testing.assert_array_equal(filled[1, 1], quantized[0, 1])

    def test_cross_fill_does_not_cross_a_real_boundary(self):
        red = np.array([220, 20, 20], dtype=np.uint8)
        blue = np.array([20, 20, 220], dtype=np.uint8)
        rgb = np.tile(red, (3, 3, 1))
        rgb[1, 1] = blue
        rgb[1, 0] = blue
        quantized = self.quantize_rgb(rgb)
        filled = self.local_fill(quantized)
        np.testing.assert_array_equal(filled[1, 1], quantized[1, 1])

    def test_one_pixel_image_uses_replicated_edges(self):
        rgb = np.array([[[37, 91, 173]]], dtype=np.uint8)
        quantized = self.quantize_rgb(rgb)
        filled = self.local_fill(quantized)
        np.testing.assert_array_equal(filled, quantized)

    def test_constant_image_has_no_sobel_edges(self):
        rgb = np.full((7, 9, 3), (100, 150, 200), dtype=np.uint8)
        cartoon, edge, filled = self.filter_rgb(rgb)
        self.assertEqual(cartoon.dtype, np.uint8)
        self.assertEqual(filled.dtype, np.uint8)
        self.assertEqual(edge.dtype, np.uint8)
        self.assertEqual(cartoon.shape, rgb.shape)
        self.assertFalse(edge.any())

    def test_step_image_has_a_sobel_contour(self):
        rgb = np.zeros((7, 9, 3), dtype=np.uint8)
        rgb[:, 5:] = 255
        _, edge, _ = self.filter_rgb(rgb)
        self.assertTrue(edge[:, 4:6].any())
        self.assertFalse(edge[:, :3].any())

    def test_rejects_non_rgb888_input(self):
        with self.assertRaises(ValueError):
            self.quantize_rgb(np.zeros((4, 4), dtype=np.uint8))
        with self.assertRaises(ValueError):
            self.quantize_rgb(np.zeros((4, 4, 3), dtype=np.uint16))


if __name__ == "__main__":
    unittest.main()
