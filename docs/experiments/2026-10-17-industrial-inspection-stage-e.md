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

## 2026-10-17 修正版回归与位流归档

- `project`：审计发现 TD 构建入口实际使用逐通道量化 `video_cartoon.v`，与登记册冻结的 `s3_luma` 版本不一致；已将 `scripts/build_industrial_td.py` 切换为 `work/rtl/video_cartoon_luma.v`，并将 HDMI 集成阈值统一为冻结值 `Sobel threshold=240`。
- `project`：新增 `work/tests/run_cartoon_luma_sim.py`，16×8 多帧输入覆盖 Original/Sobel/Cartoon、帧边界切换、帧内请求变化、空白周期和 sideband 延迟，Icarus 逐周期比较 `1102` 周期全部通过。
- `project`：新增 `fallback/tb_osd_led_joint.v`，验证 `NO_OBJECT` 状态文本完整显示 `NO_OBJECT` 的尾部 `C/T` 字符，并验证分类器状态与 PASS LED/检测 LED 同步；测试通过。
- `project`：新增 `fallback/tb_color_detect_golden.v` 与 `work/tests/run_industrial_rtl_golden.py`，由 Python 冻结硬件模型生成四像素输入，实际 RTL 逐帧比对 7 个连续帧（含空场、噪声、边界、孔洞、满屏、有效间歇）和 1 个非法 ROI，全部通过。
- `project`：修复 `industrial_osd_overlay.v` 的 `NO_OBJECT` 文本映射（补齐位置 14/15 的 `C/T`）。固定红色检测、模式、OSD/LED 和软件回归均重新通过。
- `project`：修正版 TD 产物已完成综合、布局、布线、Hold Fix、最终时序和 bitgen；`route.qor` 为 Setup WNS `+142 ps`、TNS `0`、Hold WNS `+21 ps`、TNS `0`、违规端点 `0`，资源为 `18,463 slices / 87.02%`、`35 RAM`、`24 DSP`。
- `project`：当前发布文件 `release/industrial-v1/camera_to_dsi_display_compress.bit` 大小 `1,339,505 bytes`，SHA-256 为 `886efa33c4f79d2f1f1b5fec5945bfce341efe1ab680c0ae53bb976f57038905`。此前 `6817f...` 哈希对应修正前位流，仅保留为历史记录，不再代表当前发布文件。
- `unknown`：本次仍未下载至 PH1P35，未连接 SC520CS/HDMI，也没有 LED、冷启动、热复位、长稳或显示效果证据；Stage G 仍未通过。TD 构建脚本依赖本机工具和官方基线工程绝对路径，干净环境复现仍需后续处理。
- `project`：上板操作与原始证据填写模板见 `docs/evidence/industrial-v1-stage-g-template.md`。

## 2026-10-17 本轮 TD 重建与发布证据校正

- `project`：提交 `abd35f7` 后使用显式 `--td-exe`、`--flow-tcl` 和 `--baseline-runs` 参数重新执行完整 TD 流程；综合、布局、布线、Hold Fix、Route QoR、最终时序和 bitgen 均以本轮日志完成，TD exit code 为 `0`。
- `project`：本轮 `route.qor` 为 Setup WNS `+142 ps`、Setup TNS `0`、Hold WNS `+21 ps`、Hold TNS `0`、违规端点 `0`；资源为 `18,463 slices / 87.02%`、`35 RAM`、`24 DSP`。
- `project`：当前压缩位流大小 `1,339,505 bytes`，SHA-256 为 `84a88f85fc1998e400aef8d85afe93707f9c62454651bc1782df7c1f2f5ea03c`；对应未压缩位流 SHA-256 为 `74d24e83668df5ef5f43847b126b92af9479abcecd717c7843ec4b423ad23a6f`。
- `project`：`release/industrial-v1/industrial-v1-manifest.json` 记录源码哈希、Git 提交、TD 输入路径、位流哈希、`route.qor` 和 `final_timing.rpt` 哈希；不再只依赖口头路径说明。
- `project`：补齐 `tb_industrial_subsystem.v` 的 `O_invalid → I_invalid` 连接后，联合 RTL 仿真重新通过；Icarus 仅剩形态学数组 `@*` 敏感列表告警，未发现浮空 INVALID 端口。
- `project`：本轮 TD 的 `SYN-5011/5025`、`HDL-5314/5317/5323`、`SYN-5065`、`PHY-5060/5016/5079/5088` 和 `PRJ-5611` 已按来源和风险建立归类记录，见 `docs/evidence/industrial-v1-td-warning-audit.md`；它们仍是 OPEN，不因正 WNS 自动关闭。
- `unknown`：仍无 PH1P35、SC520CS、HDMI 的下载和显示实测；Stage G、冷启动、热复位、LED 管脚、帧率、延迟和长稳均未验证。DDR 初始化宏的 `SYN-5011/SYN-5025` 告警仍需逐条归类，Slice 占用仍高于 80% 目标。

