# GitHub 参考工程总表

这些仓库用于学习协议、视频链路、图像算法和验证方法。它们面向不同 FPGA 平台，默认不能直接移植到 PH1P35。

| 仓库 | 平台/语言 | 主要关联 | 适配等级 | 使用边界 |
|---|---|---|---|---|
| [lifeng0718/Multifunctional-video-processing-platform](https://github.com/lifeng0718/Multifunctional-video-processing-platform) | 安路 PH1A90 / Verilog | 多模式视频切换、HDMI拼接/旋转 | B | 仅学习多模式切换与降采样架构 |
| [maojinxiang/FPGA-ANLU-National-First-Prize](https://github.com/maojinxiang/FPGA-ANLU-National-First-Prize) | 安路 EG4S20 / Verilog | 3×3 腐蚀膨胀流水线、Sobel、Line Buffer | B | **无 License，严禁复制代码**；仅学习流水比较树 |
| [InitialXE/Multi-Function-Image-Processing-PLAT](https://github.com/InitialXE/Multi-Function-Image-Processing-PLAT) | 安路 EG4S20 / Verilog | 流式周长/面积统计、形状识别、Hu矩 | B | 重点参考 ROI 边缘与面积计数法 |
| [YuxiangJia111/FPGA_ANLU_National_First_Prize](https://github.com/YuxiangJia111/FPGA_ANLU_National_First_Prize) | **安路 PH1P35** / Verilog | 连通域多目标 BBox、CNN 裁剪适配器 | A | **重点避坑**：布线失败教训；学习 Bitmap 双 Bank 连通域 |
| [zdxddmx/anlogic_fpga_vision_udp](https://github.com/zdxddmx/anlogic_fpga_vision_udp) | 安路 EG4S20 / Verilog | 流式单目标 BBox、边框叠加、模板匹配 | A | **MIT**；单帧极值更新+次帧画框最佳参考 |
| [Aurora-520/anlogic-ph1p35-vision](https://github.com/Aurora-520/anlogic-ph1p35-vision) | **安路 PH1P35** / Verilog | 解耦架构、无乘法器 Y、自适应二值、Sobel、卡通、Logo OSD | A | **首选架构基线**；无除法自适应二值与零乘法器灰度 |
| [FHDO-ICLAB/MIPI-CSI-2-HDMI-Bridge](https://github.com/FHDO-ICLAB/MIPI-CSI-2-HDMI-Bridge) | GateMate / Verilog | MIPI CSI-2、Framebuffer、DVI | C | 只看链路结构 |
| [circuitvalley/mipi_csi_receiver_FPGA](https://github.com/circuitvalley/mipi_csi_receiver_FPGA) | Lattice / Verilog | 通用 MIPI 接收 | C | README 标注 Legacy，只看协议和模块划分 |
| [georgeyhere/fpga-video-processing](https://github.com/georgeyhere/fpga-video-processing) | Artix-7 / Verilog | 灰度、Gaussian、Sobel、FIFO、HDMI | B | 重点借鉴图像流水线 |
| [Galapple/Image-processing---Verilog](https://github.com/Galapple/Image-processing---Verilog) | PYNQ-Z2 / Verilog | Line Buffer、3×3、Sobel、FIFO | B | 重点借鉴 Sobel 和仿真 |
| [olivier-le-sage/camera-filters](https://github.com/olivier-le-sage/camera-filters) | Spartan-7 / VHDL | MIPI 到 HDMI 中间的颜色处理 | B | 借鉴定点颜色处理，不能直接用底层接口 |
| [hdl-util/hdmi](https://github.com/hdl-util/hdmi) | 多平台 / SystemVerilog | HDMI/DVI 输出、视频模式、文字模式 | C | 只作 HDMI 时序和 OSD 参考 |
| [cliffordwolf/SimpleVOut](https://github.com/cliffordwolf/SimpleVOut) | 多平台 / Verilog | VGA/DVI/HDMI 输出、视频 DMA、Overlay | C | 只作视频输出结构参考 |
| [hdl-util/mipi-demo](https://github.com/hdl-util/mipi-demo) | 多平台 | MIPI CSI-2 和 MIPI CCS | C | 只看协议示例 |
| [gatecat/CSI2Rx](https://github.com/gatecat/CSI2Rx) | Xilinx / VHDL | CSI-2 Receiver | C | 不移植 PHY 和器件原语 |

## 快速开发检索指引（后续 AGY/Codex 专项任务导航）

当后续会话需要具体实现某功能时，请直接参考以下映射：

1. **“我要做 Sobel 边缘检测与无乘法器灰度，先看哪个项目？”**
   - **首选**：`Aurora-520/anlogic-ph1p35-vision`（文件：`rtl/isp/pixel_algorithm.v`）。
   - **亮点**：移位无乘法器 BT.601 Y 灰度提取、双 BRAM 行缓存、流水线计算 `|Gx|+|Gy|`、时序零违例。
   - **辅助**：`maojinxiang`（文件：`Main/q3q4/import/sobel_process.v`）。

2. **“我要做形态学（腐蚀/膨胀/消噪），先看哪些 RTL？”**
   - **首选**：`zdxddmx/anlogic_fpga_vision_udp`（文件：`import/other/image_erode_filtering.v`, `image_dilate_filtering.v`，MIT 许可证）。
   - **算法参考**：`maojinxiang`（文件：`Main/q3q4/import/morphology_process.v`，两级比较树计算 3×3 Max/Min；仅学算法思路，不复制代码）。

3. **“我要做 Bounding Box 目标外接矩形框，哪个安路项目最接近？”**
   - **单目标检测与实时画框（极简高时序）**：`zdxddmx/anlogic_fpga_vision_udp`（文件：`import/dual_cam/bounding_box.v`）。流式极值更新 + 次帧边界绘蓝框，资源极少。
   - **多目标连通域检测与独立 BBox**：`YuxiangJia111/FPGA_ANLU_National_First_Prize`（文件：`user_source/hdl_source/digit_multi_bbox.v`）。3×3 采样紧凑 Bitmap + 双 Bank 连通域扫描合并，支持输出多达 8 个框。

4. **“我要在 PH1P35 上实现面积、周长和几何尺寸测量，参考什么？”**
   - **首选**：`InitialXE/Multi-Function-Image-Processing-PLAT`（文件：`MFIPP/RTL/Perimeter_aera.v`）。在工位 ROI 内部统计 Sobel 像素得周长、统计前景像素得面积，通过面积/周长比识别零件几何形态。

5. **“我要做 HDMI OSD 画面叠加与安路 Logo，参考什么？”**
   - **首选**：`Aurora-520/anlogic-ph1p35-vision`（文件：`rtl/overlay/logo_overlay.v`, `rtl/overlay/anlogic_logo_rom.v`）。
   - **动态边框叠加**：`zdxddmx/anlogic_fpga_vision_udp`（文件：`import/other/motion_border_overlay.v`）。

## 适配等级

- A：算法或验证代码可以直接参考（同器件或高契合度）。
- B：模块结构可以参考，需要改接口和时序。
- C：只适合协议和架构学习。
- D：与当前项目关联较弱。

## 选择原则

优先阅读带有完整 README、模块图、仿真说明和许可证的仓库。任何直接进入比赛工程的代码，都需要重新检查平台原语、时钟、复位、数据位宽、视频时序和许可证。

