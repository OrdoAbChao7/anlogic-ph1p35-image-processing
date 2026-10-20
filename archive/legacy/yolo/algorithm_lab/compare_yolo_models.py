"""Predeclared model/scale ablation on existing public COCO diagnostic sets.
No training, relabeling, threshold fitting, or FPGA work. Saves every prediction.
"""
import hashlib,json,sys,time
from pathlib import Path
import cv2
import numpy as np
import torch
from ultralytics import YOLO
ROOT=Path(__file__).resolve().parents[2]
LAB=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'work/y1_yolo'))
from evaluate import score_image,iou_xyxy
NAMES={39:'bottle',41:'cup',67:'cell phone'}
OUT=LAB/'exports/yolo_quality_comparison'

def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def matched_gt(preds,objects):
    used=set()
    for pred in sorted(preds,key=lambda x:-x['confidence']):
        candidates=[]
        for j,o in enumerate(objects):
            if j in used or o['class']!=pred['class']: continue
            x,y,w,h=o['box']
            candidates.append((iou_xyxy(pred['box'],[x,y,x+w,y+h]),j))
        overlap,j=max(candidates,default=(0,-1))
        if overlap>=.5: used.add(j)
    return used

def main():
    global OUT
    balanced = "--balanced-confirmation" in sys.argv
    if balanced:
        OUT = OUT / "balanced_confirmation"
    torch.set_num_threads(4)
    OUT.mkdir(parents=True,exist_ok=True)
    manifest=ROOT/'work/yolo_fpga_feasibility/data/frozen_eval_manifest.json'
    hold=ROOT/'work/y2_micro/data/manifest.json'
    datasets={'diagnostic60':json.loads(manifest.read_text(encoding='utf8')),
              'confirmation55':json.loads(hold.read_text(encoding='utf8'))['test']}
    bases={'diagnostic60':ROOT,'confirmation55':ROOT/'work/y2_micro'}
    assert not ({r['image_id'] for r in datasets['diagnostic60']} & {r['image_id'] for r in datasets['confirmation55']})
    # Freeze all configurations before inference; do not choose thresholds from these sets.
    plan={'confidence':.25,'nms_iou':.7,'match_iou':.5,'device':'cpu','threads':4,
          'runs':[['diagnostic60','yolov8n',640],['diagnostic60','yolov8n',960],
                  ['diagnostic60','yolov8m',640],['diagnostic60','yolov8m',960],
                  ['confirmation55','yolov8n',640],['confirmation55','yolov8m',960]],
          'scope':'Reused public diagnostics, NOT unseen workstation acceptance or COCO mAP',
          'manifest_sha256':digest(manifest),'confirmation_manifest_sha256':digest(hold),
          'weights':{m:digest(LAB/(m+'.pt')) for m in ('yolov8n','yolov8m')}}
    if balanced:
        plan['runs'] = [['confirmation55','yolov8m',640]]
        plan['scope'] += '; supplementary confirmation of the balanced 640 candidate selected on diagnostic60'
    (OUT/'plan.json').write_text(json.dumps(plan,indent=2),encoding='utf8')
    summary={}
    for split,variant,size in plan['runs']:
        key=f'{split}_{variant}_{size}'
        model=YOLO(str(LAB/(variant+'.pt')))
        parameters=sum(p.numel() for p in model.model.parameters())
        totals={n:dict(tp=0,fp=0,fn=0) for n in NAMES.values()}
        # Size bins describe original COCO pixel area, never exclude hard examples.
        bins={s:dict(gt=0,tp=0) for s in ('small_lt32','medium_32_96','large_ge96')}
        rows=[]; timing=[]; negatives=0; negative_fp=0
        for rec in datasets[split]:
            path=bases[split]/rec['file']; img=cv2.imread(str(path))
            if img is None: raise FileNotFoundError(path)
            assert img.shape[:2]==(rec['height'],rec['width']),(path,img.shape,rec)
            begin=time.perf_counter()
            result=model.predict(img,imgsz=size,conf=.25,iou=.7,device='cpu',verbose=False)[0]
            timing.append((time.perf_counter()-begin)*1000)
            preds=[{'class':NAMES[int(b.cls[0])],'confidence':float(b.conf[0]),
                    'box':[float(v) for v in b.xyxy[0].tolist()]}
                   for b in result.boxes if int(b.cls[0]) in NAMES]
            objects=[o for o in rec['objects'] if not o.get('iscrowd',0)]
            counts=score_image(preds,rec["objects"])
            for name in totals:
                for k in totals[name]: totals[name][k]+=counts[name][k]
            used=matched_gt(preds,objects)
            for j,o in enumerate(objects):
                area=o['box'][2]*o['box'][3]
                bucket='small_lt32' if area<32**2 else ('medium_32_96' if area<96**2 else 'large_ge96')
                bins[bucket]['gt']+=1; bins[bucket]['tp']+=int(j in used)
            if not objects: negatives+=1; negative_fp+=bool(preds)
            rows.append({'image_id':rec['image_id'],'source':str(path.relative_to(ROOT)),
                         'sha256':digest(path),'detections':preds,'counts':counts,
                         'matched_gt_indices':sorted(used),'objects':objects})
        for v in totals.values():
            v['precision']=v['tp']/max(1,v['tp']+v['fp']); v['recall']=v['tp']/max(1,v['tp']+v['fn'])
        for v in bins.values(): v['recall']=v['tp']/max(1,v['gt'])
        summary[key]={'classes':totals,'size_bins':bins,'negative_images':negatives,
                      'negative_images_with_fp':negative_fp,'parameters':parameters,
                      'median_cpu_total_ms':float(np.median(timing[1:]))}
        (OUT/(key+'.json')).write_text(json.dumps(rows,indent=2),encoding='utf8')
        (OUT/'summary.json').write_text(json.dumps(summary,indent=2),encoding='utf8')
        print(key,json.dumps(summary[key]),flush=True)
    print('DONE',flush=True)
