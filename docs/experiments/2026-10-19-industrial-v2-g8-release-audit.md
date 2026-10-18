# Industrial Vision V2 G8 发布审计

## 结论

`G8=BLOCKED`。发布审计入口已建立并可重复运行；V1 冻结位流 SHA-256 复核通过。当前已经有正式七功能顶层的 TD/STA/Bitgen 候选和 QoR，但尚未完成最终发布包、告警闭环、板卡功能矩阵、长稳记录或外部执行机构证据。

用户已明确将需要视觉审批的情况默认通过。本记录仅将 `visual_approval` 记为 `PASS`，不把视觉授权扩展为硬件、时序、构建或机械验收。

## 执行环境

- 工作树：`E:/Projects/FPGA-v2`
- 分支：`goal/industrial-v2-advanced`
- 审计入口：`scripts/verify_industrial_v2_release.py`
- 审计命令：`python -B scripts/verify_industrial_v2_release.py --strict`
- 审计快照：由脚本输出绑定当前 Git `HEAD`

## 结果摘要

| 类别 | 状态 | 证据/阻塞 |
|---|---|---|
| V1 冻结基线 SHA | `PASS` | 期望与实际均为 `b483a1ffc30d0b7ae9e8ebef4f31f617d33a53d6784ded8007d5443c51ad80ef` |
| 七项软件/RTL/TD | `BLOCKED` | 七功能正式顶层与 TD 候选已通过；G1-G7 的硬件/物理证据和 Stage D 前置一致性仍未闭合 |
| 同一 V2 Bitstream | `BLOCKED` | `release/industrial-v2/` 不存在 |
| V1 回归 | `BLOCKED` | `work/tests` 保留 8 个冻结基线与后续目录契约漂移失败 |
| V2 TD/QoR/告警 | `BLOCKED` | formal feature-spine 候选 TD/STA/Bitgen PASS；PHY-5079/PHY-5088 告警审计仍开放，且尚未绑定最终发布目录 |
| 上板/性能/长稳 | `BLOCKED` | 无绑定板卡、摄像头、显示器、Bitstream 和原始记录 |
| 外部执行机构 | `BLOCKED` | GPIO、电气、机械闭环仍未知 |
| 视觉审批 | `PASS` | 用户授权：默认通过，仅限 Stage C 视觉审查 |

## 可复现结果

脚本以非零退出码结束，符合 `--strict` 在阻塞时拒绝发布的合同。模块级 G1-G7 回归结果继续引用各阶段 summary；本记录不把它们升级为整机证据。

## 下一入口

下一次执行 G8 应从告警/CDC/约束审计和候选包复现开始，随后产出与 commit、源码哈希、Bitstream SHA-256、TD 版本、板卡/摄像头配置和原始上板记录绑定的证据包；在硬件证据闭合前状态保持 `BLOCKED`，不得标记 `RELEASED`。
