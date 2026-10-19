# fixed-red v1 TD 告警归类记录

本记录对应当前 fixed-red v1 第二次显式 ERAM 构建，发布提交为 `8077f9567e546998cbed93671e3ad8b4ac2b8561`，功能源码修复提交为 `2eec6701ab2635b2133485cabb2876491d050770`；发布位流、报告和输入哈希以 `release/industrial-v1/industrial-v1-manifest.json` 为准。工具为 Tang Dynasty `v6.2.168116`，器件为 `PH1P35MDG324 / Speed 3`。

当前告警来自本次构建日志：

- 综合：`work/td_industrial/td_project/camera_to_dsi_display_Runs/syn_1/flow_exec.log`；本次完整运行汇总：`work/td_industrial/repeat-build-20261017.log`
- 物理实现：`work/td_industrial/td_project/camera_to_dsi_display_Runs/phy_1/flow_exec.log`

## 结论摘要

本轮 TD 各阶段 exit code 为 `0`。第二次 Route QoR 为 Setup WNS `+103 ps`、Hold WNS `+20 ps`、TNS `0`、违规端点 `0`；Slice `16,852/79.43%`、RAM `43`、DSP `24`，STA coverage `96.52%`。四个形态学行缓存显式映射为 `PH1P_LOGIC_ERAM`，ROI 边界复制语义已随源码重建，ISP 输出 ready 已显式 tie-high；正时序不能自动关闭结构性告警，以下当前日志告警全部保持 **OPEN**，也没有任何板卡证据。

| 告警 | 定位 | 当前归类 | 是否关闭 |
|---|---|---|---|
| `HDL-5001` | 综合日志中的匿名实例/网络未重命名提示 | 工具命名提示；需确认是否影响后续网表追踪 | **OPEN** |
| `HDL-5007` | 注释或端口位宽不匹配提示 | RTL/生成源接口卫生问题；需逐项核对 | **OPEN** |
| `HDL-5106` | `scl_r`、`sda_o` 等非 DFF 初始值被省略 | 初始值语义需结合复位和综合实现确认 | **OPEN** |
| `HDL-5314` / `HDL-5317` / `HDL-5323` | DDR PHY、Demosaic、FIFO、divider 和 `dib` 信号的未驱动/未连接端 | 生成 IP/存根端口告警；不能仅因 bitgen 成功判定无害 | **OPEN** |
| `HDL-5369` | 生成 DDR `alc_mc_top_all.enc.sv` 中推断锁存 | 厂商生成源结构告警；需结合 IP 配置和门级行为确认 | **OPEN** |
| `PRJ-5611` | Logo ROM 与摄像头寄存器文件 CompileOrder 相同 | 工程编译序号冲突；应在项目文件整理中固定唯一序号 | **OPEN** |
| `SYN-5011` | Demosaic/DDR 初始化 RAM 存在未驱动数据端 | 生成 RAM/DDR 初始化端口；需结合 IP 配置和板级 DDR 初始化确认 | **OPEN** |
| `SYN-5013` | 当前日志中的 `key_remove_shakes/I_rst_n`、AWB `signal_delay` 和延迟 RAM `dib` 等未驱动网络 | `S_ISP_O_tready` 已在本轮源码中显式 tie-high，最新综合日志不再报告该网络；其余生成/接口告警仍需逐项复核 | **OPEN** |
| `SYN-5025` | 工具将未驱动引脚/网络统一置 `0` | 结果依赖工具补值；不能代替 RTL 或 IP 端口审计 | **OPEN** |
| `SYN-5041` | FIFO/cartoon RAM 使用了不匹配的 `RAM_STYLE/AUTO` 属性 | 存储推断属性与目标资源的映射风险；需审查约束和 QoR | **OPEN** |
| `SYN-5065` | `O_invalid`、`acc_invalid` 及厂商 DDR 寄存器出现异步复位/置位组合语义 | 综合解释风险；仿真和 STA 通过不等于结构已确认 | **OPEN** |
| `PHY-5016` | PLL `clkc` 驱动无 location 的 IO，且不是 clock-capable IO | 板级时钟引脚/约束风险，需原理图、约束和上板波形确认 | **OPEN** |
| `PHY-5060` | `O_cam_24m_syn_3` 与 `u_uicfgcs520/u_i2c/scl_clk` 存在混合时钟/数据扇出 | 需审查实际 sink 和约束；不能凭 WNS 正值关闭 | **OPEN** |
| `PHY-5079` | 时钟网络使用 local routing resources | 时钟路由风险，需详细时钟分析和上板稳定性证据 | **OPEN** |
| `PHY-5088` | clock analyzer 检出 clock buffer 驱动非时钟 sink 或其他 clock net | 时钟树结构风险，需逐网审查 | **OPEN** |

## 已确认的边界

- 当前告警代码来自第二次 ERAM 构建日志，而不是沿用旧版资源告警记录；本记录不把已通过的 WNS 当作告警关闭依据。第一次完整构建的位流和报告差异已保留在实验记录中。
- `S_ISP_O_tready` 已在 `fallback/td_source/design_top_wrapper.v` 中明确 tie-high，因为当前 `video_in` 没有反压输出；第二次完整 TD 日志未再报告该网络未驱动问题。
- 没有修改厂商 DDR、MIPI、HDMI、PLL 或约束生成文件来换取表面通过。
- 当前没有 PH1P35 板卡、SC520CS 摄像头和 HDMI 现场证据；冷启动、热复位、锁相、画面、长稳和真实时钟行为仍属于 Stage G 未完成项。

## 关闭条件

每项告警必须给出来源、sink/约束解释、必要的最小修改或官方 IP 依据，并重跑完整 TD；涉及摄像头、DDR、PLL、HDMI 或时钟网络的项目，还需要真实板卡冷启动、热复位和长稳证据。告警关闭前保持 **OPEN**，不得用 bitgen 成功或单张显示截图替代证据。

当前发布绑定（工程构建证据，告警仍保持 OPEN）：`release/industrial-v1/camera_to_dsi_display_compress.bit`，SHA-256 `e9815a4a42f085d26cb8744c0d5a485020d3ece3e1a1bb7aff20d92264de68d3`；对应 Slice `16,852/79.43%`、Setup WNS `+103 ps`、Hold WNS `+20 ps`。
