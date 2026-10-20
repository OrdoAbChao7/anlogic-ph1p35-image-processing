"""Train the Y2 three-class micro detector from COCO public-data study split."""
from __future__ import annotations

import argparse
import json
import math
import random
from pathlib import Path

import cv2
import numpy as np
import torch
from torch import nn
from torch.utils.data import DataLoader, Dataset

from microdet import CLASSES, MicroDet

ROOT = Path(__file__).resolve().parent


class DetectionData(Dataset):
    def __init__(self, manifest: list[dict], size: int, augment: bool):
        self.items, self.size, self.augment = manifest, size, augment

    def __len__(self) -> int:
        return len(self.items)

    def __getitem__(self, index: int):
        item = self.items[index]
        image = cv2.imread(str(ROOT / item["file"]))
        if image is None:
            raise FileNotFoundError(item["file"])
        h, w = image.shape[:2]
        image = cv2.cvtColor(cv2.resize(image, (self.size, self.size)), cv2.COLOR_BGR2RGB)
        flip = self.augment and random.random() < .5
        if flip:
            image = cv2.flip(image, 1)
        if self.augment:
            factor = random.uniform(.75, 1.25)
            image = np.clip(image.astype(np.float32) * factor, 0, 255).astype(np.uint8)
        image = torch.from_numpy(image.copy()).permute(2, 0, 1).float().div_(255)
        gh = gw = self.size // 8
        target = torch.zeros((gh, gw, 8), dtype=torch.float32)
        collisions = 0
        for obj in item["objects"]:
            x, y, bw, bh = obj["box"]
            cx, cy = (x+bw/2)/w, (y+bh/2)/h
            if flip:
                cx = 1-cx
            cx, cy = min(max(cx, 1e-5), 1-1e-5), min(max(cy, 1e-5), 1-1e-5)
            gx, gy = min(int(cx*gw), gw-1), min(int(cy*gh), gh-1)
            if target[gy, gx, 4] > 0:
                collisions += 1
                # Keep larger target in a cell; other target is unrepresentable.
                if bw*bh <= target[gy, gx, 2]*target[gy, gx, 3]*w*h:
                    continue
            target[gy, gx, :4] = torch.tensor([cx*gw-gx, cy*gh-gy,
                                                 min(bw/w, 1), min(bh/h, 1)])
            target[gy, gx, 4] = 1
            target[gy, gx, 5:] = 0
            target[gy, gx, 5+CLASSES.index(obj["class"])] = 1
        return image, target.permute(2, 0, 1), collisions


def loss_fn(pred: torch.Tensor, target: torch.Tensor) -> tuple[torch.Tensor, dict]:
    pos = target[:, 4] > 0
    obj = nn.functional.binary_cross_entropy_with_logits(
        pred[:, 4], target[:, 4], reduction="none",
        pos_weight=pred.new_tensor(30.0))
    pos_obj = obj[pos].sum() / obj.numel()
    neg_obj = obj[~pos].sum() / obj.numel()
    if pos.any():
        # Cross entropy is defined only on occupied cells.
        cls_pred = pred[:, 5:].permute(0, 2, 3, 1)[pos]
        cls_gt = target[:, 5:].permute(0, 2, 3, 1)[pos].argmax(dim=-1)
        cls_loss = nn.functional.cross_entropy(cls_pred, cls_gt)
        box_pred = pred[:, :4].sigmoid().permute(0, 2, 3, 1)[pos]
        box_gt = target[:, :4].permute(0, 2, 3, 1)[pos]
        box_loss = nn.functional.smooth_l1_loss(box_pred, box_gt, beta=.05)
    else:
        cls_loss = pred.sum()*0
        box_loss = pred.sum()*0
    total = 5*(pos_obj + neg_obj) + cls_loss + 10*box_loss
    return total, {"obj_pos": float(pos_obj.detach()), "obj_neg": float(neg_obj.detach()),
                   "cls": float(cls_loss.detach()), "box": float(box_loss.detach())}


def train(size: int, epochs: int, batch: int, lr: float, init: str | None) -> None:
    random.seed(20261012)
    np.random.seed(20261012)
    torch.manual_seed(20261012)
    torch.set_num_threads(4)
    manifest = json.loads((ROOT / "data" / "manifest.json").read_text(encoding="utf-8"))
    loader = DataLoader(DetectionData(manifest["train"], size, True), batch_size=batch,
                        shuffle=True, num_workers=0)
    model = MicroDet()
    if init:
        model.load_state_dict(torch.load(init, map_location="cpu", weights_only=True))
    optimizer = torch.optim.AdamW(model.parameters(), lr=lr, weight_decay=1e-4)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=epochs)
    (ROOT / "checkpoints").mkdir(exist_ok=True)
    history = []
    for epoch in range(epochs):
        model.train()
        total, collisions = 0., 0
        for images, targets, collision in loader:
            optimizer.zero_grad(set_to_none=True)
            loss, _ = loss_fn(model(images), targets)
            loss.backward()
            optimizer.step()
            total += float(loss.detach())
            collisions += int(collision.sum())
        scheduler.step()
        row = {"epoch": epoch+1, "size": size, "loss": total/len(loader),
               "collision_annotations": collisions, "learning_rate": optimizer.param_groups[0]["lr"]}
        history.append(row)
        print(json.dumps(row), flush=True)
    model.eval()
    checkpoint = ROOT / "checkpoints" / f"microdet_{size}.pth"
    torch.save(model.state_dict(), checkpoint)
    (ROOT / "checkpoints" / f"history_{size}.json").write_text(
        json.dumps({"size": size, "epochs": epochs, "batch": batch, "init": init,
                    "seed": 20261012, "history": history}, indent=2), encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--size", type=int, choices=(96, 128, 160), required=True)
    parser.add_argument("--epochs", type=int, default=16)
    parser.add_argument("--batch", type=int, default=16)
    parser.add_argument("--lr", type=float, default=.002)
    parser.add_argument("--init")
    args = parser.parse_args()
    train(args.size, args.epochs, args.batch, args.lr, args.init)
