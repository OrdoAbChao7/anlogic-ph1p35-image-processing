# fixed-red v1 `s4-region-fill-v1` 候选下载包

这是已通过 RTL 回归和 TangDynasty 综合/布局布线的卡通化候选包，不是已完成 Stage G 的硬件发布包。

下载文件：`camera_to_dsi_display_compress.bit`

- 目标器件：`PH1P35MDG324`
- TD：`v6.2.168116`
- Setup WNS：`+119 ps`
- Hold WNS：`+20 ps`
- Setup/Hold violated endpoints：`0 / 0`
- Slice：`17397 / 21216 (82.00%)`
- RAM/DSP：`43 / 24`
- SHA-256：`d331d6b7af11b9bb1f8d51826818bf40d3badf87b194251a3587aee4f4c5baf7`

位流包含原图、Sobel、卡通化、固定红色 `red_part` 检测、3×3 Opening、BBox/面积/尺寸判定、PASS/NG/NO_OBJECT/INVALID、Logo/OSD 和 LED 逻辑。

当前状态：`BUILD_PASS`，`HARDWARE_NOT_RUN`。正式发布基线 `release/industrial-v1/` 未被替换。上板前请按项目文档连接 PH1P35、SC520CS、HDMI 和 JTAG，并记录冷启动、模式切换、检测框、OSD、LED 及长稳结果。
