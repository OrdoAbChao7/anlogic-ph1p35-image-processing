"""Automated verification script for Industrial Inspection (F1~F4) software & hardware models."""
import cv2
import numpy as np
from pathlib import Path
import sys

BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))

from plugins.industrial_inspection import IndustrialInspectionAlgorithm

def run_tests():
    plugin = IndustrialInspectionAlgorithm()
    samples_dir = BASE_DIR / "samples"
    exports_dir = BASE_DIR / "exports" / "industrial_inspection_preview"
    exports_dir.mkdir(parents=True, exist_ok=True)

    test_cases = [
        ("workpiece_normal_pass.png", "open_3x3", "PASS"),
        ("workpiece_oversized_ng.png", "open_3x3", "NG"),
        ("workpiece_undersized_ng.png", "open_3x3", "NG"),
        ("workpiece_empty_conveyor.png", "open_3x3", "NO_OBJECT"),
        ("workpiece_noisy_speckles.png", "open_3x3", "PASS")
    ]

    params = {
        "target_color": "red_part",
        "morphology_mode": "open_3x3",
        "min_area": 100,
        "nominal_width": 120,
        "width_tolerance": 15,
        "nominal_height": 80,
        "height_tolerance": 12
    }

    print("================================================================================")
    print("RUNNING INDUSTRIAL INSPECTION SUITE (F1~F4) BENCHMARK VERIFICATION")
    print("================================================================================")

    all_passed = True
    for filename, morph, expected in test_cases:
        img_bgr = cv2.imread(str(samples_dir / filename))
        if img_bgr is None:
            print(f"Error: Could not load {filename}")
            all_passed = False
            continue
        img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
        cur_params = dict(params, morphology_mode=morph)

        ref_out, ref_metrics = plugin.process_visual_reference(img_rgb, cur_params)
        hw_out, hw_metrics = plugin.process_hardware_equivalent(img_rgb, cur_params)

        # Save visual comparison side-by-side: Input | Software Visual Ref | Hardware FPGA Model
        # Scale to 640x360 each for compact composite
        h, w = img_rgb.shape[:2]
        s_in = cv2.resize(img_rgb, (640, 360))
        s_ref = cv2.resize(ref_out, (640, 360))
        s_hw = cv2.resize(hw_out, (640, 360))
        composite = np.hstack([s_in, s_ref, s_hw])
        composite_bgr = cv2.cvtColor(composite, cv2.COLOR_RGB2BGR)
        cv2.imwrite(str(exports_dir / f"cmp_{filename}"), composite_bgr)

        ref_v = ref_metrics["verdict"]
        hw_v = hw_metrics["verdict"]
        ref_w = ref_metrics["width_px"]
        hw_w = hw_metrics["width_px"]
        ref_h = ref_metrics["height_px"]
        hw_h = hw_metrics["height_px"]

        status = "PASS" if (ref_v == expected and hw_v == expected) else "FAIL"
        if status == "FAIL":
            all_passed = False

        print(f"[{status}] {filename:<28} | Expected: {expected:<9} | Ref: {ref_v:<9} (W={ref_w:3d}, H={ref_h:2d}) | HW: {hw_v:<9} (W={hw_w:3d}, H={hw_h:2d})")

    print("--------------------------------------------------------------------------------")
    if all_passed:
        print(">>> ALL 5 INDUSTRIAL INSPECTION BENCHMARK TESTS PASSED WITH 100% AGREEMENT <<<")
        print(f"Side-by-side previews saved in: {exports_dir}")
    else:
        print(">>> SOME TESTS FAILED <<<")
    print("================================================================================")
    return all_passed

if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
