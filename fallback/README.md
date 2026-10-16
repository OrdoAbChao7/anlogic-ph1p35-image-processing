# 工业颜色检测与包围框修复版

这是 SC520CS Lab3 既有颜色检测链路的修复候选，不是完整 F1–F5 工业检测系统。尚未加入形态学滤波、毫米标定、PASS/NG、多目标连通域或语音联动。

## 重建和回归

在 PowerShell 执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\test.ps1 -IcarusBin 'C:/path/to/iverilog/bin'
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -TdRoot 'C:/path/to/TD'
```

在原仓库 fallback 目录使用时可省略工具参数；解压包必须提供本机工具安装目录。TD 版本6.2.168116，器件PH1P35MDG324 -3，顶层design_top_wrapper。工程入口为 project/td_project/camera_to_dsi_display.al；不要用目录通配符加入未列入工程的参考文件。

构建脚本从源文件重建syn_1/phy_1，不依赖旧数据库；检查全部57个显式工程引用和最终Setup/Hold WNS、TNS。测试、构建、导出均绑定输入哈希。export.ps1拒绝负WNS、非零TNS及测试/构建后修改过的源文件。脚本在本进程修正PATHEXT，并使用正斜杠Tcl路径，以兼容当前Windows工具调用环境。

保留原SC520CS初始化、管脚、PLL、DDR和HDMI配置；禁用自动ChipWatcher插入。本包不修改这些底层参数，也不将用户的修复授权自动登记为VISUAL_APPROVED。

## 数据与时序契约

- 输入为RGB888，每个valid周期4像素，lane0位于95:72。固定1280×720；SOF可以先于数据，也可与首组同拍。所有valid周期都被消费，无背压；TLAST只作信息，坐标按固定组数计数。
- 保留原Q10系数及严格颜色阈值：85<Cb<125、135<Cr<200。RGB先零扩展再作有符号运算，Cb/Cr在合法输入下位于0..255。未进行工位阈值调优。
- 面积为20位；完整帧结束后发布area/BBox，下一帧统计期间保持不变。空帧输出面积0、坐标全0、target_valid=0。SOF中断的半帧不发布。valid_frame代表目标存在，不是单周期触发事件。
- AWB输出改用已有延迟标记I_tuser_r2；进入Sobel前寄存数据与控制，并让原图支路延迟匹配。模式在对齐后的帧标记生效。
- 检测到绘框之间延迟两级，绘框输出再寄存一级；绘框在SOF锁存结果，整帧使用上一捕获帧的检测框。移动目标可能存在帧间位置滞后。总延迟、摄像头帧率、DDR延迟未实测。
- 96→128打包器复位确定，valid停顿保持半包；4组96位产生3个128位字。每行1280像素对应240个输出字，行尾标记与输出valid对齐。完整行打包要求宽度为16的倍数。
- 绘框在DDR前、MIPI byte-clock域进行，没有新增多位结果跨域。det_*顶层输出当前未使用；后续跨到HDMI/外设时钟时须使用整组快照握手或FIFO。

## 验证范围

九组回归包含16384个RGB像素、921600像素完整面积、帧头两种形式、半帧中断、空场、连续帧、打包停顿、输出行尾及完整ISP接入三帧518400字比对。

完整ISP路由测试使用上游依赖模型；AWB帧标记测试使用同步RAM模型并禁用增益更新。它们验证控制和接入，不验证厂商除法器、真实RAM/IP或实际摄像头效果。实际构建结果和位流校验值以build-summary.json及reports目录为准。

## 下载与检查

1. 确认实物为PH1P35MDG324及本项目SC520CS，沿用已有接线和供电。
2. 在TD下载器中选择包内industrial_color_bbox.bit，核对build-summary.json里的SHA-256；不要选旧best_result位流。
3. 检查原图和现有按键的边缘模式。固定阈值范围内的目标应有黄色框；移除目标后，完整空帧应撤销后续画面的框。
4. 记录位流哈希、板卡/模组修订、光照、目标、冷启动、复位及连续运行现象。未经这些实测，不声明稳定、准确率达标或毫米级测量成立。

当前目录中的导出文件仅在最终时序门禁通过后才生成；真实板卡验收状态须另行记录。
