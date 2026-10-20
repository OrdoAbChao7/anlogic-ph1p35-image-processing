"""Exploratory threshold sweep on COCO128; never reports independent metrics."""
from __future__ import annotations

import json
from pathlib import Path

import cv2

from evaluate import score_image
from fastestdet_runtime import FastestDet, ROOT, TARGET_NAMES


def main() -> None:
    manifest = json.loads((ROOT / "datasets" / "tuning_manifest.json").read_text(encoding="utf-8"))
    detector = FastestDet()
    outputs = []
    for threshold in (0.15, 0.25, 0.40, 0.55, 0.65):
        totals = {name: {"tp": 0, "fp": 0, "fn": 0} for name in TARGET_NAMES}
        for item in manifest:
            image = cv2.imread(str(ROOT / item["file"]))
            detections, _ = detector.detect(image, 352, threshold)
            current = score_image(detections, item["objects"])
            for name in TARGET_NAMES:
                for key in ("tp", "fp", "fn"):
                    totals[name][key] += current[name][key]
        tp = sum(x["tp"] for x in totals.values())
        fp = sum(x["fp"] for x in totals.values())
        fn = sum(x["fn"] for x in totals.values())
        f1 = 2 * tp / max(2 * tp + fp + fn, 1)
        outputs.append({"threshold": threshold, "counts": totals, "micro_f1": round(f1, 4)})
    (ROOT / "results" / "tuning.json").write_text(json.dumps(outputs, indent=2), encoding="utf-8")
    print(outputs)


if __name__ == "__main__":
    main()
