# fixed-red v1 第一版要求逐项审计

审计对象：fixed-red v1 当前发布位流对应的提交 `af0d8e842459f93a00121332a3b24176aa1d5dbc`；发布目录中的 `industrial-v1-manifest.json` 是位流、源码和报告哈希的最终权威。本表严格区分仿真/构建证据与真实板卡证据。没有 PH1P35、SC520CS 和 HDMI 实物参与的项目，不能标记 `VERIFIED_ON_BOARD`。

## 2026-10-18 当前复核补充

- 早期 9-bit 量化索引比较候选因 TD Slice 从 `17,403/82.03%` 增加到 `17,567/82.80%` 被拒绝；四态 LED 候选随后被固定 ROI 合同构建替代，旧正式包保留在 `release/candidates/industrial-v1-pre-roi-contract/`。
- 回归阶段执行过目标契约、全量 Python 测试、1280×720 三模式全帧仿真和完整工业回归；当前 guarded VTC/mixer 版本结果为 `49 passed`、`PASS 2938270 cycles`、`13/13`；CDC 测试确认检测结果只在 HDMI 帧边界整体提交，顶层 LED 契约确认 LED 消费同一套 HDMI 域原子结果。
- 当前正式位流为 `release/industrial-v1/camera_to_dsi_display_compress.bit`，SHA-256 为 `ba451dddce56234c0e7e5801af28fa11f209d4522978ac92e668ad7554f3c53e`。以上构建证据仍不改变所有硬件验收项的 `NOT_RUN` 状态。
- 另一次删除 Cartoon RAM `ram_style` 属性的候选也已完成隔离 TD 构建和全帧仿真；候选 Slice `17,694/83.40%`、Setup WNS `101 ps`，较正式版本退化，故已拒绝。证据见 [`no-ram-style TD 归档`](industrial-v1-td-logs/industrial-v1-20261018-no-ram-style/)。
- 固定 ROI 顶层合同随后完成 TDD、完整 13 项回归和隔离 TD 构建；当前正式位流 QoR 为 Slice `17,679/83.33%`、Setup/Hold WNS `+104/+20 ps`。`INVALID=110`（`{O_led_pass,O_led_ng,O_led_det}`）与 `NO_OBJECT=000` 明确区分；物理 LED 管脚仍未确认，故上板状态仍为 `NOT_RUN`。

## 功能审计

