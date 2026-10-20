"""Pinned YOLO-FastestV2 software study; no training or FPGA build."""
import argparse
import csv
import hashlib
import json
import math
import sys
import time
from collections import defaultdict
from pathlib import Path

import cv2
import numpy as np
import torch

ROOT = Path(__file__).resolve().parent
REPO = ROOT / "upstream" / "Yolo-FastestV2"
sys.path.insert(0, str(REPO))
from model.detector import Detector  # noqa: E402
from utils.utils import handel_preds, non_max_suppression  # noqa: E402

PROJECT = ROOT.parents[1]
WEIGHT = REPO / "modelzoo" / "coco2017-0.241078ap-model.pth"
EXPECTED_SHA = "bdd956aa079bf1cdd3e0090a295ac26d73c40aef7b61b6405981b1afcbea985c"
ANCHORS = [12.64, 19.39, 37.88, 51.48, 55.71, 138.31, 126.91, 78.23, 131.57, 214.55, 279.92, 258.87]
TARGET = {39: "bottle", 41: "cup", 67: "cell phone"}
COCO_IDS = {"bottle": 44, "cup": 47, "cell phone": 77}


def load_model():
    assert hashlib.sha256(WEIGHT.read_bytes()).hexdigest() == EXPECTED_SHA
    torch.set_num_threads(1)
    model = Detector(80, 3, True).eval()
    model.load_state_dict(torch.load(WEIGHT, map_location="cpu", weights_only=True))
    return model


def config(size):
    return {"width": size, "height": size, "classes": 80, "anchor_num": 3, "anchors": ANCHORS}


def infer(model, image, size=352, conf=.3, iou=.4):
    h, w = image.shape[:2]
    x = cv2.resize(image, (size, size), interpolation=cv2.INTER_LINEAR)
    x = torch.from_numpy(x.reshape(1, size, size, 3).transpose(0, 3, 1, 2)).float() / 255.0
    with torch.inference_mode():
        t0 = time.perf_counter()
        raw = model(x)
        t1 = time.perf_counter()
        decoded = handel_preds(raw, config(size), torch.device("cpu"))
        nms = non_max_suppression(decoded, conf_thres=conf, iou_thres=iou)[0]
        t2 = time.perf_counter()
    boxes = []
    for row in nms.cpu().tolist():
        x1, y1, x2, y2, score, cls = row
        boxes.append({"class": int(cls), "name": TARGET.get(int(cls), str(int(cls))),
                      "score": score, "box": [x1*w/size, y1*h/size, x2*w/size, y2*h/size]})
    return boxes, {"forward_ms": (t1-t0)*1000, "post_ms": (t2-t1)*1000,
                   "total_ms": (t2-t0)*1000, "raw_candidates": int(decoded.shape[1])}


def draw(img, boxes):
    out = img.copy()
    for b in boxes:
        if b["class"] not in TARGET:
            continue
        x1, y1, x2, y2 = [round(v) for v in b["box"]]
        cv2.rectangle(out, (x1, y1), (x2, y2), (0, 255, 255), 2)
        cv2.putText(out, f'{b["name"]} {b["score"]:.2f}', (x1, max(18, y1-5)),
                    cv2.FONT_HERSHEY_SIMPLEX, .55, (0, 255, 255), 2)
    return out


def iou(a, b):
    ix1, iy1, ix2, iy2 = max(a[0], b[0]), max(a[1], b[1]), min(a[2], b[2]), min(a[3], b[3])
    inter = max(0, ix2-ix1) * max(0, iy2-iy1)
    area = lambda v: max(0, v[2]-v[0])*max(0, v[3]-v[1])
    return inter / (area(a)+area(b)-inter+1e-9)


