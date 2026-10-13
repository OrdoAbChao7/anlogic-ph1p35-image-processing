"""Fetch frozen public COCO val2017 sample and verify recorded bytes."""
import hashlib
import json
import urllib.request
from pathlib import Path

ROOT=Path(__file__).resolve().parent
PROJECT=ROOT.parents[1]
manifest=json.loads((ROOT/"data/frozen_eval_manifest.json").read_text(encoding="utf-8"))
hashes=json.loads((ROOT/"data/image_sha256.json").read_text(encoding="utf-8"))
for row in manifest:
    dest=PROJECT/row["file"]
    dest.parent.mkdir(parents=True,exist_ok=True)
    key=str(row["image_id"])
    if not dest.exists():
        url="https://huggingface.co/datasets/merve/coco/resolve/main/val2017/"+dest.name
        with urllib.request.urlopen(url,timeout=30) as response:
            dest.write_bytes(response.read())
    actual=hashlib.sha256(dest.read_bytes()).hexdigest()
    if actual!=hashes[key]:
        raise RuntimeError(f"image {key} sha256 mismatch: {actual}")
print(f"Verified {len(manifest)} COCO val2017 images")
