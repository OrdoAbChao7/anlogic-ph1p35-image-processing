# Y1：FastestDet 软件复现与 PH1P35 适配预研

日期：2026-10-12。结论：**Y1 研究交付 PASS；原始 FastestDet 直接部署 PH1P35 为 NO-GO。** 这不是 G5 阶段通过，也不是三类模型训练完成。没有修改 FPGA 视频工程、核心 RTL、长期目标或验收门；本轮未运行 TangDynasty，也未生成位流。

## 证据与复现

- 原始仓库：FastestDet [`50473cd155cb088aa4a99e64ff6a4b3c24fa07e1`](https://github.com/dog-qiuqiu/FastestDet/tree/50473cd155cb088aa4a99e64ff6a4b3c24fa07e1)；Yolo-FastestV2 [`ac2a5e3060bff76dd1e45f9b921dd77bfbeb194d`](https://github.com/dog-qiuqiu/Yolo-FastestV2/tree/ac2a5e3060bff76dd1e45f9b921dd77bfbeb194d)；TinyissimoYOLO [`19bea4bd1ea1e2c29a6ee6b14bd7494ce8c6ba25`](https://github.com/eth-pbl/tinyissimoyolo/tree/19bea4bd1ea1e2c29a6ee6b14bd7494ce8c6ba25)。类别、头结构和算子均从这些固定版本读出，属于 `reference`。
- FastestDet 官方权重原路径 `weights/weight_AP05:0.253207_280-epoch.pth` 含 Windows 非法冒号；`work/y1_yolo/prepare_sources.py` 使用 `git show` 直接写到 `fastestdet_coco_safe.pth`，**没有检出非法文件**。权重 SHA-256：`7f688d478ee474c82dbdb9c10e0ede2f8f3cf5d603f0825d2efd925eb561d05e`；仓库官方 ONNX SHA-256：`31cb14c017fce347cb4c846ec62fdf00d76bb3beecdf4be21e7116ac67feb880`。同一官方测试图上，PyTorch 与 ONNX 输出最大绝对差 `9.54e-5`，均值 `7.02e-8`（`project`）。
- 官方 `data/3.jpg` 以 352 输入、80 类模型、0.25 阈值检出人物和球；三类过滤为空，符合样图内容。实际三类效果见 [瓶子与杯子检出](../evidence/y1/bottle-cup-detected.jpg)、[手机检出](../evidence/y1/phone-detected.jpg)、[手机失败样例](../evidence/y1/phone-failure.jpg)。样例对应 COCO val2017 图片 ID 120777、563882、119233；这些图不是 FPGA 上板结果。
- Windows 11 / Python 3.13.7 / PyTorch 2.14.0+cpu / ONNX Runtime 1.29.0 / OpenCV 4.13.0 / NumPy 2.4.3；推理线程上限 4。独立虚拟环境位于 `work/y1_yolo/.venv`，因 pip 下载 SSL 中断而设置 `include-system-site-packages = true`，复用本机上述包；因此环境**不是完全封闭的依赖安装**。计时只适用于这台 CPU。

复现顺序：在 `work/y1_yolo` 执行 `python prepare_sources.py`、`python download_dataset.py`、`python prepare_dataset.py`、`python profile_network.py`、`python graph_liveness.py`、`python tune_threshold.py`、`python evaluate.py`。用 `python -m unittest test_y1.py` 检查解码与计分。依赖为 PyTorch、ONNX Runtime、OpenCV、NumPy。Lab 在 `work/algorithm_lab` 启动 `python -m uvicorn app:app --host 127.0.0.1 --port 8502`，打开“Y1 三类真实检测”页；上传图片/MP4/AVI，调整阈值和尺寸，下载包含原输入、带框输出与 JSON 的 ZIP。Lab 图片、3 帧视频上传/逐帧处理、ZIP 导出已走通；视频冒烟样本由真实静态图重复生成，只证明视频接口功能，不证明连续自然视频检测质量。

## 三模型比较

| 原始模型 | 许可证与公开权重 | 检测头、主要算子 | PH1P35 预研 |
|---|---|---|---|
| FastestDet | 仓库 `LICENSE.md` 为 BSD-3-Clause；随仓库有 COCO 80 类 `.pth`、ONNX、NCNN 文件，权重未见独立授权说明 | ShuffleNetV2，3 个尺度特征聚合后单尺度 85 通道 anchor-free 头；70 个卷积含 28 个 depthwise，另有 BN、ReLU、池化、上采样、channel shuffle、concat、SPP 残差；后处理含幂次评分、tanh/sigmoid、argmax、逐类 NMS | 软件最易复现；现有原模型权重和特征图均超片上余量 |
| Yolo-FastestV2 | 仓库未发现 LICENSE/COPYING；`modelzoo/coco2017-0.241078ap-model.pth` 随仓库，权重授权未单列；代码只作阅读 | ShuffleNetV2 + LightFPN，双尺度；每尺度 reg/obj/cls 分支，3 anchor，5×5 depthwise 与 1×1 卷积、上采样、concat；anchor 解码和 NMS | 双尺度缓存、anchor 候选、后处理比 FastestDet 更复杂；不直接移植 |
| TinyissimoYOLO | 仓库未发现顶层 LICENSE/COPYING 或随仓库预训练 `.pt`；说明基于 Ultralytics，部分配置含 AGPL-3.0 声明；授权边界待项目方明确 | 多个 YAML 变体；v1-small 为 Conv+MaxPool 主干、单尺度 Detect，v5 变体含 C3/SPPF/多尺度 Detect | 小模型思路值得研究，但公开仓库未提供可直接复现实验的对应权重；本轮不选作基线 |

以上许可证结论只针对检查到的固定 Commit，不推断未随仓库公开的模型权利。三个模型均未复制代码进 FPGA 工程。

## 数据分割与计分

- **训练：0 张**。原始 FastestDet 维持 COCO 80 类预训练权重，未重训或剪枝。
- **调参：9 张**，从 COCO128 的 `train2017` 选出，只用于探索阈值；可能与原模型训练集重合，不能当独立精度证据。下载包 SHA-256 `61e5e3028863d8ffc3b81d6a514603954889f0edd5e4b44c4ce60b2da99aeb8e`。
- **独立测试：29 张**，固定随机种子 20261012 从 COCO val2017 按目标类各抽 8 张，并加 5 张无三类标注图。去重后 29 张，含 bottle 25、cup 47、cell phone 12 个非 crowd 标注。图和每个标注见 `work/y1_yolo/datasets/test_manifest.json`，清单 SHA-256 `6680c8d76abfe9b21b25b9b607d47e29f2f06bf6f91eaa88ab679652ef4b9c50`；标注 JSON SHA-256 `e8c7f7908f1d7278341fae127d0da654f102f11bd7b21d8aeefa635b8c810b6f`。小样本、按目标存在性抽样，不代表总体 COCO 精度。
- 计分为同类预测与标注框一对一匹配、IoU ≥ 0.5；TP/FP/FN 和 Precision/Recall 从独立测试集逐图累计，阈值 0.25、逐类 NMS IoU 0.45。原模型仍输出 80 类，只筛选三类展示与计分。

| 输入 | bottle TP/FP/FN；P/R | cup TP/FP/FN；P/R | cell phone TP/FP/FN；P/R | CPU 前向均值 / 端到端均值 |
|---|---|---|---|---|
| 352 | 7/31/18；0.184/0.280 | 8/29/39；0.216/0.170 | 1/7/11；0.125/0.083 | 8.412 / 9.555 ms |
| 160 | 0/34/25；0/0 | 0/9/47；0/0 | 0/1/12；0/0 | 4.850 / 5.118 ms |
| 128 | 0/21/25；0/0 | 0/6/47；0/0 | 0/0/12；0/0 | 4.842 / 5.066 ms |
| 96 | 0/7/25；0/0 | 0/1/47；0/0 | 0/0/12；0/0 | 4.457 / 4.607 ms |

完整逐图预测、失败和耗时在 `work/y1_yolo/results/evaluation.json`。调参集的 352 阈值扫描 `0.15/0.25/0.40/0.55/0.65` 微平均 F1 分别为 `0.100/0.130/0.069/0.043/0.044`，见 `results/tuning.json`。独立测试始终使用预设的 0.25，没有根据其结果改阈值。**160/128/96 的零匹配是未经重训直接缩放的实际结果；若走这些尺寸，必须重训并重新在独立集上评估。**

## 实际网络与硬件预算

`work/y1_yolo/results/network_profile.json` 和 [逐层 CSV](../../work/y1_yolo/results/layer_budget.csv) 由加载真实 `.pth` 的 PyTorch 模型 forward hooks 生成。CSV 每行列出输入输出形状、卷积核、stride、groups、参数、MAC 和单张 INT8 特征图字节数；四档合计 772 行。功能性 channel shuffle、concat、残差 add 与后处理在 JSON 列出但不计入卷积 MAC。它们仍需逻辑、缓存和周期。

| 输入 | 参数总数 | 卷积 MAC/帧 | 最大单张 INT8 特征图（下界） | 图存活估算 | 32 MAC/周期、100 MHz 的卷积理论下界 |
|---|---:|---:|---:|---:|---:|
| 352 | 244,490 | 121,491,744 | 743,424 B | 1,486,848 B | 37.97 ms |
| 160 | 244,490 | 25,101,600 | 153,600 B | 307,200 B | 7.84 ms |
| 128 | 244,490 | 16,065,024 | 98,304 B | 196,608 B | 5.02 ms |
| 96 | 244,490 | 9,036,576 | 55,296 B | 110,592 B | 2.82 ms |

最大特征图是**同时存活内存的下界**，不是完整片上峰值；分支与 concat 会使真实峰值更高。`results/graph_liveness.json` 用 `torch.export` 实际计算图逐节点统计最后使用点，保守地把每个张量输出（包括可能共用存储的 view）都计为独立 INT8 缓冲。表中图存活值是该执行顺序的保守估算，不是优化后 FPGA 的精确峰值；未计行缓存和 NMS 临时区。FP32 原模型中 BN、softmax 等尚未量化；没有 INT8 精度验证。逐层卷积参数共 236,112 个，单字节权重已需 236,112 B，完整参数按一字节也需 244,490 B，且未计偏置/量化参数。当前路由报告 [`phy.area`](../../work/td_cartoon/td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display_phy.area) 和 [`route.qor`](../../work/td_cartoon/td_project/camera_to_dsi_display_Runs/phy_1/route.qor) 给出 **14,848/21,216 Slice、39/108 ERAM20K、8/40 DSP**，即算术余量 6,368 Slice、69 ERAM20K = 176,640 B、32 DSP。这是现有卡通工程变体的 `project` 报告字段，不是检测器集成后的可用保证。卷积权重单独已超过空闲 ERAM 59,472 B，352 最大单张特征图超出 566,784 B。

若假设所有 32 DSP 均能以 100 MHz 达到**每 DSP 每拍 1 个有效 INT8 MAC**，352 的卷积下界 37.97 ms 已超过 30 fps 的 33.33 ms 帧间隔，尚未计权重读取、BN/激活、数据搬运和后处理。若假设每 DSP 每拍 2 个 INT8 MAC，理论下界约 18.98 ms，但打包、双路累加、布线和时序均未验证，不能算可用性能。32 是报表中未占用的 DSP 数，不是已证明可让检测器全部使用。

DDR2 频率、实际效率与视频读写布局尚未在当前接口契约中核实。仅作**假设预算**：16-bit DDR、时钟 133–200 MHz 时理论峰值 532–800 MB/s；720p RGB888 每帧写一次读一次、30 fps 为至少 165.9 MB/s；若 352 模型所有卷积输出都写回并读回，另需约 180.2 MB/s，未计权重、分支特征、突发损失和视频其他流量。逐层流式复用可降低 DDR 流量，但现有网络的上采样、跨尺度 concat 和权重容量仍需设计证明。没有 DDR 实测，**不能声明带宽足够**。

`work/rtl/yolo/conv_pe_int8.v` 仅是一个有符号 8×8 乘法、32 位累加与移位量化 PE；`work/models/yolo/micro_cnn_golden.py` 只有 Conv1 的随机测试权重和单 patch 自检。它们不能证明 FastestDet INT8 化、完整网络、NMS、资源或时序可行。本轮只读检查，未修改二者。

## Y1 判定与 Y2 最小计划

**Y1 PASS** 指三仓库审查、官方模型/测试图复现、三类真实图片与视频接口预览、独立集指标、四分辨率对比和硬件预算均有可审查产物。模型效果评审仍为 `VISUAL_REVIEW_PENDING`，G5 未通过。就当前权重与 352 输入，**FastestDet 直接硬件化 NO-GO**；手机召回尤其不足。既有“Micro-CNN 完全可行”“零 DDR 权重瓶颈”等强结论只是假设方案，不受本次实测支持。

Y2 最小入口：固定杯/瓶/手机工位定义和可授权标注集，保证训练、调参、独立测试按场景/拍摄批次隔离；先训练并比较 96/128/160 的三类微型检测模型及空场误报；再做 INT8 量化与软件等价验证，导出逐层真实权重、峰值存活特征、精度与资源预算。只有用户确认视觉效果、且权重/缓存/算力预算有余量后，才进入 RTL 设计。Y2 退出条件至少是预先冻结的三类 Precision/Recall、误检上限和模型大小均通过独立集测试；本轮不替用户猜验收阈值。
