"""Profile the actual FastestDet PyTorch checkpoint layer by layer."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import torch
from torch import nn

from fastestdet_runtime import ROOT, UPSTREAM, WEIGHTS

sys.path.insert(0, str(UPSTREAM))
from module.detector import Detector


def profile(size: int) -> dict:
    torch.set_num_threads(min(4, torch.get_num_threads()))
    model = Detector(80, True)
    model.load_state_dict(torch.load(WEIGHTS, map_location="cpu", weights_only=True),
                          strict=True)
    model.eval()
    rows = []
    hooks = []
    interesting = (nn.Conv2d, nn.BatchNorm2d, nn.ReLU, nn.MaxPool2d,
                   nn.AvgPool2d, nn.Upsample, nn.Sigmoid, nn.Softmax)

    def hook(name: str):
        def record(module, inputs, output):
            if not isinstance(output, torch.Tensor):
                return
            inp = inputs[0]
            shape_in, shape_out = list(inp.shape), list(output.shape)
            params = sum(p.numel() for p in module.parameters(recurse=False))
            mac = 0
            if isinstance(module, nn.Conv2d):
                n, cout, h, w = shape_out
                kh, kw = module.kernel_size
                mac = n * cout * h * w * (module.in_channels // module.groups) * kh * kw
            rows.append({"layer": name, "op": type(module).__name__,
                         "input": shape_in, "output": shape_out,
                         "kernel": list(module.kernel_size) if isinstance(module, nn.Conv2d) else None,
                         "stride": list(module.stride) if isinstance(module, nn.Conv2d) else None,
                         "groups": module.groups if isinstance(module, nn.Conv2d) else None,
                         "params": params, "mac": mac,
                         "activation_int8_bytes": output.numel()})
        return record

    for name, module in model.named_modules():
        if isinstance(module, interesting):
            hooks.append(module.register_forward_hook(hook(name)))
    with torch.inference_mode():
        output = model(torch.zeros(1, 3, size, size))
    for handle in hooks:
        handle.remove()
    return {"resolution": size, "input": [1, 3, size, size],
            "output": list(output.shape),
            "parameter_count": sum(p.numel() for p in model.parameters()),
            "int8_weight_bytes_unpacked": sum(p.numel() for p in model.parameters()),
            "conv_mac": sum(r["mac"] for r in rows),
            "largest_single_activation_int8_bytes": max(r["activation_int8_bytes"] for r in rows),
            "largest_single_activation_layer": max(rows, key=lambda r: r["activation_int8_bytes"])["layer"],
            "layers": rows,
            "functional_ops_not_hooked": [
                "ShuffleV2Block.channel_shuffle: reshape+permute+split",
                "ShuffleV2Block/Detector: concat",
                "SPP: residual add and 3-way concat",
                "DetectHead: sigmoid, softmax, output concat",
                "postprocess: power-score, tanh offsets, sigmoid size, class argmax, per-class NMS"
            ],
            "memory_note": "Largest single activation is a lower bound on live feature memory; "
                           "skip branches, concatenation and line buffers make the real peak larger."}


if __name__ == "__main__":
    data = {str(size): profile(size) for size in (352, 160, 128, 96)}
    dest = ROOT / "results"
    dest.mkdir(exist_ok=True)
    (dest / "network_profile.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    for size, x in data.items():
        print(size, x["output"], "params", x["parameter_count"],
              "MAC", x["conv_mac"], "largest activation", x["largest_single_activation_int8_bytes"])
