# 日常工作区

从仓库根目录开始。这里放**我们自己编写、可以纳入 Git 的实现**。当前整合副本在 `work/integration/`；`.tools/td/work/` 保留旧原图与时钟修复副本，不是新功能默认编辑区。命令与门禁统一见 [工具链手册](../docs/development/toolchain.md) 和 [Agent工作流](../docs/development/agent-workflow.md)。完整目录职责见 [项目目录职责](../docs/project/folder-structure.md)。

| 要做什么 | 打开哪里 |
| --- | --- |
| 查看当前固定红色候选 | [`../fallback/project/`](../fallback/project/) 和 [`../fallback/rtl/`](../fallback/rtl/) |
| 查看当前整合候选 | [`integration/`](integration/)：工程快照、构建输入、报告和测试结果 |
| 运行自动化验证循环 | [`fpga_loop/`](fpga_loop/)；运行证据保留在 `fpga_loop/runs/` |
| 查看归档的 YOLO 研究 | [`../archive/legacy/yolo/`](../archive/legacy/yolo/)；只读历史区，不作为当前视频构建输入；长期目标见 PROJECT_GOAL |
| 接续组员原图/卡通工作 | [2026-10-11 同步记录](../docs/setup/team-sync-2026-10-11.md)：导入目录、源码差异、时序失败、位流哈希及待修复项；原包在 `../HX1P35A2026/` |
| 看当前该做哪一步 | [新手项目手册](../docs/setup/beginner-project-guide.md) |
| 修改或运行算法参考模型 | [models/reference_model.py](models/reference_model.py)；测试图 [models/step.pgm](models/step.pgm) |
| 改 SC520 Lab1 的 FPGA 工程 | 在仓库根目录运行 `pwsh -File .\scripts\open-td.ps1`；实际工程在 `../.tools/td/work/lab_ex1_mipi_hdmi_sc520/td_project/camera_to_dsi_display.al` |
| 看时钟修复候选工程 | 运行 `pwsh -File .\scripts\open-td.ps1 -ClockFix`；改动只在独立工作副本中 |
| 看本次构建结果与上板证据 | [构建摘要](../docs/build/goal-1-sc520-lab1/build-summary.md)、[实验记录](../docs/experiments/goal-1-baseline.md)、[上板记录](../docs/evidence/goal-1/2026-10-02-bringup.md) |
| 查接口和算法定义 | [接口契约](../preboard/02-interface-contract.md)、[算法契约](../preboard/03-algorithm-contract.md) |

在仓库根目录运行软件模型：

```powershell
python .\work\models\reference_model.py --self-test
python .\work\models\reference_model.py --input .\work\models\step.pgm --out-dir .\work\output --threshold 128 --edge-threshold 128
```

`work/output/`、`work/algorithm_lab/cache/` 和各目录下的 `__pycache__/` 都是本机生成物，已被 Git 忽略。新增的自有 RTL、仿真和样例应放在已有功能目录中，不要重新在根目录散落副本。修改 TD 厂商基线前先记录原始构建结果，按 [AGENTS.md](../AGENTS.md) 的阶段门推进。
