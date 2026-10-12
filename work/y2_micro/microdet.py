"""Small single-scale three-class detector used only for Y2 software study."""
from __future__ import annotations

import time

import cv2
import numpy as np
import torch
from torch import nn

CLASSES = ("bottle", "cup", "cell phone")


def conv_bn_relu(ci: int, co: int, stride: int = 1, groups: int = 1) -> nn.Sequential:
    return nn.Sequential(nn.Conv2d(ci, co, 3, stride, 1, groups=groups, bias=False),
                         nn.BatchNorm2d(co), nn.ReLU6(inplace=True))


class DepthwisePointwise(nn.Module):
    def __init__(self, ci: int, co: int, stride: int = 1):
        super().__init__()
        self.dw = conv_bn_relu(ci, ci, stride, groups=ci)
        self.pw = nn.Sequential(nn.Conv2d(ci, co, 1, bias=False),
                                nn.BatchNorm2d(co), nn.ReLU6(inplace=True))

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.pw(self.dw(x))


class MicroDet(nn.Module):
    """Stride-8 grid; per cell predicts xywh, objectness, and three classes."""
    def __init__(self):
        super().__init__()
        self.stem = conv_bn_relu(3, 12, 2)
        self.block1 = DepthwisePointwise(12, 20, 2)
        self.block2 = DepthwisePointwise(20, 32, 2)
        self.block3 = DepthwisePointwise(32, 48)
        self.block4 = DepthwisePointwise(48, 48)
        self.head = nn.Conv2d(48, 8, 1)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.head(self.block4(self.block3(self.block2(self.block1(self.stem(x))))))


def preprocess(image_bgr: np.ndarray, size: int) -> torch.Tensor:
    rgb = cv2.cvtColor(cv2.resize(image_bgr, (size, size)), cv2.COLOR_BGR2RGB)
    return torch.from_numpy(rgb.copy()).permute(2, 0, 1).float().div_(255)


def iou(a: list[float], b: list[float]) -> float:
    x0, y0 = max(a[0], b[0]), max(a[1], b[1])
    x1, y1 = min(a[2], b[2]), min(a[3], b[3])
    intersection = max(0., x1-x0) * max(0., y1-y0)
    aa = max(0., a[2]-a[0]) * max(0., a[3]-a[1])
    bb = max(0., b[2]-b[0]) * max(0., b[3]-b[1])
    return intersection / max(aa + bb - intersection, 1e-9)


def decode(output: torch.Tensor, width: int, height: int,
           threshold: float = .25, nms_iou: float = .45) -> list[dict]:
    """Decode model output in original-image pixel coordinates."""
    out = output.detach().cpu()[0]
    gh, gw = out.shape[1:]
    boxes = out[:4].sigmoid().numpy()
    objectness = out[4].sigmoid().numpy()
    classes = out[5:].softmax(dim=0).numpy()
    raw = []
    for yy in range(gh):
        for xx in range(gw):
            cls = int(classes[:, yy, xx].argmax())
            score = float(objectness[yy, xx] * classes[cls, yy, xx])
            if score < threshold:
                continue
            cx = (xx + float(boxes[0, yy, xx])) / gw * width
            cy = (yy + float(boxes[1, yy, xx])) / gh * height
            bw = float(boxes[2, yy, xx]) * width
            bh = float(boxes[3, yy, xx]) * height
            box = [max(0., cx-bw/2), max(0., cy-bh/2),
                   min(float(width), cx+bw/2), min(float(height), cy+bh/2)]
            raw.append({"class": CLASSES[cls], "confidence": score, "box": box})
    raw.sort(key=lambda x: x["confidence"], reverse=True)
    kept = []
    for candidate in raw:
        if all(candidate["class"] != old["class"] or
               iou(candidate["box"], old["box"]) < nms_iou for old in kept):
            kept.append(candidate)
    return kept


def detect(model: MicroDet, image_bgr: np.ndarray, size: int,
           threshold: float = .25) -> tuple[list[dict], float]:
    start = time.perf_counter()
    with torch.inference_mode():
        output = model(preprocess(image_bgr, size)[None])
    return decode(output, image_bgr.shape[1], image_bgr.shape[0], threshold), (time.perf_counter()-start)*1000


def draw(image: np.ndarray, detections: list[dict]) -> np.ndarray:
    result = image.copy()
    colors = {"bottle": (76, 198, 62), "cup": (241, 175, 60), "cell phone": (212, 81, 225)}
    for det in detections:
        x0, y0, x1, y1 = map(int, det["box"])
        color = colors[det["class"]]
        cv2.rectangle(result, (x0, y0), (x1, y1), color, 2)
        cv2.putText(result, f"{det['class']} {det['confidence']:.2f}", (x0, max(16, y0-4)),
                    cv2.FONT_HERSHEY_SIMPLEX, .5, color, 2)
    return result
