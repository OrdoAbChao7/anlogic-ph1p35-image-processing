# PH1P35 视频保留条件下的资源与 DDR 静态审计

日期：2026-10-13。证据分类：official / project / inferred / unknown。只读既有工程与报告；本次未启动 TD、未构建完整视频、未生成或下载位流。

## 结论

现有视频必须保留时，cartoon-release 的可计数未占用资源为 **6368/21216 slices、69/108 ERAM20K、32/40 DSP**；Lab1 为 **8826 slices、69 ERAM、32 DSP**。这些是未分配数量，不是可保证集成的 AI 预算；没有预留新的 DMA、缩放、激活、NMS、BBox/OSD、CDC、FIFO 和时序余量。

DDR IP 配置的是集成 **512 Mbit x16 DDR2（64 MiB）**。GUI 使用 100 MHz 参考时钟并标称 DDR CK 533.3 MHz；当前顶层却直接接 **50 MHz I_sys_clk**。最终 routed STA 一致报告 **DDR CK 266.667 MHz、UI 66.667 MHz /128bit**，理论共享数据峰值约 **1.0667 GB/s**。这是配置和实现推导，尚非示波器测量或有效吞吐实测，不能把 GUI 1066 MT/s 当成实际速率，也不能预设 UI 133–200 MHz。

HDMI 为 **75 MHz / (1650 × 750) ≈ 60.606 Hz**，不是目标文档中的 30 fps。紧凑 RGB888 每帧 2,764,800 B，显示最低读取 167.564 MB/s。以摄像头 60 fps 作保守场景，写入 165.888 MB/s，视频合计最低 **333.452 MB/s**。摄像头真实帧率未测，不能将该场景写成实测。camera30 + 当前 HDMI 时序也需要 **250.508 MB/s**，不能用读写都30来减半预算。有效余量仍 unknown。

## 版本隔离与哈希

完整路径与 SHA-256 已保存到 budget.json；当前输入文件指纹见 evidence-manifest.json。

| 版本 | 位流 SHA-256 | Slice used/free | ERAM used/free | DSP used/free | Setup/Hold WNS |
|---|---|---:|---:|---:|---:|
| Lab1 phy_1 | a3117b3ca6bb68326da2b14914b713fd9de49dcc4a2b9fde8a8abb19f9ff6010 |12390/8826|39/69|8/32|1242/20 ps|
| work/td_cartoon phy_1 |8284e7a90d3c36c20440d6e989800b4912683c5157e153cb64b3722f33bdd9f3|14848/6368|39/69|8/32|1389/20 ps|
| work/output/cartoon-release |8284e7a90d3c36c20440d6e989800b4912683c5157e153cb64b3722f33bdd9f3|14848/6368|39/69|8/32|1389/20 ps|

project：本次直接哈希确认 td_cartoon 与 cartoon-release 的 bit、route.qor、final_timing.rpt 三件全部相同。因此这里可以关联 release 与 td_cartoon 的 area 报告；不能泛化为任何最新卡通候选（特别是 s3_luma），也不能取组员失败版本数据。Lab1 是可恢复的已构建参考，STATUS 仍没有完整硬件验收；不称其硬件稳定。

资源依据：

- .tools/td/work/lab_ex1_mipi_hdmi_sc520/td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display_phy.area:2,9,11,15,26,29,34,35：器件、LUT6/DFF、Slice、ERAM、DSP、PLL/GCLK。总量 21216 LUT6/Slice、42432 slice regs、108 ERAM、40 DSP、6 PLL、32 GCLK。
- work/td_cartoon/td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display_phy.area:9,11,15,26,29：12469 LUT6、14249 regs、14848 slices、39 ERAM、8 DSP。
- 各版本 route.qor:5–19：最终 WNS/TNS、slice/RAM/DSP。
- 各版本 final_timing.rpt:1–10：TD 6.2.168116，PH1P35MDG324 speed3，Routed。Lab1 STA coverage95.53%，release95.90%，不能认为全部路径已证明。
- official：docs/research/snapshots/competition/topic2.pdf 物理第6页：PH1P35MDG324、38184 LUTs、42432 DFF、2160 Kbit ERAM、40 DSP、6 PLL；第7页50M有源时钟。PDF页眉写2025，虽本地2026资料使用，仍保留版本差异。LUTs38184与TD LUT6 21216口径不同，不能相减。总容量2160×1024/8=276480B；69块原始容量176640B，但不同位宽/深度/端口/打包模式需要整块分配。

