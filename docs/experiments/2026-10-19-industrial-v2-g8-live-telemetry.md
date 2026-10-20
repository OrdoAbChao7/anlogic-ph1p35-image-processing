# G8 live telemetry and approved AWB integration — isolated TD result

日期：2026-10-19  
状态：`RTL_PASS / SOFTWARE_PASS / TD_BLOCKED / NOT_PROMOTED`

本记录前半部分保存 fix3/fix4 原始试验；fix5–fix8 的最新状态和修复结论见文末 `2026-10-20 续记`。

## 结论

原子 CDC、HDMI OSD 和经用户批准的 AWB 像素通路已接入 formal top。10 个定向 Icarus benches 和完整 Python 回归通过（156 passed）。fix4 综合的 Setup WNS/TNS 较 fix3 改善，但 TD 在物理布局阶段因 Slice 超限停止：实际报告为 `22,797/21,216`（107.45%），并仍有负 setup slack。未生成 route QoR、最终时序报告、Bitstream 或 fix4 候选；原有 `release/industrial-v2` 包及 V1 冻结包未改动。

## 输入与源文件校验

- 目标：`PH1P35MDG324`，TD `v6.2.168116`，`DefaultFlow.tcl`，placement seed `1`。
- 输入包：`fallback/td_package`；独立工作目录：`work/td_industrial_v2_g8_awb_staticcal_fix4/`。
- 构建入口：`scripts/build_industrial_td.py`，使用 `--input-package fallback\td_package --place-seed 1 --work-project work\td_industrial_v2_g8_awb_staticcal_fix4 --release-dir release\candidates\industrial-v2-g8-awb-staticcal-fix4`。
- 逐文件比对构建输入与隔离工程副本：30 个被跟踪应用源文件全部 SHA-256 相同。源/副本对照记录集摘要（SHA-256）：`eb312b399055889cb92df2af4038ae82ea916f2f168ed868d6f9358496b2d792`；摘要算法为 30 条 `{path, sha256, copy_sha256, match}` 记录的 UTF-8 紧凑 JSON（键排序）再做 SHA-256。
- 构建在 Bitgen 前失败，因此 helper 未生成完整 `industrial-v1-manifest.json`；工具、完整 TD 输入包与输出制品的 provenance manifest 尚不存在。

## 软件与 RTL 验证

完整 Python 回归：`python -B -m pytest -q -p no:cacheprovider work/tests`，`156 passed in 1.40s`。逐项 Icarus 输出全部为 PASS：

- `TB_AXIS_GAIN_RGB96_PASS`
- `TB_AWB_FRAME_GAIN_PASS`
- `TB_AWB_FRAME_GAIN_FIXED_PASS`
- `TB_DIMENSION_CALIBRATOR_PASS`
- `TB_STREAM_ADAPTERS_96_PASS`
- `TB_FRAME_STATS_FIXED_LUMA_PASS`
- `TB_MOTION_DIFF_160_FULL_SCALE_PASS count=19200 width=15`
- `TB_INDUSTRIAL_V2_RESULT_CDC_PASS`
- `TB_INDUSTRIAL_OSD_TELEMETRY_PASS`
- `TB_INDUSTRIAL_OSD_BCD_PASS`

其中 fixed-luma bench 覆盖整数均值阈值上下界、帧 ID/统计字段对齐和固定流水延迟；AWB pixel bench 覆盖增益舍入/饱和、每帧增益快照、侧带与背压；运动计数回归达到 `19,200`。`git diff --check` 返回 0。回归明细见 `docs/evidence/industrial-v2-g8-full-tests-log.txt`。

## TD 结果与瓶颈迁移

| 隔离试验 | Gate Setup WNS / TNS | Gate `#slices` QoR | 放置结果 | 结论 |
|---|---:|---:|---:|---|
| fix3 | -26,909 / -573,011 ps | 10,115（47.68%） | 22,935/21,216 Slice；SWNS/STNS -18,202/-698,449 ps | `PHY-9053` 超限 |
| fix4 | -9,384 / -389,318 ps | 10,071（47.47%） | 22,797/21,216 Slice；末段 pre-pack SWNS/STNS -7,175/-468,274 ps | `PHY-9053` 超限 |

