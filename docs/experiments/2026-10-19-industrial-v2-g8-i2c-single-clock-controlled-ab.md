# Industrial V2 G8：I2C 单时钟方案受控 TD A/B

## 状态

`NOT_PROMOTED_RESOURCE_REPRODUCIBILITY_AND_WARNING_GATES`。用户已批准评估 `I_clk` 单时钟加边沿使能方案。12 组 Icarus 周期等价仿真见前置实验记录。本实验把 TD 输入固定为同一套当前 V2 工程，仅替换 `uii2c.v`，以分离此前不匹配输入造成的面积归因问题。

## 受控输入与构建

- 器件 `PH1P35MDG324`；Tang Dynasty `6.2.168116`；`DefaultFlow.tcl`；placement seed `1`。
- 基线包：`fallback/td_package`，被综合的 `uii2c.v` SHA-256：`032df05881f9bd7c7cf86cc1381adcb739a18f8a8744ed06b1160ac294a6dc0d`。
- 候选包：`work/td_i2c_single_clock_ab_candidate_input`，只把该 `uii2c.v` 替换为单时钟 RTL，SHA-256：`9184ee498d25278afec0305e7322331d459f6dcaaf0a38e058337ca4d54ddf5a`。
- 构建后对两个实际 TD 工作区的 `user_source` 做逐文件 SHA-256 对比：两边各 219 个文件，唯一差异是 `user_source/hdl_source/uics500_cfg/uii2c.v`。V2 顶层、IP、约束、项目文件、工具及 Flow 相同。
- 基线执行一次；同一候选输入在两个独立 work project 中执行两次。三者均完成 synthesis、place/route、STA 与 Bitgen。每次生成的 Bitstream 均只保留在各自 candidate 目录，未下载。

## 结果

| 构建 | Gate 预估 Slice | 最终 Slice | Setup WNS/TNS | Hold WNS/TNS | SHA-256（压缩位流） |
|---|---:|---:|---:|---:|---|
| 原 I2C 基线 | 16,743 | 18,404 / 21,216 (86.75%) | +112 ps / 0 | +20 ps / 0 | `d6ce820c481df32dbae519a48351b93da3e56104ef6fbc61d3042e3192a87b03` |
| 单时钟候选 1 | 16,751 | 17,181 / 21,216 (80.98%) | +105 ps / 0 | +20 ps / 0 | `d698e05ec86480e47868087e4e2ebe615a667165e34d62263bff490de228c2c5` |
| 单时钟候选 2 | 16,622 | 18,347 / 21,216 (86.48%) | +127 ps / 0 | +20 ps / 0 | `a9cc6f1264033c63723f7087da451d185200802cd4ff8613d01f7cbdc91a7f8b` |

三次构建均映射到 43 RAM、24 DSP；全设计 RTL 面积统计均为 18,367 DFF、4,530 LUT。单时钟候选局部 I2C gate 映射约 53–54 LUT、51 个序列单元，基线约 50 LUT、51 个序列单元。综合 Gate 预估 Slice 接近，但候选两次最终 Slice 相差 1,166；同 seed 的独立构建并未重复得到相同 bitstream 或资源结果。

## 时钟告警对比

- 基线报告 I2C `u_uicfgcs520/u_i2c/scl_clk` 的 `PHY-5060` 混合扇出；两次单时钟候选均不再出现 `scl_clk`，且未出现该 SCL 专属 `PHY-5060` 行。
- 三次构建都报告 `O_cam_24m_syn_3` 的 `PHY-5060` 和 `PHY-5079` 本地时钟布线告警；候选报告的 MCLK 扇出为 202 个 clock sinks，基线为 160 个。
- `PHY-5016`（PLL clkc IO 能力/位置）与 `PHY-5088`（clock analyzer）在基线和候选中均存在。它们没有因 I2C 单时钟改动而关闭。
- 候选两次最终 setup/hold 时序均为正且 TNS=0；这不覆盖综合阶段 DDR/视频 RAM 未驱动输入告警、unconstrained 点或 PHY DRC。

## 结论与边界

受控输入证明单时钟候选确实移除了 SCL 派生时钟的混合扇出路径，但其最终 Slice 在两次独立 seed=1 构建中跨越 85% 门限。因此不能据一次 80.98% 结果晋升；当前证据无法将大幅 place/route 面积波动归结为稳定收益或稳定代价。原先 85.83% 的独立实验输入还同时改变了 TD 顶层包装器及项目文件，不再用作单一 I2C 变更的面积对照。

正式 `release/industrial-v2/`、冻结 V1 位流和原 RTL 均未修改；没有板卡下载、相机/HDMI 实测、复位、长稳或执行器证据。此候选不进入正式包。后续优先关闭 `O_cam_24m`/DDR PHY 时钟告警并查明同 seed 的实现非确定性，再以多次独立构建评估资源门限。

原始证据：

- 基线：`work/td_i2c_single_clock_ab_baseline/td_project/camera_to_dsi_display_Runs/{syn_1,phy_1}/` 与 `release/candidates/industrial-v2-single-clock-ab-baseline/`。
- 候选 1：`work/td_i2c_single_clock_ab_candidate/td_project/camera_to_dsi_display_Runs/{syn_1,phy_1}/` 与 `release/candidates/industrial-v2-single-clock-ab-candidate/`。
- 候选 2：`work/td_i2c_single_clock_ab_candidate_repeat/td_project/camera_to_dsi_display_Runs/{syn_1,phy_1}/` 与 `release/candidates/industrial-v2-single-clock-ab-candidate-repeat/`。
