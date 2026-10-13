"""Run upstream test.py unchanged on three fixed COCO val2017 images."""
import hashlib
import json
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

ROOT=Path(__file__).resolve().parent
PROJECT=ROOT.parents[1]
REPO=ROOT/"upstream/Yolo-FastestV2"
OUT=ROOT/"results/official"
OUT.mkdir(parents=True,exist_ok=True)
COCO=json.loads((PROJECT/"work/y1_yolo/datasets/instances_val2017.json").read_text(encoding="utf-8"))
images={x["id"]:x for x in COCO["images"]}
expected=json.loads((ROOT/"data/official_smoke_sha256.json").read_text(encoding="utf-8"))
rows=[]
for image_id in (120777,563882,119233):
    meta=images[image_id]
    source=PROJECT/"work/y1_yolo/datasets/val_subset"/meta["file_name"]
    source.parent.mkdir(parents=True,exist_ok=True)
    if not source.exists():
        url="https://huggingface.co/datasets/merve/coco/resolve/main/val2017/"+meta["file_name"]
        with urllib.request.urlopen(url,timeout=30) as response:source.write_bytes(response.read())
    actual=hashlib.sha256(source.read_bytes()).hexdigest()
    if actual!=expected[str(image_id)]:raise RuntimeError(f"official image {image_id} sha256 mismatch")
    output=REPO/"test_result.png"
    if output.exists():raise RuntimeError(f"upstream output exists; do not overwrite: {output}")
    cmd=[sys.executable,"test.py","--data","data/coco.data","--weights","modelzoo/coco2017-0.241078ap-model.pth","--img",str(source)]
    proc=subprocess.run(cmd,cwd=REPO,capture_output=True,text=True)
    (OUT/f"{image_id}.log").write_text(" ".join(cmd)+"\n"+proc.stdout+proc.stderr,encoding="utf-8")
    if proc.returncode or not output.exists():raise RuntimeError(f"official test failed for {image_id}: {proc.returncode}")
    shutil.move(str(output),str(OUT/f"{image_id}.png"))
    rows.append({"image_id":image_id,"coco_file_name":meta["file_name"],
                 "width":meta["width"],"height":meta["height"],
                 "source_sha256":actual,
                 "target_annotations":[{"category_id":a["category_id"],"bbox":a["bbox"]}
                    for a in COCO["annotations"] if a["image_id"]==image_id and a["category_id"] in (44,47,77)]})
(OUT/"source_metadata.json").write_text(json.dumps(rows,indent=2),encoding="utf-8")
print(f"Official test.py PASS: {len(rows)} images")
