# V2 候选与失败构建版本差异根因分析

日期：2026-10-20
范围：只读核对旧打包候选与 2026-10-20 失败构建的清单、源码、项目文件、约束、IP、顶层连线和保留报告。本轮未改 RTL、约束、IP 或旧位流；未运行仿真、测试或 TD。

## 结论

17,125 与 22,882 的差值是 **5,757 Slice，但不是同阶段的可归因差值**：旧数来自最终 Route QoR，失败版数来自 Placement 失败报告。失败版 Gate 估算为 23,228；它比旧 Route 数高 6,103，而当前 Gate 到失败 Placement 的计数又下降 346。旧版没有保留同阶段 Gate 面积层级报告，也没有保留实际生成的 82 引用 PRJ 和准确启动命令，因此不能把 5,757 按功能或模块分摊。

能确认的是：两版的 PH1P35 目标、TD 可执行文件、基础 IP、约束和两份 run settings 哈希一致；旧构建脚本重建出的 82 个 PRJ 引用与失败版实际 82 个引用完全相同。按有效 user_source 树配对后有 11 个 RTL 文件内容变化、208 个文件内容相同。最新版本确实新增了 **V2 帧统计增益接入 ISP 像素链**：旧 ISP 没有增益输入，最新顶层把帧级控制器输出连入 ISP。运动历史 RAM 与三行 cartoon RAM 都已存在于旧候选，不能把其存储量整体算作新功能。

最高可验证的资源机会仍是运动历史 ERAM：现有全顶 Gate-only 单变量证据显示 Slice 估算 23,228→20,183、DRAM LUT 4,240→1,840，代价为 ERAM +16；但该结果没有 Place/Route，仍高于 18,033 的 85% Slice 预算 2,150。更关键的是，这条实验尚未与 Golden Model 等价：异常帧会改写部分历史 RAM，而 Golden 保留上一张完整历史。这个缺口在旧版 RTL 已存在，必须先定下并实现一致语义，不能先把它带进 ERAM。

## 1. 版本身份与证据完整性

| 项目 | 旧打包 V2 候选 | 最新失败版本 |
|---|---|---|
| 身份 | release 状态 CANDIDATE_ONLY；构建提交 98801ed381934ba665573fd6c15026c18c33a289 | V2 worktree HEAD 3314966f675473039e804e8515f9844c4ba287c3；记录有 140 个 dirty entries |
| 清单 | release/industrial-v2/manifest.json；SHA-256 00a323c1a0c379bb6a574ab436db5bcd9be956030414a2a2bc137f98ca4760c3 | work/td_g8_motion_inferred_a_seed1/input-manifest.json；SHA-256 9e4af0df1eb1839089509f8419d9abb88a827498f459fdcc67f6412ead21bdf4 |
| 源码清单 | source/source-manifest.json 有 249 项，SHA-256 766b816172184aabccaedc3698e23220fce3fdefca36e9ea8e62733da3b9a9d1；快照提交 22bb6980c5bbe025239de05ad50223b5f8bc1200，与构建提交不同 | 侧车清单记录 219 个 user_source 文件、82 个 PRJ 引用，user_source tree SHA-256 c0da01faebd81b146396f19c64df4f1cb06878f4d0a56581c74fc9445aa66951 |
| 结果 | 位流 1,370,289 bytes，SHA-256 d6e6a7e12ef7558834904dcc8d2783d5fda827b7fe11c6e407b0119fc3ce1c0d；Route 17,125 Slice，Setup/Hold WNS +104/+20 ps | Gate 23,228 Slice 估算、WNS/TNS −7.560/−366.675 ns；Placement 22,882/21,216 Slice 后以 PHY-9053 失败；没有 Route QoR 或位流 |

旧位流的 SHA 与 release/candidates/industrial-v2-seed1-current 中的同尺寸副本一致；两者均为 d6e6a7e1…，未触碰任何副本。旧 README 仍将该包标为 CANDIDATE_ONLY，硬件验证为 HARDWARE_NOT_RUN。