Gate QoR 的 `#slices` 是该阶段摘要值；布局估算/实际 pack 数在 `camera_to_dsi_display_gate.area` 与 `phy_1/flow_exec.log` 中，不能把前者的 47% 当成器件最终利用率。fix4 的 gate area 报告列出 `#slice*=23,185/21,216 (109.28%)`、`DSP=41/40 (102.50%)`、`ERAM=43/108`；放置阶段合并一个 9×9 DSP 后记录为 40 DSP，但最终 Slice 仍为 22,797，且触发 `PHY-9053`。关键日志还报告 `PHY-7022` 估算 Slice 利用率 106%。

本次统计流水 retime 后，最差综合路径从 fix3 的 `u_axis_gain_rgb96` 到 `u_v2_frame_stats/O_mean_luma_reg[0]`（36.501 ns、41 logic levels）转移到 AWB 增益计算：fix4 从 `u_awb_frame_gain_controller/mult11_syn_168` 到 `O_gain_r_reg[0]`，数据延迟 `18.976 ns`、21 levels（10 ADDER、1 DSPTADD、1 DSPMULT），Setup slack `-9.384 ns`。说明帧统计路径已不再是当前最差端点，但剩余 AWB 路径与资源预算都未通过；不能据此归因全部面积超限由单一改动造成。

fix4 仍报告两条 `PHY-5060` critical warning：I2C `scl_clk` 混合 1 个 clock fanout 与 2 个 data/control fanout；`O_cam_24m_syn_3` 混合 160 个 clock fanout 与 1 个 data/control fanout。warning/CDC/约束门继续保持 OPEN。

报告位置：

- fix3：`work/td_industrial_v2_g8_awb_staticcal_fix3/td_project/camera_to_dsi_display_Runs/syn_1/gate.qor`、`camera_to_dsi_display_gate.timing`、`phy_1/flow_exec.log`
- fix4：`work/td_industrial_v2_g8_awb_staticcal_fix4/td_project/camera_to_dsi_display_Runs/syn_1/gate.qor`、`camera_to_dsi_display_gate.area`、`camera_to_dsi_display_gate.timing`、`phy_1/flow_exec.log`
- 综合层级中保留了 `u_industrial_osd`、`u_industrial_v2_feature_spine/u_awb_frame_gain_controller`、`u_isp_top` 和 `u_v2_frame_stats` 实例，详见 fix4 的 `camera_to_dsi_display_gate.area`。

## 严格发布审计与边界

`python -B scripts/verify_industrial_v2_release.py --strict` 退出码为 1（阻塞时的预期行为），审计报告保存在 `docs/experiments/2026-10-19-industrial-v2-g8-live-telemetry-release-audit.json`：13 项中 7 PASS、6 BLOCKED。该审计的 TD/资源 PASS 指向此前未更改的正式候选包，不代表 fix4；其硬件、性能、长稳、复现、告警和执行器门仍未闭合。

本试验未下载硬件。未测 SC520CS/HDMI 画面、真实光照、物理尺寸标定、视频/端到端延迟、GPIO 或执行机构。算法预览的 Stage-C 视觉授权按用户指示默认通过，不替代这些验收。

## fix4 后只读代码审查发现（历史状态）

对相关 RTL、顶层连线和 benches 做只读复核后，有四项重要问题需在任何候选晋级前处理：

