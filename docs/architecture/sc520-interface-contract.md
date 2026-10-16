# fixed-red v1 视频接口与时钟审计

本文只记录当前 `fallback/td_source/design_top_wrapper.v`、`fallback/td_source/isp/isp_top.v`、TD 工程约束和最终时序报告能够直接证明的内容。它是代码级/构建级审计，不替代 SC520CS 模组、PH1P35A 板卡和 HDMI 显示器的实测；不能把下表的 `project` 事实写成 `measured`。

## 端到端结构

```text
SC520CS MIPI pads
  → MIPI D-PHY / CSI-2 unpacket
  → RAW10 AXI4-Stream (40 bit)
  → demosaic (BGGR, 1280×720) → AWB (RGB 96 bit / 4 pixels)
  → fixed-red detector (parallel branch) + RGB 96→128 converter
  → DDR2 frame buffer
  → DDR reader → 720p timing (`uivtc`) → HDMI mixer / OSD
  → HDMI TX / TMDS
```

代码定位：顶层端口与内部信号见 `fallback/td_source/design_top_wrapper.v:3-115`；MIPI/CSI/RAW10 连接见 `:558-714`；ISP 与检测分支见 `:714-749`；DDR 写读见 `:751-866`；720p 时序和 HDMI mixer 见 `:872-918`；模式控制和 OSD 见 `:938-1062`。

## 已能确认的接口契约（project）

| 段 | 数据与控制 | 时钟/复位 | 背压与缓存 | 当前证据 |
|---|---|---|---|---|
| CSI-2 → ISP | `S_axis_tdata[39:0]`，`S_axis_tvalid`，`S_axis_tlast`，`S_axis_tuser`；顶层实例化 `isp_top` | `S_csi_rx_clk`；ISP 使用 `I_rst_n` | `isp_top` 暴露 AXI4-Stream `I_tready/O_tready` | `design_top_wrapper.v:87-101`、`isp_top.v:3-14` |
| ISP → detector | AWB 输出 `awb_O_tdata[95:0]`，每拍 4 个 RGB 像素；`awb_O_tvalid/tlast/tuser` | `axi4s_video_aclk=S_csi_rx_clk`；检测器同域 | `isp_top` 将 detector 并行接在 AWB 输出，检测结果由形态学 drained frame end 更新 | `isp_top.v:94-160`、`color_detect_96_v2.v:1-44` |
| ISP → DDR 写入 | `S_vi_ddr_wr_en`、`S_vi_ddr_wr_addr[24:0]`、`S_vi_ddr_wr_data[127:0]`、`S_vi_ddr_wr_ready` | `S_ddr_clk`；DDR wrapper 输出 user clock | `video_in` 与 DDR user interface 通过 ready/valid 连接 | `design_top_wrapper.v:119-130,751-821` |
| DDR 读出 → HDMI | `S_vo_ddr_rd_en/addr/ready`、`S_ddr_user_rd_valid/data`；`video_out` 产生 HDMI 像素流 | DDR 域到 `S_hdmi_pixel_clk`，由 `video_out` 内部 FIFO/CDC 承接 | 读请求和返回数据走 DDR user interface；时序由 `uivtc` 驱动 | `design_top_wrapper.v:132-168,784-818,872-918` |
| HDMI 时序 → OSD/TX | `S_hdmi_out_vsync/hsync/de/data[23:0]`；模式控制按 `S_hdmi_out_vsync` 帧边界提交 | `S_hdmi_pixel_clk`；`S_hdmi_rst_n=S_pll_lock` | OSD 和 mixer 同像素时钟，HDMI TX 接 mixer 输出 | `design_top_wrapper.v:872-918,938-1062` |

## 最终 TD 报告中的时钟事实

来源：`release/industrial-v1/final_timing.rpt`，TD `v6.2.168116`，器件 `PH1P35MDG324 / Speed 3`。

| 时钟名 | 报告频率 | 说明 |
|---|---:|---|
| `MIPI_RX_BYTE_CLK` | 103.520 MHz | MIPI 接收字节时钟 |
| `HDMI_PIXEL_CLK` | 75.002 MHz | HDMI 像素时钟；`uivtc`/mixer/OSD 所在域 |
| `u_ph1p35_324_ddr_wrapper/u_ddr2/usr_clk` | 66.667 MHz | DDR user interface 时钟 |
| `pll_clk_24m` | 23.810 MHz | 摄像头控制/复位时钟候选 |
| `sys_clk_50m` | 50.000 MHz | 板级系统时钟域 |
| `HDMI_SERIAL_CLK` | 375.094 MHz | HDMI 串行发送时钟 |

该报告的最终 Setup WNS 为 `+114 ps`、Hold WNS 为 `+20 ps`、TNS 均为 `0`，STA coverage 为 `96.46%`。这些是 TD 构建事实，不是板级测量。

## 尚未关闭的接口问题（unknown / measured）

- SC520CS 当前模组实际 RAW 位宽、Bayer 顺序、Lane 数和速率，仍需模组资料与上板抓取确认；代码中的 `BGGR` 和 RAW10 是当前工程配置，不等价于实物输出已测得。
- MIPI/CSI 输入的实际帧率、行间空拍、`tuser/tlast` 与有效像素坐标映射，尚无波形或板级采样证据。
- DDR2 实际读写稳定性、HDMI 物理输出刷新率、端到端延迟和帧率，尚无板级测量。
- `PHY-5060/5016/5079/5088` 及厂商 IP 的 undriven-pin 告警仍保持 OPEN；不能仅凭 WNS 为正关闭。
- `S_hdmi_debug_status` 当前用于调试 OSD 的状态路径，不能替代 HDMI/摄像头正常工作的硬件验收。

## 阶段结论

代码级接口路径、时钟名、数据位宽、复位和主要 ready/valid 连接已经可定位；G2 的硬件接口、CDC 波形、真实帧率和延迟验收仍依赖 G1/M5 上板。该文档不改变阶段门，也不宣称硬件已验证。