旧包有可用的 package manifest、源码快照和旧版 build_industrial_td.py。manifest 记录 TD 6.2.168116、工具 SHA-256 e2e04ada5e256dccd017240c0f4dcface7f96dca67cde0e56e606ac0e02f827a、DefaultFlow SHA-256 d1a5d4291706dac224cc33008d8945e79ed2eb1adf8ce86cca46be564975bade，以及旧输入包内四个基础 run 文件的哈希。额外核验发现 provenance.sources 的 30 个源文件哈希全部匹配归档 source-manifest，但其中 14 个与 build commit 98801ed 和 snapshot commit 22bb698 两个 Git tree 都不匹配；因此这两个 commit 不能单独作为旧位流源码身份。逐文件归档哈希是更直接的源码证据。manifest **没有**保留旧构建生成后的 PRJ 哈希和精确 TD 启动命令；provenance.project 字段还误写为 V1 文案。故旧构建输入可以依据归档文件哈希和旧脚本高置信重建，不能称为完整的逐次启动清单。

失败版的 237 项 input-manifest 是保留侧车；其 SHA-256 为 9e4af0df1eb1839089509f8419d9abb88a827498f459fdcc67f6412ead21bdf4。另有 228 项 full_run_input_manifest.json，SHA-256 70e629335bd65d01286309f91606f5a3f5bf98799f747955b737400ee13619cc，inventory SHA-256 287dec59bc2930377c6b192a6dc675719ddbf0a0bb589b00f572e0ae8beaa3d6；它明确标为从失败快照事后重建，original_manifest_present=false，准确的外层 Python 命令未保留。数量差异是 228 项重建清单不含 10 个 td_project/al_ip 辅助文件、但多记录 1 个构建脚本，工具路径也用了不同标签；两份清单不能合并成一份“原始启动清单”。当前 Gate/Place 原始日志、area 和 timing 报告仍在失败目录。

## 2. 输入差异矩阵

| 维度 | 核对结果 | 归因意义 |
|---|---|---|
| 器件、顶层、工具 | 两版均为 PH1P35MDG324、speed 3、design_top_wrapper、TD 6.2.168116；TD 可执行 SHA 相同 | 未发现器件或工具版本变化 |
| 默认约束与设置 | pin.adc SHA aee8f1cb88042db5155a24a9698766e8f85c0ae916bd6ba9691245799184f2ae；SDC SHA 390dfe5fa12669afc5e8db01e893300132605ffb6bfb962ec40da5be022b068f；syn/phy settings SHA 0edb3a700629ede8b9f436782036851e07146991899bd2533622ee221e70c149 / 082f4f12f328456316e9d4452a85aa12034bd92651c839929ab9afe0214edce8，逐项完全相同 | 不能用约束或基础 run setting 变化解释增长 |
| IP | user_source/ip_source 53 项全部同路径同 SHA；td_project/al_ip 辅助项 10 项也全部同 SHA | 未发现 IP 源码或 IP 参数差异 |
| PRJ 引用 | 旧包基础 PRJ 有 71 项；旧 build 提交中的脚本追加 11 项 V2 文件。重建后的 82 项引用与最新实际 82 项路径集合完全相同 | 没有“最新版多编进 11 个模块”的证据；两版编译模块集合一致 |
| PRJ 哈希 | 旧基础 syn/phy PRJ 为 3c49931700e21cf01e1fcb92fd38b11dfc5bac0c56c936e468695ad078d43add / ab86457335328f6bf86de0b91e75ce27a0c877a0b38b60b0eab7ca3bdb1e70b7；最新生成 PRJ 为 7e41f2b65deaee47d5a21b7b259d1e06070c2bbb6ecefed1659a6c30d507a30f / aa7502b01565c13f4f271902134af6e63169195c1c05b4a543b3fce939e87c59 | 最新 PRJ 与旧基础 PRJ 不同是预期的 11 个 V2 引用追加结果；旧生成版完整 PRJ 未归档，不能逐字节比对 |
| 生效 RTL 树 | 从旧 249 项源清单及旧构建脚本的覆盖规则重建后，与最新 219 项 user_source 配对：11 项内容不同，208 项相同。旧清单另有一个未被 PRJ 引用的 video_cartoon_luma.v 来源项 | 这是版本间明确的 RTL 差异边界；不是 11 个全新模块 |
| 显式宏 | PRJ/settings 未发现用户显式 define；latest motion 的 ERAM 参数默认关闭，Gate 层级显示该模块仍映射为 DRAM LUT、ERAM=0。外层原始启动命令缺失，不能证明未记录的环境宏 | 不能把“源码含 ERAM 分支”当成失败版已启用 ERAM |
| Flow | 旧 DefaultFlow SHA d1a5d4291706dac224cc33008d8945e79ed2eb1adf8ce86cca46be564975bade；最新 industrial_v2_fixed_seed.tcl SHA 1f07f9a70f7f2d328d2193eba84fa261bd81c9762dfb71ee307102de763f325b。对比显示两者主体相同，最新只多 set_param place seed 1 两行。旧 manifest 声明 seed=1，但实际如何传入旧运行未保留 | 放置种子作用方式仍是一个复现缺口；会影响布局结果，不解释 RTL Gate 的全部增长 |
| 顶层功能参数 | 旧 feature_spine 未显式设置静态校准和固定像素数参数；最新设 USE_STATIC_CAL_CONFIG=1、USE_FIXED_AWB_PIXEL_COUNT=1、固定计数 921600，并增加结果帧 tag 输入。两版均将 I_arm、I_external_fault、I_clear_fault 绑 0；视频有效输入均绑 0 | 最新存在功能/控制行为变化；分拣脉冲仍被禁用，视频延迟观察链仍无有效输入 |

