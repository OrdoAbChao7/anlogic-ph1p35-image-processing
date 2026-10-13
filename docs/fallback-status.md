# 备用路线（传统工业视觉检测）现状与演进规划

## 1. 现状盘点与资产继承

### 1.1 现有已实现模块审查
在原始项目资产（`HX1P35A2026/lab_ex1-3_SC520/lab_ex3_osd_SC520/lab_ex3_osd/user_source/hdl_source/isp/color_detect_96.v`）中，已经具备了一套可运行的 96-bit 4 像素流实时目标检测逻辑：
- **输入数据**：4 像素并行的 24-bit RGB（每个周期 96 位数据）
- **色彩空间转换**：硬件定点实现 RGB 到 YCbCr 转换（Q10 格式乘加逻辑）
- **颜色阈值二值化**：针对特定目标（如红色工件）进行色彩判别
- **几何统计特征计算**：
  - 动态计算包围盒（$x_{\min}, y_{\min}, x_{\max}, y_{\max}$）
  - 动态累加目标面积（`area`，19-bit 像素计数器）
  - 逐帧锁存并输出有效帧标志 `valid_frame`

### 1.2 现有实现状态评估
- **模块状态**：`IMPLEMENTED_UNVERIFIED`（已编写完整 Verilog，并在 Lab3 中引脚绑定，但缺乏针对零件测量的标定机制和形态学滤波）。
- **局限性**：易受椒盐噪声干扰，缺乏开闭运算，尚未对尺寸异常进行 PASS/NG 判定。

---

## 2. 备用路线任务演进阶段 (F1 ~ F5)

| 阶段编号 | 任务名称 | 目标交付物 | 当前状态 |
|---|---|---|---|
| **F1** | 现有代码复用与模块重构 | 将 `color_detect_96.v` 整合至备用工作区，规范端口与时钟域 | `IMPLEMENTED_UNVERIFIED` |
| **F2** | 基础视觉预处理与滤波 | 增加 3×3 腐蚀/膨胀形态学滤波核，消除孤立毛刺 | `PLANNED` |
| **F3** | 几何特征与尺寸测量 | 增加长宽比、质心计算，以及毫米级像素标定转换模块 | `PLANNED` |
| **F4** | PASS/NG 缺陷判定器 | 设定公差范围，输出零件合格判定，驱动 LED 与 HDMI OSD 显示框 | `PLANNED` |
| **F5** | 独立 TD 工程交付包 | 建立备用工作区的一键编译脚本与完整 README 说明 | `IN_PROGRESS` |


---

## 3. 开源参考映射与技术推荐清单 (F1 ~ F5)

结合 2026-10-13 完成下载与审计的 6 个安路开源工业视觉参考工程（位于 `.tools/references/anlogic-vision/`），针对 F1~F5 阶段建立具体的技术参考和避坑指引：

| 阶段 | 阶段任务 | 推荐参考工程与模块路径 | 关键技术借鉴点 | 注意事项与避坑 |
|---|---|---|---|---|
| **F1** | 现有代码复用与目标定位 | `05_vision_bbox_template`<br>(`import/dual_cam/bounding_box.v`) | • 单帧动态流式更新坐标极值 `(x_minr, x_maxr, y_minr, y_maxr)`<br>• `vsync` 边界锁存并在次帧直接计算几何中心点 | 注意 96-bit 4 像素流与单像素流的时钟与坐标步进差异（每拍 4 像素需要并行比较 4 个 X 坐标）。 |
| **F2** | 基础视觉预处理与滤波 | `06_ph1p35_vision_baseline`<br>(`rtl/isp/pixel_algorithm.v`)<br>`02_image_algorithm_library`<br>(`Main/q3q4/import/morphology_process.v`) | • 06 的无乘法器 BT.601 Y 灰度与无除法自适应二值化（倒数乘法 `146/2^27`）<br>• 02 的 3×3 两级比较树形态学膨胀/腐蚀流水线（Max2/Min2 函数级联） | 02 仓库无开源许可证，仅在 Python 模型中借鉴两级树算法，禁止复制代码；06 的倒数乘法可直接消除除法器。 |
| **F3** | 几何特征与尺寸测量 | `03_geometry_recognition`<br>(`MFIPP/RTL/Perimeter_aera.v`) | • 指定 ROI 内部通过 Sobel 计数累加周长 `Perimeter`<br>• 二值前景计数累加面积 `Aera`<br>• 计算面积/周长比与长宽比识别零件形状 | 避免引入 03 中的全图高阶 Hu 矩（资源过重）；除法计算应在帧尾空白期使用序列除法器或定点移位，避免打断实时流。 |
| **F4** | PASS/NG 缺陷判定器与 OSD | `05_vision_bbox_template`<br>(`import/dual_cam/bounding_box.v`<br>`import/other/motion_border_overlay.v`)<br>`06_ph1p35_vision_baseline`<br>(`rtl/overlay/logo_overlay.v`) | • 05 的次帧视频流动态绘制边界框（落在线框范围强制替换为绿/红像素）<br>• 06 的官方安路 Logo ROM 叠加与状态文字 OSD | 边框叠加逻辑经历与视频一致的流水延迟，避免线框与画面错位。 |
| **F5** | 独立 TD 工程交付包 | `06_ph1p35_vision_baseline`<br>(`rtl/app/vision_pipeline.v`<br>`vendor_reference/`)<br>`04_ph1p35_bbox_cnn`<br>(`doc/route_failure_notes.md`) | • 06 的平台层（官方原语/IP）与应用层（视觉流水线）严格解耦架构<br>• 04 的重大教训：严禁用 Verilog 组合逻辑展开大型查找表（导致布线 3 小时崩溃） | 保持时序收敛（Setup WNS > 0），特征图或权重严格使用 BRAM IP/MIF 实例化。 |

*注：本映射仅作为各阶段实现的架构与算法依据，F1~F5 的实现与验证状态维持不变。*
