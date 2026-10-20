# 工具链操作手册

核对日期：2026-10-20。以下命令按当前脚本源码核对；不是本次构建或硬件通过记录。执行前满足 [Agent工作流](agent-workflow.md) 与 [软件先行](software-first-protocol.md) 门禁。

## 1. 环境与工作目录

全部命令从仓库根目录运行，使用 PowerShell。先确认 git rev-parse --show-toplevel 与当前项目一致；不要混用另一个 FPGA-fallback 工作区。

~~~powershell
git status --short
git diff --stat
git diff --cached --stat
Get-Command python, powershell, rg, git
python --version
python -m work.fpga_loop --help
~~~

相关文件继续用 git diff -- 路径查看，不能覆盖已有修改。本机默认位置：

| 工具/对象 | 位置 | 判断依据 |
|---|---|---|
| Python | 当前 python 解释器 | 检查 sys.executable 和所需依赖；不把Lab虚拟环境与测试环境混用 |
| Icarus | .tools/iverilog/bin/iverilog.exe、vvp.exe | 当前路径及版本输出（行为仿真） |
| ModelSim | C:\intelFPGA\20.1\modelsim_ase\win32aloem\vsim.exe | 2020.1 Starter Edition，支持解密 PH1 原语加密段 |
| PH1 仿真库 | .tools/modelsim_ph1p_lib\ph1p_lib | 通过 scripts/compile_modelsim_ph1p.ps1 编译，82个模型全数通过 |
| TD | .tools/td/app/bin/td_commands_prompt.exe | 现有报告为6.2.168116；当前版本须本机核对 |
| TD flow | .tools/td/app/doc/scripts/DefaultFlow.tcl | build.ps1在指定Run目录调用它 |
| 整合工程 | work/integration/project/td_project/camera_to_dsi_display.al | PH1P35MDG324，顶层design_top_wrapper；以实际.al为准 |
| 备用工程 | fallback/project/td_project/camera_to_dsi_display.al | 独立路线，不能把其测试当整合副本测试 |
| 旧原图工程 | .tools/td/work/lab_ex1_mipi_hdmi_sc520/ | G1历史构建与上板基线，不作为新算法默认修改区 |

环境巡检：

~~~powershell
python -m work.fpga_loop doctor
~~~

同义入口为 scripts/fpga-loop.ps1，它转发当前 python，不自动激活虚拟环境。doctor仅检查部分文件/依赖；许可文件存在不等于许可实际生效。当前版本探针调用TD的 -v，可能被TD当作脚本文件；不要把这类错误当综合失败，也不要用 -h/--help/help 猜TD命令。版本应结合启动banner与真实构建日志。doctor输出状态必须人工核对，退出码0不等于环境全通过。缺TD不阻塞纯文档审计或已具备Python依赖的软件工作。

## 2. 命令选择：模块验证与整机分开

### 独立颜色模块

~~~powershell
# 单帧Golden检查，当前实现固定为color_detect_96
python -m work.fpga_loop test --module color_detect_96

# 单帧Golden + fallback的九组既有RTL回归
python -m work.fpga_loop test --module color_detect_96 --regressions

# 八类Golden向量 + 摘要；不加--build不会运行综合
python -m work.fpga_loop run --module color_detect_96 --project fallback
~~~

实际对象来自 fallback/rtl/color_detect_96.v；test分支的 --module 不是通用模块发现器，不能换个名字就声称测了另一个模块。八向量覆盖黑/白/空场/单点/多命中/跨组/多行/随机，与九组工程回归不是同一套测试。

仅在适用构建门满足、且任务确需独立预算时：

~~~powershell
python -m work.fpga_loop run --module color_detect_96 --project fallback --build
~~~

这构建的是100MHz独立颜色模块，输出在 work/fpga_loop/runs/<run_id>/，不是SC520CS→HDMI整机位流。检查 summary.json 的 target_rtl、stages.simulation、stages.build、final_status；当前CLI未把run返回的FAIL/BLOCKED统一转成非零退出码，因此不能只看进程退出码。未加--build时PASS仅限已执行阶段。

