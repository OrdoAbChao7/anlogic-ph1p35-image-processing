"""Regression tests for model-specific inference settings and experiment identity."""
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from fastapi.testclient import TestClient
import app

class TestYoloContract(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app.app)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def test_yolov8_default_uses_640_and_records_correct_identity(self):
        with patch.object(app, 'Y1_LAB_DIR', self.root):
            response = self.client.post('/api/yolo/process', json={
                'sample_id': '563882', 'model': 'ultralytics_yolov8n'})
        self.assertEqual(response.status_code, 200, response.text)
        result = response.json()
        self.assertEqual(result['params']['resolution'], 640)
        self.assertIn('YOLOv8n', result['model'])
        self.assertTrue(any(d['class']=='cell phone' and d['confidence']>.7 for d in result['detections']))
        saved = json.loads((self.root/result['run_id']/'result.json').read_text(encoding='utf8'))
        self.assertEqual(saved['params'], result['params'])

    def test_medium_reference_runs_at_960_and_matches_official_predict(self):
        from ultralytics import YOLO
        import cv2
        with patch.object(app, 'Y1_LAB_DIR', self.root):
            response = self.client.post('/api/yolo/process', json={
                'sample_id': '563882', 'model': 'ultralytics_yolov8m', 'resolution': 960})
        self.assertEqual(response.status_code, 200, response.text)
        result = response.json()
        self.assertEqual(result['params']['resolution'], 960)
        self.assertIn('YOLOv8m', result['model'])
        image = cv2.imread(str(app.yolo_input_path('563882')))
        direct = YOLO(str(app.BASE_DIR/'yolov8m.pt')).predict(
            image, imgsz=960, conf=.25, iou=.7, device='cpu', verbose=False)[0]
        expected = [b for b in direct.boxes if int(b.cls[0]) in (39,41,67)]
        self.assertEqual(len(result['detections']),len(expected))
        self.assertGreater(len(expected), 0)
        for actual, gold in zip(result['detections'], expected):
            self.assertEqual(actual['class'],direct.names[int(gold.cls[0])])
            self.assertAlmostEqual(actual['confidence'],float(gold.conf[0]),places=3)
            for a,b in zip(actual['box'],gold.xyxy[0].tolist()):
                self.assertAlmostEqual(a,b,places=1)

    def test_crowd_detections_are_ignored_but_real_duplicates_count_as_fp(self):
        import sys
        sys.path.insert(0,str(app.Y1_DIR))
        from evaluate import score_image
        objects=[{'class':'bottle','box':[0,0,10,10]},
                 {'class':'bottle','box':[20,20,100,100],'iscrowd':1}]
        predictions=[{'class':'bottle','box':[0,0,10,10],'confidence':.9},
                     {'class':'bottle','box':[0,0,10,10],'confidence':.8},
                     {'class':'bottle','box':[25,25,35,35],'confidence':.7}]
        self.assertEqual(score_image(predictions,objects)['bottle'],{'tp':1,'fp':1,'fn':0})

    def test_fixed_v2_resolution_cannot_be_silently_ignored(self):
        response = self.client.post('/api/yolo/process', json={
            'sample_id': '563882', 'model': 'yolo_fastestv2', 'resolution': 96})
        self.assertEqual(response.status_code, 400, response.text)

    def test_yolov8_weights_are_independent_of_working_directory(self):
        import os
        saved = os.getcwd()
        cached = app.YOLO8_MODEL
        try:
            app.YOLO8_MODEL = None
            os.chdir(self.temp.name)
            with patch('ultralytics.YOLO') as loader:
                app.get_yolov8()
                path = Path(loader.call_args.args[0])
                self.assertTrue(path.is_absolute(), str(path))
                self.assertTrue(path.is_file(), str(path))
        finally:
            os.chdir(saved)
            app.YOLO8_MODEL = cached

if __name__ == '__main__':
    unittest.main()
