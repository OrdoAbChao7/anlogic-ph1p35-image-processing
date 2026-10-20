"""Freeze local YOLOv8m and export an auditable static FP32 ONNX graph."""
from pathlib import Path
import copy, csv, hashlib, json, importlib.metadata as md
from collections import Counter
import numpy as np
import cv2
import torch
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'models'/'deps'))
import onnx
import onnxruntime as ort
from onnx import numpy_helper
from ultralytics import YOLO
from ultralytics.data.augment import LetterBox

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def save(name,obj): (OUT/name).write_text(json.dumps(obj,indent=2),encoding='utf8')
def shape(v): return [int(d.dim_value) for d in v.type.tensor_type.shape.dim]

def main():
    torch.set_num_threads(2)
    weight=ROOT/'work/algorithm_lab/yolov8m.pt'
    assert sha(weight)=='5d4a90cdc7a21786cc59cd19778e9eafff836df9e2da32524737c7ee6efe4fe5'
    source_paths=['work/algorithm_lab/plugins/yolo_reference.py','work/algorithm_lab/compare_yolo_models.py','work/algorithm_lab/rescore_yolo_coco.py','work/algorithm_lab/exports/yolo_quality_comparison/coco_rescore.json','work/yolo_fpga_feasibility/data/frozen_eval_manifest.json','work/y2_micro/data/manifest.json']
    manifest=json.loads((ROOT/source_paths[-2]).read_text())
    save('freeze.json',dict(weight=str(weight.relative_to(ROOT)),weight_sha256=sha(weight),packages={x:md.version(x) for x in ['torch','ultralytics','onnx','onnxruntime','numpy','opencv-python']},baseline=dict(imgsz=640,rect=True,confidence=.25,nms_iou=.7,device='cpu',classes=[39,41,67],status='VISUAL_REVIEW_PENDING'),export=dict(shape=[1,3,640,640],rect=False,opset=17,fp32=True,nms=False),sources={p:sha(ROOT/p) for p in source_paths},note='Original baseline uses stride-aligned rectangular letterbox. Static square export is a separate deployment graph; no equivalence of image padding is assumed.'))
    y=YOLO(str(weight)); model=y.model.float().eval()
    trainable=sum(p.numel() for p in model.parameters())
    model.fuse()
    head=model.model[-1]; head.export=True; head.format='onnx'; head.dynamic=False
    x=torch.zeros(1,3,640,640)
    records=[]
    def hook(name):
        def collect(mod,ins,out):
            if isinstance(mod,torch.nn.Conv2d):
                records.append(dict(name=name,input=list(ins[0].shape),output=list(out.shape),kernel=list(mod.kernel_size),stride=list(mod.stride),groups=mod.groups,weight_elements=mod.weight.numel(),mac=out.numel()*mod.weight.shape[1]*mod.kernel_size[0]*mod.kernel_size[1]))
        return collect
    handles=[m.register_forward_hook(hook(n)) for n,m in model.named_modules() if isinstance(m,torch.nn.Conv2d)]
    with torch.no_grad(): raw=model(x)
    for h in handles:h.remove()
    assert list(raw.shape)==[1,84,8400],raw.shape
    save('torch_profile.json',dict(unfused_parameter_elements=trainable,fused_parameter_elements=sum(p.numel() for p in model.parameters()),conv_mac=sum(r['mac'] for r in records),layers=records,output=list(raw.shape)))
    target=OUT/'yolov8m_640_fp32.onnx'
    torch.onnx.export(model,x,str(target),opset_version=17,input_names=['images'],output_names=['detections'],dynamic_axes=None,do_constant_folding=True,dynamo=False)
    graph=onnx.shape_inference.infer_shapes(onnx.load(str(target)))
    onnx.checker.check_model(graph,full_check=True)
    onnx.save(graph,str(target))
    dims={v.name:shape(v) for v in list(graph.graph.value_info)+list(graph.graph.input)+list(graph.graph.output)}
    init={v.name:numpy_helper.to_array(v) for v in graph.graph.initializer}
    dims.update({n:list(a.shape) for n,a in init.items()})
    rows=[]
    for node in graph.graph.node:
        outshapes=[dims.get(n,[]) for n in node.output]
        mac=0
        if node.op_type=='Conv':
            w=init[node.input[1]]; mac=int(np.prod(outshapes[0]))*int(np.prod(w.shape[1:]))
        rows.append(dict(name=node.name,op=node.op_type,inputs=list(node.input),outputs=list(node.output),input_shapes=[dims.get(n,[]) for n in node.input],output_shapes=outshapes,conv_mac=mac,output_elements=sum(int(np.prod(s)) for s in outshapes if s)))
    # No-inplace execution-order estimate. Views counted separately, all activations 1B
    # is a storage hypothesis only, not proof of INT8 numerical equivalence.
    last={n:i for i,row in enumerate(rows) for n in row['inputs']}
    for o in graph.graph.output:last[o.name]=len(rows)
    live={v.name:int(np.prod(dims[v.name])) for v in graph.graph.input}
    peak=sum(live.values()); peak_at='input'
    for i,row in enumerate(rows):
        for n,s in zip(row['outputs'],row['output_shapes']):
            if s:live[n]=int(np.prod(s))
        sz=sum(live.values())
        if sz>peak:peak,peak_at=sz,row['name']
        live={n:b for n,b in live.items() if last.get(n,-1)>i}
    conv_weights={n: init[n] for row in rows if row['op']=='Conv' for n in row['inputs'][1:2]}
    conv_io=sum(sum(int(np.prod(dims[n])) for n in [r['inputs'][0]]+r['outputs']) for r in rows if r['op']=='Conv')
    profile=dict(onnx_sha256=sha(target),onnx_bytes=target.stat().st_size,checker='PASS',input=[shape(v) for v in graph.graph.input],output=[shape(v) for v in graph.graph.output],operators=dict(Counter(r['op'] for r in rows)),initializer_elements=sum(a.size for a in init.values()),initializer_fp32_and_other_bytes=sum(a.nbytes for a in init.values()),conv_weight_elements=sum(a.size for a in conv_weights.values()),conv_mac=sum(r['conv_mac'] for r in rows),max_single_activation_elements=max(r['output_elements'] for r in rows),conservative_all_1byte_live_peak=peak,peak_at=peak_at,conv_io_all_spill_bytes_if_int8=conv_io,note='1-byte figures hypothetical; integer indices, scale/bias, accumulators, alignment, banking and non-Conv costs require additional storage/cycles.',layers=rows)
    assert profile['conv_mac']==sum(r['mac'] for r in records)
    save('onnx_profile.json',profile)
    opts=ort.SessionOptions();opts.intra_op_num_threads=2;opts.inter_op_num_threads=1
    sess=ort.InferenceSession(str(target),opts,providers=['CPUExecutionProvider'])
    images=manifest['images'] if isinstance(manifest,dict) else manifest
    comparisons=[]
    for item in images[:3]:
        p=ROOT/item['file']; img=cv2.imread(str(p)); assert img is not None
        padded=LetterBox(new_shape=(640,640),auto=False)(image=img)
        arr=np.ascontiguousarray(padded[:,:,::-1].transpose(2,0,1)[None],dtype=np.float32)/255
        with torch.no_grad(): a=model(torch.from_numpy(arr)).numpy()
        b=sess.run(None,{'images':arr})[0]
        delta=np.abs(a-b)
        np.testing.assert_allclose(a,b,rtol=1e-4,atol=.003)
        comparisons.append(dict(path=item['file'],image_sha256=sha(p),shape=list(a.shape),max_abs=float(delta.max()),mean_abs=float(delta.mean()),class_max_abs=float(delta[:,4:].max()),status='PASS'))
    save('onnx_equivalence.json',dict(tolerance=dict(rtol=1e-4,atol=.003),comparisons=comparisons,scope='same square RGB/255 input, raw decoded FP32 output; no INT8 or hardware claim'))
    print(json.dumps({k:v for k,v in profile.items() if k!='layers'},indent=2),flush=True)

if __name__=='__main__':main()