自动gate只检查有限项目名及仿真结果，不读取完整G1/G2、当前视觉批准和参数快照。尤其 --project fallback 不是跳过视觉验收的授权。

### 整合副本九组回归

~~~powershell
$taskIcarus = (Resolve-Path '.tools/iverilog/bin').Path
powershell -NoProfile -ExecutionPolicy Bypass -File ./work/integration/test.ps1 -IcarusBin $taskIcarus
~~~

实际执行 tb_industrial、tb_colors、tb_full_frame、tb_box、tb_pack、tb_pack_line、tb_pipeline、tb_awb_tags、tb_isp。输出在 work/integration/test-results/，通过后保存 test-input-manifest.json。

脚本先比较 rtl/ 与 project/ 中四个镜像模块哈希。修改这四个模块时必须核对两份同步；其他文件以 .al 的实际引用为准。ISP/AWB测试使用依赖模型，不能作为厂商IP、摄像头或AWB画质通过证据。新增模块须扩充测试入口；九组测试不自动覆盖新功能。

备用路线任务使用 fallback/test.ps1，同样显式传 -IcarusBin。整合目录比fallback深一层，不能使用脚本按父目录猜出的工具默认路径。

## 3. 整机TD构建

默认新增整合功能只在 work/integration/ 构建；fallback/release 中的冻结包不原地运行build。为验证冻结包，应复制到独立验证目录后执行包内入口并保留原包。

执行前检查：适用视觉/模型/仿真门、G1/G2集成门、实际.al所有引用、输入快照、约束、工具版本、修改目标与回退点。build.ps1本身不会检查全部这些条件。

~~~powershell
$taskTd = (Resolve-Path '.tools/td/app').Path
powershell -NoProfile -ExecutionPolicy Bypass -File ./work/integration/build.ps1 -TdRoot $taskTd
~~~

此命令会删除并重建该副本 project/td_project/camera_to_dsi_display_Runs/syn_1 和 phy_1，也会替换该副本构建凭据。先保存需保留的旧报告，确认解析后的目录在本轮工作区内；不要对原包或用户正在使用的另一个工程执行。

脚本验证：显式文件引用可解析、TD退出码、综合/bitgen完成标记、bit存在、最终Setup/Hold WNS非负、两项TNS为0，以及构建期间输入清单不变。输出：

- project/td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display.bit
- 同目录 route.qor、final_timing.rpt、console.log等原始报告
- 副本根目录 build-input-manifest.json、build-output-manifest.json

-SynthesisOnly仅供定位综合问题，不代表布局布线或位流通过，不能作为完整导出凭据。

额外人工/审计检查：STA覆盖、所有相关约束与CDC、PHY关键告警分类、资源余量、正确的输入/顶层、算法及帧对应行为。WNS≥0不等于所有路径都被正确约束。

**不要将 python -m work.fpga_loop build --project fallback 作为整机入口。** 当前build分支没有用project参数选择工程，未传--dir会落到旧 work/td_cartoon 的Runs目录；也不等价于上述干净构建和输入门禁。当前文档只推荐显式工程的build.ps1。

## 4. 报告读取与候选导出

~~~powershell
# 只读解析本次整合实现报告，必须显式指定目录
python -m work.fpga_loop report --dir work/integration/project/td_project/camera_to_dsi_display_Runs/phy_1

# 只读解析已归档的原候选报告
python -m work.fpga_loop report --dir docs/build/industrial-repair/final
~~~

裸report默认也指向旧卡通目录；--run-id按固定布局找build/phy_1，不保证适合所有独立模块目录。先确认真实报告路径，缺字段视为UNKNOWN，不视为通过。route.qor以ps为单位，final_timing.rpt以ns为单位；1ns=1000ps。资源使用最终实现结果，不混用综合估计或其他版本。

同一输入的测试与完整构建完成、相关导出条件满足后：

