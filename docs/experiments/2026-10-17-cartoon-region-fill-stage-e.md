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
- 行缓存使用三 bank ring，当前行写入 bank 与前两行读取 bank 分离，不依赖厂商 RAM 的 read-during-write 模式。
- Sobel 亮度按完整 `(R+2*G+B)>>2` 加权和计算，并有低位进位向量测试。

## TD 候选构建

| 项目 | 结果 |
|---|---|
| 器件 | `PH1P35MDG324` |
| TD 版本 | `v6.2.168116` |
| 候选视频 RTL | `work/rtl/video_cartoon_region_fill.v` |
| 隔离工程 | `work/td_industrial_region_fill/` |
| 发布目录 | `work/output/cartoon-region-fill-td/` |
| 最终 Setup WNS/TNS | `+119 ps / 0 ps` |
| 最终 Hold WNS/TNS | `+20 ps / 0 ps` |
| 违例端点 | Setup 0，Hold 0 |
| 资源 | 17,397 slices（82.00%）、43 RAM、24 DSP、229 DRAMHARDCON |
| QoR 门 | PASS |

本次候选构建清单绑定提交 `c458986`；视频 RTL 源文件 SHA-256 为 `985b18caefb0237e56121f29870e037d8660675c7893e2d360f123183d8eeb4b`。

关键原始报告：

- `work/td_industrial_region_fill/td_project/camera_to_dsi_display_Runs/syn_1/flow.status`
- `work/td_industrial_region_fill/td_project/camera_to_dsi_display_Runs/phy_1/route.qor`
- `work/td_industrial_region_fill/td_project/camera_to_dsi_display_Runs/phy_1/final_timing.rpt`
- `work/td_industrial_region_fill/td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display.bit`

候选位流：

- 未压缩：`camera_to_dsi_display.bit`，1,789,539 bytes，SHA-256 `2c6c546fbdb7c6584b9b50861b9cef8206c429556e8319049e6f0b75c7070601`
- 压缩：`camera_to_dsi_display_compress.bit`，1,368,369 bytes，SHA-256 `d331d6b7af11b9bb1f8d51826818bf40d3badf87b194251a3587aee4f4c5baf7`
- 发布目录中的 `industrial-v1-manifest.json` 记录了构建工具、基线 Runs、源文件哈希和上述制品哈希。

综合阶段曾报告 Setup WNS `-1219 ps`、TNS `-18890 ps`，但最终布局布线 `route.qor` 的 QoR 门为通过；两者均保留，不能只引用最终正时序而隐藏中间报告。

本轮修复后的 Slice 占用为 `82.00%`，高于项目期望的 `80%` 资源目标；这不是当前脚本的时序失败，但属于正式发布前必须处理或明确接受的资源余量风险。

## 阶段边界

- Stage C：用户已批准，记录见 `docs/experiments/2026-10-17-cartoon-region-fill-stage-c.md`。
- Stage D：硬件等价模型与边界契约测试通过。
- Stage E：RTL 与 Golden 逐周期仿真通过。
- Stage F：候选 TD 构建与最终 QoR 通过。
- Stage G：尚未执行；当前没有本轮位流下载、摄像头画面、HDMI、按键、LED 或长稳证据。
