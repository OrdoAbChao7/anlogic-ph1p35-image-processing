# 固定红色零件工业视觉第一版设计

## 目标

在 HX1P35A / PH1P35MDG324 上形成一个可复现的单 `.bit` 现场演示版本：SC520CS MIPI 输入，经 ISP、DDR2 和三种图像模式处理后输出 HDMI；并在固定工位内检测一种红色零件，输出 `PASS/NG/NO_OBJECT/INVALID`、BBox、尺寸、类别和总数。

## 范围冻结

第一版包含：

- 原图、Sobel、卡通化三种模式；
- 按键在帧边界切换模式；
- 安路 Logo、模式、帧计数和工业检测 OSD；
- 固定 ROI 的 `red_part` 单目标检测，数量 `0/1`；
- 3×3 开运算、面积、BBox、宽高、公差比较和 LED 联动；
- 所有运行时逻辑和静态资源内嵌到一个 `.bit`。

第一版不包含：

- YOLO/Micro-CNN、INT8 MAC、NMS、多类别和多目标；
- WM8978 语音播报；
- 未标定的毫米级尺寸承诺；
- 运行时软件或外部权重/字体/参数文件。

## 数据流

```text
SC520CS RAW10
  → MIPI D-PHY / CSI-2
  → ISP：Bayer + 白平衡
  → DDR2 帧缓存
  → RGB 视频流分叉
      ├─ Original
      ├─ Sobel：Line Buffer + 3×3 梯度
      ├─ Cartoon：颜色量化 + 区域填充 + Sobel 轮廓
      └─ Inspection：Q10 分割 + 3×3 开运算 + BBox/尺寸/判定
  → 帧边界结果锁存
  → Logo/文字/检测框 OSD + LED
  → HDMI 720p
```

检测分支与显示模式并行。检测结果在帧尾锁存，OSD 在下一帧使用稳定结果，避免边框和文字随扫描位置变化。

## 检测契约

- 红色分割：`85<Cb<125` 且 `135<Cr<200`；Q10 偏置 `131072`，右移 `10`。
- 形态学：3×3 opening，边界为 `BORDER_REPLICATE`。
- 初始参数：最小面积 `100 px`，标准尺寸 `120×80 px`，宽/高公差 `±15/±12 px`。
- 结果：`PASS`、`NG`、`NO_OBJECT`、`INVALID`。
- 尺寸：第一版只输出像素宽高；毫米换算另行标定后再纳入。
- RTL 必须把面积计数器扩展到至少 20 bit，并统一 `Cr<200` 契约。

## 模块边界

| 模块 | 责任 | 输出 |
|---|---|---|
| `video_base` | MIPI、ISP、DDR2、HDMI 边界和时钟复位 | RGB 视频流和同步 |
| `mode_controller` | 按键同步、去抖、帧边界模式更新 | `ORIGINAL/SOBEL/CARTOON` |
| `sobel_stream` | Line Buffer、3×3 窗口、梯度和饱和 | Sobel 像素流 |
| `cartoon_stream` | 颜色量化、区域填充、轮廓融合 | 卡通像素流 |
| `industrial_detector` | 分割、形态学、面积、BBox、尺寸判定 | 帧锁存检测结果 |
| `osd_overlay` | Logo、字体、模式、计数、状态和检测框 | HDMI 像素替换 |
| `event_outputs` | PASS/NG/NO_OBJECT/INVALID 到 LED | LED 状态 |

厂商 MIPI、DDR2、HDMI、PLL 和管脚接口在 G1/G2 审计前不猜测、不重写；算法模块只依赖冻结后的 RGB 流契约。

## 阶段门

1. G1：原图链路完成构建、下载、冷启动、热复位和连续观察。
2. G2：冻结像素格式、位宽、同步、时钟域、CDC 和延迟。
3. G3/G4：三模式、Sobel、卡通化完成软件/RTL 比对和按键验证。
4. G5：固定红色检测完成边界、空场、标准件和超差件验证。
5. G6：Logo、模式、帧计数、检测框、类别、总数、尺寸和 LED 在整机中一致。
6. G7/G8：完成时序、资源、长稳、单 `.bit` 下载和发布包验收。

## 通过条件

- 同一个 `.bit` 能完成摄像头显示、三模式切换和红色零件检测；
- 空场、标准件、超差件、复位和模式切换行为符合预期；
- 冷启动、热复位、重新下载和长稳测试有原始证据；
- WNS/TNS、资源、帧率和端到端延迟来自实际工程或实测；
- 源码、约束、IP 配置、Bitstream 哈希和演示步骤可复现。
