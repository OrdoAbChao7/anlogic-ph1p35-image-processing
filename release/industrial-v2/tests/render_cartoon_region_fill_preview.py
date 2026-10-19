"""Render the unapproved cartoon region-fill candidate and its evidence."""

from __future__ import annotations

import hashlib
import json
import sys
import argparse
from pathlib import Path

import cv2

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "work" / "algorithm_lab"))

from plugins.cartoon import CartoonAlgorithm  # noqa: E402


SAMPLES = {
    "workpiece_empty_conveyor": ROOT / "work" / "algorithm_lab" / "samples" / "workpiece_empty_conveyor.png",
    "workpiece_noisy_speckles": ROOT / "work" / "algorithm_lab" / "samples" / "workpiece_noisy_speckles.png",
    "workpiece_normal_pass": ROOT / "work" / "algorithm_lab" / "samples" / "workpiece_normal_pass.png",
    "workpiece_oversized_ng": ROOT / "work" / "algorithm_lab" / "samples" / "workpiece_oversized_ng.png",
    "workpiece_undersized_ng": ROOT / "work" / "algorithm_lab" / "samples" / "workpiece_undersized_ng.png",
    "sample_city": ROOT / "work" / "algorithm_lab" / "samples" / "sample_city.png",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--approved",
        action="store_true",
        help="record the user's visual approval in the generated candidate report",
    )
    args = parser.parse_args()
    output = ROOT / "work" / "output" / "cartoon-region-fill-candidate"
    output.mkdir(parents=True, exist_ok=True)
    algo = CartoonAlgorithm()
    params = {
        "variant": "s4_region_fill",
        "quant_levels": "8",
        "sobel_threshold": 240,
        "smooth_passes": "0",
        "edge_source": "quantized",
    }
    report = {
        "status": "VISUAL_APPROVED" if args.approved else "VISUAL_REVIEW_PENDING",
        "version": "s4-region-fill-v1",
        "parameters": params,
        "samples": {},
    }

    for name, path in SAMPLES.items():
        bgr = cv2.imread(str(path), cv2.IMREAD_COLOR)
        if bgr is None:
            raise FileNotFoundError(path)
        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
        rendered, metrics = algo.process_hardware_equivalent(rgb, params)
        rendered_path = output / f"{name}_s4_region_fill.png"
        cv2.imwrite(str(rendered_path), cv2.cvtColor(rendered, cv2.COLOR_RGB2BGR))
        report["samples"][name] = {
            "input": str(path.relative_to(ROOT)),
            "input_sha256": sha256(path),
            "output": str(rendered_path.relative_to(ROOT)),
            "output_sha256": sha256(rendered_path),
            "metrics": metrics,
        }

    report_path = output / "visual-review.json"
    report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"WROTE {report_path}")
    print(f"STATUS {report['status']}")


if __name__ == "__main__":
    main()
