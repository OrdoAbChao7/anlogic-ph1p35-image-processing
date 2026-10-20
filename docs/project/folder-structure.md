# 项目目录职责

本目录结构按“当前实现、验证工具、证据文档、厂商资料、历史方案”分区。当前近期整合对象是颜色检测候选；长期目标与发布依赖仅由 PROJECT_GOAL 和验收矩阵定义，YOLO归档不等于目标删除。目录整理以 `E:\Projects\FPGA` 为准；`E:\Projects\FPGA-fallback` 是独立 fallback 工作区，不与本目录混用。

## 一眼看懂的项目树

```text
E:\Projects\FPGA\
├─ fallback/       当前固定红色检测候选：RTL、TD 工程、测试和候选发布包
├─ work/           当前研发源码与验证工具
│  ├─ algorithm_lab/  软件视觉预览与参数验收入口
│  ├─ models/         软件参考模型和小型输入
│  ├─ fpga_loop/      仿真、Golden Model、TD 适配器和回归源码
│  ├─ integration/   独立整合候选快照，不是厂商工作目录
│  ├─ rtl/            可独立仿真的图像处理 RTL
│  ├─ tests/          软件/RTL 测试入口
│  ├─ output/         被忽略的历史生成物和预览输出
│  └─ td_cartoon/     早期卡通 TD 候选，保留作历史证据
├─ docs/             目标、设计、实验、构建和验收证据
├─ preboard/         上板前契约、操作说明和资料清单
├─ archive/          历史路线和历史实验的只读归档
├─ HX1P35A2026/      组员/厂商工程原始副本
├─ SC520CS摄像头资料/  摄像头原始资料
├─ 安路HX1P35A比赛文档2026/ 比赛和 TD 原始资料
└─ reference/        第三方参考工程，只读
```

## 当前开发区

| 目录 | 职责 | 是否属于当前主线 |
|---|---|---|
| `fallback/project/` | 当前固定红色方案的 TangDynasty 工程、约束、IP 和板级源文件 | 是 |
| `fallback/rtl/` | 现有颜色检测、包围盒/绘框和打包RTL镜像；形态学与缺陷判定仍属规划 | 是 |
| `fallback/tests/` | 固定红色 RTL 的测试与回归入口 | 是 |
| `fallback/release/` | 当前候选发布包和下载说明 | 是，发布前仍需硬件验收 |
| `work/integration/` | 当前集成候选的工程快照、构建输入、报告和测试结果 | 是，作为整合验证区 |
| `work/algorithm_lab/` | 软件参考模型、硬件等价预览和 `VISUAL_APPROVED` 留痕 | 是 |
| `work/models/` | 通用图像算法参考模型和小型测试输入 | 是 |
| `work/rtl/` | 可独立仿真的图像处理 RTL，如 Sobel、卡通化 | 是，接入主工程前仍按阶段门验收 |
| `work/tests/` | 软件模型和 RTL 的测试脚本 | 是 |
| `work/fpga_loop/` | 自动化仿真、综合、报告解析和运行证据 | 是 |
| `scripts/` | 打开 TD、运行算法实验台和 FPGA 验证循环的入口 | 是 |

## 资料和证据区

| 目录 | 职责 |
|---|---|
| `docs/project/` | 目标、阶段、状态、目录和决策 |
| `docs/research/` | 比赛资料、器件资料、开源评估和未关闭缺口 |
| `docs/experiments/` | 可复现实验记录和失败记录 |
| `docs/build/` | 综合、实现、时序和构建摘要 |
| `docs/evidence/` | 上板、显示、长稳和演示证据 |
| `docs/verification/` | 验收矩阵和验证要求 |
| `preboard/` | 上板前接口契约、算法契约、操作说明和资料包清单 |
| `docs/evidence/fpga-loop/` | 从验证循环提炼的可长期保留摘要；不放原始 TD 数据库 |

## 非主线目录

| 目录 | 说明 |
|---|---|
| `archive/legacy/yolo/` | 归档的 YOLO/检测研究快照。只保留历史实验、报告、模型和可追溯来源，不作为当前构建输入 |
| `work/td_cartoon/` | 早期卡通化 TD 候选和历史构建材料；当前固定红色集成不直接依赖它 |
| `.tools/td/` | 本机 TangDynasty 程序和工作副本，不纳入日常源代码维护 |
| `安路HX1P35A比赛文档2026/`、`SC520CS摄像头资料/`、`HX1P35A2026/`、`reference/` | 原始厂商资料、组员工程和第三方参考，只读对照区 |
| `work/output/`、`work/algorithm_lab/cache/`、`__pycache__/` | 本机生成物或缓存，不是源代码和交付输入 |
| `work/fpga_loop/runs/` | 每次验证循环的原始输出，已加入 `.gitignore`；需要保留的结论必须提炼到 `docs/evidence/`、`docs/build/` 或 `docs/experiments/` |

## 已执行的清理边界

- 已将 YOLO/检测研究从 `work/` 迁入 `archive/legacy/yolo/`；归档内容保留来源、失败记录和许可证线索，不作为当前构建输入。
- 已删除 `work/fpga_loop/runs/` 下 2,677 个未跟踪临时文件，共约 142.7 MB；这些是可由验证循环重新生成的 TD 数据库、虚拟环境、`.vvp` 和激励文件。
- 保留 `fallback/release/`、`docs/build/`、`docs/evidence/` 和 `work/integration/` 中的工程/报告/校验清单，因为它们仍承担恢复、审计或发布证据职责。
- 未删除原始比赛资料、SC520CS 资料、第三方参考工程和历史卡通候选；这些不是当前源码，但仍可能用于接口核对或追溯既有结论。

## 进入当前工作的推荐顺序

统一遵循 [AGENTS](../../AGENTS.md) 的按任务阅读路由与 [Agent工作流](../development/agent-workflow.md)。整合回归/构建使用本副本脚本并显式指定工具路径，见 [工具链手册](../development/toolchain.md)。历史清理统计不代表当前目录大小，也不授权重复删除。