1. `frame_stats_96` 对缺失 SOF 只在输入当拍报告错误；fixed result 的 invalid 只按像素数计算。因此像素数正确但没有 SOF 的帧可能以 `O_invalid=0` 发布，并满足顶层 AWB 的 `v2_stats_valid && !v2_stats_invalid` 条件。见 `fallback/rtl/integration/frame_stats_96.v` 与 `fallback/td_source/design_top_wrapper.v`。
2. `industrial_v2_result_cdc` 在源/目的时钟域使用同一个异步复位；顶层直接把 `S_pll_lock` 接到两侧 reset，释放时没有每域同步级。需先为源、目的域定义安全复位释放。
3. `industrial_v2_feature_spine` 的 input/result/video frame ID 都接到同一个当前 `I_frame_id`。这不能证明延迟结果仍属于该输入帧；当前 `PROC` 可能被错误地标为有效。修复真实帧标签前，结果必须保持 `PROC:N/A`。
4. AWB pixel stage 在每个被接受的 SOF 锁存当时的 gain；统计更新晚于 SOF 时，该帧使用旧 gain。该行为维持帧内稳定，但目前没有“更新应在下一帧生效”的保证，也没有控制器到 pixel stage 的联合时序回归。需要明确按“更新后的首个 SOF”生效，或另行设计跨帧调度；不可假设最小帧间隔。

以上是 fix4 后当时的审查结论；后续 RTL/TB 修复及当前仍未闭合的测量边界见下方续记。

## 后续入口

fix4 当时的后续入口已由下方续记取代；任何新候选仍须在独立 TD 工作目录完成 Slice/DSP/Setup/Hold 门，并在满足门槛前不替换现有正式候选包。

## 2026-10-20 续记（fix5–fix8）

### 已修复的 RTL/SIM 合同

- `frame_stats_96` 将缺失 SOF 错误保持到固定帧统计结果；增加恰好 `1280×720` 像素但无 SOF 的反例，修复前 `invalid=0`、修复后判 invalid。
- `industrial_v2_result_cdc` 的 CSI 与 HDMI 两域分别使用异步断言、同步释放复位链；顶层 feature spine、统计/运动适配器和结果标签状态分别连接本地复位。
- 新增深度 4 的有序 `frame_result_tag_queue`：在 accepted SOF 入队、检测结果事件出队，FIFO 溢出/下溢时 tag 无效并 fail-closed。结果 ID 不再取实时输入帧 ID。
- `latency_monitor` 与 `frame_tag_monitor` 默认 timeout 从 1,024 提高到 `2×1280×720` 周期。完整 `921,600` 周期等待 bench 得到 `PROC=921600 cycles`，匹配标签且未超时；短 timeout override 既有用例仍通过。
- AWB cadence 明确为：统计更新和 accepted SOF 同沿时该像素帧锁存更新前增益；更新沿之后的首个 accepted SOF 锁存新增益；不假定帧间最小空隙。
- AWB 固定均值输入按合法最大通道和 `235,008,000` 窄化：`sum>>8 ≤ 918,000`，使用 20-bit 输入和 41-bit 完整乘积。固定帧 target RGB 均值在 10-bit 总和 `0..765` 上用 `(sum×683)>>11` 精确实现 `floor(sum/3)`；Python 穷举全域，RTL 覆盖 `763/764` 边界。

定向 Icarus：`TB_FRAME_STATS_FIXED_LUMA_PASS`、`TB_RESET_RELEASE_SYNC_PASS`、`TB_INDUSTRIAL_V2_RESULT_CDC_PASS`、`TB_FRAME_RESULT_TAG_QUEUE_PASS`、`TB_AWB_FRAME_GAIN_CADENCE_PASS`、`TB_INDUSTRIAL_V2_FEATURE_SPINE_PASS`、`TB_LATENCY_MONITOR_PASS`、`TB_FRAME_TAG_MONITOR_PASS`、`TB_LATENCY_MONITOR_FULL_FRAME_PASS cycles=921600`、`TB_AWB_FRAME_GAIN_FIXED_PASS` 均通过。最新完整 `work/tests` 回归为 `162 passed`，详见 `docs/evidence/industrial-v2-g8-full-tests-log.txt`。

### fix5–fix8 隔离 TD 对照

每次均从 `fallback/td_package` 建立独立工作树、seed `1`、TD `v6.2.168116`、器件 `PH1P35MDG324`。V2 工作树自身默认 `.tools/td` 路径不存在，因此构建命令显式传入本机已有 TD executable 和 `DefaultFlow.tcl`；工具安装只读使用。所有构建均在 `PHY-9053` 停止，未进入 route/Bitgen，未产生候选位流。

