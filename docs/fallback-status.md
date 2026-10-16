# 固定红色零件 v1 状态与历史资料

> **2026-10-17 当前版本校正：** 本文第 6 节及 F1/F5 表格中的旧 TD 位流、旧 QoR 和旧哈希是历史记录，不是当前 v1 的证据。当前可确认的是 Stage D、RTL 独立仿真、模式控制仿真和 OSD 静态编译；本次 TD 构建以 [Stage E/F 记录](experiments/2026-10-17-industrial-inspection-stage-e.md) 为准，Stage G 尚无硬件实测。


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
- **模块状态**：已完成升级重构为 `color_detect_96_v2.v`，增加全流水线打拍打断 DSP 关键路径，时序收敛达到 Setup WNS > 0。
- **TD 工程**：独立 `work/td_industrial` 已生成位流，最终时序报告为正裕量；但仍有 `PHY-5079`/`PHY-5088` 时钟告警，且没有当前板卡下载、显示器或长稳证据，不能写成板级已验证。

---

## 2. 备用路线任务演进阶段 (F1 ~ F5)

| 阶段编号 | 任务名称 | 目标交付物 | 当前状态 | 验证依据 |
|---|---|---|---|---|
| **F1** | 现有代码复用与模块重构 | 将 `color_detect_96.v` 升级为稳态双缓冲全流水 `color_detect_96_v2.v`，输出零抖动 | `SIM_PASS / TD_BUILD_PASS，行为缺口 OPEN` | `tb_industrial_subsystem.v` 覆盖的三类场景通过；TD 综合布局通过；19-bit `area` 全帧覆盖与行边界契约仍未关闭 |
| **F2** | 基础视觉预处理与滤波 | 增加 3×3 腐蚀/膨胀形态学滤波核，消除孤立毛刺 | `ALGO_VERIFIED` | 软件先行开运算消噪验证通过（5 组工位对比基准） |
| **F3** | 几何特征与尺寸测量 | 流式坐标差与包围盒长宽提取 (`W = xmax - xmin + 1, H = ymax - ymin + 1`) | `SIM_PASS / TD_BUILD_PASS，待板级` | `defect_classifier.v` 离线仿真与 TD 报告；尚无板级尺寸实测 |
| **F4** | PASS/NG 缺陷判定器 | 设定公差范围，输出零件合格判定，驱动 LED 与 HDMI OSD 绿/红边框 | `SIM_PASS / TD_BUILD_PASS，待板级` | `defect_classifier.v` + `bbox_draw_overlay.v` 离线仿真；管脚连接尚未由下载实测证明 |
| **F5** | 独立 TD 工程交付包 | 建立备用工作区的一键编译脚本与完整交付物 | `TD_BUILD_PASS，复现性与告警 OPEN` | TD 编译成功，Bitstream 生成，最终 Setup WNS = +221 ps；构建脚本仍含外部工程绝对路径，告警未分类 |

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

*注：本映射仅作为各阶段实现的架构与算法依据。*

---

## 4. 软件先行（Software-First）视觉验收归档 (Stage C)

- **交付物**：在 Algorithm Lab 中上线专用插件 [`plugins/industrial_inspection.py`](../work/algorithm_lab/plugins/industrial_inspection.py)，生成 5 组基准工位实测对比图（`work/algorithm_lab/exports/industrial_inspection_preview/`）。
- **验收状态**：`VISUAL_APPROVED`（用户于 2026-10-16 明确确认全部视觉效果通过，冻结版本 `v1.0-approved`）。
- **对比证据**：软件浮点参考模型与硬件定点模型在标准件（PASS）、超差件（NG）、欠尺寸件（NG）、空场（NO_OBJECT）、150点椒盐噪声开运算消噪（PASS）全部 5 项测试中达成 100% 判定与尺寸吻合；2026-10-16 另增加 ROI、非法 ROI 和参数预设回归。详见当前实验记录 [`docs/experiments/2026-10-16-industrial-inspection-algorithm-lab.md`](experiments/2026-10-16-industrial-inspection-algorithm-lab.md)。

