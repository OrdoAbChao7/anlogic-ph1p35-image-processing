# Industrial Vision V2 G6 阶段总结

日期：2026-10-19（Asia/Shanghai）  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`  
G6 commits：`0d90567`, `cc7dc49`, `1f42985`

## 审计与实现

- 审计确认现有 `awb.v` 已由 `isp_top.v` 接入，但当前代码路径是累加/除法/增益流水，缺少本项目所需的独立帧统计原子更新证据；`ae_set.v` 的传感器 AE/AG 写入资料仍不完整。
- 新增 `awb_reference.py` 和 `awb_frame_gain_controller.v`，只在帧统计事件更新 Q8.8 R/B 增益，G 固定 256，输出下一帧使用的增益。
- 暗/亮场、空统计和场景亮度跳变保持旧增益；每帧最多变化 8 个 Q8.8 单位。

## 受影响验证

| 检查 | 结果 |
|---|---|
| G1-G6 软件模型 | `42 passed in 0.12s` |
| G1-G6 RTL 定向回归 | 13 个入口全部 compile/run `0`，新增 `TB_AWB_FRAME_GAIN_PASS` |
| `python -B -m pytest -q work/tests` | `88 passed, 8 failed`；8 项仍为冻结 V1 release/path/旧入口契约漂移 |
| `python -B work/algorithm_lab/verify_stage_d.py` | exit `1`；Stage D 样本通过，registry `ef929f...` 与 plugin `08f929...` SHA 不一致 |

## 硬件与视觉边界

- 用户已授权视觉审批默认通过，因此软件视觉 Stage C 不再等待交互确认；但当前工作区没有新的真实光照采样、显示截图或板级测量，不能把默认授权写成视觉效果实测。
- 新控制器未接入正式 `isp_top`，未修改传感器 AE/I2C 或 SC520CS 寄存器；TD、真实光照、红色检测误检率和硬件资源均未测量。

## 阶段判定

`V2-G6 = BLOCKED`，分层为：

- AWB 软件模型：`SOFTWARE_PASS`；
- 独立定点 RTL：`RTL_PASS`；
- 正式 ISP/传感器顶层：`NOT_RUN/BLOCKED`；
- 真实光照/视频/资源时序：`NOT_RUN/BLOCKED`。

G6 只证明一个可审计的帧统计增益控制候选，不宣称替换现有 AWB、不宣称传感器自动曝光或真实画质改善。
