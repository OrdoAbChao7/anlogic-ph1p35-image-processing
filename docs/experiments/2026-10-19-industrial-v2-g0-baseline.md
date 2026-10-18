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

待执行。每条命令记录实际退出码、输出位置和证据类型；不得把历史 STATUS 文本复制为本轮实测。

## 当前已知边界

- 原 `E:/Projects/FPGA` 与 `E:/Projects/FPGA-fallback` 均存在用户已有修改；V2 使用独立 Worktree，未清理原目录。
- V1 冻结候选和 SHA-256 已由 Worktree 创建前的只读审计核对。
- `sdd-workspace` 因主机无 WSL/bash 未运行，计划台账已按同一目录契约手工创建。
