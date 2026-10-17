# fixed-red v1 第一版任务要求审计

审计依据：用户提供的任务附件 `pasted-text-1.txt`，SHA-256
`7750e82c7d0263ce6e3a2d7315cb2b3b475e545019662fb60b2a52c5b4cc120a`。

审计对象：GitHub 分支 `fallback/industrial-inspection` 的 `s4-region-fill-v1`
候选包，源码提交 `dba6c0c28e1feba06a460951d5f8d232459b62e4`，候选发布包提交
`414dd492af63c14c2041ac47daae6e0a86bcfc9d`。

## 第一版功能要求

| 要求 | 当前状态 | 证据 |
|---|---|---|
| Original 原图 | `SIM_PASS / BUILD_PASS` | `work/tests/run_cartoon_luma_sim.py`；完整 TD 候选构建 |
| Sobel 模式 | `SIM_PASS / BUILD_PASS` | 三模式逐周期比较；`video_cartoon_region_fill.v` |
| Cartoon 模式 | `SIM_PASS / BUILD_PASS` | 量化 + 局部区域填充 + Sobel 融合参考模型和 RTL 全帧回归 |
| 按键同步、去抖、帧边界切换 | `SIM_PASS / BUILD_PASS` | `fallback/rtl/mode_controller.v`、`tb_mode_controller.v` |
| 四像素并行 Q10 红色分割 | `SIM_PASS / BUILD_PASS` | `fallback/rtl/color_detect_96_v2.v`、严格开区间边界回归 |
| 3×3 Opening | `SIM_PASS / BUILD_PASS` | `fallback/rtl/morph_open_96.v`、两级 1-bit 行缓存、ROI 边界回归 |
| 面积与 Bounding Box | `SIM_PASS / BUILD_PASS` | 1280×720 全前景 `area=921600`、全幅 BBox 回归 |
| 宽高测量 | `SIM_PASS / BUILD_PASS` | `defect_classifier.v` 的闭区间宽高计算 |
| 公差比较 | `SIM_PASS / BUILD_PASS` | `120×80` 名义尺寸、宽 `105..135`、高 `68..92` |
| PASS / NG / NO_OBJECT / INVALID | `SIM_PASS / BUILD_PASS` | 四态分类器与 LED 互斥回归 |
| `red_part` 与数量 `0/1` | `SIM_PASS / BUILD_PASS` | `isp_top.v` 固定检测分支和 OSD 状态文本 |
| Logo、模式、帧计数、框、类别、数量、宽高、状态 OSD | `SIM_PASS / BUILD_PASS` | `industrial_osd_overlay.v`、Logo ROM、OSD/LED 联调 |
| LED 联动 | `SIM_PASS / BUILD_PASS` | `defect_classifier.v`、顶层 `O_led_pass/ng/det` 连接 |
| 单一 `.bit` 下载文件 | `BUILD_PASS` | `release/cartoon-region-fill-v1/camera_to_dsi_display_compress.bit` |

## 真实验收状态

当前候选位流 SHA-256：
`d331d6b7af11b9bb1f8d51826818bf40d3badf87b194251a3587aee4f4c5baf7`。

TD QoR：Setup WNS `+119 ps`、Hold WNS `+20 ps`、TNS `0`、违例端点 `0`、Slice
`17397/21216 (82.00%)`、RAM `43`、DSP `24`。

以下项目仍为 `NOT_RUN`，不能标记为硬件通过：

- PH1P35/JTAG 下载和配置恢复。
- SC520CS 摄像头锁定、HDMI 实时显示和真实三模式视觉效果。
- 检测框、OSD、LED 管脚和极性实测。
- 冷启动、热复位、重复下载、帧率、端到端延迟和长稳运行。

因此该包状态冻结为 `BUILD_PASS / HARDWARE_NOT_RUN / formal_release=NOT_PROMOTED`。
正式 `release/industrial-v1` 基线没有被候选包覆盖。
