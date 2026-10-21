# Industrial V2 板级视频故障 —— 根因调查冻结记录

**状态**：`BOARD_VIDEO_FAILURE_ROOT_CAUSE` — **部分定位，未闭环**
**冻结日期**：2026-10-21
**证据等级**：所有板测结论均为 `USER_REPORTED_ON_BOARD`（用户实测口述）；本文档不含我自行测量的硬件数据。

---

## 1. 实测时间线

同一块开发板、同一个 SC520CS 摄像头、同一台 HDMI 显示器、同一组线缆：

| 位流 | 现象 |
|---|---|
| V1 | 显示正常 |
| R1（E1+E2） | 严重闪烁、图像拼接、错位 |
| R2（E1+E2+E4） | 同样现象 |
| **D0**（R2 − AWB 增益级） | **闪烁消失，画面稳定**；剩余：`PROC/VIDEO/E2E` 显示 N/A、OSD 文字笔画缺失且错位 |
| D1（D0 + 字体修复） | 未测 |

板测附加观察：Logo 与 OSD 一直能显示；摄像头画面能部分出现；**文字错位是静态的**；**Logo 未损坏**。

### 这组证据直接排除

- **不是 E4**：R1 不含 E4，现象相同。
- **不是板级/线缆/摄像头/显示器**：同一套硬件上 V1 正常。
- **不是 HDMI 输出通路**：OSD 与 Logo 稳定，说明 PLL、VTC、TMDS、OSD 叠加正常工作。
- **不是常规时序违例**：R1/R2/D0/D1 全部时序收敛且 0 违例；而未收敛的 V0 从未上板。

---

## 2. 差异审计：V1 ↔ V2 视频数据通路

### 方法

V1 的冻结包 `industrial-v1-manifest.json` 的 `sources[]` 显示，V1 **实际编译**的是
`fallback/td_source/` 下的 guard 覆盖版本，而不是 `fallback/td_package/user_source/`
内的同名副本。若直接比对包内副本，会把"未参与构建的副本差异"误判为版本差异。
本文档的比对**按 V1 实际编译集重建映射**，并按行尾归一化后逐文件哈希比对。

### 结果

| 范围 | 结论 |
|---|---|
| 非 HDL 文件（IP 配置 `.tcl`、`ddr2.adc`、`ddr2.sdc`、PLL、`pin.adc`、FIFO IP） | **全部逐字节相同** |
| `syn_1/settings.cfg` | 相同 |
| `phy_1/settings.cfg` | 仅 `end_step` 不同（V1 到 bitgen，V2 到 opt_route） |
| 源文件清单 | V2 增加 16 个模块，**未删除任何一个** |
| 视频链模块 `video_in` / `video_out` / `mc_to_user_interface` / `ph1p35_324_ddr_wrapper` / `uivtc` / `hdmi_mixer` / `hdmi_tx` / `csi_unpacket_2lane` / `raw10_unpacket_2lane` / `uial2axis` / `demosaic` / `data_96bit_to_128bit` | **全部逐字节相同** |
| 上述模块的顶层接线（含 DDR 读写控制、VTC、mixer、复位、时钟） | **相同** |
| 视频域时钟与复位结构 | **相同** |

### 结论

> **整条视频数据通路上，V2 相对 V1 只多了一个元件**：`isp_top` 中插在 `awb` 与
> `data_96bit_to_128bit` 之间的 `axis_gain_rgb96`（两级 AXI 流水）。

静态推演显示它**应当透明**：增益恒为 `16'd256`（Q8.8 = 1.0），
`(pixel*256+128)>>8 ≡ pixel`；顶层 `S_ISP_O_tready` 两版都硬接 `1'b1`，
故 `product_ready`/`raw_ready` 恒 1 不产生气泡；下游齿轮箱的装包相位
`S_cnt` 只由 `I_96b_valid` 的连续游程决定，纯延迟不改变游程。

**因此静态分析无法解释实测现象。** 这一点必须保留：既不宣称该级"已排除"，
也不宣称"已确认"。D0 的板测结果（旁路后闪烁消失）是强证据，但单点，
且旁路同时改变了布局，**尚未排除布局因素**。

---

## 3. 三个缺陷

### 3.1 闪烁 —— 与 AWB 增益级相关，机制未证实

- 证据：D0 旁路该级后闪烁消失（用户实测）。
- 未证实：为何一个静态透明级会导致闪烁；是否含布局因素。
- 待办：**D0c2 对照** —— 保留两级流水形状、去掉乘法算术
  （`O_tdata <= I_tdata` 延迟两拍）。仍闪 → 问题在流水形状/延迟；
  不闪 → 问题在算术通路。见 `NEXT_ACTION.md`。

### 3.2 遥测 N/A —— `design_top_wrapper.v`，确定性缺陷

feature spine 实例第 **1231–1237** 行把整个 HDMI 视频契约硬接为零：

```verilog
.I_video_valid (1'b0)  .I_video_de (1'b0)   .I_video_hsync (1'b0)  .I_video_vsync (1'b0)
.I_video_rgb (24'd0)   .I_video_x (11'd0)   .I_video_y (11'd0)     .I_video_frame_id (16'd0)
```