## 5. 软件先行 Stage D：硬件等价模型冻结与回归

- **状态**：`PASS (software-only)`。冻结契约、参数哈希、输入样本哈希和逐像素报告见 [`work/algorithm_lab/exports/stage_d/stage_d_report.json`](../work/algorithm_lab/exports/stage_d/stage_d_report.json)；复现入口为 `python work/algorithm_lab/verify_stage_d.py`。
- **结果**：5 个冻结样本的 raw mask、3×3 形态学后 mask 均 `different_pixels=0 / MAE=0 / PSNR=inf`，判定、BBox、宽高和面积逐字段一致；Q10 严格阈值、`Y=60/59`、ROI 边界、非法 ROI 和 `BORDER_REPLICATE` 边界向量通过 `5/5` Stage D tests。
- **证据边界**：本阶段只证明 PC 软件参考模型与硬件等价软件模型一致，不证明 RTL、整机视频、TD 构建或 PH1P35 上板结果。下一步可进入 Stage E 的 RTL 等价仿真，但仍不得据此宣称板级实现。

---

## 6. 板级硬件实现与构建证据 (Stage F)

- **构建入口**：`python scripts/build_industrial_td.py`
- **目标器件**：Anlogic `PH1P35MDG324`，Speed Grade 3
- **综合与物理实现环境**：Tang Dynasty v6.2.168116
- **编译时间**：2026-10-13 20:09

### 6.1 QoR 时序与资源收敛指标 (`route.qor`)

| 指标项 | 测量值 | 验收门限 | 结论 |
|---|---|---|---|
| **Setup WNS** | **+221 ps (+0.221 ns)** | $> 0$ ps | **MET (收敛)** |
| **Setup TNS** | **0 ps** | $= 0$ ps | **MET (无违例)** |
| **Hold WNS** | **+20 ps (+0.020 ns)** | $> 0$ ps | **MET (收敛)** |
| **Hold TNS** | **0 ps** | $= 0$ ps | **MET (无违例)** |
| **NUM_FEPS** | **0** | $= 0$ | **MET (0 个违例端点)** |
| **LUT6 占用** | 13,089 / 21,216 (61.69%) | $< 85\%$ | **PASS (余量 38.31%)** |
| **Slice Reg 占用**| 14,568 / 42,432 (34.33%) | $< 70\%$ | **PASS (余量 65.67%)** |
| **ERAM20K (BRAM)**| 39 / 108 (36.11%) | $< 80\%$ | **PASS (余量 63.89%)** |
| **DSP 乘法器** | 24 / 40 (60.00%) | $< 80\%$ | **PASS (余量 40.00%)** |

### 6.2 交付物与校验哈希 (`work/output/industrial-release/`)

| 文件名 | 大小 (Bytes) | SHA-256 校验哈希 | 用途说明 |
|---|---|---|---|
| `camera_to_dsi_display.bit` | 1,789,539 | `f599af5ecc7448f82199ce306a62fd443eb0cad0f8a2b06308f86afe6e650848` | 标准 FPGA 位流文件 |
| `camera_to_dsi_display_compress.bit` | 1,342,705 | `fbd7e0ff50a72d265fc9abcf541bd9dadbf6e9c3d5c92ac156856b19dfa85850` | 压缩位流文件（下载更快） |
| `route.qor` | 1,313 | — | TD 官方时序收敛 QoR 总结 |
| `final_timing.rpt` | 4,730,648 | — | 全系统所有时钟域详细 STA 时序报告 |

### 6.3 物理引脚绑定确认 (`pin.adc`)

