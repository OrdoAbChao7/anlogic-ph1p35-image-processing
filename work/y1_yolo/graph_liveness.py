"""Conservative INT8 activation liveness estimate from actual torch.export graph.

Every tensor-valued graph node is counted as a separate allocation, including
views that a hardware schedule might alias. Thus the result is an upper bound
for this graph execution order, not an optimized FPGA RAM requirement.
"""
from __future__ import annotations

import json
import sys

import torch

from fastestdet_runtime import ROOT, UPSTREAM

sys.path.insert(0, str(UPSTREAM))
from module.detector import Detector


def numel(value) -> int:
    if isinstance(value, torch.Tensor):
        return value.numel()
    if isinstance(value, (tuple, list)):
        return sum(numel(x) for x in value)
    return 0


def estimate(size: int) -> dict:
    model = Detector(80, True).eval()
    exported = torch.export.export(model, (torch.zeros(1, 3, size, size),))
    nodes = list(exported.graph_module.graph.nodes)
    remaining = {node: len(node.users) for node in nodes}
    allocations = {}
    live = peak = 0
    peak_node = ""
    for node in nodes:
        if node.op == "placeholder" and node.name != "x":
            continue  # weights/BN constants are budgeted separately
        size_bytes = numel(node.meta.get("val"))
        if size_bytes:
            allocations[node] = size_bytes
            live += size_bytes
            if live > peak:
                peak, peak_node = live, node.name
        for source in node.all_input_nodes:
            remaining[source] -= 1
            if remaining[source] == 0 and source in allocations:
                live -= allocations.pop(source)
    return {"resolution": size, "graph_nodes": len(nodes),
            "peak_graph_live_int8_bytes_conservative": peak,
            "peak_after_node": peak_node,
            "assumption": "Each tensor graph output uses separate INT8 storage, "
                          "even views; graph execution order fixed; parameter tensors excluded. "
                          "Does not include line buffers, DDR controller or NMS scratch."}


if __name__ == "__main__":
    values = {str(s): estimate(s) for s in (352, 160, 128, 96)}
    path = ROOT / "results" / "graph_liveness.json"
    path.write_text(json.dumps(values, indent=2), encoding="utf-8")
    for key, value in values.items():
        print(key, value["peak_graph_live_int8_bytes_conservative"],
              value["peak_after_node"])