| 要求 | 当前证据 | RTL/TD 状态 | 上板状态 |
|---|---|---|---|
| Original 原图显示 | `fallback/td_source/design_top_wrapper.v` 的显示模式集成；完整 TD 工程通过 | `PASS`（整机 build） | `NOT_RUN` |
| Sobel 模式 | `work/tests/run_cartoon_region_fill_sim.py --full-frame`，Original/Sobel/Cartoon 1280×720 全帧逐周期比较 | `PASS`（仿真 + build） | `NOT_RUN` |
| Cartoon 模式 | `fallback/rtl/video/video_cartoon_region_fill.v`，冻结 `s4-region-fill-v1`：逐通道 8 级量化、四邻域填充和 Sobel 融合；1280×720 全帧逐周期测试 | `PASS`（仿真 + build） | `NOT_RUN` |
| 帧边界模式切换 | `fallback/sim/control/tb_mode_controller.v`；去抖、按键优先级、帧边界提交和释放复原；顶层 `I_button[0]`/`I_button[1]` 分别接入 Sobel/Cartoon 请求 | `PASS`（RTL + 顶层契约） | `NOT_RUN` |
| Q10 红色分割 | `fallback/rtl/inspection/color_detect_96_v2.v`；bias 131072，严格 `85<Cb<125`、`135<Cr<200` | `PASS`（边界 + Golden） | `NOT_RUN` |
| 3×3 Opening | `fallback/rtl/inspection/morph_open_96.v`；四像素流、1-bit 行缓存、`BORDER_REPLICATE`、帧尾排空 | `PASS`（RTL + Golden） | `NOT_RUN` |
| BBox 与面积 | `tb_color_detect_96_v2.v` 全帧面积 `921600`、BBox `0/0/1279/719`；面积 20 bit | `PASS` | `NOT_RUN` |
| 宽高测量 | `defect_classifier.v` 使用闭区间 `xmax-xmin+1` / `ymax-ymin+1` | `PASS`（子系统 RTL） | `NOT_RUN` |
| 公差判定 | 名义 `120×80`，宽 `105..135`，高 `68..92`，面积下限 `100` | `PASS`（Python + RTL） | `NOT_RUN` |
| 四态判定 | `PASS/NG/NO_OBJECT/INVALID` 互斥；复位/非法 ROI 不误报 PASS | `PASS`（classifier + invalid ROI） | `NOT_RUN` |
| `red_part` / 数量 `0/1` | detector/classifier/OSD 使用固定类别和单目标约定 | `PASS`（逻辑边界已定义） | `NOT_RUN` |
| 安路 Logo | `fallback/rtl/display/anlogic_logo_rom.v` 已纳入 TD `.prj` 和顶层 OSD | `PASS`（build/integration） | `NOT_RUN` |
| 模式、帧计数、类别、数量、宽高、状态 OSD | `fallback/rtl/display/industrial_osd_overlay.v`；`tb_osd_led_joint.v` 覆盖状态文本和联动 | `PASS`（RTL + build） | `NOT_RUN` |
| 检测框 | `fallback/rtl/inspection/bbox_draw_overlay.v`；PASS 绿色、NG 红色、空场清除旧框 | `PASS`（子系统 RTL） | `NOT_RUN` |
| LED 联动 | classifier 四态 LED 编码；顶层 LED 与 OSD/检测框共同消费 HDMI 域原子结果；最终管脚仍需板卡确认 | `PASS`（RTL + TD） | `NOT_RUN` |
| 单文件下载 | 推荐 `release/industrial-v1/camera_to_dsi_display_compress.bit`，SHA-256 `ba451dddce56234c0e7e5801af28fa11f209d4522978ac92e668ad7554f3c53e` | `PASS`（当前 package-based bitgen） | `NOT_RUN` |

## 本轮证据

- 软件/Golden：`python work/tests/run_industrial_rtl_golden.py`，正常 7 帧 + ROI 边界 1 帧 + 非法 ROI 1 帧通过；ROI Opening 使用与 Stage D 一致的 `BORDER_REPLICATE`。
- 三模式：`python work/tests/run_cartoon_region_fill_sim.py --full-frame --rtl fallback/rtl/video/video_cartoon_region_fill.v`，`2,938,270` 周期通过。
- RTL：重新编译并运行 morph、full-frame color、threshold boundary、classifier、industrial subsystem、mode controller、OSD/LED，全部 exit code `0`；工业子系统补齐 `O_invalid → I_invalid` 后再次通过。
- 软件模型：`test_industrial_inspection.py` `5/5`、`test_stage_d.py` `5/5`、`test_industrial_contract.py` `4/4`。
- TD：Tang Dynasty `v6.2.168116`；本版显式使用四个 `PH1P_LOGIC_ERAM` 形态学行缓存，并将 ISP 输出 ready 明确 tie-high。最新 `route.qor` 为 Setup WNS `+104 ps`、Hold WNS `+20 ps`、TNS 均 `0`、违规端点 `0`；Slice `17,679/83.33%`、RAM `43`、DSP `24`、DRAMHARDCON `229`，STA coverage `96.34%`。这些是当前工程构建结果，不等同于上板验证。
- 发布 provenance：`release/industrial-v1/industrial-v1-manifest.json`，同时记录源码、报告、位流和输入路径哈希。

## 当前未完成项

