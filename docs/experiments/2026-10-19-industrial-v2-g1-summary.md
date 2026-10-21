# Industrial Vision V2 G1 Summary

日期：2026-10-19（Asia/Shanghai）  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`  
V1 基线：`256d99c1d0dc4dbae2ace8d0ff3a97f504d514c9`  
G1 commits：`85af102`, `eb820c0`, `c174a19`

## 本阶段完成

- 模式按键变为去抖单击循环，显示模式仅在帧边界提交；两套模式控制器 testbench 均通过。
- OSD 的帧号、宽度和高度改为帧边界快照的十进制字符；原图、检测状态、LED 联合仿真通过。
- ISP 顶层固定 ROI 显式写成半开端点 `[0,1280) × [0,720)`；软件模型和 RTL 覆盖全帧、ROI 四边、半目标、ROI 外干扰、空场和非法 ROI。
- 用户授权的视觉审批策略已记录为 `default_pass_per_user_instruction`，仅作用于 Stage C，不替代 RTL、TD 或硬件证据。

## 受影响回归

| 检查 | 结果 |
|---|---|
| `tb_mode_controller`（`fallback/sim`） | compile/run `0`，`TB_MODE_CONTROLLER_PASS` |
| `tb_mode_controller`（根 testbench） | compile/run `0`，`TB_MODE_CONTROLLER_PASS` |
| `tb_osd_led_joint` | compile/run `0`，`PASS OSD status and four-state classifier LED joint contract` |
| `tb_industrial_contract` + `MORPH_SIMULATION` | compile/run `0`，ROI/状态/复位/非法 ROI 全部通过 |
| `test_v2_roi_contract.py` | `6 passed` |
| ROI 静态构建契约 | `1 passed, 26 deselected` |

OSD 编译仍有 `anlogic_logo_rom.v` 继承 timescale 的 warning；它未改变本次行为判定，后续单独清理。

## 全量门结果

- `python -B -m pytest -q work/tests`：`52 passed, 8 failed`。8 个失败集中在冻结提交与后续工作区之间的既有构建/release/路径契约漂移；没有出现 G1 模式、OSD 或 ROI 用例失败。
- `pwsh -File .\\scripts\\verify-industrial-subsystem.ps1`：第 1/13 阶段 Algorithm Lab 的 5 个样本通过；第 2/13 阶段因 Stage D registry 的 `model_sha256=ef929f...` 与当前 plugin `08f929...` 不一致而停止。该问题属于冻结基线一致性缺口。
- 未运行 TD 综合/实现/Bitgen：前置回归存在一致性失败，且 V2 尚无独立 QoR 报告。
- 未进行板卡、摄像头、HDMI 或外部执行器测试；当前硬件枚举未发现可用下载设备。

## 阶段门

`V2-G1 = BLOCKED`，分层结果为：

- 软件合同：`SOFTWARE_PASS`；
- RTL 合同：`RTL_PASS`；
- TD：`NOT_RUN/BLOCKED`；
- 硬件：`NOT_RUN/BLOCKED`。

V1 冻结候选仍是唯一 `BASELINE_V1`；V2 没有产生可称为 `LAST_GOOD_V2` 的 Bitstream。下一入口是先解决或正式界定冻结基线一致性问题，再做隔离 TD 构建和真实硬件验收。
