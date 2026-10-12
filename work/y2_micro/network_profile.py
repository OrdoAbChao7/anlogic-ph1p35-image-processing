"""Profile actual MicroDet tensor shapes, convolution MACs, and storage bounds."""
from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path

import torch
from torch import nn

from microdet import MicroDet

ROOT = Path(__file__).resolve().parent


def profile(size: int) -> dict:
    model = MicroDet().eval()
    checkpoint = ROOT / "checkpoints" / f"microdet_{size}.pth"
    if checkpoint.exists():
        model.load_state_dict(torch.load(checkpoint, map_location="cpu", weights_only=True))
    rows = []
    handles = []

    def hook(name):
        def record(module, inputs, output):
            x = inputs[0]
            params = sum(p.numel() for p in module.parameters(recurse=False))
            mac = 0
            if isinstance(module, nn.Conv2d):
                mac = (output.shape[2]*output.shape[3]*module.out_channels*
                       (module.in_channels//module.groups)*
                       module.kernel_size[0]*module.kernel_size[1])
            rows.append({"name": name, "type": module.__class__.__name__,
                         "input": list(x.shape), "output": list(output.shape),
                         "kernel": list(module.kernel_size) if isinstance(module, nn.Conv2d) else None,
                         "stride": list(module.stride) if isinstance(module, nn.Conv2d) else None,
                         "groups": module.groups if isinstance(module, nn.Conv2d) else None,
                         "parameters": params, "mac": mac,
                         "input_int8_bytes": x.numel(), "output_int8_bytes": output.numel(),
                         "input_plus_output_bytes": x.numel()+output.numel()})
        return record

    for name, module in model.named_modules():
        if isinstance(module, (nn.Conv2d, nn.BatchNorm2d, nn.ReLU6)):
            handles.append(module.register_forward_hook(hook(name)))
    with torch.inference_mode():
        model(torch.zeros(1, 3, size, size))
    for handle in handles:
        handle.remove()
    conv = [r for r in rows if r["type"] == "Conv2d"]
    result = {"size": size, "parameters": sum(p.numel() for p in model.parameters()),
              "checkpoint_sha256": hashlib.sha256(checkpoint.read_bytes()).hexdigest() if checkpoint.exists() else None,
              "conv_parameters": sum(r["parameters"] for r in conv),
              "conv_mac_per_frame": sum(r["mac"] for r in conv),
              "peak_adjacent_input_output_bytes": max(r["input_plus_output_bytes"] for r in rows),
              "largest_single_feature_bytes": max(r["output_int8_bytes"] for r in rows),
              "32_dsp_100mhz_one_mac_per_cycle_lower_bound_ms":
              sum(r["mac"] for r in conv)/32/100_000_000*1000,
              "layers": rows,
              "memory_assumption": "INT8 bytes, adjacent layer input+output only; no video buffers, line buffers, NMS, scales, or parallel branch overhead"}
    out = ROOT / "results"
    out.mkdir(exist_ok=True)
    (out / f"profile_{size}.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    with (out / f"layers_{size}.csv").open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    return result


if __name__ == "__main__":
    for size in (96, 128, 160):
        r = profile(size)
        print({k: r[k] for k in ("size", "parameters", "conv_mac_per_frame",
                                  "peak_adjacent_input_output_bytes",
                                  "32_dsp_100mhz_one_mac_per_cycle_lower_bound_ms")})
