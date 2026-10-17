# 全系统模块验证矩阵 (Verification Matrix)

本矩阵严格遵循工程事实，标记各项功能的当前真实状态：
- `VERIFIED_ON_BOARD`：真板硬件已验证通过
- `BUILD_PASS`：TD 综合/实现/Bitstream 生成通过
- `SIM_PASS`：RTL 仿真与 Golden Model 对齐通过
- `IMPLEMENTED_UNVERIFIED`：已编写 RTL，但尚未通过完整验证
- `PLANNED`：已完成架构设计，尚未编码
- `BLOCKED`：受硬件、工具或资料缺口阻塞

---

## 1. 基础视频与显示链路 (底座)

| 功能模块 | 代码位置 | 验证级别 | 证据出处与说明 |
|---|---|---|---|
| **SC520CS MIPI RX** | `uics520_cfg/`, `uiisp_beta/` | `VERIFIED_ON_BOARD` | 用户实测已出实时画面；TD QoR Setup WNS > 1ns |
| **Demosaic (拜耳转RGB)**| `isp/demosaic_4x_2_0/` | `VERIFIED_ON_BOARD` | 组员工程与 TD 实现验证 |
| **DDR2 控制器** | `ph1p35_ddr/` | `VERIFIED_ON_BOARD` | 720p@30fps 帧缓存闭环 |
| **HDMI 输出** | `video_out.v`, `pll_hdmi.v` | `VERIFIED_ON_BOARD` | 稳定输出 720p 视频时序 |

---

## 2. 主线：YOLO-tiny 智能视觉系统

| 功能模块 | 代码位置 | 验证级别 | 证据出处与说明 |
|---|---|---|---|
| **卡通化流式滤波** | `work/rtl/video_cartoon_luma.v` | `BUILD_PASS` / `SIM_PASS` | iverilog 5329 周期无缝通过；TD 6.2 路由 Setup WNS 1389ps |
| **Python 黄金参考模型** | `work/models/cartoon_luma_reference.py` | `SIM_PASS` | 逐像素与 RTL 严格位对齐 |
| **YOLO 硬件可行性论证** | `docs/yolo-feasibility.md` | `SIM_PASS` | 算力与存储定量推导，确立片上 Micro-CNN 路线 |
| **轻量卷积加速单元 (PE)** | `work/rtl/yolo/` | `PLANNED` | 下一阶段攻坚核心 |
| **OSD 智能检测框叠加** | `work/rtl/osd/` | `PLANNED` | 基于坐标与置信度动态划线与安路 Logo 融合 |

---

## 3. 备用线：传统工业视觉检测系统

| 功能模块 | 代码位置 | 验证级别 | 证据出处与说明 |
|---|---|---|---|
| **四像素并行色彩二值化** | `color_detect_96.v` | `IMPLEMENTED_UNVERIFIED` | 原始 Lab3 RTL 完整保留，需补充 Testbench |
| **实时包围盒与面积统计** | `color_detect_96.v` | `IMPLEMENTED_UNVERIFIED` | 动态统计 xmin/ymin/xmax/ymax 及面积 |
| **形态学滤波 (开闭运算)**| `fallback/morphology/` | `PLANNED` | 规划消除孤立噪点 |
| **工件尺寸公差判定** | `fallback/defect_eval/` | `PLANNED` | 判定合格/异常并输出控制信号 |

---

## 4. 当前固定红色 v1 验收矩阵（2026-10-17）

| 要求 | 当前证据 | 状态边界 |
|---|---|---|
| Original/Sobel/Cartoon 帧边界切换 | `work/tests/run_cartoon_luma_sim.py`，1102 周期逐周期通过 | `SIM_PASS`；未上板 |
| 红色 Q10 分割、3×3 opening、BBox、面积 | `tb_morph_open_96.v`、`tb_color_detect_96_v2.v`、`tb_color_detect_96_v2_boundaries.v` | `SIM_PASS`；未上板 |
| PASS/NG/NO_OBJECT/INVALID 与 LED | `tb_defect_classifier.v`、`tb_osd_led_joint.v`、`tb_industrial_subsystem.v` | `SIM_PASS`；管脚未实测 |
| Logo、模式、帧计数、类别、尺寸和状态 OSD | `fallback/rtl/industrial_osd_overlay.v`，整机 TD 集成；OSD/LED 联调 | `BUILD_PASS`；显示效果未实测 |
| 单文件下载 | `release/industrial-v1/camera_to_dsi_display_compress.bit`，SHA-256 `e9815a4a42f085d26cb8744c0d5a485020d3ece3e1a1bb7aff20d92264de68d3`；manifest 同目录 | `BUILD_PASS`；未下载 |
| Timing/resource | 第二次 `route.qor`：Setup WNS +103 ps、Hold WNS +20 ps、TNS 0；Slice 79.43%、RAM 43、DSP 24，STA coverage 96.52% | 时序和资源门禁通过；告警与板级状态仍待关闭 |
