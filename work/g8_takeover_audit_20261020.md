# G8 现场接管与当前证据归因（2026-10-20）

## A. 版本与证据对应

首次接管查询未发现 Tang Dynasty 构建进程（进程查询只匹配到查询自身的 PowerShell）。当前仓库、候选位流与失败构建不是同一个版本，不能拼接其结果：

| 身份 | 可核验版本/产物 | 证据与边界 |
|---|---|---|
| V1 冻结恢复包 | `release/candidates/industrial-v1-hx1p35a-pin-correction/`；Bitstream SHA-256 `b483a1ffc30d0b7ae9e8ebef4f31f617d33a53d6784ded8007d5443c51ad80ef` | 冻结记录明确指定此目录为恢复入口。其 WNS +103/+20 ps、Slice 17,642 是该 V1 位流的记录，不是 V2。 |
| 另一份 V1 构建包 | `release/industrial-v1/`；SHA-256 `e9815a4a42f085d26cb8744c0d5a485020d3ece3e1a1bb7aff20d92264de68d3` | 与冻结恢复位流不同，不能替换其身份。 |
| 既有 V2 七功能候选 | `release/candidates/industrial-v2-formal-feature-spine/` SHA `60aea582cff6fa2d5a03eaa5f1d9aab4bdc142371af86053d04f8acf40e9ebc1`；后续候选 `release/industrial-v2/industrial-v2.bit` SHA `d6e6a7e12ef7558834904dcc8d2783d5fda827b7fe11c6e407b0119fc3ce1c0d` | 后者 README 记录 Slice 17,125/21,216（80.72%）、Setup/Hold +104/+20 ps；属于旧候选的 TD 证据，不是 fix8 源码的构建结果，也不是硬件验收。 |
| 当前源码树 | `E:/Projects/FPGA-v2`，分支 `goal/industrial-v2-advanced`，HEAD `3314966f675473039e804e8515f9844c4ba287c3`，审计记录 140 个 dirty 项 | 按 `scripts/build_industrial_td.py` 的真实覆盖规则（TD package 基线 + `fallback/rtl`、`fallback/td_source` 覆盖）解析后，219/219 个 `user_source` 文件与最新构建快照 SHA-256 完全一致。实际卡通源为 `fallback/rtl/video/video_cartoon_region_fill.v`；未覆盖的 package 模板不是本次综合输入。工作树仍可变，不等于任一已发布位流。 |
| 最新完整源码构建输入 | `work/td_g8_motion_inferred_a_seed1/`，2026-10-20 00:58:54 综合、01:02:46 Place | 219 个 `user_source` 文件；事后清单覆盖 228 项输入，清单 SHA-256 `70e629335bd65d01286309f91606f5a3f5bf98799f747955b737400ee13619cc`，输入库存 SHA-256 `287dec59bc2930377c6b192a6dc675719ddbf0a0bb589b00f572e0ae8beaa3d6`。已逐项复核 228 个输入与 7 个原始输出的长度/哈希；原始 launcher manifest 不存在，故仍标为事后重建。 |
| 前一完整源码构建（fix8） | `work/td_industrial_v2_g8_awb_staticcal_fix8/` | 历史 Gate `#slice* 23,165`、Place 22,420/21,216，`PHY-9053`；不是最新完整构建。其单独清单保留在 `work/g8_fix8_reconstructed_input_manifest_20261020.json`。 |
| 后续完整 R1 ERAM 路由候选 | `work/g8_r1_v2_integration/work/td_g8_r1_motion_eram_seed1/`；输入侧车 `.../td_g8_r1_motion_eram_seed1_release/input-manifest.json` SHA-256 `731ff493ef607ed20909d4c72a60e28b85a21f76ac75c10015797096fedc5ed1`；输入记录 commit `0f81e3957257b739710decc5c8e83103b6dedd36`、219 个 user_source、motion storage=`ph1p-single-port-eram-read-before-write` | 后续完整 Route 报告生成于 18:32:25；`route.qor` SHA-256 `3869f58a47323ff5a0fd3b67aaf4795cb165a8baa003fee4d27d91c638ef3027`。此输入与默认 inferred 快照、旧 V2 位流均不同。 |

默认 inferred 完整输入 `td_g8_motion_inferred_a_seed1`：Gate `#slice* 23,228/21,216`，Place `4,360 mslices + 18,522 lslices = 22,882/21,216`，以 `PHY-9053` 失败；无 Route 或新位流。fix8 是更早版本，不能称为最新。其后另有独立 R1 ERAM 完整路由候选（见下表）；它完成 Route，但资源与时序仍未过门。三个版本不能按单个 Slice 数拼接为同一候选。

功能验证状态另行保留：V2 状态记录中的 `work/tests` 为 162 passed、Stage D 软件等价为 PASS，遥测实验记录了对应定向 Icarus 回归；本次接管没有重复运行这些不变输入测试。它们不是 fix8 位流验证（fix8 没有位流），本轮也没有产生新的 RTL 功能验证结果。

## B. 默认 inferred 快照资源、存储和关键路径

`camera_to_dsi_display_gate.area` 是门级估算；Place 原始日志中的 packed Slice 才是本次实际放置数字。层级行是嵌套统计，不要相加。

| 范围 | 层级资源（Gate） | 关键归因 |
|---|---|---|
| 全设计 Gate | `#slice* 23,228/21,216 (109.48%)`；LUT 28,175；寄存器 16,885；DRAM LUT 4,240；ERAM 43/108；DSP 40/40；DDR byte 6/12 | STA coverage 96.52%；Setup WNS/TNS -7.560/-366.675 ns；Hold +0.114/0 ns。 |
| 全设计 Place | 4,360 mslices + 18,522 lslices = **22,882/21,216 (107.86%)** | 原始 `PHY-9053` 终止；超器件容量 1,666 Slice。85% 预算上限为 18,033 Slice，仍差 **4,849 Slice**。Place 没有完成 route，不能报告最终 route timing。 |
| `u_industrial_v2_feature_spine` | 2,233 logic LUT、683 ripple、350 seq、14 DSP、2,400 DRAM LUT | 主要结构性存储消耗在此层。子层资源已包含于层级树，不重复求和。 |
| `u_motion_diff_160` | 1,172 logic LUT、78 ripple、85 seq、**2,400 DRAM LUT、0 ERAM** | RTL 历史阵列为 160×120×8 = 153,600 bit（19,200 byte）。`ram_style="block"` 没有令当前 PH1P35 TD 映射到 ERAM。 |
| `u_video_cartoon` | 661 logic LUT、58 ripple、353 seq、1,536 DRAM LUT、8 shifter LUT | 与运动历史分开的另一块大分布式存储。 |
| `u_awb_frame_gain_controller` | 945 logic LUT、352 ripple、29 seq、11 DSP | AWB 增益控制算术仍位于当前最差路径锥。 |
| `u_isp_top / u_awb` | ISP：2,794 LUT、2,907 ripple、7,932 seq、26 ERAM、24 DSP；其 AWB 子层：1,534 LUT、2,306 ripple、6,086 seq、10 ERAM、8 DSP | 与 feature spine 中的帧级 AWB 控制器是两个层级，不可混为一个模块统计。 |
| `u_v2_frame_stats` / `u_video_in` / `u_video_out` | frame stats 2 DSP；video_in 与 video_out 各 4 ERAM | DDR 帧槽仍没有 frame-ID/write-complete sideband；VIDEO/E2E 继续 N/A。 |

Gate 最差 Setup 路径：`u_awb_frame_gain_controller/mult12_syn_168.clk → O_gain_b_reg[0].d`，数据延迟 17.152 ns（cell 9.531 ns，net 7.621 ns），18 logic levels，最大 fanout 46；约束周期 9.660 ns，slack -7.560 ns。它证实 AWB 增益更新算术锥仍是实际关键路径，但不足以把根因缩到某一条源码表达式。Place 阶段在容量失败后未进入 Route，不能报告最终 route timing。

### 后续 R1 ERAM 完整路由候选（独立输入）

输入侧车和 raw report 位于 `work/g8_r1_v2_integration/work/td_g8_r1_motion_eram_seed1_release/` 与 `work/g8_r1_v2_integration/work/td_g8_r1_motion_eram_seed1/td_project/camera_to_dsi_display_Runs/`。Route 报告为 19,749/21,216 Slice（93.09%）、Setup WNS/TNS −7,791/−307,321 ps、Hold +20/0 ps、121 setup endpoints、75 RAM、40 DSP；高于 18,033 的 85% 预算 1,716 Slice。该候选能完成 Route，但不是资源/时序通过版本。

| 层级 | R1 Gate hierarchy | 存储/归因 |
|---|---|---|
| 全设计 | `#slice* 20,368`，DRAM LUT 1,840，ERAM 75，DSP 40 | Gate 估算与 Route 19,749 是不同阶段字段。 |
| `u_industrial_v2_feature_spine` | 1,181 logic LUT、698 ripple、379 seq、32 ERAM、14 DSP | 子模块统计包含在上层层级内，不重复相加。 |
| `u_motion_diff_160` | 118 logic LUT、93 ripple、114 seq、32 ERAM、0 DRAM LUT | R1 输入明确选择 PH1P single-port ERAM。 |
| `u_video_cartoon` | 663 logic LUT、58 ripple、353 seq、1,536 DRAM LUT | 仍是分布式存储；与两行隔离候选 Gate 不是同一构建。 |
| `u_awb_frame_gain_controller` | 947 logic LUT、352 ripple、29 seq、11 DSP | 路径仍落在 AWB 增益算术。 |
| `u_isp_top / u_awb` | ISP 2,802 LUT、2,907 ripple、7,932 seq、26 ERAM、24 DSP；AWB 子层 1,532 LUT、2,306 ripple、6,086 seq、10 ERAM、8 DSP | 不与 feature-spine 中 AWB 控制器混为一项。 |

