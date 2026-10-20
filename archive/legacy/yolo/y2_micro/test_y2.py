"""Checks for split leakage and detector behavior that would invalidate metrics."""
from __future__ import annotations

import json
from pathlib import Path

import torch

from evaluate import score
from microdet import MicroDet, decode
from train import loss_fn

ROOT = Path(__file__).resolve().parent


def main() -> None:
    manifest = json.loads((ROOT / "data" / "manifest.json").read_text(encoding="utf-8"))
    splits = [{x["image_id"] for x in manifest[name]}
              for name in ("train", "tune", "test", "dev_test")]
    assert sum(len(x) for x in splits) == len(set.union(*splits))
    assert [len(x) for x in splits] == [580, 120, 55, 29]

    # A detector that fires on every empty cell must pay a larger objectness loss.
    empty = torch.zeros(1, 8, 12, 12)
    quiet = torch.zeros_like(empty)
    loud = torch.zeros_like(empty)
    loud[:, 4] = 4
    assert loss_fn(loud, empty)[0] > loss_fn(quiet, empty)[0]

    output = torch.full((1, 8, 12, 12), -20.)
    output[0, :4, 2, 3] = 0
    output[0, 4, 2, 3] = 10
    output[0, 5, 2, 3] = 10
    detections = decode(output, 96, 96, .5)
    assert len(detections) == 1 and detections[0]["class"] == "bottle"
    counts = score(detections, [{"class": "bottle", "box": [4, 0, 48, 44]}])
    assert counts["bottle"]["tp"] == 1
    assert sum(p.numel() for p in MicroDet().parameters()) == 6988
    print("Y2 split, objectness, decode, matching: PASS")


if __name__ == "__main__":
    main()
