# 固定红色零件检测 v1：Stage E/F 当前记录

- 日期：2026-10-17
- 版本：v1.0-approved（Stage C 已由用户确认 VISUAL_APPROVED）
- 当前分支：fallback/industrial-inspection
- 证据边界：以下 RTL/软件/TD 证据来自当前工作区；没有板卡下载或显示器实测，不代表 Stage G 已通过。

## 已通过

| 层级 | 结果 | 证据 |
|---|---|---|
| Stage D 硬件等价软件模型 | PASS | python work/algorithm_lab/test_stage_d.py，5/5 |
| 工业视觉软件合同 | PASS | python work/algorithm_lab/test_industrial_contract.py，4/4 |
| 工业视觉基准集 | PASS | python work/algorithm_lab/test_industrial_inspection.py，5/5、100% 一致 |
| 3×3 开运算 RTL | PASS | tb_morph_open_96.v，连续行、帧排空、全前景和孤立噪声 |
| 红色检测 RTL | PASS | tb_color_detect_96_v2.v，全帧面积 921600、BBox 0/0/1279/719 |
| Q10 阈值边界 RTL | PASS | tb_color_detect_96_v2_boundaries.v，四个端点严格开区间 |
| 判定器 RTL | PASS | tb_defect_classifier.v，PASS/NG/NO_OBJECT/INVALID 与 LED 互斥 |
| 工业子系统 RTL | PASS | tb_industrial_subsystem.v，标准件、超差件、空场、绿/红框 |
| 按键模式控制 | PASS | tb_mode_controller.v，消抖、帧边界提交、优先级和释放复原 |
| OSD/Logo RTL 静态编译 | PASS | Icarus -tnull 编译 anlogic_logo_rom.v + industrial_osd_overlay.v |

## TD 构建证据

- 构建入口：python scripts/build_industrial_td.py
- 工具：Tang Dynasty v6.2.168116；器件 PH1P35MDG324，Speed 3。
- 本轮流程：综合、布局、布线、Hold Fix、Route QoR、最终时序、bitgen 均完成；TD flow 统计总时长约 4m33s。
- 最终 Setup WNS：+142 ps；Setup TNS：0；违规端点：0。
- 最终 Hold WNS：+21 ps；Hold TNS：0；违规端点：0。
- 资源：18,463 slices / 87.02%；35 RAM；24 DSP；该 Slice 占用高于项目目标的 80% 上限，属于发布风险，不应写成资源余量充足。
- 综合日志存在厂商 DDR 初始化宏的 undriven-pin warnings；本轮未修改厂商 DDR IP，需在后续告警归类中处理。

## 发布位流

- 文件：release/industrial-v1/camera_to_dsi_display_compress.bit
- 大小：1,339,505 bytes
- SHA-256：6817f946be06340ede434146a17f343ecc68dbf4e3f2e492252b3c79354d7b49
- 该位流尚未在 PH1P35 板卡上下载、冷启动、热复位、接摄像头和显示器实测。

## 下一步

1. 在有板卡、SC520CS 和 HDMI 显示器后下载发布位流，记录冷启动、热复位、三种模式和 PASS/NG/NO_OBJECT/INVALID。
2. 处理 Slice 87.02% 资源风险和厂商告警，再决定是否冻结发布版本。
3. 在板级证据齐全前，不能把本版本写成可上板稳定。