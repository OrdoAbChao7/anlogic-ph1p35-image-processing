# SC520 卡通化修复实施计划

> 执行方式：当前会话按 superpowers:executing-plans 连续执行。用户已明确要求编写代码实现效果；不再重复请求启动许可。

**Goal:** 交付保持原图/边缘/卡通切换的 RTL、参考模型、仿真证据和 TD 构建候选位流。

**Architecture:** 保留组员 SC520、ISP 原图、DDR 和 HDMI 配置；去除 ISP 内失败的边缘/卡通分支，在 DDR 读出、HDMI 编码前增加单像素 RGB888 流水线。双行缓存构造因果 3×3 窗口，Gaussian 平滑、8 级/通道量化、Sobel 黑边；OSD 使用独立旁路像素，避免参与滤波。物理开关仍为 A4 边缘、B4 卡通，卡通优先，在下一帧首个有效像素锁存同步后的开关状态。

**Tech Stack:** Verilog-2001、Python/OpenCV/NumPy、Icarus Verilog、TD 6.2.168116。

**Spec:** 本文的接口契约及 `docs/setup/team-sync-2026-10-11.md` 的故障证据。

## 接口与范围

- `work/rtl/video_cartoon.v`：RGB888 单像素/拍，DE 为有效像素，HS/VS 原样等延迟传递，VS 高电平期间清空坐标；无背压。WIDTH=1280，HEIGHT=720。
- 六级寄存器流水线；模式、原图、OSD mask/color、DE/HS/VS 与处理数据一起延迟。复位后有效位清零，不清 RAM；首两行按边界复制屏蔽历史帧。
- 窗口覆盖 `(x-2..x,y-2..y)`，负坐标复制第 0 行/列；不丢首尾行像素。它是因果滤波，特征相对原图约向右下平移一像素，不冒充居中 OpenCV 默认边界。
- Gray=`(R>>2)+(G>>1)+(B>>2)`；Gaussian 权重 `[1,2,1]×[1,2,1]`，总和右移 4 截断；量化为高 3 位按 3+3+2 重复扩展到 8 位；Sobel `abs(Gx)+abs(Gy)>=160` 置黑，纯边缘模式置白。
- 保留既有时钟/外设配置，不扩展 YOLO、语音等无关功能。不将本次软件结果写成实物验收通过。

## 任务与验证

- [ ] 1. `work/tests/tb_legacy_cartoon.v` 复现旧除法错误，保存失败证据；建立 `work/models/cartoon_reference.py` 与 `work/tests/test_cartoon.py`，独立数值样例检查参考模型。
- [ ] 2. `work/tests/tb_video_cartoon.v` 驱动全尺寸和小尺寸、连续帧、颜色边界、随机噪声、行间空白、有效间隙、帧中切换、复位与 OSD；实现 `work/rtl/video_cartoon.v`，逐周期比对 RGB 和所有伴随信号。
- [ ] 3. `scripts/build-cartoon.py` 从组员原包生成拒绝覆盖的独立 TD 副本，补原图 ISP ready、接入 HDMI 前处理及 OSD 旁路；复用厂商默认 Tcl 流程，以相对路径构建，保留日志。
- [ ] 4. 运行仿真和 TD 综合/布局布线，检查 RAM 推断、时序、关键告警；失败先定位再修改，禁止放宽时序约束。
- [ ] 5. `work/output/cartoon-release/` 交付候选 `.bit`、源工程包、SHA-256、报告及操作说明；回填计划、构建摘要和资料缺口。

## 重点复核

- 老帧 RAM 不得污染新帧前两行。
- 空白和暂停有效拍不得推进窗口。
- 帧中开关不改变当前帧；两开关同时置位仍选卡通。
- 原图逐像素无损，OSD 在三模式下均保持原色和位置。
- 整条链路保留原始约束；生成位流不等于时序或上板验收通过。
