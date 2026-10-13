# YOLO 软件测试入口排错（2026-10-12）

## 结论

基本推理入口存在真实配置和启动缺陷，已修复；整组检测效果有所改善，但低召回问题未完全解决。无需用户工位素材即可复现这些问题。没有训练、改权重、改 RTL、运行 TD 或授予 VISUAL_APPROVED。

## 已复现的问题（project）

1. 页面默认模型为 YOLOv8n，但尺寸下拉框默认 352；首次打开没有执行模型切换函数。后端省略尺寸也固定为 352。同一公开图 563882 的手机置信度为 0.2908；恢复 640 后为 0.8364。这只证明尺寸影响，不把置信度当准确率。
2. YOLOv8n 和 YOLO-FastestV2 的结果被标为 Y2 MicroDet；V2 请求 96 时实际仍跑 352，却把 96 写进导出参数。已修正模型名称，按模型默认尺寸推理，拒绝不支持的组合。
3. 一键启动使用系统 python，实际报 ModuleNotFoundError: No module named 'ultralytics'。现固定使用已有 work/y1_yolo/.venv/Scripts/python.exe 并先检查依赖。
4. YOLOv8n 权重使用相对当前工作目录的路径，现固定为 work/algorithm_lab/yolov8n.pt，缺失时明确报错。

## 固定集对照（project）

沿用 work/yolo_fpga_feasibility/data/frozen_eval_manifest.json 的全部 60 张图，134 个非 crowd 三类标注；同一 YOLOv8n 权重、置信度 0.25、IoU≥0.5 一对一匹配，仅改变输入尺寸。没有改标签、筛除失败图片或降低阈值。该集已被项目使用，只称公开诊断集，不称新的独立验收集；不使用 COCO mAP 名义。

| 类别 | 352 TP/FP/FN | 640 TP/FP/FN | 352→640 Recall | 640 Precision |
|---|---|---|---|---|
| bottle | 11/12/41 | 17/17/35 | 21.2%→32.7% | 50.0% |
| cup | 23/10/37 | 34/15/26 | 38.3%→56.7% | 69.4% |
| cell phone | 10/1/12 | 12/1/10 | 45.5%→54.5% | 92.3% |

总 TP 44→63，FP 23→33，总召回 32.8%→47.0%。改善伴随误报增加，不能写为检测效果达标。已有微型模型容量、训练不足等原因仍是待对照验证的假设，不能仅凭低分确定各因素的因果贡献。

## 文件与复现

修改 work/algorithm_lab/app.py、static/index.html、run_lab.bat；新增 test_yolo.py 与 verify_yolo_baseline.py。保留工作区已有改动。

在仓库根目录运行：

~~~powershell
& .\work\y1_yolo\.venv\Scripts\python.exe .\work\algorithm_lab\verify_yolo_baseline.py
Push-Location work/algorithm_lab
& ..\y1_yolo\.venv\Scripts\python.exe -m unittest discover -v
Pop-Location
~~~

交互入口：运行 work/algorithm_lab/run_lab.bat 后访问 http://127.0.0.1:8501/，选择“三类真实检测”。默认 YOLOv8n 640，公开图片已内置，可直接切换或上传。

证据目录：work/algorithm_lab/exports/yolo_baseline_audit/：summary.json（权重/清单 SHA-256）、detections_352.json、detections_640.json（全部逐图预测与计分）、before_after.jpg、live_api.json、model_smoke.json、server.log。

## 验证与边界

- 三个新增回归先失败：默认尺寸 352、V2 静默忽略 96、权重路径非绝对；修复后与原有四个算法测试合计 7/7 PASS。
- 前端内嵌 JavaScript 语法检查 PASS。
- 启动实际服务后，四种模型同服务切换均 HTTP 200；默认 YOLOv8n 实际记录 640 和正确模型名；ZIP 导出 HTTP 200 且文件名正确。
- 官方 V2 依赖仍产生 torch.meshgrid 未来 indexing 参数警告；本轮未改第三方代码。
- 旧报告“成熟模型稳定、高准确率”的结论与其表中低召回数据不相符，已补充纠正，不能据其推进 FPGA。
- 用户尚未实际视觉验收；G1/G2/G5 与硬件验收状态不变。下一入口是以修复后的公开基线进行效果对照，保留每类 P/R 和失败图片；基本复现不以提供工位素材为前提。模型压缩/硬件等价转换需在软件效果经用户确认之后。

补充检查：启动依赖检查 PASS。全工作区 git diff --check 报已有 docs/research/OPEN_SOURCE.md 第 180–182 行 Markdown 行尾双空格；该文件本轮未改，保留原改动。