| 试验 | 相对上一版的变更 | Gate Setup WNS/TNS (ps) | Gate QoR slices / DSP | 放置 slices | 结果 |
|---|---|---:|---:|---:|---|
| fix5 | 修复 review findings | -9,367 / -392,881 | 10,079 / 41 | 22,637 / 21,216 (106.70%) | `PHY-9053` |
| fix6 | ledger timeout 覆盖完整 720p 栅格 | -9,392 / -386,854 | 10,100 / 41 | 22,672 / 21,216 (106.86%) | `PHY-9053` |
| fix7 | 固定 AWB 通道均值乘法输入定宽 | -9,392 / -400,072 | 10,100 / 41 | 22,665 / 21,216 (106.82%) | `PHY-9053` |
| fix8 | 固定 AWB target mean 改为精确窄域 `/3` reciprocal | -7,216 / -303,000 | 10,114 / 40 | 22,420 / 21,216 (105.68%) | `PHY-9053` |

fix8 的 gate area 估算为 `23,165/21,216` slices、`40/40` DSP、`43/108` ERAM；放置前 pre-pack SWNS/STNS 为 `-6,932/-337,999 ps`。WNS 较 fix7 改善 `2,176 ps`、TNS 改善 `97,072 ps`，放置用量减少 `245` slices；数学改写结果正向，但资源仍超上限 `1,204` slices，不能称为收敛。固定 seed 的历史试验已显示 P&R 有 run-to-run 波动，245-slice 差异不单独归因于 RTL。

fix8 最差路径仍在 AWB 增益更新：`mult12_syn_168` 至 `O_gain_r_reg[0]`，数据延迟 `16.808 ns`、17 logic levels，Setup slack `-7.216 ns`。Hold WNS/TNS 为 `+114/0 ps`。`PHY-5060` 仍报 `O_cam_24m_syn_3` 和 I2C `scl_clk` mixed fanout，`PHY-7022` 估算 slice 利用率 105%，`PHY-5088` 时钟分析告警仍存在。无 route QoR、最终时序报告或 Bitstream。

fix8 原始证据：

- `work/td_industrial_v2_g8_awb_staticcal_fix8/td_project/camera_to_dsi_display_Runs/syn_1/gate.qor`
- `work/td_industrial_v2_g8_awb_staticcal_fix8/td_project/camera_to_dsi_display_Runs/syn_1/camera_to_dsi_display_gate.area`
- `work/td_industrial_v2_g8_awb_staticcal_fix8/td_project/camera_to_dsi_display_Runs/syn_1/camera_to_dsi_display_gate.timing`
- `work/td_industrial_v2_g8_awb_staticcal_fix8/td_project/camera_to_dsi_display_Runs/phy_1/flow_exec.log`

fix5–fix7 报告分别保留在同名 `work/td_industrial_v2_g8_awb_staticcal_fixN/td_project/camera_to_dsi_display_Runs/{syn_1,phy_1}/` 目录。正式 `release/industrial-v2`、既有 V2 候选和 V1 冻结包未改动。严格发布审计仍针对既有正式候选，不把 fix5–fix8 失败试验纳入晋级；fix8 后报告单独保存至 `docs/experiments/2026-10-20-industrial-v2-g8-live-telemetry-fix8-release-audit.json`。

### 当前未闭合边界

- HDMI 视频帧事件仍在 formal top tie-off：feature spine 的 `I_video_valid=0`，`I_video_frame_id=0`。因此 video latency 和端到端 latency 仍为 N/A；full-raster bench 只证明内部 tagged PROC ledger 的仿真行为，不是物理延迟测量。
- 板卡/SC520CS/HDMI、外部执行器与实体标定没有新证据；stage-C 视觉授权不替代硬件验收。
- G8 资源与时序未过门，需继续在保持七项功能的条件下削减至少 `1,204` 放置 slices 并收敛 Setup；时钟/CDC warning、可复现构建、硬件、长稳与执行器仍 OPEN。
