# Git 分支管理与 Worktree 双工作区策略

## 1. 分支拓扑与路径映射

| 路线类别 | 分支名称 | 物理工作区绝对路径 | 职能定义 |
|---|---|---|---|
| **主线** | `main` | `E:\Projects\FPGA` | YOLO-tiny 目标识别、轻量 CNN 加速器、卡通化渲染及系统集成 |
| **备用线** | `fallback/industrial-inspection` | `E:\Projects\FPGA-fallback` | 传统工业视觉检测、零件尺寸测量、缺陷判别与独立参赛交付包 |

## 2. 隔离与安全规则

1. **绝对禁止危险 Git 命令**：
   - 严禁执行 `git reset --hard` 清除已有开发进展。
   - 严禁未经人工核验直接执行 `git clean -df`。
   - 严禁强行 `push -f` 覆盖远端或覆盖默认分支。
2. **Worktree 工作区无锁并发**：
   - 主工作区执行 Python 算法量化、PyTorch 权重导出、YOLO 加速器 RTL 编码与仿真。
   - 备用工作区独立运行工业检测 RTL 迭代、TD 综合实现和工业 Demo 约束优化。
   - 两个工作区的构建缓存（`work/output/`、`camera_to_dsi_display_Runs/`）互相解耦，避免 TangDynasty 临时文件冲突。
3. **底层代码受控同步机制**：
   - 若摄像头驱动、MIPI 解包、DDR 时钟等公用底座发现 Bug，修复流程必须为：
     ```powershell
     # 1. 在 main 分支调试并通过测试
     git commit -m "fix(mipi): fix byte clock handshake jitter"
     $FIX_COMMIT = git rev-parse HEAD
     
     # 2. 进入备用工作区受控同步
     cd E:\Projects\FPGA-fallback
     git cherry-pick $FIX_COMMIT
     ```
   - 严禁直接使用文件管理器批量复制替换公共目录。

## 3. 当前版本基线快照

- **原始快照 Commit**：`da478b5287055133ba449be72ee34fe9685150fa`
- **内容覆盖**：完整收录了组员导入的卡通化工程、分阶段亮度卡通化 RTL、参考模型测试用例、历史 TD 路由报告。
