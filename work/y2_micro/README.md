# Y2 三类 MicroDet 软件预研

本目录包含杯子、瓶子、手机三类检测的公开数据预研。**当前模型在新 55 图测试中只有 128 输入匹配到 2 个瓶子，且有 822 个误报，不能用于分拣或硬件化。** 结论、指标、来源和 PH1P35 预算见 [`docs/experiments/2026-10-12-y2-microdet.md`](../../docs/experiments/2026-10-12-y2-microdet.md)。

`models/` 是冻结的 96、128、160 FP32 权重；`results/` 包含逐图评估、INT8 对照、逐层预算和训练日志。COCO 原图存放在被忽略的 `data/images/`，重新运行 `prepare_data.py` 获取。`data/manifest.json`、`data/image_sha256.json` 固定划分及图像校验值。Y1 虚拟环境中的 PyTorch CPU、OpenCV 和 FastAPI 可复用。

```powershell
$py = 'work/y1_yolo/.venv/Scripts/python.exe'
& $py work/y2_micro/prepare_data.py
& $py work/y2_micro/test_y2.py
& $py work/y2_micro/evaluate.py --size 160
& $py work/y2_micro/quantize.py --size 160
& $py work/y2_micro/network_profile.py
cd work/algorithm_lab
& ../y1_yolo/.venv/Scripts/python.exe -m uvicorn app:app --host 127.0.0.1 --port 8503
```

Lab 的“三类目标检测 · Y1 / Y2 软件对比”支持图片、视频、阈值、检测框和 ZIP 导出。Y2 处于软件实现状态，未经用户视觉确认；本目录没有 PH1P35 硬件等价模型或 RTL。