### 11 个内容不同的有效 RTL 文件

SHA 均为完整文件 SHA-256；路径为生成工程中的 user_source 相对路径。旧/新值来自旧包快照与失败版输入侧车，未从当前源码 HEAD 猜测。

| 文件 | 旧 SHA-256 | 新 SHA-256 |
|---|---|---|
| awb_frame_gain_controller.v | f4e5420a7492b3af9616a92485b92abbaf4b0bb6650c901a716f5a3563204dd6 | 0baf5a3e6ad6ad335b903c584e228a2955083fbfa9378a23b08ad6c31fe063a3 |
| design_top_wrapper.v | 26606cea60d96e7ca8bc36171d0b78f770af45a6d4e2bcf975e0f61fb629b769 | 3c58faf97194bb0d789b2afe2e5e9729981c01a311af46a967961a267b0a11ff |
| dimension_calibrator.v | ea368a3549f6589f4c2f389059f6c914553123d7d4af557c309b0756d71a4978 | 0a38f04aaa96730d25e2a25c25d4c7570c70b9d3d323e3df78e7d42bf655b474 |
| frame_stats_96.v | 03f7eb9c9c975e84dfaebec48936401541aa5f757359ef77401e052f06b86d43 | a40e26b76e95fceb80b8bdbe51fc95fbc446aaaef255de93432ebb59bb38352e |
| frame_tag_monitor.v | ea76b52d773920a4ab6fcef6e33f98d3a8c10639a772759cbe801c871d4c5310 | be728c1a7181b8b142032b7849d89ab73332d149d38566a9a75783f49d1ae182 |
| industrial_osd_overlay.v | cd4201a77bbf18b9ddc3f3b0d840f39a1907fb59cea8c273d6e8c5f5983aec73 | 233482a5ca46213fbc3b4d37c594ca0337e49cb1a77e5b94ef1493cdb75e6ac5 |
| industrial_v2_feature_spine.v | d12bb372581ea0037ec8c7ce2082540dc5ce7157ee8e15c7b178ad91e8cd7079 | 96aaf9c4a82a6d22b9fa057d5580c4df415036d989de5e8bdc196f465e0ee199 |
| industrial_v2_result_cdc.v | acd09e7979d9b4773f1c36935ae5b4c89d0b98568bf0c3cd0d947930dbbfd9fd | b0f50c0798b57a348e290e5d9b07e1cd11dc2059d4600aad238a1f74894c1dbb |
| isp/isp_top.v | e1bf575458d2fba86572f077f9e104104619aaea015896fc9ad88aadd8e29f9a | 1975559f2d4aba92775e9359f90e5230f3ce2ac9bc46d39c22a397fd84cb3a08 |
| latency_monitor.v | 2c1ba20f4dad851bf9cb1143a90201a273546131f02778a835a20f7dfb37ce47 | 422be06e451579e582cb16f802fe939ac169b4d95972aa234ec5030a4ebfa9a4 |
| motion_diff_160.v | 38944cccb0be89dfbeaf5ab0cad21ef9f53752a32a455631c160b2ab5a1015e2 | f3f880cb5265fb1309dcab5a9d686dbbed766fa4250b4e24e936f4c089f66976 |

