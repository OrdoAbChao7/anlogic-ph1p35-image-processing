"""Transparent theoretical PH1P35 budget from executed PyTorch Conv2d hooks."""
import csv
import json
import math
from pathlib import Path

ROOT=Path(__file__).resolve().parent
PROFILE=json.loads((ROOT/"results/profile/network_profile.json").read_text(encoding="utf-8"))
OUT=ROOT/"results/budget"
OUT.mkdir(parents=True,exist_ok=True)
ROWS=[]
for layer in PROFILE["layers"]:
    if layer["operator"]!="Conv2d":continue
    n,ci,hi,wi=layer["input"]
    _,co,ho,wo=layer["output"]
    kh,kw=layer["kernel"]
    group=layer["groups"]
    # Ideal work bound; channel/spatial tile overhead is computed for standard convolution only.
    ideal=math.ceil(layer["mac"]/16)
    if group==1:
        spatial=math.ceil(ho/26)*math.ceil(wo/26)
        channel=math.ceil(ci/4)*math.ceil(co/4)
        tile_cycles=spatial*channel*26*26*kh*kw
        tile_note="standard 4x4 tile; full edge tiles charged"
    else:
        tile_cycles=None
        tile_note="depthwise/grouped: 4x4 standard tile schedule invalid; mapping TBD"
    ROWS.append({"layer":layer["name"],"input":layer["input"],"output":layer["output"],
                 "kernel":layer["kernel"],"groups":group,"parameters_executed":layer["parameters"],
                 "mac":layer["mac"],"ideal_16mac_cycles":ideal,"ideal_16mac_ms_100mhz":ideal/100000,
                 "padded_tile_cycles":tile_cycles,"tile_note":tile_note,
                 "input_bytes_int8":n*ci*hi*wi,"output_bytes_int8":layer["output_bytes_int8"]})
with (OUT/"layer_budget.csv").open("w",newline="",encoding="utf-8") as f:
    writer=csv.DictWriter(f,fieldnames=list(ROWS[0]))
    writer.writeheader();writer.writerows(ROWS)
M=PROFILE["conv_mac_executed"]
summary={"assumptions":{"clock_mhz":100,"effective_mac_per_cycle":16,"goal_fps":30,
                         "tile":{"tn":4,"tm":4,"tr":26,"tc":26},"eram20k_bytes":2560,
                         "no_overhead_ideal_bound":True},
         "conv_calls":len(ROWS),"conv_mac":M,"unique_parameters":PROFILE["parameters_unique"],
         "ideal_16mac_ms":M/16/100000,"ideal_32mac_ms":M/32/100000,
         "ideal_16mac_fps":100e6*16/M,"required_mac_per_cycle_30fps":M*30/100e6,
         "weights_int8_bytes_no_quant_metadata":PROFILE["parameters_unique"],
         "weights_eram20k_blocks":math.ceil(PROFILE["parameters_unique"]/2560),
         "max_single_leaf_feature_int8_bytes":PROFILE["largest_single_feature_bytes_int8"],
         "max_single_leaf_feature_eram20k_blocks":math.ceil(PROFILE["largest_single_feature_bytes_int8"]/2560),
         "tile_3x3_pingpong_input_bytes":2*28*28*4,
         "tile_pingpong_int32_partial_bytes":2*26*26*4*4,
         "tile_pingpong_total_eram20k_blocks":math.ceil((2*28*28*4+2*26*26*4*4)/2560),
         "conv_input_output_bytes_if_every_conv_spills_to_ddr":sum(z["input_bytes_int8"]+z["output_bytes_int8"] for z in ROWS),
         "conv_spill_ddr_mb_per_sec_at_30fps":sum(z["input_bytes_int8"]+z["output_bytes_int8"] for z in ROWS)*30/1e6,
         "standard_conv_padded_tile_cycles_only":sum(z["padded_tile_cycles"] or 0 for z in ROWS),
         "depthwise_excluded_from_padded_tile_cycles":sum(z["groups"]>1 for z in ROWS)}
(OUT/"summary.json").write_text(json.dumps(summary,indent=2),encoding="utf-8")
print(json.dumps(summary,indent=2))
