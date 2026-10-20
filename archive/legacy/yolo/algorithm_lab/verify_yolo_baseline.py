"""Frozen COCO diagnostic: same images/threshold, only YOLOv8n input size changes.
Run with work/y1_yolo/.venv/Scripts/python.exe work/algorithm_lab/verify_yolo_baseline.py.
This is subset P/R at IoU .5, not COCO mAP or a hardware acceptance test.
"""
import hashlib
import json
import sys
from pathlib import Path
import cv2
import numpy as np
import torch
import app
sys.path.insert(0, str(app.Y1_DIR))
from evaluate import score_image
from fastestdet_runtime import draw
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'work/algorithm_lab/exports/yolo_baseline_audit'

def main():
    torch.set_num_threads(4)
    OUT.mkdir(parents=True, exist_ok=True)
    manifest_path=ROOT/'work/yolo_fpga_feasibility/data/frozen_eval_manifest.json'
    records=json.loads(manifest_path.read_text(encoding='utf8'))
    summary={'manifest_sha256':hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
        'weights_sha256':hashlib.sha256((app.BASE_DIR/'yolov8n.pt').read_bytes()).hexdigest(),
        'images':len(records),'confidence':.25,'match_iou':.5,
        'note':'Reused frozen public diagnostic subset; no training or threshold tuning. Not COCO mAP.',
        'runs':{}}
    for size in (352,640):
        totals={n:dict(tp=0,fp=0,fn=0) for n in ('bottle','cup','cell phone')}
        rows=[]
        for record in records:
            image=cv2.imread(str(ROOT/record['file']))
            if image is None: raise FileNotFoundError(record['file'])
            detections,ms=app.yolov8_detect(image,.25,size)
            objects=[o for o in record['objects'] if not o.get('iscrowd',0)]
            counts=score_image(detections,record["objects"])
            for name in totals:
                for k in totals[name]: totals[name][k]+=counts[name][k]
            rows.append(dict(image_id=record['image_id'],detections=detections,counts=counts))
        for v in totals.values():
            v['precision']=v['tp']/max(1,v['tp']+v['fp'])
            v['recall']=v['tp']/max(1,v['tp']+v['fn'])
        summary['runs'][str(size)]=totals
        (OUT/f'detections_{size}.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
        print(size,totals,flush=True)
    # Public diagnostic examples, kept separate from the 60-image score.
    panels=[]
    for image_id in ('120777','563882','119233'):
        img=cv2.imread(str(app.yolo_input_path(image_id)))
        views=[]
        for size in (352,640):
            det,_=app.yolov8_detect(img,.25,size)
            view=draw(img,det)
            view=cv2.resize(view,(640,480))
            cv2.putText(view,f'YOLOv8n {size} / COCO {image_id}',(12,28),cv2.FONT_HERSHEY_SIMPLEX,.7,(255,255,255),2)
            views.append(view)
        panels.append(np.hstack(views))
    cv2.imwrite(str(OUT/'before_after.jpg'),np.vstack(panels))
    (OUT/'summary.json').write_text(json.dumps(summary,indent=2),encoding='utf8')

if __name__=='__main__': main()
