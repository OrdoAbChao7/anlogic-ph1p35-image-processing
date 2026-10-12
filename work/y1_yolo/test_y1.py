import unittest

import numpy as np

from evaluate import score_image
from fastestdet_runtime import NAMES, decode


class Y1Tests(unittest.TestCase):
    def test_decode_keeps_only_three_classes(self):
        # One cell, 80-class head; make bottle score dominate.
        pred = np.zeros((1, 85, 1, 1), dtype=np.float32)
        pred[0, 0, 0, 0] = 0.9
        pred[0, 5 + NAMES.index("bottle"), 0, 0] = 0.8
        det = decode(pred, (100, 100, 3), threshold=0.2)
        self.assertEqual(len(det), 1)
        self.assertEqual(det[0]["class"], "bottle")
        pred[0, 5 + NAMES.index("bottle"), 0, 0] = 0
        pred[0, 5 + NAMES.index("person"), 0, 0] = 0.8
        self.assertEqual(decode(pred, (100, 100, 3), threshold=0.2), [])

    def test_one_to_one_iou_matching(self):
        gt = [{"class": "cup", "box": [10, 10, 20, 20]}]
        pred = [{"class": "cup", "confidence": 0.9, "box": [10, 10, 30, 30]},
                {"class": "cup", "confidence": 0.8, "box": [11, 11, 29, 29]}]
        self.assertEqual(score_image(pred, gt)["cup"], {"tp": 1, "fp": 1, "fn": 0})


if __name__ == "__main__":
    unittest.main()