1. Stage G：尚未下载到真实 PH1P35，未连接 SC520CS/HDMI，未验证摄像头锁定、画面、三模式视觉效果、检测框、LED、冷启动、热复位、重复下载、帧率、延迟和长稳。
2. TD 告警：`SYN-5011/5013/5025`、`HDL-5001/5007/5106/5314/5317/5323/5369`、`SYN-5041/5065`、`PHY-5060/5016/5079/5088`、`PRJ-5611` 已按当前日志归类但仍 OPEN，见 `industrial-v1-td-warning-audit.md`；正 WNS 不会自动关闭结构性告警。
3. 资源：最新正式发布 Slice `83.33%`，高于项目 `80%` 目标；本次为显式固定 ROI 合同、区域填充模式、按键模式接入并将 LED 统一到 HDMI 域原子结果后的真实构建结果。需要后续优化或在发布决策中明确接受余量，不能据此宣称上板可用。
4. 干净环境：构建脚本已取消对单一本机路径的强依赖，改为 CLI/环境变量输入；但官方基线 `Runs`、TD 安装和厂商 IP 仍需在新机器提供，尚未形成完全自包含的无授权工程包。

YOLO/Micro-CNN、WM8978、多类别多目标和毫米级标定不属于本版验收范围，不能作为当前 fixed-red v1 的缺陷项。

## 2026-10-17 当前提交重建校正

上文的旧构建数值和位流哈希属于历史记录；当前工作树构建的最新发布产物以 `release/industrial-v1/industrial-v1-manifest.json` 和 [`2026-10-17-industrial-inspection-current-build.md`](../experiments/2026-10-17-industrial-inspection-current-build.md) 为准。当前推荐压缩位流为 `release/industrial-v1/camera_to_dsi_display_compress.bit`，SHA-256 为 `1de801130217edaf203994d59010145ad7f68ba3f4c8dd08861a2c655562d944`；当前 Slice `17,821/84.00%`、RAM `43`、DSP `24`、DRAMHARDCON `229`、Setup WNS `+106 ps`、Hold WNS `+20 ps`。当前 manifest 已将 `fallback/td_package/` 记录为正式发布输入包。

本次重建仍没有真实 PH1P35、SC520CS、HDMI 和 LED 证据，因此所有硬件验收列继续保持 `NOT_RUN`；TD 结构性告警也继续保持 `OPEN`。

## 2026-10-17 21:18 fresh build 权威校正

上文保留较早构建作为历史记录。本轮实际完成的 TD 构建以 `release/industrial-v1/industrial-v1-manifest.json` 为准：

- 下载文件：`release/industrial-v1/camera_to_dsi_display_compress.bit`
- SHA-256：`3676c2860be4bd89ed1e1eab9682bcfc7d274381bd2e29fdf849b492f65b7c9e`
- Setup WNS `+106 ps`，Hold WNS `+20 ps`；TNS 和违规端点均为 `0`
- Slices `17,913/84.43%`，RAM `43`，DSP `24`，DRAMHARDCON `229`
- 构建提交：`af0d8e842459f93a00121332a3b24176aa1d5dbc`

以上仍是工程构建证据，不是板级证据。Stage G、摄像头、显示器、LED、冷启动、热复位和长稳项目均继续标记 `NOT_RUN`。

## 2026-10-18 HX1P35A 管脚修正版当前交付

本节覆盖前述历史发布记录，作为当前修正后的工程构建证据：

- 下载文件：`release/candidates/industrial-v1-hx1p35a-pin-correction/camera_to_dsi_display_compress.bit`
- 大小：`1,366,769 bytes`
- SHA-256：`b483a1ffc30d0b7ae9e8ebef4f31f617d33a53d6784ded8007d5443c51ad80ef`
- 按键：`I_button[0]=D5`、`I_button[1]=A9`
- LED：`LED1=D10`、`LED2=E10`、`LED3=C6`
- 复位/屏幕端口：移除 `I_rst_n=R10` 和 `O_screen_pwm=R11`
- MIPI：`DPHY0 + 2-lane`，无 lane polarity inversion
- Setup/Hold WNS：`+103/+20 ps`；TNS 和违例端点均为 `0`
- Slice/RAM/DSP：`17,642/83.15%`、`43`、`24`

该位流已通过 TD 综合、布局布线、Hold Fix、Bitgen 和 QoR 门禁，但尚未下载到真实 HX1P35A；所有 Stage G 实测项目继续为 `NOT_RUN`。

