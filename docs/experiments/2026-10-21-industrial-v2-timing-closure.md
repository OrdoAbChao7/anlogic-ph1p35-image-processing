# Industrial V2 — 整机时序收敛与首个可上板 Bitstream

日期：2026-10-21。结论：AWB-Lite 整机从 Setup `−2.539 ns / 24 违例` 收敛到
`+0.137 ns / 0 违例`，生成 Bitstream。**未上板**，`HARDWARE_PASS` 仍为否。

## 版本衔接

接管自原 Codex 会话。基线为
`E:\Projects\FPGA\work\g8_r1_v2_integration\work\g8_r3_awb_lite_20261021\full_candidate`，
接管时逐文件重算哈希，与冻结清单 `INPUTS.sha256` **完全一致**
（`design_top_wrapper.v 8D9E119E…`、`dimension_calibrator.v A9004712…`、
`industrial_osd_overlay.v 233482A5…`、`camera_to_dsi_display.sdc 390DFE5F…`）。

父清单 `731FF493EF607ED20909D4C72A60E28B85A21F76AC75C10015797096FEDC5ED1`
经查是 `R1-input-manifest.json` 的 SHA-256（455 抓取 / 236 暂存文件），是
R1 与 AWB-Lite 的**共用基线**，不是跨版本误引用。该身份冲突关闭。

## 违例归属（以原始 Route 报告为准）

24 条 Setup 违例并非均匀分布。按 TNS 反推并逐条核对：

- MIPI `MIPI_RX_BYTE_CLK`（9.660 ns）：**1 条**，`−2.539 ns`，独占 clk0 的 TNS。
  `color_detect_96_v2/O_xmin_reg[0] → dimension_calibrator/O_shape_valid_reg`，
  12.008 ns / 9 级，`ADDER×4 + DSPMULT×2`：宽高减法 → `+1` → `w*h` DSP →
  `×occ_min` DSP → 33 位比较。
- HDMI `HDMI_PIXEL_CLK`（13.333 ns）：**23 条**，最差 `−0.974 ns`，
  **起点全部是同一个** `u_industrial_osd/x_reg[2]`。整条 OSD 叠加判决
  （6,388 项组合 Logo ROM + `text_char` 12×16 case + `glyph_row` + 颜色 mux）
  挤在一级组合逻辑里驱动 `O_rgb`，net delay 占 69 %。

## 两项结构改动（各自独立验证后合并）

### E1 —— MIPI BBox 预计算流水（`dimension_calibrator.v`）

先证明时序窗口真实存在：`color_detect_96_v2` 在边沿 T 提交 BBox/area，
`defect_classifier` 在 T+1 翻转 toggle，`ind_v2_toggle_d` 再延迟一拍，使
`ind_result_event` 只在周期 T+1 为高，校准器在 T+2 采样。**周期 T 是空闲窗口。**

新增 `USE_BBOX_PIPELINE`（默认 0，生产实例设 1）：把 BBox 几何/面积操作数
提前一拍寄存，结果级消费寄存副本。提交沿、Frame 关联、复位、非法几何语义
与 8 个输出全部不变。

- ModelSim 逐周期差分：**1,058 检查 / 528 帧 / 0 mismatch**，覆盖 1×1、
  反向 BBox、满帧、面积钳位、占用率 199/200/201/256/257、纵横比边界、
  标定无效、复位、512 帧确定性扫描；另用"非合规激励"证明流水寄存器
  确实存在而非被综合折叠。
- 匹配模块 Gate（9.660 ns，两臂 `.prj`/`settings.cfg` 哈希相同）：
  WNS `−403 → +2,289 ps`，关键路径 `9.999 → 7.176 ns`，`#slice*` `133 → 140`
  （+5.26 %，门槛 10 %）。

### E2 —— HDMI/OSD 决策流水（`industrial_osd_overlay.v`）

坐标译码 → 字符/Logo ROM → 字形与 RGB 选择，三级寄存；`I_rgb/I_de/I_hsync/I_vsync`
同步延迟三拍。**不是**此前被拒的 49 ps mux 重排（那次没有流水级）。

- ModelSim 逐周期差分：**2,475,199 周期 / 1,843,397 有效像素 / 0 mismatch**，
  比较方式是"候选 N 拍对基线 N−2 拍"，同时断言像素内容一致且延迟为常量 2 拍。
- 匹配模块 Gate（13.333 ns）：WNS `−657 → +3,189 ps`，关键路径
  `13.926 → 10.080 ns`，`#slice*` `2698 → 2512`（**下降 6.9 %**）。

### E4 —— 检测器四像素组统计并行化（`color_detect_96_v2.v`）

E1 合并后，MIPI 的瓶颈转移到检测器内部的**四像素串行累加循环**
（12 级逻辑、8 个 ADDER）：`stat_*_next` 对 `morph_mask[3:0]` 逐位串行更新。

对置位集合 S，串行循环的不动点等价于：

```
area     += |S|                       （popcount）
xmin      = min(xmin, base + min S)   （base = out_group*4）
xmax      = max(xmax, base + max S)
ymin/ymax = min/max with out_y        （out_y 在一个组内恒定）
```

因为 min/max 与"加逐位常数"都可交换结合，改写后在数学上完全等价，空掩码两种
写法都不更新。实现为 popcount + 最低/最高置位位 + 每组一次比较/选择。