另两项旧构建复制时有历史文件名覆盖：uivtc_guarded.v → vtc/uivtc.v，hdmi_mixer_guarded.v → hdmi_mixer.v。两者与失败版目标文件 SHA 相同，是路径/命名覆盖，不是内容变化。

## 3. 5,757 Slice 的来源分类

| 类别 | 可以确认的内容 | 不能声称的内容 |
|---|---|---|
| 新增或加强的行为 | 最新 ISP 新增三路 AWB gain 输入；top 将 feature_spine 的 v2_gain_r/g/b 连到 ISP 像素校正级。frame_stats 增加固定 921,600 像素路径及 pending 统计阶段；frame_tag_monitor 增加结果 ID 队列；top 增加复位释放同步器；OSD 输入扩展到处理/运动/计数遥测；校准可由参数静态配置 | 缺少逐项 A/B 面积，不能断言这些共贡献了多少 Slice |
| 原有功能与存储 | 旧版已有 motion_grid_adapter_96、motion_diff_160、frame_stats、AWB controller、cartoon region fill 等源/实例。运动历史仍是 160×120×8=153,600 bit；三行 cartoon 缓存仍是 3×1280×24=92,160 bit，核心 cartoon 文件 SHA 完全相同 | 不能把 2,400 DRAM LUT 的最新运动历史映射全部算成新加 RAM；没有旧版 Gate hierarchy 证明旧版实际映射数量 |
| 综合/布局映射与报告阶段 | 旧值是 Route 最终报告；新值是 Gate estimate 或未完成 Placement。新 Gate 23,228 对旧 Route 17,125 是 +6,103；新 Place 相对本轮 Gate 估算减少 346 | 5,757 不是同一阶段、同一报告字段的纯 RTL 增量；不能把全部差值称为“真实新增逻辑”或“布局开销” |
| 未解释 | 11 个 RTL 文件多处同时变化；没有旧 Gate area/timing/hierarchy、旧生成 PRJ 哈希和准确启动命令；Flow seed 的旧应用方式未留档 | 当前证据不足以按功能分摊 5,757，也无法从最终 Route 单点反推出旧综合映射 |

因此当前能给出的根因等级是：**输入环境大体锁定；功能改动边界可列明；面积增长主因尚未完成因果分解。** 最强的功能级增长假设是新闭环 AWB 像素增益和相关流水线/统计逻辑，但这是代码路径推断，没有同阶段 A/B Slice 报告作证。

## 4. 旧候选七项能力核对

旧 README 将七项功能的软件、RTL、TD 标为 PASS，硬件均为 NOT_RUN。下面按旧快照的实际顶层连线核对，不能把 README 标签当作硬件或可观察效果验收。

| README 功能 | 旧包的源/顶层证据 | 严格状态 |
|---|---|---|
| OSD、按键、基础质量 | mode_controller、工业 OSD、显示链在顶层；显示模式和检测/判定结果接入 OSD | RTL/TD 候选有路径；没有本位流上板验收 |
| 动态跟踪 | temporal_tracker、trajectory_history、tracking_overlay、V2 display/result 模块已在源和 PRJ 引用中 | 跟踪数据链存在；视频相关输入 I_video_valid 绑 0，轨迹/视频关联与实时显示不能据此宣称已验证 |
| 延迟测量 | latency_monitor 已实例化 | 顶层 I_video_valid 绑 0，相关结果未形成可验证的实时端到端测量 |
| ROI 帧差 | motion_grid_adapter_96 与 motion_diff_160 已实例化并接收 ISP 后 AWB 像素流 | 能力代码已存在；历史提交遇异常帧会破坏 Golden 所要求的上一完整基线 |
| 分拣控制 | sort_event_controller、安全互锁与脉冲生成器在 V2 spine 中 | I_arm、故障和清除输入绑 0；实际执行脉冲被禁用，不能算已验收执行器 |
| 自适应白平衡 | 旧 ISP 本身有 AWB 处理；V2 frame_stats 与 awb_frame_gain_controller 也已实例化 | 旧 ISP 没有增益输入，V2 控制器输出未接回像素链。最新版本首次建立这条闭环；这是 7 项中能直接确认的新增有效功能 |
| 标定与形状验证 | dimension_calibrator 与结果控制链在顶层；旧 top 以常量标定值和常高 calibration_valid 驱动 | 固定参数下的 RTL 路径存在；不是板级标定，也没有实测尺度证据 |

