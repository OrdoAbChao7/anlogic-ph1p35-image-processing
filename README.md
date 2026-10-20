# 安路 PH1P35 实时图像处理项目

目标是在SC520CS → MIPI/ISP → DDR2 → HDMI链路上完成三模式图像处理、工业检测、OSD与外设联动。已有可构建候选和部分仿真证据，完整硬件闭环与作品验收尚未通过。当前状态只维护在 [STATUS](docs/project/STATUS.md)。

## 从这里开始

| 需要什么 | 入口 |
|---|---|
| Agent进入项目 | [AGENTS.md](AGENTS.md) → [稳定目标](docs/project/PROJECT_GOAL.md) → [当前状态](docs/project/STATUS.md) → [执行工作流](docs/development/agent-workflow.md) |
| 运行工具链 | [工具链手册](docs/development/toolchain.md)：区分独立模块、整机回归、TD构建、报告与导出 |
| 判断阶段是否通过 | [阶段依赖](docs/project/PHASES.md)与[验收矩阵](docs/verification/acceptance-matrix.md) |
| 算法效果与参数 | [软件先行协议](docs/development/software-first-protocol.md)、work/algorithm_lab/ |
| 接续工程整合 | [整合方案](docs/development/integration-plan.md)、work/integration/ |
| 找源码与恢复包 | [目录职责](docs/project/folder-structure.md)、[日常工作区](work/README.md) |
| 查来源与未知项 | [研究索引](docs/research/INDEX.md)、[开源评估](docs/research/OPEN_SOURCE.md)、[缺口](docs/research/known-gaps.md) |

## 工程边界

- work/integration/ 是当前独立整合区；fallback/ 是传统工业视觉路线；fallback/release/ 保留候选恢复包。
- 厂商/组员原包、第三方参考和本机.tools不作新功能默认编辑区；工程输入以实际.al引用为准。
- archive/legacy/yolo/ 保存历史检测研究，当前未接入视频构建；归档不等于取消PROJECT_GOAL中的裁剪检测网络目标。
- Logo与显示CNT已有工程接入；单颜色框不证明物体类别或多目标数量。位流生成不证明上板稳定。
- 原始工程/本机工具并非全部随Git交付。完整重建使用对应候选包及工具链手册，不承诺仅clone仓库即可得到可下载位流。

本页只做导航，不另存阶段状态或性能数字。历史进展见 [状态快照](docs/project/status-history-20261016.md)，正式目标与验收不由目录名称、README或旧报告决定。
