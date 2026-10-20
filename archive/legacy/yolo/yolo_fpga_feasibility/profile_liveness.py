"""Conservative graph-tensor liveness at fixed 352 input (not physical RAM allocation)."""
import json
from pathlib import Path
import torch
from run_study import ROOT, load_model

torch.set_num_threads(1)
model=load_model()
graph=torch.export.export(model,(torch.zeros(1,3,352,352),)).graph
nodes=list(graph.nodes)
users={node:len(node.users) for node in nodes}
live={}
peak=0
peak_at=""
record=[]


def nbytes(node):
    val=node.meta.get("val")
    if not isinstance(val,torch.Tensor):return 0
    return val.numel()  # hypothetical INT8 activation bytes


for node in nodes:
    # Exported parameter/buffer placeholders are not counted as activation memory.
    size=nbytes(node) if node.op not in ("placeholder","output") else 0
    if size:live[node]=size
    current=sum(live.values())
    if current>peak:peak,peak_at=current,node.name
    for used in node.all_input_nodes:
        users[used]-=1
        if users[used]==0:live.pop(used,None)
    record.append({"node":node.name,"operator":str(node.target),"new_bytes":size,
                   "live_after_free_bytes":sum(live.values())})

result={"graph_nodes":len(nodes),"peak_graph_tensor_int8_bytes":peak,
        "peak_at_node":peak_at,
        "warning":"Conservative tensor liveness: views/aliases counted as materialized, params excluded; actual hardware can fuse, tile, or spill to DDR. Not a BRAM allocation.",
        "records":record}
out=ROOT/"results/profile/graph_liveness.json"
out.write_text(json.dumps(result,indent=2),encoding="utf-8")
print({k:v for k,v in result.items() if k!="records"})