- ModelSim 逐周期差分：**701,440 检查 / 691,200 beat / 0 mismatch**。三整帧
  1280×720：移动矩形、双矩形、一整帧逐像素伪随机红/灰（让 4 位掩码取遍任意值）。
  额外 X 检查确认形态学模型确实工作（`detections=3`、`max_area=162327`），
  避免 X 与 X 相比的假通过。仿真使用 RTL 自带的 `+define+MORPH_SIMULATION`
  行为分支——厂商 `PH1P_LOGIC_ERAM` 模型在 ModelSim Intel 2020.1 下无法
  elaborate（`Unresolved reference to 'PH1P_PHY_GSR'`，加 stub 亦无效）。
- 匹配模块 Gate（9.660 ns）：WNS `−1,096 → +2,786 ps`，关键路径
  `10.692 → 6.626 ns`（13 级 → 8 级），`#slice*` `739 → 593`（**−19.8 %**）。

## 整机结果

| 指标 | 基线 AWB-Lite | E1 单独 | E1+E2 (r1) | **E1+E2+E4 (r2，交付)** |
|---|---:|---:|---:|---:|
| Setup WNS / TNS | −2.539 / −14.705 ns | +0.104 / 0 ns | +0.137 / 0 ns | **+0.644 / 0 ns** |
| Setup 违例端点 | 24 | 0 | 0 | **0** |
| Hold WNS / TNS | +0.020 / 0 ns | +0.021 / 0 ns | +0.020 / 0 ns | **+0.021 / 0 ns** |
| Slice | 18,421 | 18,359 | 18,248 | **18,233（85.94 %）** |
| ERAM / DSP | 75 / 32 | 75 / 32 | 75 / 32 | **75 / 32** |
| 线长 | 5,233,152 | 5,527,136 | 5,127,376 | **4,912,048** |

分时钟裕量（r1 → r2）：MIPI **+0.154 → +0.755 ns**、HDMI **+0.137 → +0.644 ns**、
DDR usr_clk +1.428 → +2.628 ns，其余 ≥ +1.292 → ≥ +1.364 ns。

综合阶段（Gate）已单独闭合成正：r1 为 −1,101 ps / 4 违例，r2 为 **+860 ps / 0 违例**。

## Bitstream

| 版本 | 文件 | 字节 | SHA-256 |
|---|---|---:|---|
| **r2（推荐）** | `camera_to_dsi_display.bit` | 1,789,539 | `E6BA3DA87DABF82907F3DB1B4FAC18A9E8350A43917F3D5E6DA64A0A35617C36` |
| r2 压缩 | `camera_to_dsi_display_compress.bit` | 1,504,689 | `1B7E853FAE95BE4E08029F37E5BAE7FD4C727F280D908BE6C56490FA5DCEE471` |
| r1（回退参考） | `camera_to_dsi_display.bit` | 1,789,539 | `ADD2DC46403670C279CADCE2E051F79B83EA9F2BBD1F4E78E7FBB7EB5606BC8C` |

r2 由 `camera_to_dsi_display_pr.db`（`C4217862…F6966E`）执行 `bitgen` 生成，
退出码 0，stderr 为空，`.bitgen.end.f` 存在。

交付目录：
- `release/candidates/industrial-v2-timing-closed-r2/`（r2，推荐，21 文件）
- `release/candidates/industrial-v2-timing-closed/`（r1，回退参考）

两版并存的原因：r2 改动了检测器（安全关键模块）。虽然逐周期等价已证明，
保留 r1 可在上板出现意外时快速回退。

## 约束诚实性

`camera_to_dsi_display.sdc` 与冻结基线**逐字节相同**。全设计仅有两类时间例外，
均为 DDR2 厂商 IP 的 `set_max_delay … -datapath_only` 灰码 CDC 约束，
且被 `set_clock_groups` 100 % 忽略。**未添加任何 false path、multicycle 或降频。**

STA coverage 96.54 % 已用 `check_timing -file … -verbose` 在 Routed DB 上完整枚举：
1 个未约束生成时钟（`u_uicfgcs520/u_i2c/scl_clk`，24 MHz / 240 ≈ 99.2 kHz）、
34 输入 / 65 输出无 IO delay（MIPI/DDR 硬核焊盘、TMDS、I2C、LED、按键）、
4 个无害 dangling 节点、0 非法约束、0 组合环。两个关键时钟域**没有**未约束内部逻辑。

尝试为该 I2C 时钟补 `create_clock` 并重算时 TD 崩溃（`0xC0000005`，minidump 已留存）；
该变体不再重试。99 kHz 结论因此是 RTL 常数推导，不是实测 STA 数值。

## 已知限制

1. 裕量已健康（MIPI +0.755 ns、HDMI +0.644 ns），但仍是有限值；插入
   ChipWatcher 调试逻辑必须重新构建并重新收敛。
2. AWB 关闭（继承 AWB-Lite），ISP 增益固定为 1.0。
3. 分拣执行器被抑制（`I_arm=1'b0`）。
4. 标定常数仍为临时值（0.5/0.25 mm/px、60×20 mm、±2 mm）。
5. HX1P35A/HX1P35B 引脚文档差异未关闭。
6. 综合告警谱与基线逐项一致（未新增、未屏蔽）。

## 结论

`RTL_VERIFIED` / `TIMING_PASS` / `BITSTREAM_READY` / `READY_FOR_BOARD_TEST` 成立；
`HARDWARE_PASS` **不成立**——本会话没有开发板，未做下载、视频链路、稳定性与
功能验收。上板步骤见交付包 `BOARD_TEST.md`。