`latency_monitor.v` 的 `video_match_now = pending && I_video_valid && (frame_id 相等)`
因此恒假 → `O_video_valid` / `O_e2e_valid` 永不拉高 → `VIDEO: N/A`、`E2E: N/A`
是结构性必然。

**修复是安全的**：spine 的 `O_video_*` 在顶层全部悬空，真实叠加由
`u_industrial_v2_display_tracking` 完成，接通输入不改变任何像素。

**但语义未定**：设计中没有"屏上当前是第几帧"的信息。直接接
`v2_hdmi_result_valid` 会让 N/A 变成数字，但那个数字测的是"结果跨到 HDMI 域"，
不是端到端。**需要一个设计决定**（见 `NEXT_ACTION.md`）。

**PROC 是独立问题**：它不依赖 `I_video_valid`，但 `O_proc_valid` 是 MIPI 域单拍脉冲，
经 CDC 后在 HDMI 域被 vsync 快照，单拍极易漏采。中等置信度，待接通后复测。

### 3.3 文字缺笔画 + 错位 —— `industrial_osd_overlay.v`，确定性缺陷

```verilog
reg [4:0] current_row;                  // 字形 5 列，bit4 最左，bit0 最右
text_col = ((x - 180) & 7) >> 1;        // 只能取 0..3
text_on  = current_row[4 - text_col];   // 只索引 bit4..bit1
```

8 像素字格被压成 4 个字形列，**字形第 0 列整列永不选中**。以 "B"（row1 = `10001`）
为例，丢 bit0 后只剩 `1000`，右侧竖笔消失；同时 4 列被拉宽填满 8 像素，
比例失真 —— 完全对应"笔画缺失 + 错位"。

**该缺陷 V1 同样存在**（相关表达式逐字相同），**不是 V2 回归**。
Logo 走 `anlogic_logo_rom` 独立路径，故不受影响，与观察一致。

---

## 4. 诊断位流

### D0 —— `release/diagnostics/d0b-gain-bypass-on-r2/`

`R2 − axis_gain_rgb96`：删除该实例，用 5 条 `assign` 把 `awb` 直连齿轮箱
（即 V1 的视频配置）。相对 R2 **只有 `isp_top.v` 一个文件改变**。

| 项 | 值 |
|---|---|
| Setup / Hold WNS | +103 ps / +21 ps，0 违例 |
| Slice | 17,943（84.57 %） |
| 位流 | `camera_to_dsi_display_d0.bit` `BFAA29F9…22BEC` |
| 板测 | **闪烁消失**；遥测 N/A；字体缺陷 |

### D1 —— `release/diagnostics/d1-osd-font-fix/`

`D0 + OSD 字形修复`：字格 8→10 像素，`text_col = (off%10)>>1` 取 0..4，
5 列各 2 像素均匀绘制。相对 D0 **只有 `industrial_osd_overlay.v` 一个文件改变**（27 行）。

| 项 | 值 |
|---|---|
| Setup / Hold WNS | +121 ps / +20 ps，0 违例 |
| Slice | 18,091（85.27 %） |
| 位流 | `camera_to_dsi_display_d1.bit` `031F5DAB…DE9B6` |
| 验证 | ModelSim 黄金测试，见下 |
| 板测 | **未测** |

**黄金测试（带对照组）**：1280×720 光栅、`I_mode=ORIGINAL`、快照输入全 0、
`I_rgb=0`，第 0 行渲染 "MODE:ORIGINAL"，按字形表逐行计算期望亮点数并比对，
与流水对齐无关。

| 字形行 | 未修版（D0） | 修复版（D1） |
|---|---|---|
| row0 | 140 / 164 | **164 / 164** |
| row1 | 64 / 92 | **92 / 92** |
| row2 | 60 / 88 | **88 / 88** |
| row3 | 100 / 128 | **128 / 128** |
| row4 | 56 / 84 | **84 / 84** |
| row5 | 56 / 84 | **84 / 84** |
| row6 | 132 / 168 | **168 / 168** |

未修版 7 行全部短缺、差值恰为丢失的第 0 列；修复版逐行精确相符。
**对照组证明该测试确实能检出缺陷**，否则"通过"没有意义。

### D0（首版，作废）

`work/d0_gain_bypass/` 基于时序未收敛的 V0 构建，报 `Setup −2.191 ns / 40 违例`。
一个时序不收敛的位流无法区分"逻辑错误"与"时序错误"，**未 bitgen、未上板、仅存证据**。

---

## 5. 未完成项

| 编号 | 内容 | 阻塞于 |
|---|---|---|
| D1 板测 | 字体修复效果 | 硬件可用性 |
| D0c2 | 闪烁归因（流水形状 vs 算术） | 一次构建 |
| D2 | 遥测接线 | **需要设计决定：显示侧帧标签来源** |
| — | 闪烁因素的布局排除 | D0c2 之后 |

## 6. 边界

R2 **不得**标记 `HARDWARE_PASS`。D0/D1 是诊断位流，不是发布候选。
V1/R1/R2 的任何产物均未被覆盖。
