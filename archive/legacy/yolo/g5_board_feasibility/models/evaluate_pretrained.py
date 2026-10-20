"""Official FP32 inference, fixed confidence .25, COCO crowd-aware counts (not mAP)."""
import sys,json,hashlib,time,importlib.util
from pathlib import Path
import cv2,numpy as np,torch
ROOT=Path(__file__).resolve().parents[3]; OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'work/algorithm_lab'))
from rescore_yolo_coco import score_rows
from pycocotools.coco import COCO
kind=sys.argv[1];torch.set_num_threads(1)
TARGET={39:'bottle',41:'cup',67:'cell phone'}
def load_file(name,p):
 spec=importlib.util.spec_from_file_location(name,p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
if kind=='fastestdet':
 sys.path.insert(0,str(ROOT/'work/y1_yolo'))
 from fastestdet_runtime import FastestDet,decode,WEIGHTS
 runner=FastestDet(); model=runner.model; weight=WEIGHTS
 from utils.tool import handle_preds
 def infer(image):
  x=torch.from_numpy(cv2.resize(image,(352,352)).transpose(2,0,1)[None].astype(np.float32)/255.)
  raw=model(x); official=handle_preds(raw,torch.device('cpu'),.25,.45)[0]
  h,w=image.shape[:2];rows=[]
  for b in official.tolist():
   rows.append({'class_id':int(b[5]),'class':TARGET.get(int(b[5]),str(int(b[5]))),'confidence':b[4],'box':[b[0]*w,b[1]*h,b[2]*w,b[3]*h]})
  wrapper=decode(raw.numpy(),image.shape,.25,.45,False)
  # Compare on original coordinates; wrapper rounds/clips before NMS.
  delta=None
  if len(rows)==len(wrapper) and [a['class_id'] for a in rows]==[a['class_id'] for a in wrapper]:
   delta=max([abs(a-b) for p,q in zip(rows,wrapper) for a,b in zip(p['box'],q['box'])] or [0])
  return rows,{'official_count':len(rows),'wrapper_count':len(wrapper),'max_box_delta_if_order_matches':delta}
 nms=.45
else:
 study=load_file('study',ROOT/'work/yolo_fpga_feasibility/run_study.py');model=study.load_model();weight=study.WEIGHT
 def infer(image):
  b,t=study.infer(model,image,352,.25,.4)
  return [{'class_id':p['class'],'class':p['name'],'confidence':p['score'],'box':p['box']} for p in b],t
 nms=.4
# profile actual loaded network, including repeated invocations
layers=[];handles=[]
def hook(name):
 def run(m,inp,o):
  if not isinstance(o,torch.Tensor):return
  r={'name':name,'op':type(m).__name__,'input':list(inp[0].shape),'output':list(o.shape),'output_elements':o.numel()}
  if isinstance(m,torch.nn.Conv2d):r.update(groups=m.groups,kernel=list(m.kernel_size),stride=list(m.stride),mac=o.numel()*(m.in_channels//m.groups)*m.kernel_size[0]*m.kernel_size[1])
  layers.append(r)
 return run
for name,m in model.named_modules():
 if not list(m.children()):handles.append(m.register_forward_hook(hook(name)))
with torch.inference_mode():raw=model(torch.zeros(1,3,352,352))
for h in handles:h.remove()
profile={'parameters':sum(p.numel() for p in model.parameters()),'conv_mac':sum(p.get('mac',0) for p in layers),'largest_single_int8_feature_bytes':max(p['output_elements'] for p in layers),'weight_sha256':hashlib.sha256(weight.read_bytes()).hexdigest(),'input':[1,3,352,352],'layers':layers}
(OUT/(kind+'_profile.json')).write_text(json.dumps(profile,indent=2))
coco=COCO(str(ROOT/'work/y1_yolo/datasets/instances_val2017.json'))
sets={'diagnostic60':ROOT/'work/yolo_fpga_feasibility/data/frozen_eval_manifest.json','confirmation55':ROOT/'work/algorithm_lab/exports/yolo_quality_comparison/balanced_confirmation/confirmation55_yolov8m_640.json'}
summary={}
for label,path in sets.items():
 records=json.loads(path.read_text());rows=[]
 for rec in records:
  p=ROOT/rec.get('file',rec.get('source')); img=cv2.imread(str(p));assert img is not None,p
  sha=hashlib.sha256(p.read_bytes()).hexdigest()
  if 'sha256' in rec:assert rec['sha256']==sha
  with torch.inference_mode():preds,check=infer(img)
  rows.append({'image_id':rec['image_id'],'source':str(p.relative_to(ROOT)),'sha256':sha,'detections':[p for p in preds if p['class'] in TARGET.values()],'all_80_class_detections':preds,'check':check})
 (OUT/(label+'_'+kind+'.json')).write_text(json.dumps(rows,indent=2))
 summary[label]={'classes':score_rows(coco,rows),'conf':.25,'nms_iou':nms,'match_iou':.5,'manifest_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'images':len(rows)}
 print(kind,label,summary[label],flush=True)
(OUT/(kind+'_summary.json')).write_text(json.dumps(summary,indent=2))