## 2026-10-17 HDMI 时序修复后的最新 TD 重建

- `project`：提交 `660bee5` 恢复官方 SC520 基线中的 `uivtc` 720p 时序发生器和 `hdmi_mixer`，解决集成顶层中 `S_hdmi_vsync/hsync/de` 及 `S_hdmi_out_*` 未驱动的契约缺口；新增 `work/tests/test_video_top_contract.py`，静态契约测试通过。
- `project`：在同一提交上重新执行 `python scripts/build_industrial_td.py`，TD `v6.2.168116` / `PH1P35MDG324 Speed 3` 综合、布局、布线、Hold Fix、Route QoR、最终时序和 bitgen 全部完成，exit code `0`。
- `project`：最终 Setup WNS `+101 ps`、Setup TNS `0`、Hold WNS `+20 ps`、Hold TNS `0`、违规端点 `0`；STA coverage `95.71%`。
- `project`：资源为 `20,861 slices / 98.33%`、`39 RAM`、`26 DSP`、`229 DRAMHARDCON`；`PHY-7022` 资源告警保持 OPEN，不能写成资源余量充足。
- `project`：压缩位流 `release/industrial-v1/camera_to_dsi_display_compress.bit` 大小 `1,356,849 bytes`，SHA-256 `e541b310defed61babe91f8a966fca7992f2a06a1154897d8cb3b1b68e9f057f`；未压缩位流大小 `1,789,539 bytes`，SHA-256 `dde77154113b0a17a2e1f1e4364be2b331ef21c2dfdafcc731d38a4f37814e74`。
- `project`：本轮软件/RTL回归 `run_industrial_rtl_golden.py`、`run_cartoon_luma_sim.py`、两个 build/top contract、工业视觉基准集和 Stage D/contract 测试均通过；FPGA Agent doctor 为 `Overall Environment Status: PASS`。
- `unknown`：仍无 PH1P35、SC520CS、HDMI 的下载和显示实测；Stage G、冷启动、热复位、LED 管脚、帧率、延迟和长稳均未验证。`SYN-5011/5025`、`HDL-5314/5317/5323`、`SYN-5065`、`PHY-5060/5016/5079/5088`、`PHY-7022` 和 `PRJ-5611` 仍 OPEN。

## 2026-10-17 OSD 字库资源优化后的最新 TD 构建

- `project`：按 TDD 先新增 `work/tests/test_osd_font_contract.py`，在旧版整字动态选位实现上正确失败；随后将 `fallback/rtl/industrial_osd_overlay.v` 的 35-bit glyph ROM 改为按字符和行输出 5-bit `glyph_row`，保持字符图案、OSD 状态文本和像素时序契约不变。
- `project`：使用同一 TD `v6.2.168116`、器件 `PH1P35MDG324 / Speed 3` 和官方基线 Runs 完成综合、布局、布线、Hold Fix、bitgen，exit code `0`。
- `project`：最终 Setup WNS `+116 ps`、Setup TNS `0`、Hold WNS `+20 ps`、Hold TNS `0`、违规端点 `0`；STA coverage `95.71%`。
- `project`：资源为 `20,159 slices / 95.02%`、`39 RAM`、`24 DSP`、`229 DRAMHARDCON`；相对上一版 `20,861/98.33%` 减少 `702 slices`，`PHY-7022` 仍 OPEN。
- `project`：压缩位流 `release/industrial-v1/camera_to_dsi_display_compress.bit` 大小 `1,356,145 bytes`，SHA-256 `77fd2acdc10d1fea6aadb180767a7b93af7c43748228d5c600669b820f9cf8d4`；未压缩位流大小 `1,789,539 bytes`，SHA-256 `278aac832d22e570ec6c00455084cf6c7aed421d52e68f37e77b30c7145e03d0`。
- `project`：工业 RTL/Golden、卡通化逐周期、构建/top/OSD 契约、工业视觉 5 项基准、Stage D/contract 测试均通过；`fallback/tb_osd_led_joint.v` 重新编译并运行通过。
- `unknown`：仍无 PH1P35、SC520CS、HDMI 的下载和显示实测；Stage G、冷启动、热复位、LED 管脚、帧率、延迟和长稳均未验证。厂商 IP/时钟告警和 `PHY-7022` 仍 OPEN。
