# Industrial Vision V2 G8 TD 随机源控制审计

日期：2026-10-19  
工作区：`E:/Projects/FPGA-v2`  
目标：确认官方 TD Flow 是否公开了 placement 之外的 gate、route 或 bitgen 随机源控制参数，作为固定 seed 可复现性门禁的补充证据。

## 检查对象

本次只检查随 TD `v6.2.168116` 安装的官方脚本和策略文件，以及当前仓库使用的派生 Flow：

| 文件 | 检查结果 |
|---|---|
| `.tools/td/app/doc/scripts/DefaultFlow.tcl` | `opt_gate`、`opt_place`、`opt_route`、`bitgen` 均有 Editable zone；默认 Flow 在 `opt_place` 只调用 `place`，`opt_route` 只调用 `route`，`bitgen` 只调用 `bitgen -bit` |
| `.tools/td/app/doc/scripts/MultiSeed.tcl` | 官方多 seed Flow 只在每个 seed 的物理阶段设置 `set_param place seed $seed` |
| `.tools/td/app/doc/strategies/official_strategy_ph1.json` | 策略公开的是优化选项，如 `multi_thread_mapping`、place/route effort；未发现 gate/route/bitgen seed 参数 |
| `release/industrial-v2/DefaultFlow.tcl` | 当前候选仅在官方 `opt_place` Editable zone 注入 `set_param place seed 1` |
| `scripts/build_industrial_td.py` | `--place-seed` 只生成上述 placement seed 注入，不伪造其它随机参数 |

## 结论

在上述官方脚本和策略文件中，没有找到可证实的 gate、route 或 bitgen 随机种子接口。该结果不能证明 TD 内部不存在未公开随机源，但证明当前工程没有可依据的官方参数继续固定它们。

因此：

1. 现有 `--place-seed` 仍是可追踪构建输入，但不是字节级可复现的充分条件。
2. 不能把 `multi_thread_mapping`、优化 effort 或关闭并行映射误写成随机种子控制；它们会改变实现策略，且没有字节一致性证明。
3. 在没有 TD 官方参数文档、工具补丁或两次字节一致干净构建前，`reproducible_build_package` 继续保持 `BLOCKED`。

## 证据边界

- 本记录是 `project` 静态工具链审计，不是新的 TD/STA/Bitgen 构建结果。
- 已有重复构建证据仍以 [`docs/evidence/industrial-v2-g8-fixed-seed-reproducibility.md`](../evidence/industrial-v2-g8-fixed-seed-reproducibility.md) 和单线程探针为准。
- 本次没有修改 IP、PLL、管脚、约束或正式候选 Bitstream，也没有放宽发布门禁。

## 下一步

若要继续关闭该门禁，只接受以下证据之一：取得 TD 官方文档中完整随机控制接口并固定所有相关参数，或在同一干净输入、同一工具和完整参数记录下得到至少两次 SHA-256 完全一致的 Bitstream。