## 2026-10-17 21:40 输入包告警修复后的权威校正

本轮在正式输入包补入 `td_project/al_ip/ChipWatcher_mipi/` 后重新生成发布物。当前单文件下载绑定为：

- `release/industrial-v1/camera_to_dsi_display_compress.bit`
- 大小 `1,370,545 bytes`
- SHA-256 `00770be00a7c2c3e90e6da5405bced26a8d6b27efa3ebcc8e92667d4188ee8af`
- Setup WNS `+116 ps`、Hold WNS `+20 ps`；TNS 和违规端点均为 `0`
- Slices `16,693/78.68%`，RAM `43`，DSP `24`，DRAMHARDCON `229`，STA coverage `96.43%`

最新 syn/phy 日志中 `PRJ-7001` 已消失；其他告警仍保持 `OPEN`。这只更新工程构建证据，不改变所有硬件验收项的 `NOT_RUN` 状态。

## 2026-10-17 21:57 当前发布修正

在参数化 ROI 合法性修正后重新完成 TD 全流程，当前发布绑定为：

- `release/industrial-v1/camera_to_dsi_display_compress.bit`
- 大小 `1,369,649 bytes`
- SHA-256 `1de801130217edaf203994d59010145ad7f68ba3f4c8dd08861a2c655562d944`
- Setup WNS `+106 ps`、Hold WNS `+20 ps`；TNS 和违规端点均为 `0`
- Slices `17,821/84.00%`，RAM `43`，DSP `24`，DRAMHARDCON `229`
- 最新 syn/phy 日志：`industrial-v1-20261017-215732-*`

该记录仍只证明软件、RTL、TD 构建和 Bitgen；所有摄像头、HDMI、LED、冷启动、热复位和长稳验收继续为 `NOT_RUN`。

## 2026-10-17 当前目录整理后的正式发布

当前正式发布文件为 `release/industrial-v1/camera_to_dsi_display_compress.bit`，大小 `1,371,057 bytes`，SHA-256 `54c496277607733f4d848ed6f8085ea01f82d6aac95d15fd7bd30bf137baed50`。本次构建使用整理后的功能目录和正式 Cartoon 入口，manifest 与构建证据位于 `release/industrial-v1/industrial-v1-manifest.json`、`docs/evidence/industrial-v1-td-logs/`。

该发布只更新工程和位流构建证据；没有板卡、SC520CS、HDMI 或 LED 实测，因此所有 Stage G 验收项继续为 `NOT_RUN`。

## 2026-10-18 位宽契约修复后的当前发布

当前发布文件为 `release/industrial-v1/camera_to_dsi_display_compress.bit`，大小 `1,368,753 bytes`，SHA-256 `199cc9c65484c24d97e57affd5a6b12ff49a6de39bdf780f652c006e553c5b7a`。Route QoR 为 Setup WNS `+106 ps`、Hold WNS `+20 ps`、TNS/违规端点均为 `0`、Slices `17,403/82.03%`、RAM `43`、DSP `24`、DRAMHARDCON `229`；manifest 已绑定 11 个当前源文件。

本轮仅证明项目连接层位宽修复后的软件、RTL、TD 和 Bitgen 结果；没有真实板卡、SC520CS、HDMI 或 LED 测量，Stage G 验收继续为 `NOT_RUN`。

## 当前目录发布绑定（2026-10-17 第二次 ERAM 构建）

当前 `release/industrial-v1/` 的唯一正式下载文件为 `camera_to_dsi_display_compress.bit`，SHA-256 为 `e9815a4a42f085d26cb8744c0d5a485020d3ece3e1a1bb7aff20d92264de68d3`。对应 `route.qor` 为 Slice `16,852/79.43%`、Setup WNS `+103 ps`、Hold WNS `+20 ps`、TNS 和违例端点均为 `0`。这些仍是软件/RTL/TD/Bitgen 证据，硬件状态保持 `NOT_RUN`。
