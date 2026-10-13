"""Official NanoDet-Plus-m320 release ONNX; no training or model alterations.
Apache-2.0 source functions loaded from pinned upstream using AST to avoid optional training dependencies.
"""
import ast,sys,json,hashlib,math,importlib.util,types
from pathlib import Path
import cv2,numpy as np,torch,torch.nn as nn,torch.nn.functional as F,onnxruntime as ort
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent;UP=OUT/'upstream/nanodet'
sys.path.insert(0,str(ROOT/'work/algorithm_lab'))
from rescore_yolo_coco import score_rows
from pycocotools.coco import COCO
TARGET={39:'bottle',41:'cup',67:'cell phone'};torch.set_num_threads(1)
def module(name,path):
 s=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
warp=module('warp',UP/'nanodet/data/transform/warp.py');color=module('color',UP/'nanodet/data/transform/color.py');nms=module('nms',UP/'nanodet/model/module/nms.py');box=module('box',UP/'nanodet/util/box_transform.py')
ns=dict(torch=torch,nn=nn,F=F,math=math,distance2bbox=box.distance2bbox,multiclass_nms=nms.multiclass_nms)
node=next(n for n in ast.parse((UP/'nanodet/model/head/gfl_head.py').read_text()).body if isinstance(n,ast.ClassDef) and n.name=='Integral')
exec(compile(ast.Module(body=[node],type_ignores=[]),'upstream/Integral','exec'),ns)
headnode=next(n for n in ast.parse((UP/'nanodet/model/head/nanodet_plus_head.py').read_text()).body if isinstance(n,ast.ClassDef) and n.name=='NanoDetPlusHead')
methods=[n for n in headnode.body if isinstance(n,ast.FunctionDef) and n.name in ('get_bboxes','get_single_level_center_priors')]
headnode.body=methods;headnode.bases=[]
exec(compile(ast.Module(body=[headnode],type_ignores=[]),'upstream/NanoDetPlusHead','exec'),ns)
head=ns['NanoDetPlusHead']();head.strides=[8,16,32,64];head.reg_max=7;head.num_classes=80;head.distribution_project=ns['Integral'](7)
options=ort.SessionOptions();options.intra_op_num_threads=1
session=ort.InferenceSession(str(OUT/'nanodet-plus-m_320.onnx'),sess_options=options,providers=['CPUExecutionProvider'])
print('ORT interfaces',[(x.name,x.shape) for x in session.get_inputs()],[(x.name,x.shape) for x in session.get_outputs()],flush=True)
normalize={'normalize':[[103.53,116.28,123.675],[57.375,57.12,58.395]]}
shape=warp.ShapeTransform(False,**normalize)
priors=[]
for stride in head.strides:
 yy,xx=np.meshgrid(np.arange(math.ceil(320/stride)),np.arange(math.ceil(320/stride)),indexing='ij');priors.extend(np.stack([xx.ravel()*stride,yy.ravel()*stride,np.full(xx.size,stride)],1).tolist())
priors=np.array(priors,np.float32)
def infer(img,check=False):
 h,w=img.shape[:2];meta=shape({'img':img},(320,320));meta=color.color_aug_and_norm(meta,normalize)
 data=meta['img'].transpose(2,0,1)[None].astype(np.float32)
 raw=session.run(None,{session.get_inputs()[0].name:data})[0]
 # ONNX _forward_onnx already sigmoid-normalizes the first 80 channels.
 scores=torch.from_numpy(raw[0,:,:80]);reg=torch.from_numpy(raw[0,:,80:])
 dist=head.distribution_project(reg)*torch.from_numpy(priors[:,2,None])
 boxes=box.distance2bbox(torch.from_numpy(priors[:,:2]),dist,max_shape=(320,320))
 det,labels=nms.multiclass_nms(boxes,torch.cat([scores,torch.zeros(scores.shape[0],1)],1),.05,{'type':'nms','iou_threshold':.6},100)
 comparison={}
 if check:
  # Official get_bboxes consumes logits; invert export-only sigmoid for numerical parity.
  clipped=scores.clamp(1e-7,1-1e-7);logits=torch.logit(clipped)[None]
  ref,refcls=head.get_bboxes(logits,reg[None],{'img':torch.from_numpy(data)})[0]
  comparison['official_nms_labels_equal']=bool(torch.equal(labels,refcls));comparison['official_nms_max_abs']=float((det-ref).abs().max()) if det.numel() else 0
  rr=raw[0,:,80:].reshape(-1,4,8);pr=np.exp(rr-rr.max(-1,keepdims=True));pr/=pr.sum(-1,keepdims=True)
  dd=(pr*np.arange(8,dtype=np.float32)).sum(-1)*priors[:,2,None]
  bb=np.stack([priors[:,0]-dd[:,0],priors[:,1]-dd[:,1],priors[:,0]+dd[:,2],priors[:,1]+dd[:,3]],-1).clip(0,320)
  comparison['independent_numpy_dfl_box_max_abs']=float(np.max(np.abs(bb-boxes.numpy())))
  plain=cv2.warpPerspective(img,np.diag([320/w,320/h,1.]),(320,320)).astype(np.float32)/255.
  plain=(plain-np.array(normalize['normalize'][0],np.float32)/255)/(np.array(normalize['normalize'][1],np.float32)/255)
  comparison['independent_preprocess_max_abs']=float(np.max(np.abs(plain-meta['img'])))
  assert comparison['official_nms_labels_equal'] and comparison['official_nms_max_abs']<.0001 and comparison['independent_numpy_dfl_box_max_abs']<.001
 det=det.numpy();det[:,:4]=warp.warp_boxes(det[:,:4],np.linalg.inv(meta['warp_matrix']),w,h)
 rows=[{'class_id':int(c),'class':TARGET.get(int(c),str(int(c))),'confidence':float(p[4]),'box':p[:4].tolist()} for p,c in zip(det,labels.tolist()) if p[4]>=.25]
 return rows,comparison
coco=COCO(str(ROOT/'work/y1_yolo/datasets/instances_val2017.json'));summary={};checks=[]
sets={'diagnostic60':ROOT/'work/yolo_fpga_feasibility/data/frozen_eval_manifest.json','confirmation55':ROOT/'work/algorithm_lab/exports/yolo_quality_comparison/balanced_confirmation/confirmation55_yolov8m_640.json'}
for label,path in sets.items():
 rows=[]
 for i,rec in enumerate(json.loads(path.read_text())):
  p=ROOT/rec.get('file',rec.get('source'));img=cv2.imread(str(p));assert img is not None
  sha=hashlib.sha256(p.read_bytes()).hexdigest()
  if 'sha256' in rec:assert sha==rec['sha256']
  with torch.inference_mode():pred,check=infer(img,True)
  checks.append({'image_id':rec['image_id'],**check})
  rows.append({'image_id':rec['image_id'],'source':str(p.relative_to(ROOT)),'sha256':sha,'detections':[x for x in pred if x['class'] in TARGET.values()],'all_80_class_detections':pred})
 (OUT/(label+'_nanodet.json')).write_text(json.dumps(rows,indent=2))
 summary[label]={'classes':score_rows(coco,rows),'conf':.25,'nms_iou':.6,'match_iou':.5,'images':len(rows),'manifest_sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
 print(label,summary[label],flush=True)
(OUT/'nanodet_summary.json').write_text(json.dumps(summary,indent=2));(OUT/'nanodet_numerical_checks.json').write_text(json.dumps(checks,indent=2))
