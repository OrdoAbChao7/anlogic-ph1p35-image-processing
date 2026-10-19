# Industrial V2 G8：发布包源快照重建候选

## 状态

`REJECTED_CANDIDATE`。本次从 `release/industrial-v2/` 中已经打包的源快照、TD package 和 `DefaultFlow.tcl` 重建，TD 物理流程完成到 Bitgen，但资源超过发布目标，且外层构建包装器未在观察窗内返回退出码。因此不替换正式候选，不关闭可复现性或硬件验收门。

## 输入与边界

- 工作区：`E:/Projects/FPGA-v2`
- 目标器件：`PH1P35MDG324`
- TD：`6.2.168116`
- Flow：`release/industrial-v2/DefaultFlow.tcl`
- 源快照：`release/industrial-v2/source/`
- TD 输入包：`release/industrial-v2/source/fallback/td_package/`
- 顶层：`release/industrial-v2/source/fallback/td_source/design_top_wrapper.v`
- 视频 RTL：`release/industrial-v2/source/fallback/rtl/video/video_cartoon_region_fill.v`
- placement seed：`1`（作为构建脚本参数传入）
- 隔离工作区：`work/td_industrial_v2_package_rebuild/`
- 候选输出：`release/candidates/industrial-v2-package-rebuild/`

正式候选 `release/industrial-v2/industrial-v2.bit` 未被覆盖。

## 结果

TD 工作目录中存在 `.opt_place.end.f`、`.opt_route.end.f` 和 `.bitgen.end.f`，并生成 `camera_to_dsi_display_compress.bit`、`route.qor` 与 `final_timing.rpt`。外层 Python 包装器在 300 秒观察窗内超时；随后观察到 TD 进程退出，故这里仅将 TD 阶段标记作为证据，不把包装器记为 PASS。

| 指标 | 结果 |
|---|---:|
| Setup WNS / TNS / violated S-EP | `+127 ps / 0 / 0` |
| Hold WNS / TNS / violated H-EP | `+20 ps / 0 / 0` |
| Slice | `18305/21216 = 86.28%` |
| RAM / DSP / DRAMHARDCON | `43 / 24 / 229` |
| 压缩 Bitstream | `1,367,985 bytes` |
| Bitstream SHA-256 | `11a99053b800e27cc2cdae4b0295548c715e73d5e61ed64607d2f5a65468558a` |
| `route.qor` SHA-256 | `77eea237c4d47bf2b860bd717b491326b99e8dacfdba8307dbd8798064fc39c7` |
| `final_timing.rpt` SHA-256 | `583dde23861ff67b2103b5e8b103f09320ae92f0ef2549344eb826a30a7abf2e` |

## 告警与判定

物理流程日志仍出现 PHY-5016、PHY-5060、PHY-5079 和 PHY-5088。资源结果超过 `≤85%` Slice 发布目标；同时包装器观察超时未形成可重复构建的正常退出证据。因此本次候选拒绝晋级。

- TD placement/route/bitgen 阶段产物：`PASS`（仅限本次 TD 目录标记）。
- 时序：候选级通过，不能替代发布门。
- 资源预算：`FAIL`，86.28%。
- warning/CDC/constraints：`OPEN`。
- 外层可重复构建：`OPEN`，包装器超时。
- 硬件下载、冷启动、长稳和功能矩阵：`NOT_RUN`。
- 正式候选：保持不变，继续使用 SHA-256 `d6e6a7e12ef7558834904dcc8d2783d5fda827b7fe11c6e407b0119fc3ce1c0d` 的候选位流。

详细产物和 TD 日志保存在 `release/candidates/industrial-v2-package-rebuild/`；其中 `package-rebuild-manifest.json` 记录了输入、阶段标记、哈希和拒绝原因。

