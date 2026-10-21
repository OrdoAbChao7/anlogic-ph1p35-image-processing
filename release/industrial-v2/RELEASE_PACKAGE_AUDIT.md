# Industrial Vision V2 候选发布包完整性审计

状态：`CANDIDATE_ONLY`，不是最终发布签核。  
审计依据：用户最终要求文件 `a127966e01a0fe7a4abcf9ebc0a6df6b45b3c9093651120f55497318285adf52`。

## 结论

当前 `release/industrial-v2/` 已包含正式七功能候选 Bitstream、SHA-256、manifest、TD 报告、核心源码/约束快照、测试快照和候选版手册；它仍不是最终硬件发布包。物理性能结果、硬件验收和完整可复现性仍需真实证据，不能用文档占位替代。

## 要求逐项审计

| 最终交付物要求 | 当前状态 | 当前证据或缺口 |
|---|---|---|
| 唯一正式下载 `.bit` | `PRESENT_CANDIDATE` | `industrial-v2.bit`；SHA-256 见 `manifest.json`；最终发布仍被硬件门禁阻止 |
| SHA-256 | `PRESENT` | `manifest.json` 与 `README.md` |
| Manifest | `PRESENT_CANDIDATE` | `manifest.json`；包含 TD、源码和候选位流 provenance |
| TD 完整报告 | `PRESENT_CANDIDATE` | `route.qor`、`final_timing.rpt`、`td-reports/` |
| 工程复现说明 | `PRESENT_CANDIDATE` | `handbook/REBUILD.md`、`source/README.md`、`source/source-manifest.json`；TD 安装和完整干净重建仍是外部依赖 |
| 核心源码与必要约束 | `PRESENT_CANDIDATE` | `source/fallback/rtl/`、`source/fallback/td_source/`、`source/fallback/td_package/`，共 249 个文件 |
| 测试与证据索引 | `PRESENT_CANDIDATE` | `tests/` 共 73 个文件、`evidence/INDEX.md`；包内测试是快照 |
| 现场演示手册 | `PRESENT_CANDIDATE` | `handbook/DEMO_RUNBOOK.md`，绑定候选 Bitstream SHA |
| 回退版本说明 | `PRESENT_CANDIDATE` | `fallback/README.md`；V1 位流仍保存在仓库冻结候选目录 |
| 上板验收矩阵 | `PRESENT_CANDIDATE` | `hardware/HARDWARE_TEST_PLAN.md`；所有硬件项目仍为 `NOT_RUN` |
| 性能测试结果 | `PRESENT_WITH_PHYSICAL_GAP` | `performance/RESULTS.md`；只有软件/RTL/TD 层证据，物理帧率、端到端延迟和检测更新率未测 |
| 已关闭和未关闭风险列表 | `PRESENT_CANDIDATE` | `RISK_REGISTER.md`；告警、硬件、复现和执行器风险仍开放 |

## 七项功能状态

当前候选的七项功能均达到 `SOFTWARE_PASS / RTL_PASS / TD_PASS`，硬件列统一为 `HARDWARE_NOT_RUN`：

1. OSD、按键、基础质量
2. 动态跟踪
3. 延迟测量
4. ROI 帧差
5. 分拣控制
6. 自适应白平衡
7. 标定与形状验证

视觉审批按用户指令记为 `AUTHORIZED`，仅适用于 Stage C，不改变上述硬件状态。

## 进入最终包的条件

只有在不改变候选功能语义的前提下，完成材料封装，并将同一 commit、Bitstream SHA-256、TD 版本、板卡/摄像头配置和原始硬件记录绑定后，才能把本目录从 `CANDIDATE_ONLY` 提升为发布包。物理性能、冷启动、长稳、执行器和告警闭环仍必须取得真实证据。
