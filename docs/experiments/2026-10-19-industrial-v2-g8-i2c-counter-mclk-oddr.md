# Industrial V2 G8：I2C counter phase + MCLK ODDR 组合探针

## 目的

在不修改正式候选位流的前提下，将两个已独立验证过的结构性探针组合：

- I2C 配置器把 `scl_clk` 反馈寄存器替换为 `clkdiv` 比较器，并在 `I_clk` 域生成外部 SCL 相位；但内部状态机仍由 `posedge/negedge scl_clk` 触发，因此本探针没有消除派生事件时钟；
- 摄像头 `O_cam_24m` 通过 `PH1P_LOGIC_HD_ODDR` 输出，隔离 PLL 时钟直接扇出。

本实验只用于 G8 的告警闭合与资源/时序对照，不改变正式候选。

## 输入与可追溯性

- 输入包：`work/td_i2c_counter_mclk_oddr_input`
- 生成脚本：`scripts/prepare_i2c_counter_mclk_oddr.py`
- 生成的 `uii2c.v` SHA-256：`114c6f265e16ddca1a3336fa209300e2646e6e93d452daa86673369356f78af8`
- 生成的 top SHA-256：`fd65440dc4dfaea1305f0dd31e42fcb79413628301106a87272cb3647ab2c3e0`
- 静态检查：`work/tests/test_v2_i2c_counter_mclk_oddr.py`，2 项通过。

## 构建结果

使用 TangDynasty 默认流程、PH1P35MDG324、独立 work project 和不同 place seed：

| seed | 构建 | setup WNS | hold WNS | TNS / violated endpoints | PHY-50xx | Slice |
|---:|---|---:|---:|---|---|---:|
| 3 | PASS | +126 ps | +20 ps | 0 / 0 | 原始 `flow_exec.log`：PHY-5016×4、PHY-5088×4 | 18,528 / 21,216 = 87.33% |
| 1 | PASS | +113 ps | +20 ps | 0 / 0 | 原始 `flow_exec.log`：PHY-5016×4、PHY-5088×4 | 17,050 / 21,216 = 80.36% |
| 1（独立重复） | PASS | +109 ps | +20 ps | 0 / 0 | 原始 `flow_exec.log`：PHY-5016×4、PHY-5088×2 | 18,251 / 21,216 = 86.02% |
| 1（analyze_clock 详细诊断） | PASS | +101 ps | +20 ps | 0 / 0 | 原始 `flow_exec.log`：PHY-5016、PHY-5088 仍在 | 18,488 / 21,216 = 87.14% |

前三次构建的 RAM / DSP / DRAMHARDCON 均为 43 / 24 / 229。seed=1 首次位流大小为 1,370,865 bytes，SHA-256 为 `c59d3cf136268abe32dcdbd76a9e9a5dca697ef17e7d99a28c355d64599eba62`；同 seed 独立重复位流大小为 1,365,937 bytes，SHA-256 为 `fa42a3b5906964bda149fb5ceeda06b8540fd919adc906f51257dfd62b84ea3b`；seed=3 位流大小为 1,369,457 bytes，SHA-256 为 `1807fa5fe10230cc806f17d9cb095075d5e3c85333564315fa96ababe2ee181a`。详细诊断构建 route 报告 RAM / DSP / DRAMHARDCON 为 43 / 24 / 229，诊断位流为 1,359,729 bytes，SHA-256 为 `0fb1c1268b154e1a9bb8142952f750b86014b40dd70205a0a277a6a37ab89f5a`。

## 结论

`project`：三次组合探针均完成 TD 综合、实现、时序和 bitgen，route STA 通过。逐一检查与候选 Bitstream/QoR 哈希绑定的原始 `phy_1/flow_exec.log` 后，三次都确认存在 `PHY-5016` 和 `PHY-5088`；seed=3 与 seed=1 首跑各记录 4 条、seed=1 独立重复记录 2 条 `PHY-5088`，三次均记录 4 条 `PHY-5016`。此前“未检出”的判断只扫描外层包装日志，外层日志不包含 TD 内层告警，属于证据采集漏检；组合探针没有闭合这些告警。

`project`：同 seed=1 两次构建的 Slice 分别为 80.36% 和 86.02%，且 Bitstream SHA-256 不同；seed=3 为 87.33%。两次 seed=1 manifest 的 30 个 source hash、TD 工具 hash、flow Tcl hash 和 place seed 完全一致，差异不是已登记输入漂移。资源门限和字节级可复现性不稳定，且原始日志证明告警始终存在；候选拒绝晋升。

`unknown`：未进行板卡下载、SC520CS 采集、HDMI 显示、冷启动、长稳和外设验收；本探针不得写成硬件可用或最终发布版本。

## 同输入 seed=1 时钟级联诊断

为定位告警拓扑，从同一组合输入快照复制官方 `DefaultFlow.tcl`，仅在 `route` 后追加 `analyze_clock -detail`，独立运行 seed=1。该次 TD 综合、route、STA 和 bitgen 均完成；route QoR 为 Setup/Hold WNS `+101/+20 ps`、TNS 均为 0，但 Slice 为 `18,488/21,216 = 87.14%`，超过项目 `<=85%` 初始资源门，因此只作为诊断候选，不晋升。

原始 `phy_1/flow_exec.log` 的详细级联表指出 DDR PHY 中的 `AL_PHY_SCLK` 主时钟网经过 `u_pll_inst(AL_PHY_PLL)` 驱动从属 `clkc[0]`，其接收缓冲为 `AL_PHY_GCLK`；物理时钟状态表还记录 I2C `u_uicfgcs520/u_i2c/scl_clk` 为 `AL_PHY_LSLICE`。日志仍有 `PHY-5016`（PLL `clkc` 驱动未定位、且未驱动 clock-capable IO）和 `PHY-5088`（clock-net cascade）告警。该报告定位了网表级级联关系，但没有证明板级引脚能力、告警是否无害或硬件稳定；`PHY-5016/5088` 仍未闭合。

