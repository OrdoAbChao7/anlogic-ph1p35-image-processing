# PH1P35 最小 INT8 核心与存储器器件实验

结论（project）：9 路 INT8 点积、INT32 bias、定点右移和饱和链通过 Python Golden 对照；PH1P35 真实综合确认朴素 9 路乘法使用 9 DSP，原共享乘数双打包使用 1 DSP，1024×32 同步 RAM 使用 2 ERAM20K。只有 core9 与寄存器包裹 RAM 的本次已分析路径在 100 MHz 下无 setup/hold 违例；双打包探针仍有输出 IO 路径 setup 失败。不能写成完整加速器 100 MHz、16 MAC 阵列通过或网络可上板。

本轮按用户明确授权执行隔离 Golden→RTL 仿真→小规模 TD 综合/布局布线；没有正式视频集成、bitgen 或板级测试。G1/G2、模型 INT8 全网量化及 VISUAL_APPROVED 门禁未由此关闭。

## 文件、接口与算术

- int8_core.v：新写的独立纯 Verilog 9 路 signed INT8 乘法、19 位精确求和、33 位 bias 相加、固定算术右移 8 和 [-128,127] 饱和。core_probe 仅用移位装载限制物理 IO 数，不能代替阵列访存调度。
- 接受输入条件为上升沿 !rst && ce && in_valid。流水线共四个 enabled 上升沿；输入采样计第一沿，第四沿后输出有效。无停顿启动间隔 1 拍、每拍 9 个乘积。CE=0 时数据与 valid 一起保持；消费者只在 ce && out_valid 时接受，不能把停顿保持的 valid 计成重复事务。同步高有效 rst 优先于 ce，冲刷全部流水线及输出。
- bias 与输入事务同行延迟，取 signed INT32 完整范围，扩展到 33 位再相加。右移为数学 floor，非 nearest 或 toward-zero。这是局部算术契约，尚不是模型 per-channel scale/zero-point 方案，也没有跨输入通道的部分和累加。
- golden_sim.py：固定 seed 20261013；vectors.json、vectors.txt 与 tb.v 为可复现刺激及期望。
- cal_mul_int8_x2*.v：adamgallas/fpga_accelerator_yolov3tiny commit 6ba312bd220e67a987d3417bacd030db30b15770 原样拷贝，Apache-2.0 与 NOTICE 随附。其无 reset/valid；打包是 a×c 与 b×c 共享 c，不能等同任意两路独立 MAC。先前 19 位候选树的溢出结论用于本次宽度设计，未复制原树。
- ram_probe：单时钟、独立读写地址、1024×32、同步读，无 RAM 清零或初始化。只做推断和时序探针，未验收碰撞语义、bank 仲裁或完整 tile 存活期。
- probe_wrappers.v：给双打包和 RAM 加输入/输出寄存器的第二配置，延迟不同，仅用于判断 IO 对结果的影响。

## 仿真结果

simulation.log：PASS 1200 周期，908 次 valid 或保持有效数据对照。覆盖连续输入、随机 invalid bubbles、CE 停顿、复位冲刷、INT8 全幅、INT32 bias 两端，以及用 bias 抵消全幅点积后检查零点和饱和邻界，防止饱和掩盖加法树溢出。输出逐周期对 Python 任意精度整数 Golden 检查；没有 post-route 仿真。

首轮测试平台因 Python 字符串转义产生 Verilog 格式串语法错误，证据 simulation_first_failure.log；修正为 raw 字符串后通过，未放宽断言。

## TD 实际结果

工具 Tang Dynasty V6.2.168116（6.2.1），器件 PH1P35MDG324，speed 3。每项均有 Read Design、Optimize RTL/Gate、Place、Route 完成标记。下表来自 td/<配置>/phy/route.qor，ns 由原始 ps 除 1000；资源为布线后报告。

