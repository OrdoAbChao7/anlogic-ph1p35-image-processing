"""Create a reproducible COCO val2017 software-study split for Y2.

The existing Y1 test IDs remain frozen. COCO does not carry workbench/session IDs,
so this public-data split does not satisfy the final workstation-scene gate.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import random
import urllib.request
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

ROOT = Path(__file__).resolve().parent
Y1 = ROOT.parent / "y1_yolo" / "datasets"
CAT_IDS = {44: "bottle", 47: "cup", 77: "cell phone"}
SEED = 20261012
ANNOTATION_SHA256 = "e8c7f7908f1d7278341fae127d0da654f102f11bd7b21d8aeefa635b8c810b6f"
TEST_SHA256 = "6680c8d76abfe9b21b25b9b607d47e29f2f06bf6f91eaa88ab679652ef4b9c50"


def make_manifest(train_positive: int = 480, tune_positive: int = 100,
                  train_negative: int = 100, tune_negative: int = 20) -> dict:
    annotation_hash = hashlib.sha256((Y1 / "instances_val2017.json").read_bytes()).hexdigest()
    test_hash = hashlib.sha256((Y1 / "test_manifest.json").read_bytes()).hexdigest()
    if annotation_hash != ANNOTATION_SHA256 or test_hash != TEST_SHA256:
        raise RuntimeError("Y1 annotation or frozen test manifest hash changed")
    source = json.loads((Y1 / "instances_val2017.json").read_text(encoding="utf-8"))
    fixed = json.loads((Y1 / "test_manifest.json").read_text(encoding="utf-8"))
    excluded = {int(x["image_id"]) for x in fixed}
    images = {x["id"]: x for x in source["images"]}
    objects: dict[int, list[dict]] = defaultdict(list)
    for ann in source["annotations"]:
        if ann["category_id"] in CAT_IDS and not ann["iscrowd"]:
            objects[ann["image_id"]].append({"class": CAT_IDS[ann["category_id"]],
                                              "box": ann["bbox"]})
    rng = random.Random(SEED)
    positive = sorted(set(objects) - excluded)
    negative = sorted(set(images) - set(objects) - excluded)
    rng.shuffle(positive)
    rng.shuffle(negative)
    assert len(positive) >= train_positive + tune_positive
    assert len(negative) >= train_negative + tune_negative

    def records(ids: list[int]) -> list[dict]:
        return [{"image_id": i, "file": f"data/images/{images[i]['file_name']}",
                 "width": images[i]["width"], "height": images[i]["height"],
                 "objects": objects[i]} for i in sorted(ids)]

    train = records(positive[:train_positive] + negative[:train_negative])
    tune = records(positive[train_positive:train_positive + tune_positive]
                   + negative[train_negative:train_negative + tune_negative])
    # Old Y1 test images have already informed model debugging, so they are
    # retained only as development diagnostics, never as the Y2 final holdout.
    dev_test = [{"image_id": int(x["image_id"]), "file": x["file"],
                 "objects": x["objects"]} for x in fixed]
    remaining = positive[train_positive + tune_positive:]
    holdout: list[int] = []
    for class_name in CAT_IDS.values():
        have = sum(any(obj["class"] == class_name for obj in objects[i]) for i in holdout)
        for image_id in remaining:
            if have >= 15:
                break
            if image_id not in holdout and any(obj["class"] == class_name for obj in objects[image_id]):
                holdout.append(image_id)
                have += 1
        if have < 15:
            raise RuntimeError(f"Insufficient remaining images for {class_name}")
    for image_id in remaining:
        if len(holdout) >= 45:
            break
        if image_id not in holdout:
            holdout.append(image_id)
    test = records(holdout + negative[train_negative + tune_negative:
                                       train_negative + tune_negative + 10])
    assert len({x["image_id"] for x in train + tune + test + dev_test}) == len(train + tune + test + dev_test)
    return {"seed": SEED, "source": "COCO val2017; COCO annotations CC BY 4.0; images retain original licenses",
            "source_annotation_sha256": annotation_hash,
            "split_limit": "Image-ID isolation only; no session/scene metadata or workstation images",
            "train": train, "tune": tune, "test": test, "dev_test": dev_test}


def download_one(item: dict) -> tuple[str, str]:
    path = ROOT / item["file"]
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists() or path.stat().st_size == 0:
        url = "https://huggingface.co/datasets/merve/coco/resolve/main/val2017/" + path.name
        for attempt in range(3):
            try:
                urllib.request.urlretrieve(url, path)
                break
            except Exception:
                path.unlink(missing_ok=True)
                if attempt == 2:
                    raise
    return path.name, hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workers", type=int, default=8)
    parser.add_argument("--manifest-only", action="store_true")
    args = parser.parse_args()
    manifest = make_manifest()
    (ROOT / "data").mkdir(exist_ok=True)
    output = ROOT / "data" / "manifest.json"
    output.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print({key: len(manifest[key]) for key in ("train", "tune", "test", "dev_test")}, flush=True)
    if args.manifest_only:
        return
    jobs = manifest["train"] + manifest["tune"] + manifest["test"]
    hash_path = ROOT / "data" / "image_sha256.json"
    expected_hashes = json.loads(hash_path.read_text(encoding="utf-8")) if hash_path.exists() else {}
    hashes = {}
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        for i, future in enumerate(as_completed([pool.submit(download_one, x) for x in jobs]), 1):
            name, sha = future.result()
            if name in expected_hashes and expected_hashes[name] != sha:
                raise RuntimeError(f"Image content changed: {name}")
            hashes[name] = sha
            if i % 50 == 0 or i == len(jobs):
                print(f"downloaded {i}/{len(jobs)}", flush=True)
    hash_path.write_text(
        json.dumps(hashes, sort_keys=True, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
