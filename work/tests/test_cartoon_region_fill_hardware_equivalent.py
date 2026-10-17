"""Fixed-point and cycle-vector contract for the region-fill RTL candidate."""

import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "work" / "models"))

from cartoon_region_fill_hardware_equivalent import (  # noqa: E402
    LATENCY_CYCLES,
    build_expected_frame,
    generate_vectors,
    write_vectors,
)
from cartoon_region_fill_reference import filter_rgb  # noqa: E402


class CartoonRegionFillHardwareEquivalentTests(unittest.TestCase):
    def test_expected_frame_matches_reference_for_all_modes(self):
        rgb = np.zeros((5, 6, 3), dtype=np.uint8)
        rgb[1:4, 2:5] = [220, 20, 20]
        rgb[2, 3] = [20, 20, 220]
        cartoon, edge, filled = filter_rgb(rgb)
        np.testing.assert_array_equal(build_expected_frame(rgb, 2), cartoon)
        np.testing.assert_array_equal(build_expected_frame(rgb, 1), np.repeat(edge[:, :, None], 3, axis=2))
        np.testing.assert_array_equal(build_expected_frame(rgb, 0), rgb)
        self.assertEqual(filled.dtype, np.uint8)

    def test_cycle_vectors_start_with_reset_flush_and_have_fixed_latency(self):
        vectors = generate_vectors(width=5, height=4, frame_modes=(0, 2), seed=520)
        self.assertGreater(len(vectors), LATENCY_CYCLES)
        self.assertTrue(all(expected == 0 for _, expected in vectors[:LATENCY_CYCLES]))
        self.assertEqual(LATENCY_CYCLES, 6)

    def test_vectors_can_be_written_in_existing_hex_contract(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "region-fill.txt"
            vectors = write_vectors(path, width=4, height=3, frame_modes=(2,), seed=1)
            self.assertGreater(len(vectors), 0)
            lines = path.read_text(encoding="ascii").splitlines()
            self.assertEqual(len(lines), len(vectors))
            self.assertTrue(all(len(line.split()) == 2 for line in lines))
            self.assertTrue(all(len(part) in (14, 8) for line in lines for part in line.split()))


if __name__ == "__main__":
    unittest.main()
