# Industrial Vision V2 ISP stream adapters

## 结论

新增两个候选适配器，明确把现有 4-pixel RGB888/96-bit ISP 流转换为 G4/G6 所需的原子输入：

- `motion_grid_adapter_96.v`：按 `8×6` 像素步长从 `1280×720` 选取 `160×120` 灰度采样；`O_frame_start` 是独立控制周期，`O_frame_end` 标记最后一个网格点。
- `frame_stats_96.v`：在 `I_tuser` 清零，最后一行 `I_tlast` 发布一次 RGB 总和、像素数和平均亮度；四个 RGB888 lane 的字节顺序与 `color_detect_96_v2` 一致。

## 验证

- 合同测试：`work/tests/test_v2_stream_adapters_contract.py`，`2 passed`。
- RTL 测试：`fallback/sim/integration/tb_stream_adapters_96.v`。
- 结果：编译无告警，输出 `TB_STREAM_ADAPTERS_96_PASS`。
- 小尺寸验证使用 `16×12` 输入、`2×2` 网格，覆盖首帧建基线、第二帧单采样变化、统计发布和无效帧检查。

## 边界

这些适配器尚未接入正式 `isp_top.v` 源文件清单。实际接入前还需绑定 AWB 输出延迟、帧/行同步语义及跨 CSI/HDMI 时钟域；本记录不代表 V2 TD 或板级通过。
