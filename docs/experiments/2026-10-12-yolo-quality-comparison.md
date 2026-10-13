# YOLO 软件效果复核与基准升级（2026-10-12）

## 结论与范围

本轮完成软件参考的实测改善及测试链路修正，低识别率尚未彻底解决。保持相同图像、官方原标注、置信度0.25、IoU匹配0.5，不训练、不降低阈值、不移除困难样本。YOLOv8m 640 已接入 Algorithm Lab 默认页面，可直接选择内置图或上传图片/视频。当前为 VISUAL_REVIEW_PENDING。

- project：60图正确检出63→89/134，55图63→89/131。两组图像ID无交叉，但均为项目既有公开COCO诊断数据，不称全新工位验收。
- project：主要漏检集中在小目标；更强模型有改善，但误报仍在，单纯增大分辨率不是全面更好。
- project：发现并修复crowd计分问题，7组保存预测的TP/FP/FN均与官方COCOeval一致。计分修正不算模型能力提升。
- unknown：用户视觉验收、工位场景指标、可部署的小模型、INT8等价与板级吞吐。没有改RTL、执行TD或生成位流。G1/G2/G5阶段门不变。

## 来源与固定条件

官方来源：[YOLOv8文档](https://docs.ultralytics.com/models/yolov8/)，Ultralytics assets v8.4.0/yolov8m.pt；AGPL-3.0，Python包8.4.175。本地权重、数据清单与输入图哈希见 exports/yolo_quality_comparison/plan.json 和逐图JSON；未从第三方复制新网络代码。安装依赖版本见 work/algorithm_lab/requirements.txt。

预先固定主实验：n640、n960、m640、m960在60图对照，n640与m960在55图确认。看到60图容量/尺度对照后，选择m640为均衡候选，追加55图确认，单独保留 balanced_confirmation/plan.json，未更改原计划或阈值。

## 正式计分复核（project）

使用 pycocotools 2.0.11、完整 instances_val2017.json，bbox、IoU=0.5、all area、maxDets=100（每类每图），对已在confidence=0.25截断的预测计数。这里报告固定阈值Precision/Recall，不报告标准COCO AP。依据为官方[COCOeval实现](https://github.com/cocodataset/cocoapi/blob/master/PythonAPI/pycocotools/cocoeval.py)。

原简化脚本把crowd GT排除后，对群体区域中的预测照常计FP。图117719的bottle crowd区域为[6,75,474,263]。按官方规则复核后，n640有7框、m640有10框应忽略：60图n640 FP33→26，m640 FP41→31，TP不变。完整原预测与旧summary.json保留，后续引用以 coco_rescore.json 为准。

| 60图模型 | TP/FP/FN | Precision | Recall |
|---|---:|---:|---:|
| YOLOv8n 640 | 63/26/71 | 70.8% | 47.0% |
| YOLOv8n 960 | 69/32/65 | 68.3% | 51.5% |
| YOLOv8m 640 | 89/31/45 | 74.2% | 66.4% |
| YOLOv8m 960 | 93/47/41 | 66.4% | 69.4% |

| 不重叠55图模型 | TP/FP/FN | Precision | Recall |
|---|---:|---:|---:|
| YOLOv8n 640 | 63/21/68 | 75.0% | 48.1% |
| YOLOv8m 640 | 89/35/42 | 71.8% | 67.9% |
| YOLOv8m 960 | 89/45/42 | 66.4% | 67.9% |

55图m640分项：bottle P/R=64.8%/57.4%，cup=80.4%/75.5%，cell phone=70.8%/81.0%。默认640是折中：960在确认集中总TP相同却多10个FP，且更慢；没有根据这些测试重新拟合confidence。

## 漏检定位与成本

60图m640：原图bbox面积<32²的小目标54个，仅21个匹配（38.9%）；32²到96²的61个匹配51个（83.6%）；≥96²的19个匹配17个（89.5%）。这只是按原框面积分桶的诊断，非官方COCO面积AP，所有桶均包含在总分内。小目标33个FN，占全部45个FN的大部分。不能据此断言每个漏检都只由分辨率导致，遮挡、暗光、类别相似度仍待专项对照。

CPU推理总时间中位：60图n640约24ms，m640约132ms，m960约312ms；55图补测m640约294ms，明显受当时本机负载影响。这些不含文件读取/前端渲染，不能作为稳定帧率或FPGA延迟。实际服务能运行不等于实时视频达标。

m模型25,902,640参数，按INT8每参数1字节已约25.9MB。这里只作为PC视觉参考，不承诺直接部署PH1P35，也不把主线替换为CPU方案。未来压缩模型必须对照这个参考保留效果，并重新预算。

## 改动与验证

- plugins/yolo_reference.py：遵循BaseAlgorithm的官方m模型适配器，固定本地权重、CPU推理、NMS IoU=.7，640/960可选；没有伪造硬件等价输出。
- app.py、static/index.html、registry.json：新增候选、正确模型元数据、默认页面选择m640、按模型限制尺寸；原模型继续可选。
- work/y1_yolo/evaluate.py：非crowd先一对一匹配，剩余框按crowd intersection/detection area忽略；真实重复预测仍计FP；按置信度排序。
- compare_yolo_models.py、rescore_yolo_coco.py：冻结配置、保存全部预测、官方复算及与简化计分器逐组断言。verify_yolo_baseline.py同步保留crowd对象传入评分。
- 9项单元/集成回归通过，包括官方m模型逐框一致性、默认尺寸、权重定位、crowd/重复框计分。crowd回归先复现FP2/FN1，再修复为FP1/FN0。
- 新候选640/960真实HTTP推理、标注图片和ZIP导出均200；前端JavaScript语法与本次软件diff空白检查通过。该检查不替代用户视觉验收。

## 复现与证据

仓库根目录：

~~~powershell
& .\work\y1_yolo\.venv\Scripts\python.exe .\work\algorithm_lab\compare_yolo_models.py
& .\work\y1_yolo\.venv\Scripts\python.exe .\work\algorithm_lab\compare_yolo_models.py --balanced-confirmation
& .\work\y1_yolo\.venv\Scripts\python.exe .\work\algorithm_lab\rescore_yolo_coco.py
& .\work\y1_yolo\.venv\Scripts\python.exe .\work\algorithm_lab\compare_yolo_models.py --render
Push-Location work/algorithm_lab
& ..\y1_yolo\.venv\Scripts\python.exe -m unittest discover -v
Pop-Location
~~~

重跑compare后summary将使用修复后的crowd规则；本次留存的原summary为修复前计分，coco_rescore.json为复核后事实。禁止混用口径。

证据根目录 work/algorithm_lab/exports/yolo_quality_comparison/：原plan/summary、全部逐图预测、balanced_confirmation/、coco_rescore.json/log、comparison.jpg、gallery_selection.json、live_api.json、source_sha256.json。对照图按“TP增益最大的两图+剩余FN最多的一图”选取，仅供展示，不参与挑选评分样本。

## 下一入口与退出条件

软件基础测试可以在现有公开数据上继续，无需用户先拍工位素材；本轮已给出可运行参考和失败样例。要解决最终分拣场景，下一步应冻结该场景的目标最小尺寸/视野、目标类别及每类召回和误报上限，用相应未参与调参的数据验证；可先在公开数据中构建符合该场景的独立评测，不能从本次失败图中剔除困难对象来造通过。当前小模型不能因为大模型改善而自动进入硬件化。用户实际视觉确认之后才进入Stage D。
