"""Compare a separate NumPy head decoder with pinned upstream decode/NMS."""
import json
from pathlib import Path
import cv2
import numpy as np
import torch
from run_study import ROOT, load_model, config, handel_preds, non_max_suppression, ANCHORS, EXPECTED_SHA, TARGET

OUT=ROOT/"results/decode_check"
OUT.mkdir(parents=True,exist_ok=True)
torch.set_num_threads(1)
model=load_model()


def independent_decode(outputs,size):
    rows=[]
    anc=np.asarray(ANCHORS,dtype=np.float32).reshape(2,3,2)
    for scale in range(2):
        reg,obj,cls=[x.detach().numpy()[0] for x in outputs[3*scale:3*scale+3]]
        h,w=reg.shape[1:]
        cls_exp=np.exp(cls-cls.max(axis=0,keepdims=True))
        cls_prob=(cls_exp/cls_exp.sum(axis=0,keepdims=True)).transpose(1,2,0)
        for y in range(h):
            for x in range(w):
                for a in range(3):
                    r=reg[a*4:a*4+4,y,x]
                    sig=1/(1+np.exp(-r))
                    cxcy=(sig[:2]*2-.5+np.array([x,y]))*(size/h)
                    wh=(sig[2:]*2)**2*anc[scale,a]
                    ob=1/(1+np.exp(-obj[a,y,x]))
                    rows.append([*cxcy,*wh,ob,*cls_prob[y,x]])
    return np.asarray(rows,dtype=np.float32)


def independent_nms(decoded,threshold=.3,iou=.4):
    possible=decoded[decoded[:,4]>threshold].copy()
    if not len(possible):return np.empty((0,6),np.float32)
    probs=possible[:,5:]*possible[:,4:5]
    cl=probs.argmax(axis=1)
    score=probs[np.arange(len(probs)),cl]
    keep=score>threshold
    possible,cl,score=possible[keep],cl[keep],score[keep]
    boxes=np.column_stack((possible[:,0]-possible[:,2]/2,possible[:,1]-possible[:,3]/2,
                           possible[:,0]+possible[:,2]/2,possible[:,1]+possible[:,3]/2))
    rows=np.column_stack((boxes,score,cl)).astype(np.float32)
    order=np.argsort(-score,kind="stable")
    picked=[]
    while len(order):
        i=order[0];picked.append(i)
        remains=[]
        for j in order[1:]:
            if cl[i]!=cl[j]: remains.append(j);continue
            aa=boxes[i];bb=boxes[j]
            inter=max(0,min(aa[2],bb[2])-max(aa[0],bb[0]))*max(0,min(aa[3],bb[3])-max(aa[1],bb[1]))
            aarea=max(0,aa[2]-aa[0])*max(0,aa[3]-aa[1]);barea=max(0,bb[2]-bb[0])*max(0,bb[3]-bb[1])
            if inter/(aarea+barea-inter+1e-9)<=iou:remains.append(j)
        order=np.asarray(remains,dtype=np.int64)
    return rows[picked]


results=[]
for ident in (120777,563882,119233):
    source=ROOT.parent/"y1_yolo"/"datasets"/"val_subset"/f"{ident:012d}.jpg"
    image=cv2.imread(str(source));assert image is not None
    x=cv2.resize(image,(352,352),interpolation=cv2.INTER_LINEAR)
    inp=torch.from_numpy(x[None].transpose(0,3,1,2)).float()/255
    with torch.inference_mode():
        raw=model(inp)
        official=handel_preds(raw,config(352),torch.device("cpu"))
        reference=non_max_suppression(official.clone(),conf_thres=.3,iou_thres=.4)[0].numpy()
    separate=independent_decode(raw,352)
    compare=independent_nms(separate)
    np.savez_compressed(OUT/f"{ident}_all_80_class_candidates.npz",decoded=official.numpy()[0])
    # Non-max tie order may differ, compare sorted by class,score,coordinates.
    sort=lambda arr:arr[np.lexsort((arr[:,0],-arr[:,4],arr[:,5]))] if len(arr) else arr
    h0,w0=image.shape[:2]
    predictions=[]
    for box in reference:
        predictions.append({"class_index":int(box[5]),"class_name":TARGET.get(int(box[5]),str(int(box[5]))),
                            "confidence":float(box[4]),
                            "box_xyxy_original":[float(box[0]*w0/352),float(box[1]*h0/352),float(box[2]*w0/352),float(box[3]*h0/352)]})
    item={"image_id":ident,"input_file":str(source.relative_to(ROOT.parents[1])).replace('\\','/'),"weights_sha256":EXPECTED_SHA,"input_size":[352,352],
          "confidence_threshold":.3,"nms_iou":.4,"predictions_all_classes":predictions,
          "raw_candidate_count":len(separate),
          "decoded_max_abs_diff":float(np.max(np.abs(official.numpy()[0]-separate))),
          "official_box_count":len(reference),"separate_box_count":len(compare),
          "post_nms_max_abs_diff":float(np.max(np.abs(sort(reference)-sort(compare)))) if reference.shape==compare.shape and len(reference) else None}
    results.append(item)
    assert item["decoded_max_abs_diff"] < 0.0002, item
    assert item["official_box_count"] == item["separate_box_count"], item
    assert item["post_nms_max_abs_diff"] is not None and item["post_nms_max_abs_diff"] < 0.0001, item
(OUT/"comparison.json").write_text(json.dumps(results,indent=2),encoding="utf-8")
print(json.dumps(results,indent=2))