def render_saved_comparison():
    from fastestdet_runtime import draw
    before=json.loads((OUT/'diagnostic60_yolov8n_640.json').read_text(encoding='utf8'))
    after=json.loads((OUT/'diagnostic60_yolov8m_640.json').read_text(encoding='utf8'))
    before={r['image_id']:r for r in before}
    count=lambda r,k:sum(v[k] for v in r['counts'].values())
    ordered=sorted(after,key=lambda r:(count(r,'tp')-count(before[r['image_id']],'tp'),count(r,'tp')),reverse=True)
    chosen=ordered[:2]
    failure=max((r for r in after if r not in chosen),key=lambda r:count(r,'fn'))
    chosen.append(failure)
    panels=[]
    for r in chosen:
        img=cv2.imread(str(ROOT/r['source']))
        gt=[]
        for o in r['objects']:
            x,y,w,h=o['box'];gt.append(dict(o,box=[x,y,x+w,y+h],confidence=1.0))
        candidates=[('GT annotation',gt),('YOLOv8n 640',before[r['image_id']]['detections']),('YOLOv8m 640',r['detections'])]
        views=[]
        for name,dets in candidates:
            view=draw(img,dets);h,w=view.shape[:2];scale=min(480/w,330/h)
            resized=cv2.resize(view,(round(w*scale),round(h*scale)))
            panel=np.full((385,480,3),24,np.uint8)
            top=45+(330-resized.shape[0])//2;left=(480-resized.shape[1])//2
            panel[top:top+resized.shape[0],left:left+resized.shape[1]]=resized
            cv2.putText(panel,f"{name} / {r['image_id']}",(8,23),cv2.FONT_HERSHEY_SIMPLEX,.55,(255,255,255),1)
            views.append(panel)
        panels.append(np.hstack(views))
    cv2.imwrite(str(OUT/'comparison.jpg'),np.vstack(panels))
    (OUT/'gallery_selection.json').write_text(json.dumps({'rule':'Two largest TP gains and one largest remaining FN; gallery only, all images retained in metrics','ids':[r['image_id'] for r in chosen]},indent=2),encoding='utf8')

if __name__=='__main__':
    if '--render' in sys.argv: render_saved_comparison()
    else: main()
