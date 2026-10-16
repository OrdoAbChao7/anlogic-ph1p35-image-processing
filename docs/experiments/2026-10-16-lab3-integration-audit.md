# Lab3 与工业修复位流：整合前功能审计

日期：2026-10-16。范围：只读核对工程、正式赛题和导出源码；未改RTL、未构建新位流、未执行上板。证据类别为official/project，不新增measured结论。

## 结论与纠正

指定的HX1P35A2026/lab_ex1-3_SC520/lab_ex3_osd_SC520/lab_ex3_osd确实有基础视频、Sobel、安路Logo及计数OSD。修复候选C41714...AA470继承了这些功能。此前回答遗漏Logo及计数，STATUS中的“Logo RTL未实现”属于审计错误；本轮纠正为代码已接入、硬件效果待验证。

导出包与原Lab3的design_top_wrapper.v、hdmi_mixer.v、anlogic_logo_rom.v、osd_char_lib.v逐字节一致。两份.al均列入Logo/字库/mixer；顶层以DEBUG_MODE=0实例化mixer，输出送入hdmi_tx。因此不是仅目录内存在未用文件。

## 正式要求映射

依据本地docs/research/snapshots/competition/topic2.pdf第16页2.3/2.4、第17页2.5/2.6、第18页延续。官方基础要求不强制YOLO、三模式、WM8978、毫米测量或端到端<2ms；后者是项目自定目标或应用扩展，不能混同。PROJECT_GOAL.md不因本次审计修改。

| 要求 | Lab3与当前候选情况 | 整合判定 |
|---|---|---|
| MIPI采集/DDR/HDMI | 顶层完整实例链；工程按1280x720处理 | 基础功能已接入，需实测闭环 |
| FPGA至少一种图像处理 | isp_top实例化AWB、demosaic及实际import/edge_detect_96.v | Sobel已接入，需补完整效果/边界验证 |
| 连续稳定输出 | 有构建和部分仿真；无绑定当前位流的长稳结果 | 不能仅凭源码或时序判已满足 |
| OSD及安路Logo | hdmi_mixer真实叠加160x160 Logo和文字 | 已接入，待画面验收；无需重写一套 |
| 运行计数 | mixer以I_video_user递增6位BCD，显示“安路CNT:” | 已接入，但这是HDMI显示帧数，不是目标数或延迟 |
| 多算法切换及状态 | 现有原图/Sobel两路；I_button2控制，帧锁存 | 切换已接入，模式文字未接 |
| 简单目标检测/识别 | 固定色阈值、全局单BBox；当前候选修复面积/统计并画黄框 | 可作颜色目标定位；文字、类别及实际效果未闭合 |
| 坐标/面积/存在状态OSD | isp_top有det_*端口；顶层未接；mixer无对应输入 | 可作为下一步补接，需帧快照CDC及显示帧对应 |
| 多目标独立框/数量 | 当前只有全局极值统计 | 不能靠接线得到；需连通域/多对象跟踪等新算法 |
| 卡通化与区域填充 | 此.al未包含cartoon；别处有软件和RTL候选 | 需要适配和重验，区域连通填充仍缺实现 |
| 白平衡/自动曝光 | AWB代码已接入；ae_set读按键，没有图像亮度输入 | 可复用WB和手动参数通路；不能称自动曝光闭环 |
| LED/机电联动 | 顶层无检测LED/执行器端口 | 要增加有效事件、复位/去重、管脚和外设验证 |
| WM8978语音 | 列入I2S_receiver/audio_arc_calculate；顶层HDMI音频valid/data为0；无Codec播报链路 | 文件清单不等于功能，需新驱动/初始化/音源/管脚 |
| YOLO/INT8/NMS分类 | 当前工程没有整网；已有PE和PC参考不构成整网 | 不能本轮直接合并为可用检测器 |
| 延迟可视化/<2ms | 单显示帧计数没有采集/显示时刻关联 | 需采集帧ID/显示帧ID或时间戳测量，不能据CNT推算 |

## 关键源码证据

以下路径相对于原Lab3工程根目录；导出包对应层次为project/：

- user_source/hdl_source/design_top_wrapper.v:614–629 ISP、:632起写帧缓存、:667起读帧缓存、:717 DDR、:773–794 mixer、:796–824 HDMI。:778 DEBUG_MODE=0；:812–817关闭音频；:3–40无检测LED/Codec外部接口。
- user_source/hdl_source/hdmi_mixer.v:473–482实例化Logo ROM和字库；:504–546更新显示帧计数；:614–624混入Logo；:626–815显示“安路CNT:”和六位十进制；:900–904正常视频/OSD输出选择。其端口:7–26没有mode/det/class/count输入。
- user_source/hdl_source/design_top_wrapper.v:460–468的ae_set把I_button[1:0]映射到I_btn[3:2]，低两位恒1；ae_set.v:88–96对应当前按键可调增益，自动曝光尚无亮度闭环。I_button2在:628用于原图/边缘。
- 当前候选project/user_source/hdl_source/isp/isp_top.v导出的det_*仍未由同一顶层实例连接。颜色框已在DDR之前的industrial_overlay_96完成，不需要将BBox跨域才能画现有框；新增数值OSD则需要整组快照传送，并跟所显示的DDR帧对应。
- work/rtl/video_cartoon_luma.v:2、:11–19是24bit单像素、VS/HS/DE接口；当前ISP是96bit四像素流，不能直接同口替换。可评估DDR后的单像素层，但必须审计读使能、同步极性与流水延迟。

## 推荐整合边界

首个整合版本应以fallback/project修复副本为母版，沿用Lab3的MIPI/DDR/HDMI/Logo/计数：原图、Sobel、颜色框，加模式文字、目标存在、坐标和面积。不将单框显示成多目标总数，不将颜色标签当作YOLO类别。

当前候选资源16123/21216 Slice（75.99%）、39/108 ERAM、25/40 DSP，最差Setup仅70ps且落在Sobel。距项目80% Slice目标约850个Slice，不意味着新增功能必然装得下。每次整合须重新综合/实现，保留当前C41714...位流回退点。

第一步整合前检查项：冻结模式编号和按键分配（现有两个键用于增益，一个用于原图/边缘，不能重复占用）；定义捕获帧与显示帧的元数据对应和多位CDC；新增视觉输出按软件先行协议预览/验收。卡通化、区域填充、YOLO、语音、毫米测量分别建立独立入口，不一次堆入首个整合版。

退出条件：原图/边缘/Logo/CNT/目标框同屏可见，模式文字与当前显示帧一致，坐标/面积/存在状态不撕裂；复位、切换、空场和连续运行有绑定新位流哈希的真实证据。官方稳定性项只在这些上板记录完成后判通过。
