# Industrial Vision V2 候选发布包完整性审计

状态：`CANDIDATE_ONLY`，不是最终发布签核。  
审计依据：用户最终要求文件 `a127966e01a0fe7a4abcf9ebc0a6df6b45b3c9093651120f55497318285adf52`。

## 结论

当前 `release/industrial-v2/` 已包含正式七功能候选 Bitstream、SHA-256、manifest、TD 报告和构建 Flow，但还不是可独立交付的最终包。源码、完整输入包、测试/证据索引、现场手册、回退说明、上板验收矩阵和物理性能结果仍需补齐或绑定；硬件验收缺失不能用文档占位替代。

## 要求逐项审计

| 最终交付物要求 | 当前状态 | 当前证据或缺口 |
|---|---|---|
| 唯一正式下载 `.bit` | `PRESENT_CANDIDATE` | `industrial-v2.bit`；SHA-256 见 `manifest.json`；最终发布仍被硬件门禁阻止 |
| SHA-256 | `PRESENT` | `manifest.json` 与 `README.md` |
| Manifest | `PRESENT_CANDIDATE` | `manifest.json`；包含 TD、源码和候选位流 provenance |
| TD 完整报告 | `PRESENT_CANDIDATE` | `route.qor`、`final_timing.rpt`、`td-reports/` |
| 工程复现说明 | `PARTIAL` | `fallback/td_package/README.md`、`scripts/build_industrial_td.py`；TD 安装和完整干净重建仍是外部依赖 |
| 核心源码与必要约束 | `OUTSIDE_PACKAGE` | 当前位于 `fallback/rtl/`、`fallback/td_source/`、`fallback/td_package/`；尚未复制或封装到本目录 |
| 测试与证据索引 | `OUTSIDE_PACKAGE` | `work/tests/`、`docs/goals/industrial-v2/EVIDENCE_INDEX.md`；未封装到本目录 |
| 现场演示手册 | `MISSING` | 尚未形成与候选 Bitstream SHA 绑定的现场操作手册 |
| 回退版本说明 | `OUTSIDE_PACKAGE` | V1 位流与回退资料在 `release/industrial-v1/` 及 Goal 文档；未封装到本目录 |
| 上板验收矩阵 | `OUTSIDE_PACKAGE` | `docs/goals/industrial-v2/HARDWARE_TEST_PLAN.md`；硬件尚未执行 |
| 性能测试结果 | `MISSING_PHYSICAL` | 当前只有软件/RTL/TD 层证据；物理帧率、端到端延迟和检测更新率未测 |
| 已关闭和未关闭风险列表 | `OUTSIDE_PACKAGE` | `docs/goals/industrial-v2/RISK_REGISTER.md`、`BLOCKERS.md`；未封装到本目录 |

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
