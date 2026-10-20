"""Rescore saved predictions with COCO crowd/ignore semantics, no new inference.
Outputs fixed-confidence P/R, NOT standard COCO AP: predictions were truncated at .25.
"""
import hashlib
import importlib.metadata
import json
import sys
from pathlib import Path
import numpy as np
from pycocotools.coco import COCO
from pycocotools.cocoeval import COCOeval
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent/'exports/yolo_quality_comparison'
IDS={'bottle':44,'cup':47,'cell phone':77}

def score_rows(coco,rows):
    detections=[]
    for row in rows:
        for p in row['detections']:
            x1,y1,x2,y2=p['box']
            detections.append({'image_id':row['image_id'],'category_id':IDS[p['class']],
                               'bbox':[x1,y1,x2-x1,y2-y1],'score':p['confidence']})
    if not detections:
        dt=COCO();dt.dataset={'images':list(coco.imgs.values()),'categories':list(coco.cats.values()),'annotations':[]};dt.createIndex()
    else:
        dt=coco.loadRes(detections)
    evaluator=COCOeval(coco,dt,'bbox')
    evaluator.params.imgIds=[r['image_id'] for r in rows]
    evaluator.params.catIds=list(IDS.values())
    evaluator.params.iouThrs=np.array([.5])
    evaluator.params.areaRng=[[0,1e10]]
    evaluator.params.areaRngLbl=['all']
    evaluator.params.maxDets=[100]
    evaluator.evaluate()
    totals={name:dict(gt=0,tp=0,fp=0,ignored_predictions=0) for name in IDS}
    names={v:k for k,v in IDS.items()}
    for e in evaluator.evalImgs:
        if e is None:continue
        count=totals[names[e['category_id']]]
        matched=e['dtMatches'][0]>0
        ignored=e['dtIgnore'][0]
        count['gt']+=int(np.count_nonzero(~e['gtIgnore'].astype(bool)))
        count['tp']+=int(np.count_nonzero(matched & ~ignored))
        count['fp']+=int(np.count_nonzero(~matched & ~ignored))
        count['ignored_predictions']+=int(np.count_nonzero(ignored))
    for c in totals.values():
        c['fn']=c['gt']-c['tp']
        c['precision']=c['tp']/max(1,c['tp']+c['fp'])
        c['recall']=c['tp']/max(1,c['gt'])
    return totals

def main():
    annotation=ROOT/'work/y1_yolo/datasets/instances_val2017.json'
    coco=COCO(str(annotation))
    report={'pycocotools':importlib.metadata.version('pycocotools'),
            'annotations_sha256':hashlib.sha256(annotation.read_bytes()).hexdigest(),
            'scope':'Fixed confidence .25, IoU .5, maxDets=100 per category/image; crowd honored. Not COCO AP.',
            'runs':{}}
    files=sorted(OUT.glob('diagnostic60_yolo*.json'))+sorted(OUT.glob('confirmation55_yolo*.json'))+sorted((OUT/'balanced_confirmation').glob('confirmation55_yolo*.json'))
    for path in files:
        rows=json.loads(path.read_text(encoding='utf8'))
        report['runs'][path.stem]=score_rows(coco,rows)
        sys.path.insert(0,str(ROOT/'work/y1_yolo'))
        from evaluate import score_image
        simple={name:dict(tp=0,fp=0,fn=0) for name in IDS}
        for row in rows:
            annotations=coco.loadAnns(coco.getAnnIds(imgIds=[row['image_id']],catIds=list(IDS.values())))
            reverse={v:k for k,v in IDS.items()}
            objects=[{'class':reverse[a['category_id']],'box':a['bbox'],'iscrowd':a.get('iscrowd',0)} for a in annotations]
            counts=score_image(row['detections'],objects)
            for name in IDS:
                for k in ('tp','fp','fn'):simple[name][k]+=counts[name][k]
        assert all(simple[n][k]==report['runs'][path.stem][n][k] for n in IDS for k in ('tp','fp','fn')),(path,simple)
        print(path.stem,'simplified scorer == COCOeval: PASS',report['runs'][path.stem])
    (OUT/'coco_rescore.json').write_text(json.dumps(report,indent=2),encoding='utf8')

if __name__=='__main__':main()
