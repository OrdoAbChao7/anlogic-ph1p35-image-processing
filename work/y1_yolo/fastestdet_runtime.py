"""Reproduce the unmodified 80-class FastestDet COCO checkpoint on Windows.

Only the displayed results are filtered to bottle, cup and cell phone.
The upstream checkpoint is extracted from Git without checking out its
Windows-invalid ':' filename; see prepare_sources.py.
"""
from __future__ import annotations

import importlib.util
import sys
import time
from pathlib import Path

import cv2
import numpy as np

ROOT = Path(__file__).resolve().parent
UPSTREAM = ROOT / "FastestDet"
MODEL = UPSTREAM / "example" / "onnx-runtime" / "FastestDet.onnx"
WEIGHTS = UPSTREAM / "weights" / "fastestdet_coco_safe.pth"
NAMES = (UPSTREAM / "example" / "onnx-runtime" / "coco.names").read_text(
    encoding="utf-8"
).splitlines()
TARGET_NAMES = ("bottle", "cup", "cell phone")
TARGET_IDS = {NAMES.index(name) for name in TARGET_NAMES}


def _nms(boxes: np.ndarray, scores: np.ndarray, iou_limit: float) -> list[int]:
    order = np.argsort(-scores)
    keep: list[int] = []
    while len(order):
        i = int(order[0])
        keep.append(i)
        if len(order) == 1:
            break
        rest = order[1:]
        xx1 = np.maximum(boxes[i, 0], boxes[rest, 0])
        yy1 = np.maximum(boxes[i, 1], boxes[rest, 1])
        xx2 = np.minimum(boxes[i, 2], boxes[rest, 2])
        yy2 = np.minimum(boxes[i, 3], boxes[rest, 3])
        overlap = np.maximum(0, xx2 - xx1) * np.maximum(0, yy2 - yy1)
        area_i = max(0, boxes[i, 2] - boxes[i, 0]) * max(0, boxes[i, 3] - boxes[i, 1])
        area_r = np.maximum(0, boxes[rest, 2] - boxes[rest, 0]) * np.maximum(
            0, boxes[rest, 3] - boxes[rest, 1]
        )
        iou = overlap / np.maximum(area_i + area_r - overlap, 1e-9)
        order = rest[iou <= iou_limit]
    return keep


def decode(prediction: np.ndarray, image_shape: tuple[int, ...],
           threshold: float = 0.25, nms_iou: float = 0.45,
           target_only: bool = True) -> list[dict]:
    """Decode upstream [obj, xywh, 80 class probabilities] head output."""
    if prediction.ndim == 4:
        prediction = prediction[0]
    _, gh, gw = prediction.shape
    cells = prediction.transpose(1, 2, 0)
    cls = cells[..., 5:].argmax(axis=-1)
    cls_score = cells[..., 5:].max(axis=-1)
    score = cells[..., 0] ** 0.6 * cls_score ** 0.4
    selected = np.isin(cls, list(TARGET_IDS)) if target_only else np.ones_like(cls, dtype=bool)
    ys, xs = np.where((score >= threshold) & selected)
    if not len(xs):
        return []
    raw = cells[ys, xs, 1:5]
    center_x = (xs + np.tanh(raw[:, 0])) / gw
    center_y = (ys + np.tanh(raw[:, 1])) / gh
    width = 1 / (1 + np.exp(-raw[:, 2]))
    height = 1 / (1 + np.exp(-raw[:, 3]))
    h, w = image_shape[:2]
    boxes = np.stack(((center_x - width / 2) * w,
                      (center_y - height / 2) * h,
                      (center_x + width / 2) * w,
                      (center_y + height / 2) * h), axis=1)
    boxes[:, [0, 2]] = np.clip(boxes[:, [0, 2]], 0, w)
    boxes[:, [1, 3]] = np.clip(boxes[:, [1, 3]], 0, h)
    classes = cls[ys, xs]
    scores = score[ys, xs]
    result = []
    # Per-class NMS matches upstream PyTorch batched_nms, unlike its
    # standalone ONNX example's class-agnostic NMS.
    for class_id in sorted(set(classes.tolist())):
        indexes = np.where(classes == class_id)[0]
        for j in _nms(boxes[indexes], scores[indexes], nms_iou):
            k = int(indexes[j])
            result.append({"class_id": int(class_id), "class": NAMES[class_id],
                           "confidence": round(float(scores[k]), 6),
                           "box": [round(float(x), 2) for x in boxes[k]]})
    return sorted(result, key=lambda item: -item["confidence"])


class FastestDet:
    def __init__(self, backend: str = "torch"):
        self.backend = backend
        if backend == "onnx":
            import onnxruntime as ort
            self.model = ort.InferenceSession(str(MODEL),
                                              providers=["CPUExecutionProvider"])
            self.input_name = self.model.get_inputs()[0].name
        elif backend == "torch":
            import torch
            sys.path.insert(0, str(UPSTREAM))
            from module.detector import Detector
            torch.set_num_threads(min(4, torch.get_num_threads()))
            self.model = Detector(80, True)
            state = torch.load(WEIGHTS, map_location="cpu", weights_only=True)
            self.model.load_state_dict(state, strict=True)
            self.model.eval()
            self.torch = torch
        else:
            raise ValueError(backend)

    def detect(self, bgr: np.ndarray, size: int = 352,
               threshold: float = 0.25, nms_iou: float = 0.45,
               target_only: bool = True) -> tuple[list[dict], float]:
        if size not in (352, 160, 128, 96):
            raise ValueError("size must be 352, 160, 128 or 96")
        if self.backend == "onnx" and size != 352:
            raise ValueError("official ONNX graph has fixed 352x352 input")
        # OpenCV BGR and direct resize mirror upstream test.py.
        resized = cv2.resize(bgr, (size, size), interpolation=cv2.INTER_LINEAR)
        data = resized.transpose(2, 0, 1)[None].astype(np.float32) / 255.0
        start = time.perf_counter()
        if self.backend == "onnx":
            output = self.model.run(None, {self.input_name: data})[0]
        else:
            with self.torch.inference_mode():
                output = self.model(self.torch.from_numpy(data)).numpy()
        elapsed_ms = (time.perf_counter() - start) * 1000
        return decode(output, bgr.shape, threshold, nms_iou, target_only), elapsed_ms


def draw(bgr: np.ndarray, detections: list[dict]) -> np.ndarray:
    out = bgr.copy()
    colors = {"bottle": (0, 180, 255), "cup": (80, 220, 80),
              "cell phone": (255, 130, 100)}
    for item in detections:
        x1, y1, x2, y2 = (int(x) for x in item["box"])
        color = colors.get(item["class"], (180, 180, 0))
        cv2.rectangle(out, (x1, y1), (x2, y2), color, 2)
        cv2.putText(out, f'{item["class"]} {item["confidence"]:.2f}',
                    (x1, max(16, y1 - 5)), cv2.FONT_HERSHEY_SIMPLEX,
                    0.55, color, 2)
    return out
