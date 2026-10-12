"""Self-test script for FPGA Algorithm Lab backend."""
import unittest
import numpy as np
import cv2
from pathlib import Path

from plugins.grayscale import GrayscaleAlgorithm
from plugins.threshold import ThresholdAlgorithm
from plugins.sobel import SobelAlgorithm
from plugins.cartoon import CartoonAlgorithm


class TestAlgorithmLab(unittest.TestCase):
    def setUp(self):
        # Create a test synthetic RGB image (100x100)
        self.img = np.zeros((100, 100, 3), dtype=np.uint8)
        self.img[:50, :50] = [200, 50, 50]    # Red-ish
        self.img[:50, 50:] = [50, 200, 50]    # Green-ish
        self.img[50:, :50] = [50, 50, 200]    # Blue-ish
        self.img[50:, 50:] = [220, 220, 220]  # Light gray

    def test_grayscale(self):
        algo = GrayscaleAlgorithm()
        ref, r_m = algo.process_visual_reference(self.img, {})
        hw, h_m = algo.process_hardware_equivalent(self.img, {"method": "shift_212"})
        self.assertEqual(ref.shape, (100, 100, 3))
        self.assertEqual(hw.shape, (100, 100, 3))
        diff = algo.compute_diff_heatmap(ref, hw)
        self.assertEqual(diff.shape, (100, 100, 3))

    def test_threshold(self):
        algo = ThresholdAlgorithm()
        ref, r_m = algo.process_visual_reference(self.img, {"invert": "no"})
        hw, h_m = algo.process_hardware_equivalent(self.img, {"threshold_value": 128, "invert": "no"})
        self.assertEqual(ref.shape, (100, 100, 3))
        self.assertEqual(hw.shape, (100, 100, 3))

    def test_sobel(self):
        algo = SobelAlgorithm()
        ref, r_m = algo.process_visual_reference(self.img, {"edge_threshold": 128, "output_mode": "binary"})
        hw, h_m = algo.process_hardware_equivalent(self.img, {"edge_threshold": 128, "output_mode": "binary"})
        self.assertEqual(ref.shape, (100, 100, 3))
        self.assertEqual(hw.shape, (100, 100, 3))
        self.assertTrue(np.any(hw == 255))  # Should detect edges

    def test_cartoon(self):
        algo = CartoonAlgorithm()
        ref, r_m = algo.process_visual_reference(self.img, {"quant_levels": "8", "sobel_threshold": 160})
        hw, h_m = algo.process_hardware_equivalent(self.img, {
            "variant": "s3_luma",
            "quant_levels": "8",
            "sobel_threshold": 160,
            "smooth_passes": "1",
            "edge_source": "smoothed"
        })
        self.assertEqual(ref.shape, (100, 100, 3))
        self.assertEqual(hw.shape, (100, 100, 3))


if __name__ == '__main__':
    unittest.main()