R1 Route 最差 Setup 路径：`u_industrial_v2_feature_spine/u_awb_frame_gain_controller/mult0_syn_168.clk → O_gain_r_reg[4]_syn_2.ib`，17.190 ns、16 logic levels、fanout 36；时钟预算 9.660 ns、slack −7.791 ns。详见 `work/g8_r1_v2_integration/work/td_g8_r1_motion_eram_seed1/td_project/camera_to_dsi_display_Runs/phy_1/final_timing.rpt`；raw 内层日志为同目录 `flow_exec.log`。该路径锥证明 AWB 是本候选的时序热点，不证明单个 RTL 表达式是根因。

告警按 TD 内层原始日志核对且仍开放：I2C `scl_clk`、摄像头 MCLK `O_cam_24m_syn_3` 各有 `PHY-5060` mixed clock/data fanout；`PHY-5016` 原文只指明 `PLL clkc` 驱动未定位且非 clock-capable 的 IO，尚不能归属到某个具体 DDR PHY 接收端；`PHY-5088` 报告时钟网驱动非时钟负载/级联。Gate 原始日志另有 DDR PHY 初始化 RAM `ramread0_syn_*` 的未驱动 `di[]`（`SYN-5011`）及未驱动网络按 0 处理（`SYN-5025`）。源端、接收端、约束及厂商依据仍未逐项闭环，不能标为关闭。DDR 显示槽和显示帧 ID 仍未关联，VIDEO/E2E 保持 N/A；板卡、SC520CS、HDMI、实测性能、实体标定、长稳和执行器验收均未因此改变。

## C. 单变量结构优化实验卡：运动历史 ERAM 映射（已有 Gate 对照，不重复重跑）

| 项目 | 记录 |
|---|---|
| 要回答的问题 | 在最新完整 feature-spine 上显式选择 PH1P ERAM，能否把 160×120×8 历史阵列从 DRAM LUT 移入 ERAM，并形成足以推动 85% 预算的整机结构收益？ |
| 支持证据 | 最新层级 Gate 报告把 `u_motion_diff_160` 的 153,600 bit 历史阵列映射为 2,400 DRAM LUT、0 ERAM；同一完整输入快照和已有隔离映射试验可复用。 |
| 唯一变量 / 固定对照 | 只在隔离副本 `industrial_v2_feature_spine.v` 的现有运动实例显式设置 `.USE_PH1P_HISTORY_ERAM(1)`；基线是最新 `td_g8_motion_inferred_a_seed1`（默认 0）。两侧 219 个 `user_source` 文件中只有该 RTL 文件哈希不同；器件 PH1P35MDG324、TD 6.2.168116、top、Speed 3、`-packarea` 和 `read_design→opt_gate` 固定。 |
| 必须保持 | 160×120 格点、threshold 8、8-bit luma、16-bit frame ID、运动计数/无效输出与帧提交语义不变；特别包括读延迟、同地址读写、复位、首帧、短帧、缺 SOF 和短帧部分写入是否影响后续历史。 |
| 最低成本验证 / 判据 | 复核单文件差异、Icarus 定向边界回归、TD Gate 的 ERAM/DRAM 映射及 raw `.log/.logw`。已存在的测试不重复运行。物理宏时序等价未确认前不得提升到完整 Place/Route。 |
| 已有结果 | 单变量 Gate 对照将运动层从 2,400 DRAM LUT/0 ERAM 映射到 0 DRAM LUT/16 ERAM20K；全顶 `#slice*` 估算 23,228→20,183（−3,045），DRAM LUT 4,240→1,840，ERAM 43→59。候选 Setup WNS/TNS 为 -7.231/-207.148 ns，最差路径仍在 AWB。候选 Gate 估算仍比 18,033 的 85% 上限高 2,150，且没有 Place/Route/bitstream。 |
| 结果判定 / 剩余未知 | **支持映射假设，不支持整机达标或时序闭合。** 既有定向边界测试使用行为数组模型；受保护厂商模型不能由当前 Icarus 解析，PH1P primitive 的实际读延迟/冲突时序仍未知。官方 PH1A ERAM 手册不能单独证明 PH1P35 primitive 行为。 |
| 成本与次数 | 该单变量 Gate 候选已执行一次；不重跑同一输入，不因额度恢复自动升级完整构建。若取得适用 PH1P 厂商模型/文档并通过定向等价，才评估一次整机实现试验；本工作包完整工程试验次数为 0。 |

### 既有 AWB 单变量证据（历史 fix7→fix8，非本包实验）

此前的 AWB 变更只把 `floor((r+g+b)/3)` 替换为对 0…765 输入精确的乘 683/取位实现，fix8 AWB 文件 SHA-256 为 `0baf5a3e6ad6ad335b903c584e228a2955083fbfa9378a23b08ad6c31fe063a3`。历史记录给出的 Gate Setup WNS/TNS 改善为 2,176/97,072 ps，DSP 从 41 降到 40；放置 Slice 少 245，但已有同 seed 波动超过该差值，不能归因于 RTL。当前更新构建仍以 AWB `mult12_syn_168` 为最差路径，WNS -7.560 ns，因此该改动并未解决最新时序。原有功能语义还要求帧统计接受条件、逐帧增益更新、同拍 SOF 使用旧增益、后续首次接受 SOF 使用新增益、吞吐和舍入/饱和均保持；不假设额外帧间空闲。此历史对照不在本轮重跑，也不与最新 Place 数据拼成一个通过版本。

### 下一工作包建议

下一包只聚焦一个阻塞：在获得/确认厂商支持的 ModelSim 环境后，用当前安装的 PH1P 模型运行既有运动历史边界 testbench，验证读写延迟、同址读写、复位、首帧、短帧部分写入、缺 SOF 和历史提交。安路 FAQ 指出 TD 的 SIM 模型可在 ModelSim 编译并用于 RTL 功能仿真和带延时后仿真；另一条 FAQ 说明 ERAM 模型位于安装目录 SIM 且大多加密。当前已找到模型，但本机未发现 ModelSim/Questa/VCS/Xcelium 可执行文件；Icarus 在受保护块入口报语法错误，因此这不是模型语义失败，也不能宣称 primitive 等价。只有定向宏仿真通过后，才评估一次完整工程 Place；若无法加载或出现语义反例，则停止这条集成路径，保留当前 inferred 基线。七项功能、85% 资源门、时序、硬件和其他验收条件均不变。

### 厂商 ERAM 模型与仿真器现场核验（2026-10-20）

安装模型位于 `.tools/td/app/sim_release/ph1p/ph1p_logic_eram.v`，44,271 bytes，SHA-256 `70d89b70bdd51812ad86b91e88526b4604ebb117516efda5af976fcddb2e69af`。文件头声明 PH1P `PH1P_LOGIC_ERAM` functional simulation model v0.21，最近修订 2026-06-21；保护头包含 Synopsys VCS、Cadence 和 Mentor Graphics/ModelSim key block。该头信息不证明本机具备相应仿真器或该版本可成功解密。留存副本与安装文件字节一致。Icarus compile stderr 在受保护正文入口第 115 行报告语法错误，日志见 `work/codex_motion_eram_model_audit_20261020/run/compile.stderr.txt`；该失败只证明 Icarus 不能解析此加密格式，未执行任何宏语义检查。

