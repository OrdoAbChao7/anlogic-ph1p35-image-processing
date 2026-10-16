# fixed-red v1 第一版要求逐项审计

审计版本：`aa6c747` 发布产物，设计源码来自 `abd35f7`；最新告警归类见 `a20e722`。本表严格区分仿真/构建证据与真实板卡证据。没有 PH1P35、SC520CS 和 HDMI 实物参与的项目，不能标记 `VERIFIED_ON_BOARD`。

## 功能审计

| 要求 | 当前证据 | RTL/TD 状态 | 上板状态 |
|---|---|---|---|
| Original 原图显示 | `fallback/td_source/design_top_wrapper.v` 的显示模式集成；完整 TD 工程通过 | `PASS`（整机 build） | `NOT_RUN` |
| Sobel 模式 | `work/tests/run_cartoon_luma_sim.py`，Original/Sobel/Cartoon 共 1102 周期逐周期比较 | `PASS`（仿真 + build） | `NOT_RUN` |
| Cartoon 模式 | `work/rtl/video_cartoon_luma.v`，冻结 `s3_luma`/threshold 240；同一 1102 周期测试 | `PASS`（仿真 + build） | `NOT_RUN` |
| 帧边界模式切换 | `fallback/tb_mode_controller.v`；去抖、按键优先级、帧边界提交和释放复原 | `PASS`（RTL） | `NOT_RUN` |
| Q10 红色分割 | `fallback/rtl/color_detect_96_v2.v`；bias 131072，严格 `85<Cb<125`、`135<Cr<200` | `PASS`（边界 + Golden） | `NOT_RUN` |
| 3×3 Opening | `fallback/rtl/morph_open_96.v`；四像素流、1-bit 行缓存、`BORDER_REPLICATE`、帧尾排空 | `PASS`（RTL + Golden） | `NOT_RUN` |
| BBox 与面积 | `tb_color_detect_96_v2.v` 全帧面积 `921600`、BBox `0/0/1279/719`；面积 20 bit | `PASS` | `NOT_RUN` |
| 宽高测量 | `defect_classifier.v` 使用闭区间 `xmax-xmin+1` / `ymax-ymin+1` | `PASS`（子系统 RTL） | `NOT_RUN` |
| 公差判定 | 名义 `120×80`，宽 `105..135`，高 `68..92`，面积下限 `100` | `PASS`（Python + RTL） | `NOT_RUN` |
| 四态判定 | `PASS/NG/NO_OBJECT/INVALID` 互斥；复位/非法 ROI 不误报 PASS | `PASS`（classifier + invalid ROI） | `NOT_RUN` |
| `red_part` / 数量 `0/1` | detector/classifier/OSD 使用固定类别和单目标约定 | `PASS`（逻辑边界已定义） | `NOT_RUN` |
| 安路 Logo | `fallback/rtl/anlogic_logo_rom.v` 已纳入 TD `.prj` 和顶层 OSD | `PASS`（build/integration） | `NOT_RUN` |
| 模式、帧计数、类别、数量、宽高、状态 OSD | `fallback/rtl/industrial_osd_overlay.v`；`tb_osd_led_joint.v` 覆盖状态文本和联动 | `PASS`（RTL + build） | `NOT_RUN` |
| 检测框 | `fallback/rtl/bbox_draw_overlay.v`；PASS 绿色、NG 红色、空场清除旧框 | `PASS`（子系统 RTL） | `NOT_RUN` |
| LED 联动 | classifier LED 互斥；OSD/LED 联调通过；最终管脚仍需板卡确认 | `PASS`（RTL） | `NOT_RUN` |
| 单文件下载 | 推荐 `release/industrial-v1/camera_to_dsi_display_compress.bit`，SHA-256 `e541b310defed61babe91f8a966fca7992f2a06a1154897d8cb3b1b68e9f057f` | `PASS`（bitgen） | `NOT_RUN` |

## 本轮证据

- 软件/Golden：`python work/tests/run_industrial_rtl_golden.py`，正常 7 帧 + 非法 ROI 1 帧通过。
- 三模式：`python work/tests/run_cartoon_luma_sim.py`，1102 周期通过。
- RTL：重新编译并运行 morph、full-frame color、threshold boundary、classifier、industrial subsystem、mode controller、OSD/LED，全部 exit code `0`；工业子系统补齐 `O_invalid → I_invalid` 后再次通过。
- 软件模型：`test_industrial_inspection.py` `5/5`、`test_stage_d.py` `5/5`、`test_industrial_contract.py` `4/4`。
- TD：Tang Dynasty `v6.2.168116`；`route.qor` Setup WNS `+101 ps`、Hold WNS `+20 ps`、TNS 均 `0`、违规端点 `0`；Slice `20,861/98.33%`、RAM `39`、DSP `26`。
- 发布 provenance：`release/industrial-v1/industrial-v1-manifest.json`，同时记录源码、报告、位流和输入路径哈希。

## 当前未完成项

1. Stage G：尚未下载到真实 PH1P35，未连接 SC520CS/HDMI，未验证摄像头锁定、画面、三模式视觉效果、检测框、LED、冷启动、热复位、重复下载、帧率、延迟和长稳。
2. TD 告警：`SYN-5011/5025`、`HDL-5314/5317/5323`、`SYN-5065`、`PHY-5060/5016/5079/5088`、`PRJ-5611` 已归类但仍 OPEN，见 `industrial-v1-td-warning-audit.md`。
3. 资源：Slice `98.33%` 高于项目目标 `80%`，并触发 `PHY-7022`；当前没有以牺牲功能为代价的优化结论。
4. 干净环境：构建脚本已取消对单一本机路径的强依赖，改为 CLI/环境变量输入；但官方基线 `Runs`、TD 安装和厂商 IP 仍需在新机器提供，尚未形成完全自包含的无授权工程包。

YOLO/Micro-CNN、WM8978、多类别多目标和毫米级标定不属于本版验收范围，不能作为当前 fixed-red v1 的缺陷项。