对组合变换脚本和候选 I2C 源再做事件控制审计：它仍包含 `posedge scl_clk`/`negedge scl_clk`，所以“counter-derived phase enable”并不准确，应理解为相位信号重写，不是将状态机迁移到 `I_clk` 的 clock-enable 修复。此前某一次 TD 日志缺少 I2C PHY-5016/5088，不能据此声称时钟结构已消失；本详细构建的时钟状态表直接证明 `scl_clk` 仍由 `AL_PHY_LSLICE` 生成。该组合探针只证明在不同运行中告警和资源结果会变动，不构成 I2C 告警关闭证据。

详细构建证据：`work/td_i2c_counter_mclk_oddr_detail_seed1_build/td_project/camera_to_dsi_display_Runs/phy_1/flow_exec.log`、`work/td_i2c_counter_mclk_oddr_detail_flow/DefaultFlow-analyze-clock.tcl`、`release/candidates/industrial-v2-i2c-counter-mclk-oddr-detail-seed1/route.qor`、`release/candidates/industrial-v2-i2c-counter-mclk-oddr-detail-seed1/final_timing.rpt` 和该目录下 provenance manifest。

## 同 seed 综合阶段分叉定位

对 seed=1 首次构建和独立重复构建的 `syn_1` 产物做了逐行对照：两次 run-flow Tcl、syn/phy `settings.cfg` 与 `.prj` 相同；30/30 已登记源路径和哈希相同；两份完整 `user_source` 树的 219 个文件、`td_project` 下排除生成 Runs 后的 11 个输入文件均逐路径逐哈希一致。TD 可执行文件与官方 `DefaultFlow.tcl` 哈希相同，placement seed 均为 1。两份 `user_source/hdl_source/anlogic_logo_rom.v` 的 SHA-256 均为 `a105c935dafef80b1d3ed2abd505bfd1f970f44c3a5663d1574f3e452b481e98`。

分叉已出现在物理实现之前的 `syn_1` 报告：`rtl.area` 共 6 行不同（总量统计，以及顶层、OSD 和 Logo ROM 汇总行）；叶级实例的首个差异位于 `u_industrial_osd/u_logo_rom`（38,498 / 38,653），其余叶级实例行一致。之后 `gate.area` 有 58 行不同且跨多个模块；LUT 为 20,468 / 20,608，Slice 为 16,644 / 16,651。两次日志均显示 `thread=auto`、`enable_seed=off`。官方 TangDynasty V6.2 用户指南第 9.6 节列出 `thread` 可设为 1；但既有固定单线程探针已经实测出不同 Bitstream，因此 `thread=auto` 不能单独解释全部复现差异。

补充读取同两次 `syn_1` 序列化数据库：`camera_to_dsi_display_elaborate.db` 为 16,660,118 / 16,660,116 bytes，SHA-256 分别为 `3d439998bba563d32be7cb1f70240c83ae39788467ad9cb382a16ef93d7a9b3a` / `ade5b5104e8e39439b83ce0759d2fd126ee154d3526ec8beed1299e8b8434084`；`camera_to_dsi_display_rtl.db` 为 12,333,524 / 12,339,158 bytes，SHA-256 分别为 `470a6876fa96ef15fddc801a023fa0a87b45764ce8215d89a38eecfcb5d02c7e` / `fa8ea7c694305b80281d7f99b93bf65463ab949b921c29ad18de87bef5d78945`。这是序列化文件层面的不一致；没有该数据库的可审计结构比较或等价证明，不能据此断言逻辑网表不等价，也不能将原因归结为工具随机性。

判定：`project`：当前组合探针的输出差异在 RTL 优化报告阶段已经可见；该报告的叶级差异只落在 Logo ROM，但 gate 优化报告差异扩散到多个模块。`unknown`：源文件和项目输入快照一致，但 process marker 的 Host 字段一份为空、一份为机器名，运行环境未完全冻结；尚不能在 TD 内部非确定性与未记录运行环境因素之间定根因，也未做综合网表等价验证，不能把报告差异解释成已知功能错误或工具缺陷。复现门禁继续 BLOCKED，不据此改动 ROM RTL。

## 证据

- `docs/evidence/industrial-v2-g8-i2c-counter-mclk-oddr-log.txt`
- `work/i2c_counter_mclk_oddr_build.log`
- `work/i2c_counter_mclk_oddr_seed1_build.log`
- `release/candidates/industrial-v2-i2c-counter-mclk-oddr-seed1-repeat/route.qor`
- `release/candidates/industrial-v2-i2c-counter-mclk-oddr-seed1-repeat/final_timing.rpt`
- `release/candidates/industrial-v2-i2c-counter-mclk-oddr-seed1-repeat/industrial-v1-manifest.json`
- `work/td_i2c_counter_mclk_oddr_seed1_repeat_build/td_project/camera_to_dsi_display_Runs/phy_1/flow_exec.log`
- `work/td_i2c_counter_mclk_oddr_seed1_repeat_build/td_project/camera_to_dsi_display_Runs/phy_1/td_20261019_124604.log`
- `work/td_i2c_counter_mclk_oddr_build/td_project/camera_to_dsi_display_Runs/phy_1/flow_exec.log`
- `work/td_i2c_counter_mclk_oddr_seed1_build/td_project/camera_to_dsi_display_Runs/phy_1/flow_exec.log`