| 配置 | DSP | Slice | ERAM20K | Setup WNS ns | Setup TNS ns | Hold WNS ns | STA coverage |
|---|---:|---:|---:|---:|---:|---:|---:|
| core9 | 9 | 217 | 0 | +0.355 | 0 | +0.026 | 95.83% |
| packed2 | 1 | 31 | 0 | -3.000 | -22.532 | +0.044 | 96.57% |
| ram1024x32 | 0 | 0 | 2 | -2.549 | -27.178 | +3.741 | 35.77% |
| packed2_registered | 1 | 61 | 0 | -1.046 | -4.439 | +0.054 | 97.19% |
| ram1024x32_registered | 0 | 16 | 2 | +0.778 | 0 | +0.312 | 48.14% |

各项 Hold TNS 均为 0。结构化结果及全部告警在 summary.json；原始 syn/console.log、probe_gate.area、phy/console.log、probe_phy.area、probe_pr.timing、final_timing.rpt、route.qor 均保留。

资源解释（project）：core9 证明 9 个普通 signed 8×8 乘法映射 9 DSP，不是 16 路实测。packed2 的 SYN-2601 和 area 报告证明这一个共享乘数打包映射 1 DSP，不能承诺带 CE/reset、部分和累加的 16-MAC 完整核只需 8 DSP。RAM 报告 Inferred 1 RAM、最终 2 ERAM20K；4096 B 数据占两块物理 RAM。按 20,480 bit/块计容量利用率为 80%（inferred 容量比），不代表多 bank tile 效率。端口模式、跨通道部分和 banking、双缓冲和读写冲突仍需验证。

## 约束与告警边界

clock.sdc 建立 10 ns 时钟，所有非时钟输入 min 0.5 ns/max 2 ns，输出 min 0.5 ns/max 2 ns。没有 false path 或 multicycle。IO 延迟是探针实验条件，非板级契约；没有套用摄像头、DDR、PLL 或视频管脚。

全部配置 SYN-6021 报告没有用户指定 IO 位置。保留此告警：仅允许器件可行性评估，不能据自动分配位置上板或 bitgen。PRJ-5611 来自相同 CompileOrder；模块已正常解析/elaborate，属于探针元数据重复告警。未屏蔽告警。

STA coverage 未达 100%，尤其 RAM 35.77%/48.14% 未覆盖部分未细分归因，属于未关闭的约束/宏单元覆盖审计缺口，不能声明完整时序验收。core9 最差路径为输出寄存器至 q[0]；packed2 为 DSP/校正路径至 ac[14]；包裹后仍为寄存器至 ac[14]；RAM 原版为 ERAM 至 q[17]，包裹后为寄存器至 q[23]。WNS 包含自动 IO 放置影响，不能直接推导集成阵列 Fmax。后续需在真实内部端点阵列封装上审计覆盖与最差路径。

最初 Tcl 反斜杠路径解释失败，随后紧凑 PRJ 格式不被 TD 专用读取器接受；first_path_failure.log、first_project_failure.log 和时间戳 TD 日志保留。最终用正斜杠 Tcl 路径、逐行 PRJ 格式通过。TD 失败也可能返回 0，入口同时要求对应阶段完成标记。

## 复现和后续入口

从仓库根执行：

~~~powershell
& work/y1_yolo/.venv/Scripts/python.exe work/g5_board_feasibility/core/golden_sim.py
& work/y1_yolo/.venv/Scripts/python.exe work/g5_board_feasibility/core/build_td.py
~~~

第二行仅构建本目录五个微型工程；可追加配置名选择单项。依赖本地 TD/许可证及 Icarus，模板已随目录保存，不依赖视频生成物。末端固定 opt_route，没有 bitgen。重跑更新对应输出；比较前应另存本轮日志。

下一步是实际 16 路内部流水线+部分和 RAM 封装，验证共享乘数打包在 reset/CE 下的正确性及资源；补齐 RAM/时序宏单元未覆盖项；在真实数组配置上验证 100 MHz。网络准确性、INT8 量化和 DDR 实测仍是独立前提。本轮无上板、无完整视频构建、无位流。
