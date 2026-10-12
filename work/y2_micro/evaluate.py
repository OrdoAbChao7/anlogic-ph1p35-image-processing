"""Freeze a tuning-set threshold, then evaluate new Y2 holdout IDs once."""
from __future__ import annotations

import argparse
import hashlib
import json
import statistics
import time
from pathlib import Path

import cv2
import torch

from microdet import CLASSES, MicroDet, decode, draw, iou, preprocess

ROOT = Path(__file__).resolve().parent
THRESHOLDS = (.005, .01, .02, .03, .05, .10, .15, .20, .25, .30, .40, .50)


def score(predictions: list[dict], objects: list[dict]) -> dict[str, dict[str, int]]:
    total = {name: {"tp": 0, "fp": 0, "fn": 0} for name in CLASSES}
    for name in CLASSES:
        truth = []
        for obj in objects:
            if obj["class"] == name:
                x, y, w, h = obj["box"]
                truth.append([x, y, x+w, y+h])
        used = set()
        for pred in (p for p in predictions if p["class"] == name):
            matches = [(iou(pred["box"], gt), index)
                       for index, gt in enumerate(truth) if index not in used]
            overlap, index = max(matches, default=(0., -1))
            if overlap >= .5:
                used.add(index)
                total[name]["tp"] += 1
            else:
                total[name]["fp"] += 1
        total[name]["fn"] += len(truth) - len(used)
    return total


def sum_counts(rows: list[dict]) -> dict:
    totals = {name: {"tp": 0, "fp": 0, "fn": 0} for name in CLASSES}
    for row in rows:
        for name in CLASSES:
            for key in ("tp", "fp", "fn"):
                totals[name][key] += row["counts"][name][key]
    for name in CLASSES:
        d = totals[name]
        d["precision"] = d["tp"] / max(d["tp"] + d["fp"], 1)
        d["recall"] = d["tp"] / max(d["tp"] + d["fn"], 1)
        d["f1"] = 2*d["precision"]*d["recall"] / max(d["precision"]+d["recall"], 1e-9)
    return totals


def collect(model: MicroDet, items: list[dict], size: int, split: str) -> list[dict]:
    outputs = []
    for item in items:
        path = ROOT / item["file"]
        image = cv2.imread(str(path))
        if image is None:
            raise FileNotFoundError(path)
        start = time.perf_counter()
        with torch.inference_mode():
            output = model(preprocess(image, size)[None]).detach().cpu()
        latency = (time.perf_counter() - start)*1000
        outputs.append({"item": item, "output": output,
                        "width": image.shape[1], "height": image.shape[0],
                        "latency_ms": latency, "path": path})
    return outputs


def evaluate_rows(outputs: list[dict], threshold: float, save_previews: bool = False,
                  size: int = 0) -> tuple[list[dict], dict]:
    rows = []
    preview = ROOT / "results" / "preview" / str(size)
    if save_previews:
        preview.mkdir(parents=True, exist_ok=True)
    for entry in outputs:
        preds = decode(entry["output"], entry["width"], entry["height"], threshold)
        item = entry["item"]
        counts = score(preds, item["objects"])
        row = {"image_id": item["image_id"], "file": item["file"],
               "objects": item["objects"], "predictions": preds, "counts": counts,
               "latency_ms": entry["latency_ms"]}
        rows.append(row)
        if save_previews:
            image = cv2.imread(str(entry["path"]))
            cv2.imwrite(str(preview / f"{item['image_id']}.jpg"), draw(image, preds))
    return rows, sum_counts(rows)


def run(size: int) -> dict:
    torch.set_num_threads(4)
    path = ROOT / "checkpoints" / f"microdet_{size}.pth"
    model = MicroDet().eval()
    model.load_state_dict(torch.load(path, map_location="cpu", weights_only=True))
    manifest = json.loads((ROOT / "data" / "manifest.json").read_text(encoding="utf-8"))
    # Exclude first warm-up from timings.
    model(preprocess(cv2.imread(str(ROOT / manifest["tune"][0]["file"])), size)[None])
    tuning = collect(model, manifest["tune"], size, "tune")
    sweep = []
    for threshold in THRESHOLDS:
        _, counts = evaluate_rows(tuning, threshold)
        macro_f1 = statistics.mean(counts[name]["f1"] for name in CLASSES)
        sweep.append({"threshold": threshold, "macro_f1": macro_f1, "counts": counts})
    chosen = max(sweep, key=lambda x: (x["macro_f1"], x["threshold"]))
    test = collect(model, manifest["test"], size, "test")
    samples, totals = evaluate_rows(test, chosen["threshold"], True, size)
    empty = [row for row in samples if not row["objects"]]
    result = {"model": "Y2 MicroDet three-class from scratch", "size": size,
              "checkpoint_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
              "threshold_rule": "maximize unweighted macro F1 on tuning split only; tie chooses higher threshold",
              "tuning": sweep, "chosen_threshold": chosen["threshold"],
              "test": {"count": len(samples), "totals": totals,
                       "empty_images": len(empty),
                       "empty_images_with_predictions": sum(bool(x["predictions"]) for x in empty),
                       "mean_latency_ms": statistics.mean(x["latency_ms"] for x in samples),
                       "median_latency_ms": statistics.median(x["latency_ms"] for x in samples),
                       "samples": samples}}
    out = ROOT / "results"
    out.mkdir(exist_ok=True)
    (out / f"evaluation_{size}.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps({"size": size, "threshold": chosen["threshold"],
                      "tune_macro_f1": chosen["macro_f1"],
                      "test_totals": totals, "latency_ms": result["test"]["mean_latency_ms"]}), flush=True)
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--size", type=int, choices=(96, 128, 160), required=True)
    args = parser.parse_args()
    run(args.size)
