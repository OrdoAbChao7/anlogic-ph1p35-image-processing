# Industrial Vision V2 G6 帧统计白平衡设计

日期：2026-10-19  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`

## 前置审计结论

- `fallback/td_package/user_source/hdl_source/isp/isp_top.v:94-160` 将现有 `awb` 接在 demosaic 后，检测器并行使用 AWB 输出；这是代码级事实，不是上板事实。
- `fallback/td_package/user_source/hdl_source/isp/awb/awb.v:122-153` 在 `I_tuser` 时清零通道累加器，并在有效流中持续累加；`:206-218` 的除法器每次 `I_tvalid_r1` 启动；`:259-317` 在除法完成时更新增益。这些代码没有独立的“帧统计完成后、下一帧统一生效”接口合同，因此不能直接把它写成已验证的帧稳定 AWB。
- `fallback/td_package/user_source/hdl_source/uiisp_beta/ae_set.v` 是曝光/模拟增益请求路径；SC520CS 官方寄存器、I2C 写入时序和复位条件未在当前 V2 证据中闭合，本阶段不修改它。

## 独立控制器边界

新增控制器只接收一帧完成后的 `sum_r/sum_g/sum_b/pixel_count/mean_luma`，在 `I_frame_stats_valid` 单个边界事件上计算下一帧使用的 Q8.8 R/G/B 增益：

- 初值和 G 通道固定为 `1.0 = 256`；R/B 增益限幅 `[128,512]`（0.5x–2.0x）。
- 目标灰度为三通道均值的整数平均；期望增益按四舍五入定点计算。
- 每帧最多按平滑步长更新，避免反馈振荡；增益只在统计边界改变。
- 像素不足、亮度过暗/过亮或相邻帧亮度跳变超过场景门限时保持旧增益，并输出 `scene_protected`。
- 输出增益用于下一帧；不修改当前已经开始的帧。

## 检测兼容性边界

软件模型同时保留 RGB 增益应用和固定 Cb/Cr 红色检测函数，用于比较优化开关前后的检测结果。没有真实光照样本和用户视觉确认前，不能把软件模型写成硬件画面改善。

## 禁止事项

本阶段不宣称传感器自动曝光、不猜测 SC520CS 寄存器、不覆盖官方 AWB IP、不宣称现有顶层已替换为新控制器；TD、上板和真实光照数据单独作为后续门。
