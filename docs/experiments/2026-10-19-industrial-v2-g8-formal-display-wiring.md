# V2 G8 formal display wiring candidate

## 结论

本实验将结果域 CDC 候选接入 TD formal source wrapper 的 HDMI 显示路径，并把时间跟踪/轨迹叠加放在 `S_hdmi_pixel_clk` 域。该候选通过静态契约检查和隔离 Icarus 仿真，但不是完整 V2 集成，也没有执行 TD 综合、实现、Bitgen 或上板验收。

## 变更范围

- `fallback/td_source/design_top_wrapper.v`
  - 从现有 CSI/ISP 结果 toggle 和检测框建立 `industrial_v2_result_cdc` 源域 payload。
  - 在 HDMI 域实例化 `industrial_v2_display_tracking`，其输出接入既有 `bbox_draw_overlay` 的输入。
  - 当前源侧尺寸、形状、运动、计数和分拣字段明确绑为零；这表示未完成的接口边界，不是功能已实现声明。
- `scripts/build_industrial_td.py`
  - 将 CDC、显示跟踪、时间跟踪、轨迹历史和跟踪叠加 RTL 纳入隔离 TD 工作树复制清单。
- 两个 TD `.prj` 文件
  - 将上述五个 RTL 文件加入综合和实现的 Verilog source list，compile order 为 65–69。

## 验证

| 检查 | 结果 | 证据 |
|---|---|---|
| Formal display wiring static contract | PASS | `python -B -m pytest -q work/tests/test_v2_formal_display_wiring.py`，2 passed |
| Display tracking isolated contract | PASS | `python -B -m pytest -q work/tests/test_v2_display_tracking_contract.py`，1 passed |
| Display tracking isolated RTL simulation | PASS | `TB_INDUSTRIAL_V2_DISPLAY_TRACKING_PASS` |
| V2 model/contract regression | PASS | `python -B -m pytest -q work/tests/test_v2_*.py`，62 passed |
| TD synthesis/implementation/Bitgen | NOT_RUN | 当前没有 V2 QoR 或 Bitstream 证据 |
| Board HDMI/SC520CS acceptance | NOT_RUN | 当前没有板卡、下载器和实测证据 |

## 已知边界

1. 当前 candidate 只把现有检测结果经过 CDC 送入 HDMI 跟踪显示路径；`industrial_v2_feature_spine` 没有被 formal top 实例化。
2. `motion_grid_adapter_96` 和 `frame_stats_96` 通过独立仿真，但尚未接入 CSI/ISP source list/top-level。
3. CDC 的稳定多位 payload 采用两级目的域采样，仍需在 TD CDC/时序报告中审计；本实验没有把静态 RTL 接线检查当成 CDC 收敛证明。
4. 复位、帧边界刷新、OSD 与 bbox 的同帧一致性仍需 TD 仿真和硬件画面确认。

## 后续入口

先以隔离 work tree 执行 TD source synchronization 和最小 elaboration/synthesis；只有 source list、顶层端口、复位/时钟和关键 warning 可审计后，才继续完整 V2 集成和 QoR 门禁。
