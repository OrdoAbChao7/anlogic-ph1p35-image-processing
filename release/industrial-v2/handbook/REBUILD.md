# V2 工程复现说明（候选版）

本说明必须从仓库根目录执行，不能把候选包内的报告或 Bitstream 当作重建结果。

## 输入绑定

- 器件：`HX1P35A / PH1P35MDG324`
- TD：`v6.2.168116`
- Flow：`release/industrial-v2/DefaultFlow.tcl`
- Placement seed：`1`
- 输入包：`fallback/td_package/`
- 核心源码：`fallback/rtl/`、`fallback/td_source/`
- 候选包源码快照：`release/industrial-v2/source/source-manifest.json`

## 命令入口

```powershell
python -B scripts/build_industrial_td.py --place-seed 1 `
  --td-exe <TD_INSTALL>\app\bin\td_commands_prompt.exe `
  --flow-tcl <TD_INSTALL>\app\doc\scripts\DefaultFlow.tcl
```

构建必须写入隔离的 `work/` 目录，并在复制发布物前检查 `route.qor`、`final_timing.rpt`、Bitstream SHA-256、源码清单和工作树状态。不得覆盖 V1 冻结目录。

## 当前边界

当前候选 TD/STA/Bitgen 已通过，资源和时序数据见包内报告；重复固定 seed 尚未产生字节一致 Bitstream，因此本说明不能宣称完全可复现。TD 安装、器件库、板卡下载器和硬件验收仍是外部前置条件。