## DDR时钟证据链

以下 L 表示 .tools/td/work/lab_ex1_mipi_hdmi_sc520/；C 表示 work/td_cartoon/，均为仓库相对路径。

1. L/td_project/camera_to_dsi_display.sdc:1 将 I_sys_clk 定义为20ns；官方板时钟第7页为50MHz。
2. L/user_source/hdl_source/design_top_wrapper.v:803–807，DDR wrapper 的 I_sys_clk 接原始 I_sys_clk，不是 S_100m_clk。C 对应:805–809。
3. L/user_source/hdl_source/ph1p35_ddr/ddr2/.params_ddr2.txt:4–14：100MHz、1066、x16、512；:92–116：bank2/col10/row13、DQ16、MC25、UI128；:137 GUI actual533.3。
4. L/user_source/hdl_source/ph1p35_ddr/ddr2/ddr2.v:83–92：PLL0 ref100、refdiv3、feedback32、CLK2_DIV2；实际50MHz乘32除3除2=266.6667MHz。:61 tCK1876ps为生成时的标称值，不可用来覆盖实际参考接法；将来若修正时钟需重新审计时序参数，不在本轮修改。
5. L/.../phy_1/final_timing.rpt:38,45–49、release/final_timing.rpt:39,45–49：usr/ctl66.667、ddr266.667；:71–74明确 C-Freq 是 constraint freq、R-Freq 是STA估算Fmax，后者不能当实际工作频率。
6. L/user_source/hdl_source/ph1p35_ddr/ph1p35_324_ddr_wrapper.v:61,78–83：O_ddr_clk=dhi_clk；128位 PAXI interface :41–57。video_in/out工作于该UI域。

配置容量为2^(13+10+2)×16bit=67108864B。地址每个128bit事务+8（video_in.v:198–199，video_out.v:127–128），据 x16 native word 单位推导2B/address；不是128bit address单位。MC_ADDR_WIDTH=BA+ROW+COL见ddr2/src/rtl/top/ph1p_ddrmc_top.v:51。这是相互一致的project/inferred证据；未取得完整原理图/独立器件DDR手册，也未做全容量地址测试，物理可访问容量保持未实测。

## 视频缓存与并发带宽

- L/user_source/hdl_source/isp/isp_top.v:95–105实例化 data_96bit_to_128bit。isp/data96_128/data96_128.v:40–61每4组96bit打包为3组128bit；不是下面未实例化的补0到32bit/像素版本。
- video_out.v:164–193，每16 RGB888像素读取3×128bit；因此准确有效像素存储是3B/pixel。
- video_in.v:40–43、video_out.v:43–46：四基址0/7000000/14000000/21000000 native words，推导字节基址0/14M/28M/42M；四帧payload合计11059200B，但保守保留从0到末帧结尾44764800B。其后可计算的连续尾部22344064B尚未分配AI；帧间洞不得直接宣称可安全使用，读预取没有显式帧长限制。
- video_in.v:121–134由写指针给出读指针，跨帧缓冲带来帧级延迟；不能将算子小于2ms说成端到端小于2ms。
- video_in.v:147–150、video_out.v:82–99：每批240个128bit事务=3840B；读侧有prefetch和FIFO留空，帧切换复位会丢弃预取，最低有效数据流量不是总线真实占用。
- L/design_top_wrapper.v:741–746只有视频写/读二选一地址选择；mc_to_user_interface.v:44–68共用FIFO、命令接受条件和无tag读返回；ph1p35_324_ddr_wrapper.v:71将paxi_rready固定1。这里没有AI master，也没有区分AI与显示读返回的路由。不能只加一个地址mux就实现安全并发。
- C/user_source/hdl_source/design_top_wrapper.v:851–857定义1280/1650及720/750；final_timing:38为75.002MHz（STA四舍五入），按PLL名义75MHz得60.606Hz；差异不足以支持30Hz。
- C/user_source/hdl_source/uics520_cfg/uicfgcs520.v:205实际实例化uics520reg_720p60；对应表:4–5为24MHz/60fps，:39–40设VTS1000。实际MCLK约23.809524MHz，若只按比例推导则约59.524fps，但未核验传感器全时钟树，预算保留60场景。目录中uics520reg.v:176–181有30fps诊断覆盖，**该表不是当前实例**，不能被文本搜索误用为输入30fps事实。

