# Industrial Vision V2 G0 Baseline

日期：2026-10-19（Asia/Shanghai）  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`  
基线：`256d99c1d0dc4dbae2ace8d0ff3a97f504d514c9`

## 目标

保护 fixed-red v1 冻结候选，核对 V2 Worktree 干净状态、工具入口、现有软件/RTL 回归、冻结位流哈希和 V1 资源/时序基线。

## 预期

- V2 Worktree 不含未提交修改。
- 冻结位流 SHA-256 为 `b483a1ffc30d0b7ae9e8ebef4f31f617d33a53d6784ded8007d5443c51ad80ef`。
- V1 资源/时序只作为对照；V2 新结果另行记录。
- 无设备时硬件阶段保持 `NOT_RUN/BLOCKED`。

## 实际结果

### Worktree and artifacts

- V2 Worktree 在文档检查点后保持干净；原 `E:/Projects/FPGA` 与 `E:/Projects/FPGA-fallback` 的既有改动未复制、清理或覆盖。
- 冻结位流 SHA-256 重算结果：`b483a1ffc30d0b7ae9e8ebef4f31f617d33a53d6784ded8007d5443c51ad80ef`，与冻结报告一致（`project`）。
- `scripts/fpga-loop.ps1` 在 V1 冻结提交中不存在；不从另一个脏 Worktree 静默复制，记录为工具入口缺口。

### Tool audit

| Command / item | Result | Evidence type |
|---|---|---|
| `python --version` | `Python 3.13.7` | project |
| `python scripts/build_industrial_td.py --help` | exit `0`，参数入口可用 | project |
| `E:\Projects\FPGA\.tools\iverilog\bin\iverilog.exe -V` | Icarus Verilog `14.0 (devel)` | project |
| `E:\Projects\FPGA\.tools\iverilog\bin\vvp.exe -V` | VVP runtime `14.0 (devel)` | project |
| TD executable | exists at `E:\Projects\FPGA\.tools\td\app\bin\td_commands_prompt.exe` | project |
| hardware enumeration | no matching Anlogic/FPGA/JTAG device returned | unknown / not detected |

### Regression results

- `python -B -m pytest -q work/tests`：`46 passed, 8 failed`。首个失败为 `test_default_build_stays_on_s3_luma`，冻结提交的默认构建入口仍是 `fallback/rtl/video/video_cartoon_region_fill.v`，而测试期望后续工作区的 `work/rtl/video_cartoon_luma.v`；其余失败集中在后续 release/manifest/OSD 路径整理，不是 V2 改动造成。
- `pwsh -File .\\scripts\\verify-industrial-subsystem.ps1`：Stage 1 的 5 个 Algorithm Lab 样本通过；Stage 2 的 `test_approved_registry_freezes_model_params_and_inputs` 因 registry 中的 `model_sha256=ef929f...` 与当前冻结提交插件 `08f929...` 不一致而停止。该失败保留为基线一致性缺口。
- 本轮未运行 TD 综合/实现/Bitgen；G0 只完成入口核查，避免把 V1 历史报告写成 V2 构建结果。

## 当前已知边界

- 原 `E:/Projects/FPGA` 与 `E:/Projects/FPGA-fallback` 均存在用户已有修改；V2 使用独立 Worktree，未清理原目录。
- V1 冻结候选和 SHA-256 已由 Worktree 创建前的只读审计核对。
- `sdd-workspace` 因主机无 WSL/bash 未运行，计划台账已按同一目录契约手工创建。

## G0 判定

`ACTIVE / BLOCKED_ON_BASELINE_CONSISTENCY_AND_HARDWARE`。可以继续做不依赖物理设备的 V2 软件/RTL 工作；不能标记 G0 通过，也不能执行 V2 正式 TD 合并，直到回归基线缺口被记录为可接受的历史基线或完成最小一致性修复。
