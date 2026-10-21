# CURRENT_STATE

更新：2026-10-21（板级故障调查暂停，等硬件）
入口：先读 `INDEX.md`（位流总表 + 目录结构），再读本文。

---

## 一句话

**时序收敛已完成并冻结（R2，+644 ps），但板测发现视频闪烁与 OSD 字体缺陷；
闪烁已通过 D0 旁路消除，字体缺陷已修复为 D1，两者均未最终定案，且硬件暂时不可用。**

---

## 状态阶梯

| 级别 | 状态 |
|---|---|
| RTL_VERIFIED（E1/E2/E4） | **YES** — 三项逐周期差分 0 mismatch |
| RTL_VERIFIED（D1 字体修复） | **YES** — 黄金测试 + 对照组 |
| TIMING_PASS（R2） | **YES** — +644 ps / 0 违例 |
| BITSTREAM_READY（R2/D0/D1） | **YES** — 三份位流均已生成 |
| READY_FOR_BOARD_TEST | **部分** — R2 已证明**不可用**（闪烁） |
| HARDWARE_PASS | **NO** — 无任何通过硬件验收的版本 |

## 版本状态

| ID | 时序 | 板测 | 结论 |
|---|---|---|---|
| V1 | +103 ps | 正常 | 参照物，非本项目产物 |
| R1 | +137 ps | 闪烁 | 已废 |
| R2 | +644 ps | 闪烁 | **不得标记 HARDWARE_PASS** |
| D0 | +103 ps | 不闪；遥测 N/A；字体缺陷 | 诊断用，机制未定 |
| D1 | +121 ps | 未测 | 诊断用，待测 |

## 已确认的缺陷（3 项）

1. **闪烁** ← 与 `isp_top` 的 `axis_gain_rgb96` 相关（D0 旁路后消失）。
   机制未证实；静态推演该级应透明；布局因素未排除。
2. **遥测 N/A** ← `design_top_wrapper.v:1231-1237` 把 spine 的整个 HDMI 视频契约接零。
   确定性缺陷，修复安全，但**语义待定**（显示侧无帧标签）。
3. **文字缺笔画 + 错位** ← `industrial_osd_overlay.v` 的 `text_col` 只取 0..3，
   字形 bit0 永不选中。**V1 同样存在**，非 V2 回归。D1 已修复并通过黄金测试。

## 已排他

- 不是 E4（R1 无 E4，现象相同）
- 不是板级/线缆/摄像头/显示器（同硬件 V1 正常）
- 不是 HDMI 输出通路（OSD/Logo 稳定）
- 不是常规时序违例（四版全部收敛 0 违例）
- 不是 DDR IP/约束/引脚差异（与 V1 逐字节相同）

## 未提交状态

D0/D1 相关改动、冻结文档、INDEX 均**尚未提交**（本轮结束时一并提交）。

## 工具

- TD 6.2.168116（`E:\Projects\FPGA\.tools\td\app\bin\td_commands_prompt.exe`）
- ModelSim-Intel Starter 2020.1
- 运行器：`run_full_route.ps1 -Exp <dir>`、`run_bitgen.ps1 -Exp <dir>`（带时序门禁）
- `check_timing`：Routed DB 可跑；Gate DB 与"import_db 后改约束"会崩 `0xC0000005`，勿重试
- 厂商 `PH1P_LOGIC_ERAM` 模型在 ModelSim Intel 2020.1 下无法 elaborate
  （`Unresolved reference to 'PH1P_PHY_GSR'`），检测器类仿真须用
  `+define+MORPH_SIMULATION`
