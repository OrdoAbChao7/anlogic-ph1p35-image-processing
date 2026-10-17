# 卡通化区域填充 Stage E/F：等价仿真与候选 TD 构建

## 结论

批准的 `s4-region-fill-v1` 已完成软件硬件等价模型、RTL 逐周期仿真，以及独立 TD 综合、布局布线和位流生成。候选 TD 构建的最终 QoR 门通过；该结果仍是 `BUILD_PASS`，不包含 PH1P35 板级下载、HDMI 观察或长稳验证。

当前候选没有替换正式 `release/industrial-v1/`，生成物保存在被忽略的候选目录中，便于与 fixed-red v1 基线分开复现和回退。

## 软件与 RTL 证据

- Python 全量回归：13/13 PASS。
- 候选小尺寸 RTL 仿真：`PASS 559 cycles, 16x8`。
- 候选全帧 RTL 仿真：`PASS 2938270 cycles, 1280x720`。
- 原有 `s3_luma` 基线全帧仿真：`PASS 2775640 cycles, 1280x720`。
- RTL/Golden 使用右下锚定 causal `3×3` 窗口；这个决定与现有行缓存接口一致，详见设计规格中的窗口时序说明。

## TD 候选构建

| 项目 | 结果 |
|---|---|
| 器件 | `PH1P35MDG324` |
| TD 版本 | `v6.2.168116` |
| 候选视频 RTL | `work/rtl/video_cartoon_region_fill.v` |
| 隔离工程 | `work/td_industrial_region_fill/` |
| 发布目录 | `work/output/cartoon-region-fill-td/` |
| 最终 Setup WNS/TNS | `+160 ps / 0 ps` |
| 最终 Hold WNS/TNS | `+20 ps / 0 ps` |
| 违例端点 | Setup 0，Hold 0 |
| 资源 | 17,229 slices（81.21%）、43 RAM、24 DSP、165 DRAMHARDCON |
| QoR 门 | PASS |

关键原始报告：

- `work/td_industrial_region_fill/td_project/camera_to_dsi_display_Runs/syn_1/flow.status`
- `work/td_industrial_region_fill/td_project/camera_to_dsi_display_Runs/phy_1/route.qor`
- `work/td_industrial_region_fill/td_project/camera_to_dsi_display_Runs/phy_1/final_timing.rpt`
- `work/td_industrial_region_fill/td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display.bit`

候选位流：

- 未压缩：`camera_to_dsi_display.bit`，1,789,539 bytes，SHA-256 `23d88bc694a541eb1cab3617bb94b58607df62b27c1c1e39fcd6fe3e68610192`
- 压缩：`camera_to_dsi_display_compress.bit`，1,365,809 bytes，SHA-256 `882325c4bd1464283e32fa59bbc7f5c76449e2a36f544e4e7697b8d4ba0f9160`
- 发布目录中的 `industrial-v1-manifest.json` 记录了构建工具、基线 Runs、源文件哈希和上述制品哈希。

综合阶段曾报告 Setup WNS `-1219 ps`、TNS `-18890 ps`，但最终布局布线 `route.qor` 的 QoR 门为通过；两者均保留，不能只引用最终正时序而隐藏中间报告。

## 阶段边界

- Stage C：用户已批准，记录见 `docs/experiments/2026-10-17-cartoon-region-fill-stage-c.md`。
- Stage D：硬件等价模型与边界契约测试通过。
- Stage E：RTL 与 Golden 逐周期仿真通过。
- Stage F：候选 TD 构建与最终 QoR 通过。
- Stage G：尚未执行；当前没有本轮位流下载、摄像头画面、HDMI、按键、LED 或长稳证据。