安路官方 FAQ：[“如何获取 ERAM 的仿真模型”](https://tech.anlogic.com/Cn/Index/listView/catid/12/m/Cn/cate/15/tp/1/p/2.html)说明模型位于 TD 安装路径 SIM 目录且大多数已加密；[“安路平台如何在 ModelSim 上做仿真”](https://tech.anlogic.com/index.php?%2FCategory12=&cate=32&cates=44)说明可将安装 SIM 模型在 ModelSim 编译为器件库，支持 RTL 功能及带延时后仿真。这些 FAQ 给出工具入口，但没有提供足以关闭 PH1P 本例读延迟/冲突语义的专属条款。当前进程核查没有发现 TD 构建或兼容仿真器进程；PATH 和已检查的常见安装目录中也未发现相应仿真器。此为本机环境审计结果，不代表全盘不存在。

最新完整构建的事后输入清单与复现步骤见 `work/codex_motion_context_tdmap_20261020/full_run_input_manifest.json`；原始日志/报告哈希在该清单中逐项复核。fix8 历史输入另见 `g8_fix8_reconstructed_input_manifest_20261020.json`。二者不得互相替代。PH1P 器件 ERAM 容量见[安路 PH1P 官方产品页](https://www.anlogic.com/product/fpga/phoenix/ph1p)；[UG902 ERAM 手册](https://anlogic.oss-cn-shanghai.aliyuncs.com/web_doc/%E5%B7%A5%E5%85%B7%E4%B8%8E%E8%B5%84%E6%96%99%E4%B8%8B%E8%BD%BD/%E6%8A%80%E6%9C%AF%E6%96%87%E6%A1%A3/PH1A/hdvhdfhvfdh/%E4%BD%BF%E7%94%A8%E6%8C%87%E5%8D%97/UG902_%E5%AE%89%E8%B7%AF%E7%A7%91%E6%8A%80PH1A%E7%B3%BB%E5%88%97FPGA%20ERAM%E7%94%A8%E6%88%B7%E6%89%8B%E5%86%8C.pdf)适用于 PH1A，尚不能作为当前 PH1P primitive 时序/仿真等价的厂商依据。

## AWB 固定帧均值数学等价核验卡

| 项目 | 内容 |
|---|---|
| 问题 | 当前 `fixed_mean` 的 Q32 reciprocal 是否对整帧合法累加值保持 `floor(sum / 921600)`，以确认最差路径上的 line-54 乘法语义可作为后续结构优化基线？ |
| 支持证据 | 最新 Gate 最差路径从 `u_awb_frame_gain_controller/mult12_syn_168` 出发；映射报告该控制器为 945 logic LUT、11 DSP。构建快照 RTL SHA-256 `0baf5a3e6ad6ad335b903c584e228a2955083fbfa9378a23b08ad6c31fe063a3`；同一快照 `design_top_wrapper.v` 明确覆盖 `USE_FIXED_AWB_PIXEL_COUNT=1`、计数 921600（SHA-256 `3c58faf97194bb0d789b2afe2e5e9729981c01a311af46a967961a267b0a11ff`）。 |
| 唯一变量 / 对照 | RTL、参数、报告均不变；只将当前 `floor((sum >> 8) × 1193047 / 2^32)` 与整数参考 `floor(sum / 921600)` 对照。 |
| 固定范围与语义 | 合法 8-bit RGB 通道总和 `sum=0…235008000`；超过界限的既有行为是饱和到 255。本核验只判断均值函数，不改增益、限幅、舍入、帧统计接受、同拍 SOF 旧增益或后续 SOF 新增益行为。 |
| 最便宜验证 | 由 `921600=3600×256` 化为 `q=floor(sum/256)` 的 `0…918000` 全枚举，对照 `floor(q/3600)`；另用整数边界证明被丢弃的低 8 位不会跨过商边界。不跑 RTL、TD 或整机回归。 |
| 判定 / 成本 | 零差异支持当前公式的全合法域等价；任一反例即否定并停止结构替换；参数未绑定到固定模式则无法判定。执行量 918,001 次整数比较，最多一次。此核验本身不声称有 PPA 收益。 |

结果：在 `q=0…918000` 上完成 918,001 个整数比较，`floor(q×1193047/2^32)` 对 `floor(q/3600)` 为 0 mismatch，端点 0 和 918000 分别得到 0 和 255。结合低 8 位余数的边界证明，确认当前固定 `921600` 像素路径的 `fixed_mean` 在所有合法通道总和上等于 `floor(sum/921600)`；`sum>235008000` 的既有饱和分支不在合法输入域内且未修改。它支持将该精确函数作为后续 AWB 结构优化对照，但没有证明新的结构更省 Slice/DSP 或改善最差时序；同拍 SOF、帧更新节奏、限幅及整机指标均未变化。本核验没有运行 RTL/TD，也没有改动 V2 源码。

## AWB 固定帧均值结构候选（单变量、已否定）

| 项目 | 记录 |
|---|---|
| 问题 / 支持证据 | `fixed_mean` 位于最新完整快照最差路径起点；控制器为 945 logic LUT、11 DSP。上一节已证明合法固定帧输入上 `floor(sum/921600)` 与现有公式完全等价。 |
| 唯一变更 / 固定输入 | 隔离副本仅把 `sum_div_256 * 1193047 >> 32` 换为 `sum_div_256 / 3600`。基线 AWB SHA-256 `0baf5a3e6ad6ad335b903c584e228a2955083fbfa9378a23b08ad6c31fe063a3`，候选 `33241ebf51fb663b79561b614a0d710e7be352ff177c6d704bae464ebd785314`。候选 228 项输入逐项核对，唯一差异是该 AWB RTL；其余源、TD 6.2.168116、PH1P35MDG324、Speed 3、top、`-packarea` 和 `read_design→opt_gate` 固定。 |
| 保持语义 / 最低验证 | 均值舍入、`sum>235008000` 饱和、增益限幅/步进、帧统计接受条件、同拍 SOF 旧增益/后续 SOF 新增益和吞吐不变。先跑既有 `tb_awb_frame_gain_fixed`，再做 Gate 映射；仿真失败即停止。 |
| 结果 | Icarus 编译退出 0，仿真输出 `TB_AWB_FRAME_GAIN_FIXED_PASS`。TD Gate 退出 0，耗时 4m04s、峰值 1552 MB；控制器层级由 945 LUT/11 DSP 变为 1010 LUT/5 DSP（+65 LUT、−6 DSP），但全顶 DSP 由 40/40 变为 45/40。WNS/STNS 从 −7.560/−366.675 ns 变为 −14.241/−652.058 ns，Fmax 从 58.072 MHz 变为 41.839 MHz；最差路径由 `mult12_syn_168` 改为 `u_v2_frame_stats/O_sum_b_reg[20] → O_gain_b_reg[2]`。 |
| 判定 / 停止 | **否定该结构方向**：数学等价和定向回归通过，但关键路径明显恶化且全顶 DSP 超限，不进入 Place/Route。Gate `#slice*` 表面 23,228→23,056（−172），但无关层级映射行也大幅变化（包括 bbox overlay、OSD、DDR 子层）；不将该值记为可归因收益。候选已被时序/DSP 判据否定，不重跑同一基线。 |
| 告警 / 产物 | 候选内层 `.logw` 与基线均为 1,012 条、985 种告警，没有新增或消失的唯一告警；`SYN-5011/5025` 等既有告警仍开放。隔离源码、完整构建输入副本、TD 原始日志和 Gate area/timing 保留在 `work/awb_fixed_mean_div3600_trial_20261020/`。活动 V2 源码未修改；无 Place、Route 或 Bitstream。 |

### 当前下一工作包建议（更新第 56 节旧建议）

下一包只评估当前 `video_cartoon` 三行缓存能否改为两行奇偶环复用，其他算法和控制逻辑保持不变。当前是 3×1280×24 = 92,160 bit，Gate 映射 1,536 DRAM LUT、0 ERAM；两行方案逻辑存储为 61,440 bit，理论上少三分之一存储位，但不预报 Slice 收益。先审计同址读旧行/写新行、RAM 读延迟、边界、复位、首帧、短帧、缺 VS 和行计数，再用定向 Icarus 对照；若等价通过，才做单模块或全顶 Gate 映射，要求实际 DRAM/LUT 收益，否则停止。此路径先保持 inferred DRAM，不依赖当前不可用的加密 ERAM 仿真器。七项功能、85% 资源门及其他验收条件不变。

## 2026-10-20 双行缓存地址模型与官方资料复核

- **软件地址模型（非 RTL）**：按 `WIDTH,HEIGHT=1…8` 共 64 组参数；每组执行 4 类序列：无 SOF 连续流并自然帧回卷（`max(500,8WH)` 周期）、带行间 `DE` 空隙的 5 帧长度序列（`5WH`）、带 `DE` 间断/随机 VS/复位的序列（`4WH`，LCG `a=1664525,c=1013904223`，每周期 `DE=68%`、VS 约 `1/211`、复位约 `1/503`）、VS 与 DE 同拍序列（`3WH`，每 31 周期一次）。逐个有效像素按 read-before-write 模型比较三银行与 `y[0]` 奇偶双银行的有效 top/middle 行（`y=0/1` 的边界复制与 RTL 一致）。共 256 场景、44,840 个有效窗口比较，其中 20,730 次为同址读写；未见模型差异。
- **证据边界**：该模型只验证行号/地址轮转，显式假设写时读取得到旧值；未运行候选 RTL、TD 映射或硬件。临时模型源码未保存，因此数字为探索性证据，不替代可复现 RTL 回归。当前源码注释明确三银行设计用于避免依赖未定义的 RAM read-during-write 模式。
- **官方资料核对**：安路 PH1P 产品页列出 PH1P35MDG324 的 Dis-RAM 507 Kbits、ERAM 108×20K；[Soft_FIFO IPUG012](https://tech.anlogic.com/Public/Uploads/ueditor/upload/file/20230809/1691580810479801.pdf)说明 PH1 DRAM 资源按 LUT6 计数。此次检索到的资料未确认该 inferred DRAM 的同址读写语义，故该关键假设仍为 `unknown`，不能据 Icarus 或纯软件模型关闭。
- **现场与决定**：最新完整构建仍是 3-bank RTL 快照；没有候选修改、没有新 TD 构建。两银行方案保留为待确认的隔离实验，先做定向 RTL 差分，再视结果决定是否做一次模块级映射；本记录不改变七项功能、85% 资源门、性能或硬件验收条件。

## 2026-10-20 接口告警源、接收点与约束归因

下表按最新构建快照的 TD 内层 `.logw`、展开源码和实际载入约束复核。项目约束/源码只证明当前工程做了什么，不替代官方板卡、电气或 IP 时序依据；证据不足的告警保持开放。

| 告警/接口 | 当前源码源端与接收点 | 实际约束证据 | 判定与未关闭项 |
|---|---|---|---|
| `PHY-5060` I2C `u_uicfgcs520/u_i2c/scl_clk`：1 clock + 2 data/ctrl sinks | `uics500_cfg/uii2c.v` 78–81、109–120 行由 `I_clk` 分频产生 `scl_clk`；142、154、164、176、188 行有正/负边沿逻辑接收，另有 `scl_r` 组合使用。顶层 `uicfgcs520.I_clk` 接 `S_24m_clk`，I2C SCL 输出接 `O_cam_scl`。 | `pin.adc` 第 3–4 行把 `O_cam_scl`/`IO_cam_sda` 放在 K3/J3，LVCMOS33；`camera_to_dsi_display.sdc` 未显式建 `scl_clk` generated clock，也未见 SDA/SCL 外部输入/输出延迟。 | 源、内部接收逻辑和 GPIO 位置可定位；1 个 data/ctrl sink 的具体综合网表 pin 名未从 warning 提供。外部 I2C 时序/电气要求、板卡上拉与当前约束是否匹配仍缺官方依据。保留告警，不以当前可构建或管脚已赋值关闭。 |
| `PHY-5060` 摄像头 MCLK 候选 `O_cam_24m_syn_3`：160 clock + 1 data/ctrl sinks | 顶层 `design_top_wrapper.v` 552 行将 `S_24m_clk` 接到 `O_cam_24m`，PLL `clk1_out` 于 565 行驱动 `S_24m_clk`；`ae_set.I_clk`、`uicfgcs520.I_clk` 分别于 579、592 行接收。外部摄像头 MCLK 接收端是顶层 `O_cam_24m`。 | `pin.adc` 第 5 行指定 L3/LVCMOS33；SDC 将 PLL `clkc[1]` 命名为 `pll_clk_24m`，但无 `O_cam_24m` 输出延迟或板级 MCLK 相位/电气约束。 | 源、内部时钟接收模块和项目管脚已定位；Place warning 的那个 data/ctrl sink 名称未给出，不能据 1 个 sink 推断为顶层端口。相机端频率/容限及板级电气依据仍需官方模组/原理图资料。告警保持开放。 |
| `PHY-5016` PLL `clkc` → IO（4 条，重复为两组“无 location / 非 clock-capable IO”） | TD 原始 Place 日志没有给 PLL 实例、`clkc[n]`、网络、接收端或 IO 名称；目前不能将其归属到 MCLK、HDMI 或 DDR。`O_cam_24m` 在项目 pin 文件中确有 L3 位置，故不能把该位置直接当作 `PHY-5016` 的目标。 | 顶层 pin 文件有摄像头与 HDMI GPIO/TMDS 指派；DDR 另由 `ddr2.adc` 指派 DDR IO 和 PHY/PLL 位置。Place warning 没有指出哪组约束未生效。 | 目标 IO/PLL 与该器件的 clock-capable 依据未定位；必须取得更详细的 IO/PLL 检查报告或厂商工具诊断，当前不臆测、不关闭。 |
| DDR PHY Gate `HDL-5314/HDL-5323`；Place `PHY-5088` | Gate 原始日志把未驱动项定位在载入的 `ph1p_ddrphy_init.v`、`ph1p_ddrphy_fast_init_wrapper.v`、`ph1p_ddrphy_byte_wrapper.v`、`ph1p_ddrphy.v` 等 PHY 源文件（例如 `rom_w52`、`init_*` 高位、`phy_rdata[103]`、`dx*_wdata[103]`）；未连接端口例子为 `dqs_pupd_en`、`dhi_bg[11]`、wrapper 的 `apb_psel`。`ph1p35_324_ddr_wrapper.v` 84–85 行还将 `cfg_clk`、`ddrphy_rst_n` 留空。Place 只报时钟网驱动非 clock sinks/clock-net 级联，没有给网名。 | DDR 物理 IO 与 PHY/PLL 位置见 `ddr2.adc`；IP SDC 只重命名 `ref_clk/ctl_clk/ddr_clk/mcu_clk/usr_clk` 并设置 `mcu_clk` 异步组，顶层 SDC 对 DDR `ddr_clk/usr_clk` 另设异步组。未见本工程 SDC 的 DDR 外部 input/output delay。 | warning 的 RTL 位置和项目约束入口可定位，但这些高位/端口是否是该 PH1P35 IP 配置下预期裁剪、复位/配置空接是否合法、时钟例外是否完整，尚无当前确切 IP 版本的官方依据与展开后 pin 归因。保留开放；不得称其无害，也不以告警数变化关闭。 |

本轮只完成静态告警归因，没有修改 RTL/约束、运行测试或启动构建。此前接管时未发现活动 TD 构建；本轮没有新启动实例。最省成本的后续证据入口是从同版本 TD 工程导出 `analyze_clock -detail`、PLL/IO location 检查和完整 DDR IP elaboration/report，再按具体 net/pin 对照官方 PH1P35 与板卡/模组资料；若工具无法导出，保留原始告警并把未闭环项交接，不以全工程重跑替代归因。

## 2026-10-20 ERAM 行为证据复核（复用既有试验）

- 最新整机快照、ERAM 仿真输入和单模块 TD probe 使用的 `motion_diff_160.v` SHA-256 均为 `f3f880cb5265fb1309dcab5a9d686dbbed766fa4250b4e24e936f4c089f66976`。默认整机参数为 160×120、阈值 8；模块 probe 报告单独绑定其自身 wrapper/参数，不能把其 DRAM LUT 数直接换算为整机收益。
- RTL ERAM 分支明确设置 `MODE="SP"`、`REGMODE_A="NOREG"`、`WRITEMODE_A="READBEFOREWRITE"`、`CLKMODE="ASYNC"`；`rsta/rstb` 接常量 0，RAM 内容不复位，控制元数据另行复位。TD 安装的 PH1P 库声明列出 `READBEFOREWRITE` 为支持的参数值，但声明本身没有给出可审计的读延迟/碰撞波形，因此宏行为仍不能只凭参数名判定。
- 已有 Icarus 14.0 差分仿真 `work/codex_motion_eram_edgecases_20261020/` 通过：缺 SOF 样本不提交；短帧写入历史但不提交帧 ID；下一完整帧能观察到那两处写入，随后静态帧不报运动；部分帧中复位后首个完整帧只建立基线。用例为 4×3、阈值 5，逐拍比较原 inferred 分支和 ERAM 选择分支所有输出，退出输出 `TB_MOTION_DIFF_160_ERAM_EDGECASES_PASS`。但是仿真定义了 `MOTION_ERAM_SIMULATION`，两边都使用行为数组代理，不包含 `PH1P_LOGIC_ERAM` 原语；这关闭了控制/历史提交用例疑点，不关闭真实宏延迟和同址读写行为。
- 已有模块 TD Gate 对照 `work/codex_motion_eram_tdmap_20261020/` 复核到 baseline 4,096 DRAM LUT/0 ERAM，candidate 0 DRAM LUT/16 ERAM20K；Gate Slice 估算 5,714→203。该 probe 的 inferred DRAM LUT 为 4,096，而整机层级为 2,400，差异原因未知；因此它只证明 probe 中 ERAM 映射成立，不作为整机可减 5,511 Slice 或任何确定整机收益的依据。candidate Gate WNS +1.686 ns、TNS 0，但 STA coverage 61.40%；两 arm 均有 probe 未约束 IO 告警，且无 Place/Route。
- TD 安装的 `sim_release/ph1p/ph1p_logic_eram.v` 头部可读部分 SHA-256 为 `70d89b70bdd51812ad86b91e88526b4604ebb117516efda5af976fcddb2e69af`，参数声明后从第 107 行进入加密块；本机 `ph1p_macro.v` 是原语黑盒声明。安路 FAQ 说明多数 ERAM 仿真模型加密，但没有说明本例 `REGMODE_A/CLKMODE/WRITEMODE_A` 的精确时序。此前 Icarus 对加密模型编译失败不是功能反例。结论仍是：资源映射假设有 Gate 证据；真实宏语义和物理时序尚未证明，禁止据此提升为整机通过。
- 后续最值当的验证不是重跑已通过的行为代理或 Gate probe，而是用受支持的 PH1P 模型/仿真器对真实 `PH1P_LOGIC_ERAM` 跑相同测试，记录首读、连续读、写同址、读写延迟、复位后首帧和短帧提交。若本机缺少受支持仿真器，则下一可执行决策是取得官方模型/工具支持信息；对外发送厂商咨询前须先获用户授权。未完成该项前不启动这条实验的第二次完整整机试验。

## 暂缓方案：卡通行缓存无损 24→9 bit 压缩

该方案的数学等价核验保留为历史证据；当前不实施。用户已选择先评估三行→两行奇偶环缓存，不能并行叠加位宽压缩变量。

| 项目 | 记录 |
|---|---|
| 问题 | 三个 1280 深度 RGB 行缓存能否只保存算法实际使用的量化色值，并逐像素保持当前 `video_cartoon` 输出与同步完全一致？ |
| 支持证据 | 当前完整快照 `video_cartoon.v` SHA-256 `9778bb06e7dddf0238fdc2e70260125c8508ae46dbb9bb92554a811a8fff4dc0`；三个 bank 的像素在进入窗口运算后都经过 `quantize_pixel`，RAW 输出取 `raw_pipe` 而不是这些 bank。每通道只使用高 3 bit，压缩前存储规模 3×1280×24=92,160 bit。 |
| 唯一变量 / 固定对照 | 仅把 `bank0/1/2` 存储宽度 24 bit 改为 R/G/B 各 3 bit，并在读出时精确展开为现有 `quantize_pixel` 的 24-bit 结果；维持三 bank、地址、时序、`row_mod3`、其它运算/控制不变。基线参数 WIDTH=1280、HEIGHT=720、EDGE_THRESHOLD=240，使用最新整机快照；不修改正式 V2 worktree。 |
| 预期收益与必须保持 | 存储位数理论下降 62.5%（至 34,560 bit）；按当前 Gate 1,536 DRAM LUT 仅作位数推算，预计约 960 LUT 的上限级潜力，不视为 Slice 预测。必须逐像素保持 RAW/EDGE/TOON、OSD 叠加、帧边界模式、`VS/HS/DE` 延迟、边缘复制、复位及无背压行为；保持三 bank 避免同址读写，不引入新的 RAM 冲突语义。 |
| 最便宜验证 / 判据 | 先对每通道 0…255 穷举 `Q(c)` 与 pack/expand 路径；再跑同输入、同参数的候选/基线定向 RTL 差分及既有边界回归。任一像素或控制差异即否定并停止。只有 RTL 等价通过后才做一次模块 Gate；要求 DRAM LUT 实测至少减少 768、Slice 估算下降且无新阻塞告警，才能考虑整机 Gate。模块数据不得直接宣称为整机收益。 |
| 成本与次数 | 软件等价 1 次；Icarus 定向 RTL 对照 1 次；最多 1 次模块 Gate；不在此包启动 Place/Route/Bitgen。最大完整工程试验数为 0。 |

数学/软件等价阶段结果：对 3 个独立颜色通道的 0…255 全域共比较 768 组，候选 pack(c)=c[7:5]、按原 quantize_pixel 规则展开并再次量化，与基线量化输出 0 mismatch。因通道变换可分离，这覆盖全部 24-bit RGB 组合的逐通道等价。三行位数由 92,160 降为 34,560（−57,600，−62.5%）；按当前层级 1,536 DRAM LUT 的线性位宽比例仅估算约 576 LUT、潜在节省 960 LUT，不是综合实测。现有回归入口 work/tests/run_cartoon_region_fill_sim.py 可接受 --rtl 候选路径并以 seed 520 覆盖三个模式，尚未对新候选运行。RTL 差分与模块 Gate 仍待完成。

本轮未修改任何 RTL。通用命令启动器本轮多次在创建进程前返回 helper_unknown_error: setup refresh had errors，所以没有声称完成 Icarus/TD 验证或刷新 OS 进程列表；已通过只读文件接口完成附件、源码、报告和数学核验。

## 已批准待执行实验：三行→两行奇偶环缓存

| 项目 | 记录 |
|---|---|
| 问题 | 两个按行奇偶复用的 RGB 行存储，能否保持当前三银行 `video_cartoon` 的像素、模式和同步输出；TD 对 PH1P35 inferred DRAM 的同址读写映射是什么？ |
| 支持证据 | 当前基线 `video_cartoon.v` SHA-256 `9778bb06e7dddf0238fdc2e70260125c8508ae46dbb9bb92554a811a8fff4dc0`。源码明确三银行用来避免同址读写；已有软件地址模型覆盖 256 场景/44,840 窗口，但假设 read-before-write，且不是 RTL 证据。当前完整快照 cartoon 层级为 661 logic LUT、1,536 DRAM LUT；具体映射语义仍 unknown。 |
| 唯一变量 / 固定对照 | 仅在隔离副本把三 bank 改为 `y[0]` 选择的两 bank；其他 RTL、参数与数据路径不改。基线固定为上述哈希和 WIDTH=1280、HEIGHT=720、EDGE_THRESHOLD=240；定向边界用例使用同一候选/基线、同一向量与时钟配置。 |
| 必须保持 | RAW/EDGE/TOON、逐像素 RGB、VS/HS/DE 与 mode 延迟、边缘复制、帧边界模式更新、复位、首帧/短帧/缺 VS、DE 间断及帧行计数语义一致。重点检查 y≥2 时 top 行读取与当前行写入的同址碰撞；不能把 Icarus 的非阻塞赋值旧值语义当作厂商 RAM 保证。 |
| 验证与判定 | 最先做源码/存储时序审计，再做定向基线—候选 RTL 差分；任何功能或控制差异即否定并停止。RTL 等价通过后才允许一次模块级 TD 对照，读取内层原始日志、映射资源和时序；只有碰撞语义可解释且资源实测下降、无新阻塞问题，才建议整机后续评估。模块数值不外推为整机收益。 |
| 预算 | RTL 定向仿真一次；最多一次模块级 TD 映射；不跑完整工程、Place/Route 或 Bitgen。当前仅获用户批准，尚未执行。 |

2026-10-20 接管检查：本轮统一终端启动器在创建进程前失败（`helper_unknown_error: setup refresh had errors`），因此无法完成系统级 TD/仿真进程枚举；Proteus 窗口查询返回空列表，但这不等于无后台进程。没有启动任何新任务。RTL 快照和既有 Gate 摘要已核对；仿真与模块映射保持待执行，直至进程状态可核验且命令启动条件恢复。

恢复时先运行只读进程核验：`Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(td|iverilog|vvp|modelsim|vsim)' -or $_.CommandLine -match 'TangDynasty|iverilog|vvp|video_cartoon' } | Select-Object ProcessId,Name,CommandLine`。若命中已有作业，只观察其日志/退出状态；若无命中，才创建隔离仿真目录并从固定基线哈希开始，不启动全工程构建。

## 2026-10-20 现有卡通 RTL 向量覆盖审计

- 只读检查 `work/tests/run_cartoon_region_fill_sim.py`、`tb_video_cartoon_region_fill.v` 与 `cartoon_region_fill_hardware_equivalent.py`：现有向量覆盖 3 个完整帧、三种模式、固定 seed 520、帧间 VS、逐行空白、DE 间隙、帧中请求变化，以及初始复位；可用 16×8 或 1280×720。
- 现有向量没有短/截断帧、缺失 VS、帧中复位、VS 与 DE 同拍以及 1/2 像素宽或高等针对缓存轮转的边界序列。因此它不能单独覆盖本实验卡要求的历史行提交与奇偶回卷行为。
- 下一次定向仿真应在固定基线与候选之间逐周期比较全部 `{VS,HS,DE,mode,RGB}` 输出，并另加上述缺失序列；保留原 seed 520 完整帧作为回归，不重复运行它来替代边界覆盖。本审计未运行测试或修改 RTL。

## 同一整机快照的 cartoon RAM 映射原始证据

- `work/td_g8_motion_inferred_a_seed1/td_project/camera_to_dsi_display_Runs/syn_1/td_20261020_005854.logw` 第 2006–2008 行：`u_video_cartoon/ramread0_syn_22`、`ramread1_syn_22`、`ramread3_syn_22` 各有 `SYN-5041`，日志称 `RAM_STYLE/ROM_STYLE` 设置不正确、RAM inference 实际使用 `AUTO`。因此源码 `ram_style="block"` 不是映射保证。
- 同目录 `camera_to_dsi_display_gate.area` 第 21–24 行记录该快照整机 `#slice* 23,228/21,216`、`#dram lut 4,240`；第 216 行 cartoon 层级为 661 logic LUT、1,536 DRAM LUT。此为当前三银行基线的 Gate 映射，不是两银行候选收益。
- 这些 Gate/原始日志字段没有给出 read-during-write 行为或可审计的 RAM collision mode。故实际映射资源已证实，碰撞语义仍 unknown；定向 Icarus 通过也不能单独关闭该未知项。

## 2026-10-20 PH1P DRAM 仿真模型接管

- TD 安装含可读的 `E:/Projects/FPGA/.tools/td/app/sim_release/ph1p/ph1p_logic_dram.v`，13,296 bytes，SHA-256 `e3ccf3c4821d33a3bd3ceac816493d09342b0651862fadd1b3d03fff1f30efcb`。`PH1P_LOGIC_DRAM` 模型将写端时钟、异步读事件和可选 `READREG` 输出寄存器分开建模；该源文件本身没有把当前 `AUTO` 推断节点与此 primitive 配置绑定，也没有报告当前 inferred RAM 的 collision mode。
- 安路 FAQ 表示 TD 安装目录有器件模型，可在 ModelSim 中用于 RTL/延时仿真；Soft_FIFO 手册确认 PH1 DRAM 按 LUT6 计数，但未给本设计的读写碰撞保证。来源与边界已写入 `docs/research/sources.yaml` 和 `docs/research/known-gaps.md`。
- 本轮再次进行只读系统进程核验时，统一执行启动器仍在创建进程前返回 `helper_unknown_error: setup refresh had errors`。没有新构建/仿真启动；活动后台进程状态仍未知。后续不重复同一进程命令，除非启动器状态有新变化。

## 2026-10-20 既有 Gate 数据库语义可见性检查

- 只读检查基线 `syn_1` 下 13.1 MB RTL、16.6 MB Gate、15.8 MB elaborate 数据库，并扫描 Gate timing 文本：数据库的直接字符串搜索未发现 `PH1P_LOGIC_DRAM`、`ramread*_syn_22` 或 `READREG` 参数文本；timing 报告可见的 DRAM 弧属于运动历史 RAM，没有列出 `u_video_cartoon` 路径。
- 该检查只是确认现有文本报告不可直接提供 cartoon inferred RAM 的 primitive/输出寄存器配置，不能据此推断数据库中不存在对应存储单元或时序路径。现有 Gate 资源行和 `SYN-5041 AUTO` 告警仍是唯一已定位的映射证据。
- 后续若 Icarus 等价通过，单次模块 Gate 需要保留/导出 cartoon 层级 schematic 或 primitive 实例参数；若该输出仍不能绑定到 `PH1P_LOGIC_DRAM` 的 `READREG` 等配置，则碰撞语义保持 OPEN，不把普通 RTL 数组仿真当成关闭依据。本轮没有启动新任务。

## 2026-10-20 后续接管：两行缓存结果与 AWB 最差路径审计

- **三行→两行候选结论按版本区分**：旧候选 `92AD…` 在本轮固定 W=1、H=2 向量上只有 cycle 49 一处差异，基线为 `16xxxxxx`（X），候选为 `1692246d`，判 INCONCLUSIVE，不是等价 PASS，也没有定义值反例证明硬件功能错误。另一个 canonical G8-R2 候选 `9d5c…` 的多场景 RTL 回归通过，但独立模块 Gate 映射到 2,048 DRAM LUT，高于 R1 完整层级的 1,536；该两行候选的资源收益未证实并已停止。两候选不得混作同一输入；均未合入/推广。`92AD…` 的历史模块映射 2,320→1,723 `#slice*`、DRAM LUT 1,536→1,024 仍只是独立模块结果。证据分别见 `work/codex_cartoon_2row_experiment_20261020/followup_gate_candidate_w1_h2.md` 和 `work/g8_r1_v2_integration/docs/experiments/2026-10-20-industrial-v2-g8-r2-parity-ring.md`。
- **AWB 输入绑定**：最新完整输入 `td_g8_motion_inferred_a_seed1` 中的 `awb_frame_gain_controller.v` 与当前 V2 源文件 SHA-256 同为 `0baf5a3e6ad6ad335b903c584e228a2955083fbfa9378a23b08ad6c31fe063a3`；顶层实际启用 `USE_FIXED_AWB_PIXEL_COUNT=1`、`FIXED_AWB_PIXEL_COUNT=921600`。本次只读审计未修改 RTL、未重跑测试/TD。
- **最差路径确认**：同一 Gate 原始 timing 第 101–110 行为 `mult12_syn_168.clk → O_gain_b_reg[0].d`，17.152 ns、18 级、fanout 46、WNS/TNS −7.560/−366.675 ns。路径从 `fixed_mean` 的 Q32 乘法，经高 fanout 通道均值、`fixed_average3` 的乘 683、增益阈值/步进逻辑到输出寄存器。Gate 层 AWB 为 945 logic LUT、352 ripple、29 seq、11 DSP；整机 Place 22,882/21,216 并以 `PHY-9053` 停止，85% 预算仍差 4,849 Slice。AWB 是真实时序热点，但单独优化它不能被当作资源缺口已解决。
- **既有方向排除**：固定均值 `/3600` 候选已在 `work/awb_fixed_mean_div3600_trial_20261020/` 记录为路径恶化、全顶 DSP 超额；饱和分支候选见 `work/codex_awb_sat_probe_20261020/experiment.md`，只改善 402 ps、增加逻辑且仍负 WNS。两者不重跑、不外推到最新整机 PPA。
- **AWB 前置均值分段实验已执行**：详情见 `work/awb_early_stage_retime_20261020/EXPERIMENT.md`。模块 Gate WNS −9.826→−1.976 ns，但仍负裕量，Slice 1,338→1,343（+5），最差路径转为 `O_gain_b_reg[0].q→O_gain_b_reg[5].d`；依实验卡未运行 full-top Gate/Place/Route。不得把此模块结果套到 R1 全顶。
- **活动工具现场**：收尾只读核查见到 `td.exe` PID 46300（启动 10:47，路径 `.tools/td/app/bin/td.exe`）。6 秒 CPU 从 207.625 增至 207.640625，R1 `flow_exec.log` 时间戳保持 18:32:46；读取 CommandLine 被系统拒绝，故只能说观察窗口内无相关日志进展，不能断言该交互进程本身已退出或完全空闲。本轮未启动或关闭 TD。

## 2026-10-20 本地统一执行启动器复核

- 普通沙箱 `exec_command` 在主仓库、备用工作区和无 `.git` 的可写目录均于 PowerShell 创建前失败，原始错误均为 `Failed to create unified exec process: helper_unknown_error: setup refresh had errors`。同会话提权执行通道正常；无 TD/Icarus/VVP 进程，Codex sandbox 服务在运行，C/E 盘各有约 100/142 GB 可用。故障不绑定 FPGA 仓库或充值额度；可确认在 Codex 统一执行/沙箱 setup refresh 层，内部具体失败项没有可读取的服务日志，不能再精确归因。
- 未修改 ACL、未重启托管服务；使用已通的提权通道完成本轮隔离工作。恢复命令：`python -B work/codex_cartoon_9bit_storage_20261020/run_equivalence.py`；模块 Gate：`.\work\codex_cartoon_9bit_storage_20261020\run_gate.ps1`。若需恢复普通沙箱启动，应在 Codex 应用侧重启/更新后再复测，不能靠重复相同命令推进。

## 2026-10-20 Cartoon 行缓存 24→9 位映射结果

- 基线绑定最新完整构建的 `video_cartoon.v` SHA-256 `9778bb06e7dddf0238fdc2e70260125c8508ae46dbb9bb92554a811a8fff4dc0`；实验副本与正式 V2 工作树分离。候选只改变三个 bank 与同步读寄存器的存储编码，三银行/地址/时序/控制不变；候选 SHA-256 `0ab2878cc3daa0500cb5e1d33cf3705743cf7b96ebfcd5c8a7ae2ae9724b1286`。
- Icarus/VVP 14.0 固定 seed 520 的七组基线/候选周期 trace 全等，包括 `W=1,H=2`、截断帧后 `VS+DE`、缺 VS 自然回绕、帧中复位、DE 间隙和三种 mode；最长组 52,447 周期。向量、trace、runner 与日志保存在 `work/codex_cartoon_9bit_storage_20261020/`。
- 一组成对 TD 6.2.168116 PH1P35MDG324 speed3 模块 Gate（`read_design→opt_gate`）否定资源收益：`#dram lut` 1,536→1,536，Gate `#slice*` 2,320→2,323，层级 logic LUT 665→668，寄存器 453→453。原始内层日志、area/timing、输入/输出 hash 在两臂 `syn_1/`；共同有 `SYN-5025`、无管脚 probe 的 `SYN-6021`、`SYN-5041` AUTO RAM 推断告警，无 Error/Fatal。未运行 Place/Route/Bitgen，孤立 timing 报告不作为时序证据。
- 判定：像素/控制等价通过，压窄行缓存未改善 TD 映射，实验结束并停止；正式 RTL、完整构建数据及最差路径均未变化。下一选择先审计同等资源数下 TD 的 RAM 结构/推断证据，再确定是否值得另开单变量实验；本次不自动展开 AWB 或其他架构修改。

## 2026-10-20 已保存 Gate 数据库的行缓存映射归因

- 对实验两臂现存 `cartoon_probe_gate.db` 只做 `import_db → report_area → write_verilog`，未启动新综合/实现；可复查脚本为 `work/codex_cartoon_9bit_storage_20261020/db_export_existing_gate.tcl`，导出文件位于对应 `db_query/{baseline,candidate}/`。
- 基线三 bank 源码为 24 bit，候选为 9 bit；综合网表两臂的 RAM 家族均各映射 512 个 `PH1P_PHY_MSLICE`，合计 1,536 个 LUT6 DPRAM；每臂另有 192 个 `PH1P_PHY_DRAMHARDCON`（配置 `W_WIDTH("8")`）和 1,552 个 MSLICE 总数。导入 Gate area 显示 DRAM LUT 1,536→1,536、`#slice*` 2,252→2,255、logic LUT 597→600、seq 453→453；原始 `opt_gate` 面积报告绝对数为 2,320→2,323 Slice、665→668 logic LUT。两个报告阶段绝对值不可混用，但候选差均为 +3 Slice。
- 可关闭的疑点：候选 RTL 的窄存储确实进入正确 Gate 网表（顶层源路径和声明宽度可见），不是绑定错版本；最终 RAM LUT 数仍完全相同。未关闭的疑点：网表未解释 TD 为什么对 24/9 位数组都分配每 bank 512 LUT RAM；`SYN-5041` 仅说明 `ram_style="block"` 未被接受、转 `AUTO`，不足以证明其与分配数不变存在因果关系。到此停止该方向，不追加综合。
- 普通本地执行启动器的可确认故障仍是 Codex unified exec 在创建 PowerShell 前的 `setup refresh` 错误；提权通道可用并已用于只读 Gate DB 导出。平台内部 setup 日志不可见，因此内部具体失败项未知；没有在本轮重试普通启动器，也没有改 ACL 或重启托管服务。

## 2026-10-20 PH1P ERAM 加密模型语义探针结果

- 按单次实验卡对既有基线/ERAM 等价 testbench 和实际 TD PH1P 模型执行一次 Icarus 编译；未改 RTL、参数或激励。编译在 `ph1p_logic_eram.v:115`（`` `pragma protect`` 加密正文入口）报 syntax error / `I give up.`；原始 97-byte 日志保存在 `work/motion_eram_model_semantics_20261020/compile.log`。`.vvp` 与仿真日志均未生成，testbench 未运行；编译器数值退出码未单独留存。
- 当前环境的 `vlog`/`vsim` 命令不可用。结果属于仿真器无法解析厂商加密模型，**不代表 RTL 等价失败，也不代表通过**；真实 primitive 的读延迟与同址读写语义仍为 unknown。按预算停止，不追加换工具重试、模块综合或整机构建。只有获得当前 TD 模型可用的受支持仿真器后，这项验证才有新的区分价值。

## 2026-10-20 AWB 前置均值阶段单变量实验

- 固定输入绑定最新完整 Gate 快照 `td_g8_motion_inferred_a_seed1`（219 个 user_source 文件一致，重建清单 SHA `70e629335bd65d01286309f91606f5a3f5bf98799f747955b737400ee13619cc`）。只在隔离目录 `work/awb_early_stage_retime_20261020/` 为 `frame_stats_96` 增加早一拍旁带、为 AWB 增加 means/target 暂存；正式 `E:/Projects/FPGA-v2` 源码未改。
- 软件等价、AWB/帧统计单元差分及组合链路 Icarus/VVP 回归通过：定点公式和增益结果、commit 时点、无空拍输入、scene protection、错 ID/无效帧/计数异常 fail-closed、reset 清暂存、同沿 SOF 采旧增益均保持。综合的组合 testbench 输出 `TB_FRAME_STATS_AWB_PIPELINE_PASS stats=4 invalid=1 aligned_awb_updates=3 back_to_back=1`。
- 一组隔离 TD `read_design→opt_gate` 配对映射（PH1P35MDG324, TD 6.2.168116, 9.660 ns）得到：baseline WNS/TNS -9.826/-285.434 ns、最差 path 19.422 ns/21 levels、1,338 Slice、1,375 LUT、31 regs、17 DSP；candidate -1.976/-35.152 ns、11.572 ns/13 levels、1,343 Slice、1,387 LUT、49 regs、17 DSP。改善为 WNS +7.850 ns，但残余 setup 为负且增加 5 Slice。由于实验卡要求无 area regression 才可升级，未跑 full-top Gate、Place/Route/Bitgen；模块数字不是整机收益，最新全设计 22,882 placed Slice 与 -7.560 ns Gate WNS 未变化。原始两臂日志和 timing/area 在实验目录 `td_module_gate/{baseline_min,candidate_min}/syn_1/`。
- 该实验支持“均值/目标锥可被早一拍分段”，但不达整机通过/升级门槛；不自动进行第二次 AWB 重写，也不把新 RTL 合入候选。下一包仍优先解决 85% 容量缺口：先用厂商支持的仿真器确认运动历史 PH1P ERAM 的真实读延迟/同址冲突/短帧提交语义；若宏语义不可确认，继续保持 inferred 存储结构，不用门级 Slice 估算替代硬件证据。

## 2026-10-20 本地启动器复测补充

- 本轮普通 `exec_command` 成功启动 PowerShell 7.6.5；Tang Dynasty v6.2.168116 也成功执行两个 Gate。一次 TD 脚本调用把 Windows `E:\...` 反斜杠路径交给 Tcl，触发转义后“couldn't read file”；改用 `E:/...` 正斜杠路径即恢复。这是本轮 TD 命令自身的路径传参问题。
- 之后读取到 Codex 沙箱本机原始日志：08:00 左右的 `setup refresh` 失败项是对受保护的 `E:\Projects\FPGA\.git` 写入 deny ACL 时 `READ_CONTROL | WRITE_DAC` 被拒绝（Win32 error 5），因此当时的 `helper_unknown_error` 有明确环境根因。10:00 后的刷新记录均为 `processed 4 write roots; errors=[]`，命令运行器已解析并启动；本轮 PowerShell 命令也持续成功。可见的 `C:\Users\Default` 属性设置拒绝发生在 runner 启动后，不是启动失败原因。当前启动器状态已恢复；未更改 `.git` ACL、未重启托管服务。若同一错误复发，应交由 Codex 沙箱 setup 层处理，不绕过仓库元数据的只读边界。

## 2026-10-20 R1 AWB 源码关联与优化方向判定

- R1 输入清单记录 AWB RTL SHA-256 `513ffda358f46b607a8f8f57c1afd1e570c381d99627e7ed8da5e2e7b03df82f`；隔离阈值编码器 Gate 基线归一化为 LF 后 SHA-256 `0baf5a3e6ad6ad335b903c584e228a2955083fbfa9378a23b08ad6c31fe063a3`。逐字节文本在统一换行符后完全相同，因此阈值编码器 A/B 对照确实使用了 R1 的 AWB RTL 逻辑；但其独立 wrapper/约束和 Gate 数据不是整机 Route 结果。
- R1 Route 最差路径是 AWB `mult0_syn_168.clk → O_gain_r_reg[4]_syn_2.ib`，17.190 ns、16 级、fanout 36，Setup WNS −7.791 ns。对照同 RTL 的 AWB 阈值编码器模块 Gate：WNS −9.826→−9.254 ns（仅 +0.572 ns，低于实验卡 1.0 ns 门槛），TNS −285.434→−288.404 ns，QoR `#slices` +6，area `#slice*` 不变，DSP 不变。该候选按预注册标准拒绝，不重跑、不晋升、不做整机验证。
- 已有早期均值分段的模块 Gate WNS −9.826→−1.976 ns，但仍未收敛，`#slice*` +5、寄存器 +18；其实验卡明确要求无 area regression 才考虑 full-top，因此不把这组模块收益外推到 R1，也不在本轮启动 full-top Gate/Place/Route。相关原始记录分别为 `work/g8_r1_v2_integration/docs/experiments/2026-10-20-industrial-v2-g8-awb-step-encoder.md` 与 `work/awb_early_stage_retime_20261020/EXPERIMENT.md`。
- 结论：AWB 是 R1 已证实的时序热点，但阈值编码器方向已否定；前置均值分段改善了局部时序、未达到晋级门槛。R1 的 85% Slice 预算仍差 1,716，不能靠 AWB 时序实验宣称容量问题已解决。本轮没有修改 RTL、重复仿真或启动 TD。
- 现场接管复核：TD PID 46300 仍存活且 `Responding=True`；观察期间内层 `flow_exec.log` 仍保持 18:32:46，CPU 有小幅累计变化，故只记录为“进程存在、近期没有可见报告更新”，不判断为完成或挂死，也不重启。Goal `industrial-v2-advanced` 保持 ACTIVE，G8 保持 BLOCKED。
- 下一包建议：先审计已批准的两行卡通缓存短帧向量中 baseline `X` 与 candidate 确定数据的契约含义；若无法证明该输出在短帧场景无效或不受观察，则拒绝推广。此步骤只需既有源码、向量及仿真记录；在问题关闭前不再做 TD，也不把该方向扩展成整机构建。

## 2026-10-20 两行卡通缓存短帧输出契约审计

- 绑定版本：R1 顶层实际 `video_cartoon.v` SHA-256 `9778bb06e7dddf0238fdc2e70260125c8508ae46dbb9bb92554a811a8fff4dc0`；既有 Gate 两行候选 `92AD10BE33BC438224F75DD3CADF623CD8D6E47128088BC50247C330AAF84A76`。固定向量 SHA-256 `04da37569ba4c3a9c6d3c9f11116b0cc398713c022038fde7fedeb63eeb6f04b`，既有四态 trace，不重跑。
- 输出周期 49 对应输入周期 44 的 `VS=1, DE=1, TOON=1`。解码 trace 后，基线与候选的 `O_VS/O_HS/O_DE/mode` 相同，其中 `O_DE=1, mode=2 (TOON)`；基线 RGB 为 `X`，候选 RGB 为 `24'h92246D`。因此差异不是由 `DE=0` 的消隐像素掩盖。
- R1 `video_cartoon.v` 将 `o_de=de_pipe[5]`，RGB 在 `de_pipe[4]` 时按 `mode_pipe[4]` 输出，不按 `VS` 屏蔽；`design_top_wrapper.v` 又将 `S_cartoon_out_de/data` 接到 `industrial_v2_display_tracking.I_de/I_rgb`。该活动像素进入后级视频链路，现有源码没有声明它为无效数据。
- 根因：`i_vs` 分支复位 `x/y/row_mod3`，但 `x0/y0` 每拍无条件捕获旧 `x/y`；三个行数组和 `q_top_row/q_mid_row` 不复位，也没有 history-valid 屏蔽。VS 与 DE 同拍时，记忆写读条件因 `!i_vs` 不执行，但旧 `y0` 仍可能选中上一短帧留下的 `q_mid_row`。旧三银行与两银行因此可能暴露不同的未初始化/陈旧历史值。`92AD` 的确定 RGB 不足以证明其与基线等价。
- 判定：输出不在当前接口层被屏蔽，不能将该周期定为“不可观察”；基线为 X 又使它不是一个可判定的定义值反例。因此仍是 **INCONCLUSIVE，不是等价 PASS**，两行候选不晋升；不重跑原向量、不启动 TD。
- 下一工作包建议：单独评估帧起始延迟坐标对齐（VS 时将 `x0/y0` 置零）的最小修复，在基线和 `92AD` 副本上应用同一变更；先用现有 W=1,H=2 向量及已有有效帧 trace 检查边界/同步/模式语义。该修复把当前活动像素的历史行依赖改成声明的边界复制行为，需作为独立行为修复记录，不得当作原有两行结构已等价。只有新候选通过定向 RTL 后，才重做一次模块 Gate；完整构建仍不在此卡内。

### 2026-10-20 R1 实际 VTC 输入域核对（修正上一条下一步建议）

- R1 实际综合副本 `work/td_g8_r1_motion_eram_seed1/user_source/hdl_source/design_top_wrapper.v` 与冻结输入 `fallback/td_source/design_top_wrapper.v` SHA-256 同为 `62f98ab9abacfb9921f734e6864905ea692b7d9aa235be82b6dd32aa861ba8eb`；实际副本 `vtc/uivtc.v` 与 `fallback/td_source/uivtc_guarded.v` SHA-256 同为 `32a3332d2d583465c83ba5363fae78d7e5b2ce119d5fdbe9a74a51ffe0de80b4`。该关联针对 R1 目录中的源码副本，不是对任何其它版本的推定。
- 该顶层把 VTC 配置为 `V_ActiveSize=720`、`V_SyncStart=725`、`V_SyncEnd=730`；实际 `uivtc.v` 的 DE 条件为 `vcnt<720`，VS 条件为 `vcnt>725 && vcnt<=730`。两者互斥；HDMI mixer 对 VS 与 DE 都经过相同的三级输出流水线，故真实 R1 固定栅格不会生成 `VS+DE` 同拍。既有 `tb_video_timing_contract.v` 检查 mixer 边带延迟，但没有直接断言 VS/DE 互斥；互斥结论来自上述实际 RTL 条件与参数。
- 因此，cycle 49 的差异由实验向量中的非生产域 `VS+DE` 同拍及短帧历史触发；它不能作为真实 R1 视频输入上的功能失败证据。与此同时，`EXPERIMENT.md` 明确把同拍语义列为模块级等价要求，不能事后删掉该要求或把现有结果改判 PASS。两行候选仍为 **INCONCLUSIVE / 未晋升**；此前建议的 `x0/y0` VS 修复没有生产域根因支持，本轮撤回，不改 RTL。
- 下一工作包建议：若要继续评估 92AD 两行候选，只新增一次固定生产栅格的 baseline/candidate RTL 对照，输入用实际 `uivtc` 参数和 mixer 同步延迟，覆盖完整 1280×720 帧及复位后首帧/稳定帧；精确对齐活动区像素、同步和模式。启动前另写短实验卡。目标仅回答候选在 R1 合法输入域是否等价；不重复旧向量、不重做既有模块 Gate、不启动整机 TD。若该对照不通过或基线关键像素仍为 X，则停止两行候选方向，保留既有 Gate 结果但不宣称其是整机收益。

## 2026-10-20 R1 EC26 PH1P ModelSim 语义闭合与 R3 AWB 架构卡

### R1：精确 EC26 语义回归

- 输入冻结：R1 完整 TD 输入清单 SHA-256 `731ff493ef607ed20909d4c72a60e28b85a21f76ac75c10015797096fedc5ed1`；实际 TD motion core `motion_diff_160.v` SHA-256 `EC26C54A253C7DDB3502E0AAB06486CB03E1EE39B23709C0A82C8F5ACCB0FE18`。不引用独立 Gate core `8467…` 或未恢复的 `58af…`。
- 仿真环境：ModelSim Intel FPGA Starter 2020.1；PH1P library 由 `modelsim.ini` SHA-256 `C56048DAA265361A0572E45B71BE901141BACBC7C3CCA1C95C56DF09114CD6CF` 映射。精确 EC26 源文件编译 0 error/0 warning。
- `tb_motion_diff_160_r1.v` SHA-256 `C00354ED269702F7B114F7977F29D1CBF778FD8BF14AF65078C24C155CD35EB4`，transcript `work/g8_r1_motion_transactional_20261020/modelsim_ec26_full_r1_20261020/motion_core.transcript` PASS、0 error/0 warning。覆盖 INVALID 首帧不建 baseline、短帧/坏帧 rollback 与同 ID retry、孤立输入/无 SOF、坐标错误、ID gap 刷新 baseline、partial-frame reset 后重建。
- `tb_motion_adapter_r1.v` SHA-256 `91E9F9BA086B5ED5E59C2CE6E743EBA194BE2BCA6A12044387960F0D9007A3E9`，`motion_adapter.transcript` PASS、0 error/0 warning，覆盖坏 tail 与同 ID retry。独立相邻 SOF 向量 `tb_motion_back_to_back_sof.v` SHA-256 `0D13FC5C721E4851A064C1E22D381A7D84B8D67190DB805ACBC36B18DCB30828` 的 `motion-ec26-ph1p-corrected.transcript` 亦 PASS、0 error/0 warning；其 core SHA 同为 EC26。
- 原始日志 SHA-256：`compile.transcript` `FF5BF98958661159CECB7CE429B1A62C53BDB73369E87821FCC1D08F6A3C3A7B`；`motion_core.transcript` `951EBFD6FB9AB2D02B331EEB1B6B57B592BD9D9C088F582F2CFE505486833F2B`；`motion_adapter.transcript` `C753D13E7B66DF4E05F62D9E6298E21A91CC8D84EA4C99B77EAFFD1FD988BE2D`；相邻 SOF transcript `80AD1CCB072776CD323659299D7E2944E2627686EF4F4EDBF9770CD934339156`。
- 相邻 SOF 首次加载原语模型时未解析 `PH1P_PHY_GSR`，失败 transcript 保留为 `motion-ec26-ph1p.transcript`（SHA-256 `32B6DD098C6418F7122C272E1285944B3A2C004E6674D2D788AFDAEB71B3EEC4`，2 errors/0 warnings）；修正调用显式加载 `ph1p_lib.PH1P_PHY_GSR` 后才得到上述通过记录，未把加载失败隐藏或算作仿真 PASS。
- 判定：R1 指定的 INVALID、rollback、相邻 SOF、frame gap 和 reset 在**精确 EC26 的 PH1P ModelSim 定向 RTL 范围闭合**；不等于整机或板级通过。最新完整 Route 仍为 19,749/21,216 Slice、Setup WNS −7.791 ns、121 个 setup 违例；该位流不晋升 release。

### 卡通两行方向：按新退出门终止

已批准的 W=1,H=2 向量在 cycle 49 出现 baseline RGB=`X`、92AD RGB=`24'h92246D`。虽然 VTC 审计指出该 VS+DE 事件不属于生产栅格，但本轮明定“逐周期分叉即终止”。因此终止 92AD 两行结构优化：不再追加 production-raster differential、不修补、不做模块 Gate 或 TD；历史 Gate/trace 保留但不晋级，七项功能和验收门不变。

### R3：固定帧均值递推候选实验卡（仅设计，尚未改 RTL）

| 卡项 | 内容 |
|---|---|
| 问题与支持证据 | 能否用逐 beat 的精确 quotient/remainder 递推取代固定 720p 三通道帧累加后的 reciprocal mean，并在线递推 target mean，从实际 AWB 跨 DSP 关键链中移除帧末算术？Route `final_timing.rpt` SHA-256 `2516ED7FDA692060504041BE56DF30E417A1552E76BE37F0DEC116619F6797D4`：17.190 ns、16 levels、fanout 36、Setup WNS −7.791 ns；映射路径从 fixed mean (`awb_frame_gain_controller.v:54`) 经均值合并/`×683` target average (`:65`) 到步进阈值及增益输出 (`:101`, `:246-275`)。固定统计已有两级 pending 节拍 (`frame_stats_96.v:140-162`)。精确输入 controller SHA `513FFDA358F46B607A8F8F57C1AFD1E570C381D99627E7ED8DA5E2E7B03DF82F`、frame stats SHA `751729F0E6337DBD9AF9A0696A69BEAC1568B687F592131A06C3E29C8541B09E`；顶层 RGB sum 目前只馈入 AWB。
| 唯一变更与假设 | 只替换固定 1280×720 统计表示：每通道维护 `S=Q×921600+R`、`0≤R<921600`；每拍通道和 `B≤1020`，对 `U=R+B` 做至多一次商递增/减常数。目标均值维护 `Q_R+Q_G+Q_B=3×T+R_T`、`0≤R_T<3`，用每通道商递增数递推 `T,R_T`。帧末将三个均值及 target 放入既有两级 pending；原 sum 输出保留供模块兼容，但整机 AWB 改接新增均值端口，TD Gate 必须证明未使用的旧 sum 路径被裁剪。预期减少帧末 DSP 串链及统计存储；是否改善 Slice/每拍时序未知。
| 固定输入/对照 | 对照固定为上述两个 R1 实际源码 SHA、同一 `design_top_wrapper`、PH1P35MDG324、Tang Dynasty 6.2.168116、9.660 ns 时钟及相同文件顺序/设置；候选只替换固定帧统计表示和必要 mean 连线。不得混入其他 AWB、motion、DDR、时钟或 seed 变化。
| 必须保持 | 完整合法帧结果严格等于 `floor(sum/921600)` 与 `floor((mean_r+mean_g+mean_b)/3)`；首/末拍 carry、SOF 同拍首 beat、复位、无 SOF、短/坏帧 invalid、frame ID、`O_stats_valid` 和 gain update 沿不变。same-edge SOF 仍锁存 pre-edge gain，下一接受 SOF 使用新 gain；不假设帧间空拍。luma/场景保护、增益舍入饱和、green gain、视频吞吐保持。
| 逐级验证与退出门 | 先数学不变量/软件 oracle；再 Icarus 定向 full-frame、末拍 carry、黑/白/通道极值、无空拍连续帧、SOF 同拍、invalid/reset，并对比现有 Golden；通过才跑一次匹配的 frame-stats+AWB TD Gate A/B。Gate 必须证明旧 sum 逻辑被裁剪、Slice 不增、DSP 下降、WNS 至少改善 1.0 ns 且 TNS 不变差。任何已定义输出不等、更新沿变化或任一 Gate 条件失败即回退停止，不搜 seed。
| 成本/上限 | 最多软件 oracle → 一组定向 RTL 回归 → 一组匹配模块 Gate A/B；本卡不含完整工程 TD。只有 Gate 显示实际面积和时序收益，且对 19,749→18,033 Slice 缺口有可量化贡献，才另开完整构建卡。第二次模块实验仅在首次结果给出明确修正依据时考虑；失败不晋级位流。 |

设计核验边界：`R<921600` 且 `B≤1020`，故 `R+B<2×921600`，每拍至多一次商递增；此为数学推导，不是已验证 RTL。候选旨在处理跨 DSP 时序链及统计存储，不能先验宣称单独补足 1,716 Slice。

实现约束补充：target recurrence 需逐拍计算 `V=R_T+c_R+c_G+c_B`、`T'=T+floor(V/3)`、`R_T'=V mod 3`。为保持 `I_mean_luma` 和 scene protection，另保留一个 32-bit RGB-total accumulator，并沿用现有 luma normalization；模块旧 `O_sum_*` 兼容输出暂保留，但整机 AWB 不再消费，须由 Gate 证实未使用累加路径被裁剪。

软件 oracle 首级结果：Python 3.13.7，divisor=921600、230400 beats/frame、seed `0xEC26`；模型 `work/g8_r1_v2_integration/work/awb_qr_recurrence_oracle_20261020.py` SHA-256 `FEC436E058C1A775CA28A32CB619DBDADE36B75BDDBAAD5B9B85E81F6D037AF7`。全黑、全白、R 通道仅末拍越过商界、混合极值、固定种子随机 4-pixel RGB channel-sum 五种完整帧，共 1,152,000 beat transitions；每拍均断言 `Q_R+Q_G+Q_B=3T+R_T`，帧末 channel means、target、remainders 和 32-bit RGB-total 均与整数除法/直接总和 oracle 完全一致。该步 PASS 仅覆盖数学模型，不证明 RTL 周期、端口、资源或时序；下一门仍是定向 RTL。

