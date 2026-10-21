# INDEX — Industrial V2 工程结构与版本身份

本文件是本工作树（`E:\Projects\FPGA-ds-timing`，分支 `ds/industrial-v2-timing-closure`）的入口。
回来的第一件事读这里，然后读 `CURRENT_STATE.md` 与 `NEXT_ACTION.md`。

---

## 1. 位流总表（唯一权威清单）

| 编号 | 磁盘文件名 | SHA-256（未压缩） | 整机时序 | 上板实测状态 |
|---|---|---|---|---|
| **V1** | `industrial-v1-...` 包内 `camera_to_dsi_display_compress.bit` | `B483A1FF…51AD80EF` | +103 ps / 17,642 slice | **正常**（用户实测） |
| **R1** | `camera_to_dsi_display_R1.bit` | `ADD2DC46403670C279CADCE2E051F79B83EA9F2BBD1F4E78E7FBB7EB5606BC8C` | +137 ps / 18,248 | **闪烁**（用户实测） |
| **R2** | `camera_to_dsi_display.bit` | `E6BA3DA87DABF82907F3DB1B4FAC18A9E8350A43917F3D5E6DA64A0A35617C36` | +644 ps / 18,233 | **闪烁**（用户实测） |
| **D0** | `camera_to_dsi_display_d0.bit` | `BFAA29F9298B7B5DE664771183D631E55199DFB85676E25A092007A994A22BEC` | +103 ps / 17,943 | **不闪**；遥测 N/A、字体缺陷（用户实测） |
| **D1** | `camera_to_dsi_display_d1.bit` | `031F5DAB2828EA5856EEC3B234116A56A87711F5B031252DFBCD449CB34DE9B6` | +121 ps / 18,091 | **未测** |

压缩变体同目录 `*_compress.bit`。所有包内均有 `SHA256SUMS`，可 `sha256sum -c`。

## 2. 目录结构

```
E:\Projects\FPGA-ds-timing\
├─ INDEX.md                     ← 本文件
├─ CURRENT_STATE.md             当前状态与未完成项
├─ NEXT_ACTION.md               复工时的具体动作
├─ BASELINE.md                  冻结基线身份
├─ TIMING_BASELINE.md           基线时序报告分析
├─ EXPERIMENTS.md               E1..E5 / D0..D1 实验记录
├─ run_full_route.ps1           整机 syn→place→route 运行器
├─ run_bitgen.ps1               带时序门禁的 bitgen 运行器
├─ assemble_e3.sh / assemble_e5.sh
├─ docs/evidence/
│   ├─ industrial-v2-timing-closed-freeze.md      时序收敛冻结报告
│   └─ industrial-v2-board-video-failure-freeze.md 板级故障调查（主记录）
├─ release/
│   ├─ candidate-industrial-v2-timing-closed/      R1（回退参考）
│   ├─ candidate-industrial-v2-timing-closed-r2/   R2（时序收敛交付候选）
│   └─ diagnostics/
│       ├─ d0b-gain-bypass-on-r2/                  D0
│       └─ d1-osd-font-fix/                        D1
└─ work/
    ├─ awblite_baseline/        冻结基线快照（248 文件，勿改）
    ├─ e1_mipi_bbox_pipe/       E1 MIPI 预计算
    ├─ e2_osd_pipe/             E2 OSD 三级流水
    ├─ e3_integrated/           E3 = E1+E2
    ├─ e4_detect_minmax/        E4 检测器并行组统计
    ├─ e5_detect_parallel/      E5 = E1+E2+E4（R2 源码树）
    ├─ d0_gain_bypass/          ⚠ 作废：错误基线（时序未收敛），仅存证据，勿上板
    ├─ d0b_gain_bypass_on_r2/   D0 源码树
    └─ d1_osd_font_fix/         D1 源码树
```

## 3. Git

| 对象 | 内容 |
|---|---|
| 分支 | `ds/industrial-v2-timing-closure` |
| tag `industrial-v2-timing-closed-freeze-20261021` | 时序收敛交付候选（R2） |
| tag `industrial-v1-hx1p35a-pin-correction-freeze-20261018` | industrial-v1 冻结版 |

## 4. 关键约定（不要破坏）

1. `work/awblite_baseline/` 是冻结基线，**永不修改**；每个实验都是它的完整副本。
2. 每个诊断位流独立目录 + `SHA256SUMS` + 完整 TD 时序结果，**不覆盖 V1/R1/R2**。
3. `run_bitgen.ps1` 会在 `route.qor` 不干净（WNS<0 / TNS≠0 / 违例端点≠0）时**拒绝出位流**。
4. 约束**不得**放宽：SDC 与冻结基线逐字节相同，无 false path / multicycle / 降频。
5. 未上板前，任何版本都不得标记 `HARDWARE_PASS`。
