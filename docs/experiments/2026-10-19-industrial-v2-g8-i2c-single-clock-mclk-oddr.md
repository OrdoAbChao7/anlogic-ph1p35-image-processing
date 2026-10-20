# Industrial V2 G8：单时钟 I2C + MCLK ODDR 组合探针

## 判定

`REJECTED_RESOURCE_AND_WARNING_GATE`。在保持七功能顶层不变的隔离工程中组合单一 `I_clk` + edge-enable I2C 与已有 MCLK ODDR 输出隔离。placement seed 1 和 3 均完成 TD、STA、Hold Fix 与 Bitgen；两次都通过 setup/hold 时序，但 Slice 分别为 `86.85%`、`86.34%`，超过 `<=85%` 门。组合后 `PHY-5060/5079` 消失，`PHY-5016/5088` 仍存在，故不晋升、不下载。

## 输入与隔离

- I2C：`work/td_i2c_single_clock_input/user_source/hdl_source/uics500_cfg/uii2c_single_clock.v`，SHA-256 `9184ee498d25278afec0305e7322331d459f6dcaaf0a38e058337ca4d54ddf5a`。对应的逐周期 testbench 在 12 组 `CLK_DIV`/ACK/NACK 配置下通过，细节见 [`i2c-single-clock-enable`](2026-10-19-industrial-v2-g8-i2c-single-clock-enable.md)。
- 顶层覆盖：`release/candidates/industrial-v2-mclk-oddr-seed3/design_top_wrapper_mclk_oddr.v`，SHA-256 `fd65440dc4dfaea1305f0dd31e42fcb79413628301106a87272cb3647ab2c3e0`。它与当前 V2 顶层应用已测试的单一 `O_cam_24m`→`PH1P_LOGIC_HD_ODDR` 变换后精确一致。TD `--top-rtl` 覆盖将其同步到两个隔离工程；两个 `.prj` 均引用 `uii2c_single_clock.v`。
- 两份构建 manifest 的 30 个受跟踪 V2 源文件哈希完全相同，唯一构建配置差异为 placement seed `1`/`3`（对应 seed 参数化 flow Tcl）。vendor I2C 源不在 manifest 的 `sources` 数组内，故在此单独记录其哈希。
- 独立路径：`work/td_i2c_single_clock_oddr_seed1_build/`、`work/td_i2c_single_clock_oddr_seed3_build/`；Bitstream 分别保存在对应 `release/candidates/` 目录。

## TD、STA 与资源

工具为 Tang Dynasty `6.2.168116`、HX1P35A / PH1P35MDG324、官方 `DefaultFlow.tcl`。两次构建使用相同源和配置、只改变 placement seed：

| Seed | Setup WNS/TNS | Hold WNS/TNS | Slice | RAM/DSP/DRAMHARDCON | Bitstream SHA-256 |
|---:|---:|---:|---:|---:|---|
| 1 | `+105/0 ps` | `+20/0 ps` | `18,426/21,216` (`86.85%`) | `43/24/229` | `75ebfa15f0adb277326b57951dce8a25c6d1c96f50d9b1796ab95836dff6ab0f` |
| 3 | `+113/0 ps` | `+20/0 ps` | `18,318/21,216` (`86.34%`) | `43/24/229` | `d55657aab467e71cfbdde80635caae17ae2bde156881f873c27bf1bb3a3d1bf0` |

seed 1 原始日志计数为 `SYN-5011 ×13`、`SYN-5025 ×3`、`PHY-5016 ×4`、`PHY-5060 ×0`、`PHY-5079 ×0`、`PHY-5088 ×1`；seed 3 相同。`PHY-5060/5079` 在两次组合路由中均消失；其余告警保持开放。两 seed 的 Bitstream SHA 不同，不构成 byte-identical reproducibility 证据。

## 剩余时钟告警诊断

对 seed 3 已完成 route 数据库上的 `analyze_clock -detail`，命令脚本为 `work/td_i2c_single_clock_oddr_seed3_build/td_project/camera_to_dsi_display_Runs/phy_1/analyze_clock_detail_only.tcl`，原始输出为同目录 `td_20261019_190845.log`。

- `PHY-5088` 的 source/sink 级联表定位到 DDR PHY：master 为 `...u_ddrphy_clk/u_pll1/u_bufg_fbclk...` 的 `AL_PHY_SCLK`，通过 `...u_pll1/u_pll_inst (AL_PHY_PLL)` 驱动 slave `...u_pll1/clkc[0]`，slave buffer 为 `AL_PHY_GCLK`。这是具体的 DDR PLL 无缓冲级联告警，仍需官方 IP/约束边界审查，不能据此自行屏蔽。
- `PHY-5016` 在 DDR MLCLK 放置相关日志段出现 4 行（两条告警各重复两次）。源码/布局报告的最窄关联为：PLL0 `clkc[1:2]` 分别输出到 `pll0_clk_1/2`，再经 `u_mlclk_1/2` 形成 `pll0_mlclk_1/2` 并驱动 DDR `IOCLK`；最终 route clock-utilization 将两条 MLCLK 网分别放置于 `X0Y59Z0/Z1`。告警出现在 `u_mlclk_2` fixed placement 日志后，数量和顺序与两个 MLCLK 实例相符。此为 `project` 源码与路由报告的关联推断，不等于 PHY DRC 给出了唯一 sink 或 pad；`analyze_clock -detail` 也未映射精确 sink，且尚无官方 pin/IP 与板级实测闭环，故仍保持 `OPEN`。源码为 TD 输入副本 `work/td_i2c_single_clock_input/user_source/hdl_source/ph1p35_ddr/ddr2/src/rtl/clk/ph1p_ddrphy_pll0.v`、`ph1p_ddrphy_clk_top.v`，约束为对应目录 `src/sdc/ddr2.sdc`。
- 官方 `UG1310_1.2`《SALPHOENIX 1P Series FPGA Libraries Guide for HDL Designs》39 节（印刷页 84，PDF 页 103）定义 `PH1P_PHY_MLCLK` 为跨多个垂直时钟区域的时钟模块；43 节（印刷页 92，PDF 页 111）说明 `PH1P_PHY_IOCLK` 输入可来自本区域/相邻区域 MLCLK、本区域 PLL 输出或本区域 GCLKIO 输入。因此当前 RTL 的 MLCLK→IOCLK 源类型被官方手册支持；但此条不解释 PHY DRC 为何报告 PLL `clkc` 驱动 IO，也未给出唯一 sink/pad，`PHY-5016` 仍保持 `OPEN`。来源元数据登记于 `docs/research/sources.yaml` 的 `anlogic_ph1p_ug1310_library_guide`。
- route clock-utilization 表记录 `pll_clk_24m`（PLL `clkc[1]`，42 ns）驱动 `u_ae_set/I_clk`；`O_cam_24m` 已通过 ODDR 输出单元驱动，不再触发本次 `PHY-5060/5079`。

## 结论与边界

ODDR 组合稳定消除了 MCLK 相关的两类路由告警，但两次 placement 均未满足资源上限；DDR PLL cascade 与 `PHY-5016` 仍开放。停止继续扫 seed，避免以挑选单次布局掩盖资源和可复现性问题。没有上板、SC520CS/HDMI、冷启动、长稳、性能、外部执行器或视觉效果实物证据。正式 V1 和 `release/industrial-v2/` 候选均未修改。