旧候选确实是含七类功能代码的 V2 包，但其中若干能力为遥测/固定参数/禁用执行状态。最新版本增加某些闭环或可观察量，并不自动意味着七项都已通过最终验收。

## 5. 运动历史 ERAM 与 Golden 语义门

最新全顶 Gate 层级中，u_motion_diff_160 的历史数组占 2,400 DRAM LUT、ERAM=0。单变量 Gate-only 证据在同一 219 源文件快照上只把现有实例 USE_PH1P_HISTORY_ERAM 设为 1，结果为：

| 指标 | 失败版基线 | ERAM 参数候选 | 变化 |
|---|---:|---:|---:|
| Gate Slice 估算 | 23,228 | 20,183 | −3,045 |
| DRAM LUT | 4,240 | 1,840 | −2,400 |
| ERAM | 43 | 59 | +16 |
| DSP | 40 | 40 | 0 |
| Setup WNS / TNS | −7.560 / −366.675 ns | −7.231 / −207.148 ns | WNS +0.329 ns |

这是目前最大且有全顶 Gate 数字的资源机会，不是完整验收。候选没有 Place、Route 或 bitgen；Gate 估算仍比 85% Slice 预算 18,033 高 2,150。候选路径仍被 AWB 关键路径限制。

异常帧不一致早于这次 ERAM 分支：旧版和最新 motion_diff 都是在帧进行中直接写 history_mem，帧尾只在完整有效时提交 have_history/last_frame_id。短帧的部分写入不会回滚；下一次同 ID 完整帧可能与混合历史比较。Golden 的 process_frame 在输入帧无效时直接返回，不更新 _history；test_invalid_frame_does_not_destroy_previous_history 明确要求保留上一张完整历史。故这不是 ERAM 才出现的问题，而是旧候选已有的 RTL/Golden 契约缺口。

已有 ERAM edge-case A/B 仅比较 USE_PH1P_HISTORY_ERAM=0/1，并以 MOTION_ERAM_SIMULATION 将两边都替换成行为数组；其用例把“短帧写入保留、只不提交 ID”当作期望语义，没有同 Golden 对照。PH1P 真实 ERAM 仿真模型当前又因加密 pragma 无法在 Icarus 编译，真实宏的读延迟、同址碰撞、复位与未初始化行为仍未知。不能用该 A/B PASS 关闭 Golden 门。

保持当前 Golden 契约的直接实现方向是：先把输入帧写入影子历史，完整帧才原子交换历史 bank；不完整帧丢弃影子 bank。代价上限是额外承载一整张 153,600 bit 历史，实际 ERAM/LUT 映射尚未知。若改为无效帧后清除 baseline，资源会轻，但这是对现有 Golden 行为的改变，须先获得明确的功能契约决定并同步参考模型；不可为过 ERAM 或资源目标而悄悄改变。

## 6. AWB −7.560 ns 路径与等价优化方向

失败版 Gate 最差路径为 u_awb_frame_gain_controller/mult12_syn_168.clk → O_gain_b_reg[0].d：周期 9.660 ns，数据延迟 17.152 ns，cell 9.531 ns、net 7.621 ns、18 级逻辑、最大 fanout 46。路径从固定帧均值乘法经颜色均值/目标和 gain 平滑逻辑到输出增益寄存器。ERAM-only 候选仍由同一 AWB 算术域给出 −7.231 ns，说明 RAM 映射不是该时序失败的根因。

