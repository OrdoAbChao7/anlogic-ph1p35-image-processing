# Industrial V2 G8 子系统回归续跑

## 目标与环境

- 目标：在不覆盖既有 `work/tests/verification_outputs/` 结果的前提下，复跑可用的工业检测、显示、模式控制和视频流回归。
- 代码版本：`3314966`（运行时 HEAD；RTL 与正式回归脚本未修改）。
- 仿真器：Icarus Verilog 14.0 (devel)，Python 测试由当前环境 `python.exe` 执行。
- 输出：`work/tests/verification_runs/20261019-135334/` 保存首轮 1–3 阶段日志；`work/tests/verification_runs/20261019-135554/` 汇总前置日志并保存续跑 4–13 阶段产物。

## 步骤与结果

| 原步骤 | 结果 | 证据 |
|---|---|---|
| 1 Algorithm Lab 五个工业样本 | PASS，五个样本分类及硬件等价模型一致 | `algorithm_lab.stdout.log` |
| 2 Stage D、industrial contract、build/G2 contract | PASS；Stage D 5 项、industrial contract 5 项、build/G2 contract 通过 | `stage_d.stderr.log`、`industrial_contract.stderr.log`、`industrial_build_contract.stdout.log` |
| 3 归档旧版 `color_detect_96` 基线 | BLOCKED：`archive/fixed-red-legacy/tb_color_detect_96.v` 在当前 V2 检出中不存在，编译器报 `No such file or directory`；没有用 V2 RTL 冒充旧基线 | `baseline_compile.stderr.log` |
| 4 1280×720 全前景检测 | PASS，面积 `921600`，包围盒 `(0,0)-(1279,719)` | `full_frame_run.stdout.log` |
| 5 Q10 阈值边界 | PASS，开区间边界向量通过 | `threshold_boundaries_run.stdout.log` |
| 6 工业检测集成 | PASS，标准件 PASS、超宽件 NG、空场 NO_OBJECT，OSD 边框颜色一致 | `subsystem_run.stdout.log` |
| 7 检测器/分类器契约矩阵 | PASS，尺寸、ROI、边缘、间断 valid、复位和非法 ROI 场景通过 | `industrial_contract_sim_run.stdout.log` |
| 8 VTC/HDMI 时序契约 | PASS，4 帧、8×4 active、观测到 3 拍 sideband 延迟 | `video_timing_run.stdout.log` |
| 9 检测结果 CDC | PASS，帧边界原子提交测试通过 | `inspection_result_cdc_run.stdout.log` |
| 10 三模式全帧流 | PASS，`2,938,270` 周期，1280×720 的 RGB/DE/HS/VS/mode 匹配 | `three_mode.stdout.log` |
| 11 OSD/Logo/status/LED 联合测试 | PASS；编译有 timescale 继承 warning，详见下文 | `osd_led_run.stdout.log`、`osd_led_compile.stderr.log` |
| 12 模式控制器 | PASS，去抖和帧边界切换通过 | `mode_controller_run.stdout.log` |
| 13 四态分类器/LED 互斥 | PASS，PASS/NG/NO_OBJECT/INVALID 状态通过 | `defect_classifier_run.stdout.log` |

本次可验证的 13 个编号步骤中，12 项通过、1 项因缺少归档 RTL 而阻塞。Step 1/2 在首轮执行，Step 3 确认缺失后，Step 4–13 在新目录继续执行。续跑复用了脚本末尾固定的通用 `13/13` banner，但由于 Step 3 未执行，该 banner 不作为结果证据；以上逐项日志和计数为准。正式脚本保持未修改。

## 告警与副作用

- OSD 联合仿真编译提示 `anlogic_logo_rom.v` 从 `defect_classifier.v` 继承 timescale；测试仿真通过，但该 warning 仍应在 warning audit 中分类，不视为已消除。
- Step 1 刷新了被 `.gitignore` 忽略的 `work/algorithm_lab/exports/industrial_inspection_preview/` 五张 PNG；刷新后五张文件的 SHA-256 均与 fallback 工作树保留的副本一致。V2 覆盖前没有记录旧哈希，因此不推断被覆盖版本与副本逐字节一致。
- Step 10 在先前不存在的 `work/output/cartoon-region-fill-candidate/` 生成全帧向量和仿真文件；保留作为本次可重查产物。
- 正式脚本 `scripts/verify-industrial-subsystem.ps1` 与 RTL 无工作区改动。

## 结论与后续

- 这是工程级仿真证据，不代表 TangDynasty 构建、下载、板上画面、外部执行器或长稳测试通过；工业 V2 G8 发布状态不因此解除阻塞。
- 首轮执行当时缺少可追溯的 `color_detect_96` 归档源与测试平台；不能以当前 V2 模块替代旧基线。该阻塞由下方 follow-up 使用已验证来源关闭。
- 下一步仍需实际连接 PH1P35/SC520CS/显示器/JTAG 和执行器，完成硬件矩阵、冷启动/热复位、长稳和测量证据。

## 2026-10-19 follow-up：基线溯源与完整回归

- `archive/fixed-red-legacy/color_detect_96.v` 和 `tb_color_detect_96.v` 已核验来源为仓库提交 [`651f9bca3490649afbe1449802d1f3e8ae8df0bf`](https://github.com/OrdoAbChao7/anlogic-ph1p35-image-processing/commit/651f9bca3490649afbe1449802d1f3e8ae8df0bf)。CRLF 转 LF 后，两个归档文件与该提交中的源 RTL/testbench 逐字一致；Git blob 和 SHA-256 记录见 `archive/fixed-red-legacy/PROVENANCE.md`。
- 使用隔离输出目录 `work/tests/verification_runs/20261019-full-isolated/` 重跑现有一键验证脚本，13/13 阶段全部通过；三模式全帧 RGB/DE/HS/VS/mode 在 `2,938,270` 周期逐项匹配。
- 新鲜执行 `python -B -m pytest -q work/tests -p no:cacheprovider`，结果 `143 passed`，完整输出见 `docs/evidence/industrial-v2-g8-pytest-20261019-log.txt`。严格 G8 发布审计保存为 `docs/experiments/2026-10-19-industrial-v2-g8-release-audit-rerun.json`：13 个门中 7 个 PASS、6 个仍 BLOCKED（PHY/CDC 告警、实体硬件/性能/长稳、位流逐字节可复现、执行器）。
- OSD/Logo 仿真仍报告 timescale 继承 warning。本轮没有下载位流，也没有进行任何板级验收。