依据官方 `HX1P35A原理图.pdf`：
- **`O_led_pass`** $\rightarrow$ `D10`（板载用户 `LED1`，工件尺寸合格时常亮）
- **`O_led_ng`** $\rightarrow$ `E10`（板载用户 `LED2`，工件超差/缺陷时亮起）
- **`O_led_det`** $\rightarrow$ `C6`（板载用户 `LED3`，检测到有效工件时点亮）
- **HDMI 差分输出** $\rightarrow$ `G16/H16` (CH0), `F17/E18` (CH1), `H14/H13` (CH2), `C17` (CLK)

---

## 7. 上板实机操作与验证指南 (Stage G，待执行)

以下内容是待用户具备板卡、摄像头和显示器后的操作草案，不是当前硬件验证证据；当前仍无下载日志、屏幕截图、帧率、长稳或 LED 实测记录。

1. **硬件连接**：
   - 将 SC520CS RAW10 MIPI 摄像头模组接入板载 MIPI 接口。
   - 将 HDMI 线缆连接至显示器（支持 720p 30/60Hz）。
   - 将 USB JTAG 下载器连接至 PC。
2. **下载位流**：
   - 打开 Tang Dynasty 编程器（Programmer）。
   - 添加位流：`E:\Projects\FPGA-fallback\release\industrial-v1\camera_to_dsi_display_compress.bit`。
   - 点击 **Program** 烧录至 PH1P35 SRAM。
3. **视觉测试**：
   - **空场测试**：无工件时，HDMI 画面显示原始/卡通化摄像头画面，无任何边框，`LED1/LED2/LED3` 均熄灭。
   - **标准件检测 (PASS)**：将标称尺寸约 $120\times 80$ 像素的红色工件置于视场中央，HDMI 画面实时紧贴工件绘制 **绿色高亮边界框**，板载 `LED1 (D10)` 与 `LED3 (C6)` 稳定常亮，`LED2` 熄灭。
   - **超差件检测 (NG)**：将宽度超标（$>135$ 像素）的工件置于视场中，HDMI 画面边界框立即切换为 **红色高亮警示框**，板载 `LED2 (E10)` 点亮报警，`LED1` 熄灭。

## 8. 当前固定红色 v1 状态校正（2026-10-17）

当前发布口径以 `docs/experiments/2026-10-17-industrial-inspection-stage-e.md` 的最新记录为准：TD 已使用批准的 `s3_luma` 卡通化 RTL，并恢复官方 720p `uivtc`/`hdmi_mixer` 时序链路；三模式、固定红色检测、OSD/LED 联调和 TD 位流生成均有当前工作区证据。当前压缩位流 SHA-256 为 `e541b310defed61babe91f8a966fca7992f2a06a1154897d8cb3b1b68e9f057f`。旧表中的资源、时序和哈希不能用于描述当前版本。

当前仍未关闭：PH1P35 + SC520CS + HDMI 实机下载验证、冷启动/热复位/长稳、摄像头画面与三模式效果、LED 管脚实测、厂商 DDR undriven-pin 告警分类、PHY-7022 资源占用 98.33% 高于 80% 目标，以及从无本机绝对路径的干净环境重建。

## 9. 2026-10-17 本轮重建证据

- `project`：提交 `660bee5` 后，`scripts/build_industrial_td.py` 使用显式 TD/基线路径完成 TD 综合、布局、布线、Hold Fix、QoR、时序和 bitgen，TD exit code `0`。
- `project`：当前报告位于 `release/industrial-v1/route.qor` 与 `release/industrial-v1/final_timing.rpt`；Setup WNS `+101 ps`、Hold WNS `+20 ps`、TNS 均为 `0`，Slice `20,861/98.33%`、RAM `39`、DSP `26`。
- `project`：当前推荐下载文件为 `release/industrial-v1/camera_to_dsi_display_compress.bit`，SHA-256 `e541b310defed61babe91f8a966fca7992f2a06a1154897d8cb3b1b68e9f057f`；同目录 manifest 绑定了本轮源码和全部发布文件哈希。
- `project`：`tb_industrial_subsystem.v` 已补齐 INVALID 信号连接，重新编译联合仿真通过；没有硬件实测，因此不改变 Stage G 待上板状态。