def evaluate(manifest, outdir, size, conf):
    model = load_model()
    outdir.mkdir(parents=True, exist_ok=True)
    for _ in range(3):
        infer(model, np.zeros((352, 352, 3), np.uint8), size)
    rows, preds, timings = [], [], []
    gt_count = defaultdict(int)
    for record in manifest:
        image_id = record["image_id"]
        source = Path(record["file"])
        if not source.is_absolute():
            source = PROJECT / source
        image = cv2.imread(str(source))
        if image is None:
            raise FileNotFoundError(source)
        boxes, timing = infer(model, image, size, conf)
        timings.append(timing)
        cv2.imwrite(str(outdir / f'{image_id:012d}.jpg'), draw(image, boxes))
        rows.append({"image_id": image_id, "source": str(source.relative_to(PROJECT)),
                     "all_80_class_detections": boxes, "timing": timing})
        for obj in record["objects"]:
            if not obj.get("iscrowd", 0):
                gt_count[obj["class"]] += 1
        preds.append((record, boxes))
    metrics = {}
    for name in COCO_IDS:
        ranked, matched, gt_total = [], {}, gt_count[name]
        for record, boxes in preds:
            image_id = record["image_id"]
            gts = []
            for obj in record["objects"]:
                if obj["class"] == name and not obj.get("iscrowd", 0):
                    x,y,w,h = obj["box"]
                    gts.append([x,y,x+w,y+h])
            matched[image_id] = set()
            for b in boxes:
                if b["name"] == name:
                    ranked.append((b["score"], image_id, b["box"], gts))
        ranked.sort(key=lambda x: -x[0])
        tp, fp, precision, recall = 0, 0, [], []
        for score, image_id, box, gts in ranked:
            choices = [(iou(box,g), j) for j,g in enumerate(gts) if j not in matched[image_id]]
            best = max(choices, default=(0,-1))
            if best[0] >= .5:
                tp += 1
                matched[image_id].add(best[1])
            else:
                fp += 1
            precision.append(tp/(tp+fp))
            recall.append(tp/gt_total if gt_total else 0)
        # Interpolated area under the precision-recall envelope.
        ap = 0.0
        if gt_total:
            r = [0.0] + recall + [1.0]
            pr = [0.0] + precision + [0.0]
            for j in range(len(pr)-2, -1, -1):
                pr[j] = max(pr[j], pr[j+1])
            ap = sum((r[j+1]-r[j])*pr[j+1] for j in range(len(r)-1))
        metrics[name] = {"gt": gt_total, "tp": tp, "fp": fp, "fn": gt_total-tp,
                         "precision": tp/(tp+fp) if tp+fp else 0,
                         "recall": tp/gt_total if gt_total else 0, "ap50": ap}
    summary = {"weights_sha256": EXPECTED_SHA, "input_size": size, "conf": conf, "iou": .4,
               "image_count": len(rows), "classes": metrics,
               "macro_ap50": sum(v["ap50"] for v in metrics.values())/3,
               "timing_ms": {k: {"median": float(np.median([t[k] for t in timings])),
                                 "p95": float(np.percentile([t[k] for t in timings],95))}
                             for k in ["forward_ms", "post_ms", "total_ms"]}}
    (outdir/"detections.json").write_text(json.dumps(rows, indent=2), encoding="utf-8")
    (outdir/"summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))


def profile(outdir):
    model = load_model()
    outdir.mkdir(parents=True, exist_ok=True)
    records = []
    handles = []
    def hook(name, module):
        def collect(mod, inp, output):
            tensor = output if isinstance(output, torch.Tensor) else output[0]
            entry = {"name": name, "operator": type(mod).__name__,
                     "input": list(inp[0].shape), "output": list(tensor.shape),
                     "parameters": sum(v.numel() for v in mod.parameters(recurse=False)),
                     "output_bytes_int8": tensor.numel(), "output_bytes_fp32": tensor.numel()*4}
            if isinstance(mod, torch.nn.Conv2d):
                n, co, h, w = tensor.shape
                kh, kw = mod.kernel_size
                entry.update({"kernel": [kh,kw], "stride": list(mod.stride), "groups": mod.groups,
                              "mac": n*co*h*w*(mod.in_channels//mod.groups)*kh*kw})
            records.append(entry)
        return collect
    for name, module in model.named_modules():
        if len(list(module.children())) == 0:
            handles.append(module.register_forward_hook(hook(name,module)))
    with torch.inference_mode():
        outputs = model(torch.zeros(1,3,352,352))
    for handle in handles:
        handle.remove()
    result = {"input": [1,3,352,352], "output_shapes": [list(x.shape) for x in outputs],
              "parameters_unique": sum(p.numel() for p in model.parameters()),
              "conv_mac_executed": sum(x.get("mac",0) for x in records),
              "largest_single_feature_bytes_int8": max(x["output_bytes_int8"] for x in records),
              "note": "Hooks list executed leaf modules; repeated shared heads appear twice. Single-feature maximum is not peak live memory.",
              "layers": records,
              "postprocessing": ["sigmoid xy/wh/objectness", "softmax 80 classes", "anchor/grid decode", "confidence filter", "class-offset IoU NMS"]}
    (outdir/"network_profile.json").write_text(json.dumps(result,indent=2),encoding="utf-8")
    with (outdir/"network_layers.csv").open("w",newline="",encoding="utf-8") as f:
        writer=csv.DictWriter(f,fieldnames=["name","operator","input","output","parameters","output_bytes_int8","output_bytes_fp32","kernel","stride","groups","mac"])
        writer.writeheader()
        for entry in records:
            writer.writerow(entry)
    print({k:v for k,v in result.items() if k!="layers"})


if __name__ == "__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("mode",choices=["profile","eval"])
    parser.add_argument("--manifest",type=Path)
    parser.add_argument("--out",type=Path,default=ROOT/"results"/"study")
    parser.add_argument("--size",type=int,default=352)
    parser.add_argument("--conf",type=float,default=.3)
    args=parser.parse_args()
    if args.mode=="profile": profile(args.out)
    else:
        if args.manifest is None: parser.error("--manifest required")
        evaluate(json.loads(args.manifest.read_text(encoding="utf-8")), args.out,args.size,args.conf)
