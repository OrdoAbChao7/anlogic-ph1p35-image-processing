"""Evaluate FastestDet on a frozen, independent COCO val2017 subset."""
from __future__ import annotations

import argparse
import json
import statistics
import time
from pathlib import Path

import cv2

from fastestdet_runtime import FastestDet, TARGET_NAMES, draw

ROOT = Path(__file__).resolve().parent


def iou_xyxy(a: list[float], b: list[float]) -> float:
    x1, y1 = max(a[0], b[0]), max(a[1], b[1])
    x2, y2 = min(a[2], b[2]), min(a[3], b[3])
    inter = max(0, x2 - x1) * max(0, y2 - y1)
    area_a = max(0, a[2] - a[0]) * max(0, a[3] - a[1])
    area_b = max(0, b[2] - b[0]) * max(0, b[3] - b[1])
    return inter / max(area_a + area_b - inter, 1e-9)


def score_image(preds: list[dict], objects: list[dict]) -> dict[str, dict[str, int]]:
    counts = {name: {"tp": 0, "fp": 0, "fn": 0} for name in TARGET_NAMES}
    for name in TARGET_NAMES:
        gt, crowds = [], []
        for item in objects:
            if item["class"] != name:
                continue
            x, y, w, h = item["box"]
            (crowds if item.get("iscrowd", 0) else gt).append([x, y, x + w, y + h])
        used = set()
        for pred in sorted((p for p in preds if p["class"] == name),
                           key=lambda p: -p.get("confidence", 0)):
            matches = [(iou_xyxy(pred["box"], g), j) for j, g in enumerate(gt) if j not in used]
            overlap, index = max(matches, default=(0, -1))
            if overlap >= 0.5:
                used.add(index)
                counts[name]["tp"] += 1
            else:
                # COCO crowd matching uses intersection / detection area.
                # A crowd region can ignore multiple unmatched detections.
                a = pred["box"]
                area = max(0, a[2]-a[0]) * max(0, a[3]-a[1])
                covered = any(
                    max(0, min(a[2], c[2])-max(a[0], c[0])) *
                    max(0, min(a[3], c[3])-max(a[1], c[1])) / max(area, 1e-9) >= .5
                    for c in crowds)
                if not covered:
                    counts[name]["fp"] += 1
        counts[name]["fn"] += len(gt) - len(used)
    return counts


def run(threshold: float, sizes: list[int]) -> dict:
    manifest = json.loads((ROOT / "datasets" / "test_manifest.json").read_text(encoding="utf-8"))
    detector = FastestDet()
    output = {"model": "FastestDet COCO 80-class original",
              "split": "COCO val2017 independent subset",
              "threshold": threshold, "nms_iou": 0.45,
              "match_iou": 0.5, "sample_count": len(manifest),
              "resolutions": {}}
    result_dir = ROOT / "results"
    result_dir.mkdir(exist_ok=True)
    # Warm-up is excluded from timed results.
    warm = cv2.imread(str(ROOT / manifest[0]["file"]))
    detector.detect(warm, 352, threshold)
    for size in sizes:
        totals = {name: {"tp": 0, "fp": 0, "fn": 0} for name in TARGET_NAMES}
        forward_ms, total_ms, samples = [], [], []
        rendered = result_dir / f"annotated_{size}"
        if size == 352:
            rendered.mkdir(exist_ok=True)
        for item in manifest:
            image = cv2.imread(str(ROOT / item["file"]))
            start = time.perf_counter()
            detections, forward = detector.detect(image, size, threshold)
            total = (time.perf_counter() - start) * 1000
            counts = score_image(detections, item["objects"])
            for name in TARGET_NAMES:
                for metric in ("tp", "fp", "fn"):
                    totals[name][metric] += counts[name][metric]
            forward_ms.append(forward)
            total_ms.append(total)
            samples.append({"image_id": item["image_id"], "file": item["file"],
                            "ground_truth": item["objects"], "detections": detections,
                            "counts": counts, "forward_ms": round(forward, 3),
                            "total_ms": round(total, 3)})
            if size == 352:
                cv2.imwrite(str(rendered / Path(item["file"]).name), draw(image, detections))
        for name, c in totals.items():
            c["precision"] = round(c["tp"] / (c["tp"] + c["fp"]), 4) if c["tp"] + c["fp"] else 0
            c["recall"] = round(c["tp"] / (c["tp"] + c["fn"]), 4) if c["tp"] + c["fn"] else 0
        output["resolutions"][str(size)] = {
            "counts": totals, "forward_mean_ms": round(statistics.mean(forward_ms), 3),
            "forward_median_ms": round(statistics.median(forward_ms), 3),
            "total_mean_ms": round(statistics.mean(total_ms), 3),
            "samples": samples}
        print(size, totals, "forward mean ms", output["resolutions"][str(size)]["forward_mean_ms"])
    (result_dir / "evaluation.json").write_text(json.dumps(output, ensure_ascii=False, indent=2),
                                                 encoding="utf-8")
    return output


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--threshold", type=float, default=0.25)
    parser.add_argument("--sizes", type=int, nargs="+", default=[352, 160, 128, 96])
    args = parser.parse_args()
    run(args.threshold, args.sizes)
