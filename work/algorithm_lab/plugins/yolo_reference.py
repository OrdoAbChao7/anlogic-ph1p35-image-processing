"""Official pretrained YOLOv8m software reference; no hardware-equivalent model."""
import time
from pathlib import Path
import cv2
from .base import BaseAlgorithm

class YoloReferenceAlgorithm(BaseAlgorithm):
    algorithm_id = "ultralytics_yolov8m"
    display_name = "YOLOv8m 软件效果基准"
    category = "Detection"
    description = "官方 COCO 80 类权重，筛选瓶子、杯子、手机；仅 PC 预览。"
    source_reference = "https://docs.ultralytics.com/models/yolov8/"
    license = "AGPL-3.0"

    def __init__(self):
        self._model = None

    @property
    def detector(self):
        if self._model is None:
            from ultralytics import YOLO
            weights = Path(__file__).resolve().parents[1] / "yolov8m.pt"
            if not weights.is_file():
                raise FileNotFoundError("Missing work/algorithm_lab/yolov8m.pt")
            self._model = YOLO(str(weights))
        return self._model

    def get_parameter_specs(self):
        return [
            {"id":"confidence","label":"置信度","type":"float","default":.25,"min":.01,"max":.99,"step":.05},
            {"id":"resolution","label":"输入尺寸","type":"select","default":"640",
             "options":[{"label":"640 (默认)","value":"640"},{"label":"960 (对照)","value":"960"}]}]

    def detect_bgr(self, image, params):
        size = int(params.get("resolution",640))
        if size not in (640,960):
            raise ValueError("YOLOv8m reference supports 640 or 960")
        model = self.detector
        start = time.perf_counter()
        result = model.predict(image, imgsz=size, conf=float(params.get("confidence",.25)),
                               iou=.7, device="cpu", verbose=False)[0]
        elapsed = (time.perf_counter()-start)*1000
        names = {39:"bottle",41:"cup",67:"cell phone"}
        detections = [{"class":names[int(b.cls[0])],"confidence":round(float(b.conf[0]),4),
                       "box":[round(float(v),2) for v in b.xyxy[0].tolist()]}
                      for b in result.boxes if int(b.cls[0]) in names]
        return detections, elapsed

    def process_visual_reference(self, image_rgb, params):
        bgr = cv2.cvtColor(image_rgb,cv2.COLOR_RGB2BGR)
        detections,elapsed = self.detect_bgr(bgr,params)
        for d in detections:
            x1,y1,x2,y2=map(round,d["box"])
            cv2.rectangle(bgr,(x1,y1),(x2,y2),(0,220,0),2)
            cv2.putText(bgr,f'{d["class"]} {d["confidence"]:.2f}',(x1,max(16,y1-5)),
                        cv2.FONT_HERSHEY_SIMPLEX,.5,(0,220,0),1)
        return cv2.cvtColor(bgr,cv2.COLOR_BGR2RGB), {"detections":detections,"inference_ms":elapsed}

    def process_hardware_equivalent(self, image_rgb, params):
        raise RuntimeError("Software reference only; hardware-equivalent model is not implemented")