理论1.0667GB/s扣除333.452MB/s得到733.215MB/s，仅是理想算术上限，不是可分给AI的保证带宽。还要扣刷新、行激活、读写翻转、仲裁、FIFO及AI权重/特征图重复传输。对任何网络均必须计算每层真实off-chip bytes与存活期；权重容量能放DDR不代表延迟能达标。

## 尚缺的实测及整网阻塞

unknown：当前下载位流身份与硬件绑定；DDR CK/UI计数验证；摄像头frame-start与HDMI VSYNC独立计数；吞吐压力下读写accepted-beat、stall、刷新、FIFO overflow/underflow与最大延迟；三master并发公平性/显示deadline；完整地址空间测试；cache划分和帧所有权；跨域/复位恢复；现有PHY时钟warning分类。当前仅有静态资源计数，不证明新增阵列的可布线性或100MHz以上时序。

## 分阶段接入建议（未实现，不越阶段门）

1. 固定Lab1或release bit哈希完成G1冷启/热复位/画面/帧率证据，再冻结G2格式、时钟、valid/DE、四缓冲帧号、CDC和DDR QoS。退出：上述unknown关闭到足以接入算法。
2. 软件端先验收检测效果，冻结预处理、INT8、模型权重、BBox/NMS规则并获得VISUAL_APPROVED；先完成隔离网络/存储/算子验证。现有PC v8m表现不能替代硬件预算。
3. 优先在稳定ISP RGB或DDR读出像素流处分叉，流式ROI/缩放写专用AI输入缓冲；不反压摄像头和HDMI。退出：输入frame_id、尺寸、量化与黄金模型一致，丢弃策略可见。
4. AI网络使用独立权重/feature地址区和显式读写仲裁及读响应路由；以显示deadline优先并规定AI最坏等待。退出：并发仿真证明无污染/欠载，再核对集成资源和时序，获授权后才完整视频构建。
5. BBox结果携带frame_id、类别、分数、坐标、总数和有效标志，使用双缓冲/握手CDC，只在HDMI帧边界原子换页；说明显示的是哪一采集帧结果。纯Verilog NMS、缩放逆变换与类别映射均需定点golden比对。
6. OSD在当前HDMI像素域叠加，所有DE/HS/VS与RGB同延迟；无目标/超时/复位显式清除框，LED/语音仅响应已定义事件。退出：G5/G6逐场景与上板证据通过。

## 复现与验证

运行 python work/g5_board_feasibility/board/audit.py，仅重新读取本地area/bit/qor/timing并写本目录budget.json。实际执行通过：三项release来源hash一致断言、资源减法断言、容量及带宽计算。没有启动TD。脚本不是硬件测试；所有hardware_verified字段为false。源码是当前工作副本，历史构建对应源码的完整不可变清单未重新重建，证据清单仅固定本次所读文件；不把当前源码hash自动绑定旧bit。
