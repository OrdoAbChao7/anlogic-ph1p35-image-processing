"""Calibrate static INT8 FX model and compare with FP32 on the frozen split."""
from __future__ import annotations

import argparse
import hashlib
import json
import statistics
from pathlib import Path

import cv2
import torch
from torch.ao.quantization import get_default_qconfig_mapping
from torch.ao.quantization.quantize_fx import convert_fx, prepare_fx

from evaluate import CLASSES, ROOT, THRESHOLDS, sum_counts
from microdet import MicroDet, preprocess


def run(size: int) -> dict:
    torch.set_num_threads(4)
    manifest = json.loads((ROOT / "data" / "manifest.json").read_text(encoding="utf-8"))
    path = ROOT / "checkpoints" / f"microdet_{size}.pth"
    model = MicroDet().eval()
    model.load_state_dict(torch.load(path, map_location="cpu", weights_only=True))
    example = (torch.rand(1, 3, size, size),)
    prepared = prepare_fx(model, get_default_qconfig_mapping("x86"), example)
    with torch.inference_mode():
        for item in manifest["tune"]:
            image = cv2.imread(str(ROOT / item["file"]))
            prepared(preprocess(image, size)[None])
    quantized = convert_fx(prepared).eval()
    quantized_modules = [name for name, module in quantized.named_modules()
                         if module.__class__.__module__.startswith("torch.ao.nn.quantized")]
    quant_layers = []
    for name, module in quantized.named_modules():
        if name not in quantized_modules or not hasattr(module, "weight"):
            continue
        weight = module.weight()
        bias = module.bias()
        quant_layers.append({"name": name, "weight_shape": list(weight.shape),
                             "weight_bytes": weight.numel(),
                             "weight_scheme": str(weight.qscheme()),
                             "weight_scale_count": (weight.q_per_channel_scales().numel()
                                                    if weight.qscheme() in (torch.per_channel_affine,
                                                                             torch.per_channel_symmetric) else 1),
                             "bias_fp32_bytes": 0 if bias is None else bias.numel()*4,
                             "output_scale": float(module.scale),
                             "output_zero_point": int(module.zero_point)})

    def collect(items: list[dict], split: str):
        rows = []
        for item in items:
            image = cv2.imread(str(ROOT / item["file"]))
            x = preprocess(image, size)[None]
            with torch.inference_mode():
                float_output = model(x)
                quant_output = quantized(x)
            rows.append({"item": item, "width": image.shape[1], "height": image.shape[0],
                         "float": float_output, "quant": quant_output,
                         "output_mae": float((float_output-quant_output).abs().mean())})
        return rows

    from microdet import decode

    def metrics(rows: list[dict], kind: str, threshold: float):
        scored = []
        for row in rows:
            preds = decode(row[kind], row["width"], row["height"], threshold)
            scored.append({"counts": __import__("evaluate").score(preds, row["item"]["objects"]),
                           "predictions": preds, "image_id": row["item"]["image_id"]})
        return scored, sum_counts(scored)

    tune = collect(manifest["tune"], "tune")
    sweep = []
    for threshold in THRESHOLDS:
        _, counts = metrics(tune, "quant", threshold)
        sweep.append({"threshold": threshold,
                      "macro_f1": statistics.mean(counts[name]["f1"] for name in CLASSES)})
    chosen = max(sweep, key=lambda x: (x["macro_f1"], x["threshold"]))
    test = collect(manifest["test"], "test")
    quant_samples, quant_counts = metrics(test, "quant", chosen["threshold"])
    _, float_counts = metrics(test, "float", chosen["threshold"])
    result = {"size": size, "checkpoint_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
              "quantization": "PyTorch FX static PTQ x86; calibrated on tuning split; output dequantized FP32",
              "quantized_modules": quantized_modules,
              "quantized_layers": quant_layers,
              "quantized_conv_weight_bytes": sum(x["weight_bytes"] for x in quant_layers),
              "quantized_bias_fp32_bytes": sum(x["bias_fp32_bytes"] for x in quant_layers),
              "tune_threshold_sweep": sweep, "chosen_threshold": chosen["threshold"],
              "test_quant_counts": quant_counts, "test_float_at_same_threshold": float_counts,
              "test_output_mean_absolute_error": statistics.mean(x["output_mae"] for x in test),
              "test_samples": quant_samples,
              "limitation": "x86 INT8 operators and scales are not hardware-equivalent PH1P35 arithmetic"}
    out = ROOT / "results"
    out.mkdir(exist_ok=True)
    (out / f"quantized_{size}.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps({"size": size, "threshold": chosen["threshold"],
                      "quant_counts": quant_counts,
                      "output_mae": result["test_output_mean_absolute_error"]}), flush=True)
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--size", type=int, choices=(96, 128, 160), required=True)
    args = parser.parse_args()
    run(args.size)