~~~powershell
# 每次使用新的、尚不存在的目录名，保留旧包
$taskExport = Join-Path (Get-Location).Path ('work/integration/release/candidate-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
powershell -NoProfile -ExecutionPolicy Bypass -File ./work/integration/export.ps1 -OutputDir $taskExport
~~~

导出器核对测试/构建输入、bit与route哈希、bitgen标记、时序及九份PASS日志，并拒绝覆盖已有目录。输出完整目录、ZIP、manifest.json和build-summary.json。它只检查已编码条件，不验硬件、视觉、所有告警，也不自动覆盖新增模块测试。

当前导出器仍固定输出名 industrial_color_bbox.bit，并写 hardware_verified=false、visual_approved=false；这是候选包状态，不能改成true来绕过真实验收。新增功能后须检查包名/功能描述/测试清单是否仍准确，不能只换ZIP名便宣称发布新系统。

从复制的旧候选看到的根目录bit或build-summary.json，可能仍属于原恢复包。新构建以后必须以本次Run输出和新导出清单为准，禁止把旧根目录bit当新结果下载。

## 5. Algorithm Lab

现有启动入口：

~~~powershell
# 交互启动：会打开浏览器，服务端口为8501
./work/algorithm_lab/run_lab.bat
~~~

当前脚本依赖 archive/legacy/yolo/y1_yolo/.venv/Scripts/python.exe，并检查 fastapi、uvicorn、cv2、torch、ultralytics。这个历史运行时依赖不等于YOLO已在FPGA实现，也意味着不能仅因目录叫archive就删除其中环境。缺环境应先检查 requirements.txt、app.py和对应依赖；不要默默使用另一个Python。

Agent启动服务时用隐藏后台进程，记录进程和日志，先核对端口占用；不要杀掉其他会话服务。端口8501是脚本配置，历史8503记录不证明当前服务在线。

按需验证软件改动：

~~~powershell
$taskLabPython = (Resolve-Path 'archive/legacy/yolo/y1_yolo/.venv/Scripts/python.exe').Path
Push-Location work/algorithm_lab
try { & $taskLabPython -m unittest test_lab.py } finally { Pop-Location }
~~~

这个测试文件不代表所有算法已验收。C阶段须保留样本/参数/代码哈希和用户确认；D阶段的定点预览与误差必须对应同一算法。registry中的历史v1.0-test批准仅覆盖那次s3_luma，不覆盖后续A/B/C候选、四像素适配或新OSD。

## 6. 下载与验证

目前本手册没有经过核验的自动下载命令，不虚构烧录CLI。需要上板时先查当前设备、已有接线与下载步骤，绑定具体bit哈希，通过已确认的安路下载工具执行；自动验证循环默认不烧录。

G1与发布的次数、时长和性能测法见 [验收矩阵](../verification/acceptance-matrix.md)。记录捕获新帧率、HDMI刷新率、检测更新率；记录算法拍数与端到端延迟，不能相互替代。

## 7. 故障分流与清理

| 现象 | 下一步 |
|---|---|
| 工具进程无法启动 | 保留原错误，区分宿主启动问题与项目失败；可用合法只读文件接口继续审计，不改RTL试错 |
| 缺Python包/工具 | 核对实际解释器/路径和依赖；不重复安装多个环境 |
| 仿真失败 | 保存首个失败输入/日志/波形；核对模型公式、位宽和流水线后最小修复 |
| TD退出0但报告缺失/过期 | 按失败或未知处理，核对Run目录、完成标记、输入时间与哈希 |
| 时序负值或关键告警未解释 | 不导出通过版本；定位最差路径/约束，不放宽约束掩盖问题 |
| 无板卡或缺工位素材 | 保留BLOCKED范围，继续独立软件/文档工作，不提升硬件状态 |

runs、缓存、.vvp、TD数据库属于可再生输出。先把复现所需输入、首败、最终原始日志/报告及哈希转存证据目录，再删本轮无用临时物；不要清理历史恢复包、用户已有输出或另一会话的运行目录。