已有的 AWB module-only early-stage probe 使用 frame_stats_96.fixed_mean_pending 提前一拍寄存精确通道均值/目标，并保持增益发布周期。其模块 Gate WNS 从 −9.826 改到 −1.976 ns（+7.850 ns），最长逻辑由 21 级降为 13 级；代价 +5 Slice、+12 LUT、+18 FF，DSP 不变。Icarus/Golden 定向结果记录了无效帧、ID、reset、无帧间隔、同边沿 SOF 取旧增益/下一 SOF 取新增益。它仍是隔离模块 probe，不是最新整机的 Gate/Place 结果，且 WNS 仍为负。

后续 AWB 单变量候选应针对剩余的 gain ratio/smoothing 反馈链：利用现有 fixed_mean_pending 侧带提前取得操作数；对三色并行做位宽明确的常数乘/倒数和舍入，寄存均值与中间乘积，再完成平滑、限幅和写回。所有有效位、帧 ID、无效状态必须随流水级同行。验收要求输出增益提交周期不变、每拍仍可接事件，当前帧 SOF 与统计更新同边沿仍取旧值、下一 SOF 取新值，并逐位保持 Q 格式、舍入、截断、饱和和错误处理。若必须假设帧间空闲，或提交周期变化导致跨帧增益行为不同，则此结构不算帧级等价。不要用除法替代乘法作盲试：已有 /3600 试验增加 LUT、减少 DSP 但把整机 Gate WNS 恶化到 −14.241 ns，且 DSP 超预算。

## 7. 下一项最值得执行的单变量实验

**先做 history 原子提交语义实验，不运行 TD。** 只改 motion_diff_160 的历史提交策略，Golden 保持为现有契约；让未完整帧写入影子 bank，只有完整有效帧才交换 active bank。通过定向 RTL 对 Golden 验证短帧后同 ID 完整帧、缺 SOF、帧间 ID gap、部分帧复位、首个完整帧建基线和静态后续帧。失败即停止，不启用 ERAM。这个实验的目标是关闭功能不一致，不宣称有资源收益。

该语义实验通过后，再将这一份功能等价的 RTL 冻结，只改变 USE_PH1P_HISTORY_ERAM 选择，做独立 Gate-only 映射 A/B；检查 ERAM 实例结构和端口行为，资源至少先达到 18,033 Slice ceiling、并满足既有 G8 条件，才进入新的完整 TD。预计 ERAM 可回收的 3,045 Gate Slice 已有证据，但不足以单独满足预算，因此此时仍不应启动完整 TD。

AWB 另立单变量工作流；先在模块级把残余 gain 反馈路径拆开并保持提交边沿，输出逐位等价证据和模块 Gate 数字，再评估是否值得做整机 Gate。不要把 AWB 与 ERAM 改动合并到同一次实验。

## 8. 依据文件

- 旧包身份、构建输入和位流：E:/Projects/FPGA-v2/release/industrial-v2/manifest.json、source/source-manifest.json、README.md、route.qor、final_timing.rpt。
- 失败版输入和结果：E:/Projects/FPGA-v2/work/td_g8_motion_inferred_a_seed1/input-manifest.json，以及同目录 td_project/camera_to_dsi_display_Runs/syn_1 的 Gate area/timing 和 phy_1 placement log。
- 失败版事后重建清单：E:/Projects/FPGA/work/codex_motion_context_tdmap_20261020/full_run_input_manifest.json。
- ERAM 全顶 Gate-only A/B：E:/Projects/FPGA/work/codex_motion_context_tdmap_20261020/candidate_evidence.json。
- 异常帧与 Golden 证据：E:/Projects/FPGA-v2/work/td_g8_motion_inferred_a_seed1/user_source/hdl_source/motion_diff_160.v、E:/Projects/FPGA-v2/work/models/v2/motion_reference.py、E:/Projects/FPGA-v2/work/tests/test_v2_motion.py、E:/Projects/FPGA/work/codex_motion_eram_edgecases_20261020/experiment.md。
- AWB probe：E:/Projects/FPGA/work/awb_early_stage_retime_20261020/experiment.md。

本轮新增本分析报告，并在已有 dirty 的 STATUS.md 与 known-gaps.md 中仅追加本次 V2 摘要和 OPEN 缺口，没有覆盖其原有改动。未改动 V2 worktree、旧位流或失败构建目录。
