"""Reference-model checks use literal, hand-computable images."""
import sys
import unittest
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'models'))


class CartoonReferenceTests(unittest.TestCase):
    def test_constant_color_has_no_edges_and_quantizes(self):
        from cartoon_reference import filter_rgb
        rgb = np.full((5, 7, 3), (100, 150, 200), dtype=np.uint8)
        toon, edge = filter_rgb(rgb)
        self.assertTrue(np.all(toon == (109, 146, 219)))
        self.assertFalse(edge.any())

    def test_black_white_vertical_step_has_two_outline_columns(self):
        from cartoon_reference import filter_rgb
        rgb = np.zeros((5, 8, 3), dtype=np.uint8)
        rgb[:, 4:] = 255
        toon, edge = filter_rgb(rgb)
        self.assertTrue(np.all(edge[:, 4:6] == 255))
        self.assertFalse(edge[:, :4].any())
        self.assertFalse(edge[:, 6:].any())
        self.assertFalse(toon[:, :6].any())
        self.assertTrue(np.all(toon[:, 6:] == 255))

    def test_top_left_replication_and_channel_order(self):
        from cartoon_reference import filter_rgb
        rgb = np.array([[[255, 0, 0], [0, 255, 0]],
                        [[0, 0, 255], [255, 255, 255]]], dtype=np.uint8)
        toon, edge = filter_rgb(rgb, threshold=2047)
        self.assertEqual(toon[0, 0].tolist(), [255, 0, 0])
        self.assertEqual(toon[0, 1].tolist(), [182, 36, 0])
        self.assertFalse(edge.any())


if __name__ == '__main__':
    unittest.main()
