"""Build a deterministic Y1 dataset; no model training occurs here."""
from __future__ import annotations

import hashlib
import json
import random
import urllib.request
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DATA = ROOT / "datasets"
ANNOTATIONS = DATA / "instances_val2017.json"
OUT = DATA / "val_subset"
SOURCE = "https://huggingface.co/datasets/merve/coco/resolve/main/val2017"
TARGET = {44: "bottle", 47: "cup", 77: "cell phone"}


def main() -> None:
    coco = json.loads(ANNOTATIONS.read_text(encoding="utf-8"))
    images = {im["id"]: im for im in coco["images"]}
    by_image = defaultdict(list)
    for ann in coco["annotations"]:
        if ann["category_id"] in TARGET and not ann.get("iscrowd", 0):
            by_image[ann["image_id"]].append(ann)
    rng = random.Random(20261012)
    selected = set()
    # Draw from independent COCO val2017, without looking at predictions.
    for category in TARGET:
        eligible = [i for i, anns in by_image.items()
                    if any(a["category_id"] == category for a in anns)]
        rng.shuffle(eligible)
        selected.update(eligible[:8])
    negatives = [i for i in images if i not in by_image]
    rng.shuffle(negatives)
    selected.update(negatives[:5])
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = []
    for image_id in sorted(selected):
        info = images[image_id]
        filename = info["file_name"]
        dest = OUT / filename
        if not dest.exists():
            urllib.request.urlretrieve(f"{SOURCE}/{filename}", dest)
        digest = hashlib.sha256(dest.read_bytes()).hexdigest()
        manifest.append({
            "split": "independent_test",
            "source_split": "COCO val2017",
            "image_id": image_id,
            "file": str(dest.relative_to(ROOT)).replace("\\", "/"),
            "sha256": digest,
            "width": info["width"], "height": info["height"],
            "objects": [{"class": TARGET[a["category_id"]],
                         "box": [round(float(v), 2) for v in a["bbox"]]}
                        for a in by_image.get(image_id, [])],
        })
    (DATA / "test_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    # COCO128 comes from COCO train2017 and may overlap the official model's
    # pretraining. It is reserved for exploratory threshold tuning only.
    tuning = []
    tune_images = DATA / "coco128" / "images" / "train2017"
    tune_labels = DATA / "coco128" / "labels" / "train2017"
    wanted = {39: "bottle", 41: "cup", 67: "cell phone"}
    chosen = set()
    for category in wanted:
        candidates = sorted(p for p in tune_labels.glob("*.txt")
                            if any(int(line.split()[0]) == category
                                   for line in p.read_text().splitlines()))
        chosen.update(p.stem for p in candidates[:3])
    for stem in sorted(chosen):
        image_path = tune_images / f"{stem}.jpg"
        if not image_path.exists():
            continue
        import cv2
        image = cv2.imread(str(image_path))
        h, w = image.shape[:2]
        objects = []
        for line in (tune_labels / f"{stem}.txt").read_text().splitlines():
            fields = line.split()
            category = int(fields[0])
            if category not in wanted:
                continue
            cx, cy, bw, bh = map(float, fields[1:5])
            objects.append({"class": wanted[category],
                            "box": [round((cx-bw/2)*w, 2), round((cy-bh/2)*h, 2),
                                    round(bw*w, 2), round(bh*h, 2)]})
        tuning.append({"split": "tuning_only_possible_pretrain_overlap",
                       "image_id": int(stem), "file": str(image_path.relative_to(ROOT)).replace("\\", "/"),
                       "sha256": hashlib.sha256(image_path.read_bytes()).hexdigest(),
                       "width": w, "height": h, "objects": objects})
    (DATA / "tuning_manifest.json").write_text(
        json.dumps(tuning, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print("independent_test images", len(manifest))
    print("tuning_only images", len(tuning), "training images", 0)
    print("objects", {name: sum(o["class"] == name for m in manifest
                                for o in m["objects"]) for name in TARGET.values()})


if __name__ == "__main__":
    main()
