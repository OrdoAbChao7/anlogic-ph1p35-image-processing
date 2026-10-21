# V2 候选包风险清单

| 风险 | 状态 | 关闭证据 |
|---|---|---|
| `PHY-5016/5060/5079/5088` 时钟/CDC/IO 告警 | `OPEN` | 逐告警 source/sink/约束解释、必要重建及板级稳定性记录 |
| 固定 seed 字节级复现 | `OPEN` | 两次同输入、同工具、同参数的 SHA-256 一致 Bitstream |
| SC520CS/MIPI/HDMI 功能闭环 | `NOT_RUN` | 下载、相机、显示和原始观测记录 |
| 冷启动、热复位和长稳 | `NOT_RUN` | 按矩阵完成重复下载和连续 4 h 日志 |
| 物理性能 | `NOT_RUN` | 帧率、刷新率、E2E 和检测更新率测量 |
| 外部执行器 | `NOT_RUN` | GPIO、电气隔离、机械动作和故障恢复证据 |
| 候选包源码/输入漂移 | `CONTROLLED` | `source/source-manifest.json`；重新构建前需复核哈希 |

视觉审批授权为 `AUTHORIZED`，仅覆盖 Stage C，不关闭上述风险。
