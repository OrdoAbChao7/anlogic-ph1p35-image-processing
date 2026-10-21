# Industrial Vision V2 G4 motion counter-width A/B

日期：2026-10-19（Asia/Shanghai） | 工作区：`E:/Projects/FPGA-v2` | 器件：`PH1P35MDG324` | Tang Dynasty：`6.2.168116`

## 目的与变更

将 `motion_diff_160` 的帧内运动计数累加器及其最终加法结果从接口宽度 `COUNT_WIDTH` 改为：

```text
MOTION_ACCUM_WIDTH = min(COUNT_WIDTH, ceil(log2(IMG_WIDTH*IMG_HEIGHT + 1)))
```

默认 160×120 网格最多计数 19,200 个样本，因此需要 15 位。模块和 feature spine 的外部运动计数接口仍为 24 位；帧差、阈值、坐标框和有效语义没有改变。

## RTL 回归

新增 `fallback/sim/inspection/tb_motion_diff_160_full_scale.v`。测试先检查 15 位内部资源契约和 24 位外部接口，再发送两帧完整网格：首帧建立基线，下一帧令全部 19,200 个像素超过阈值。

按 TDD 顺序，在 RTL 修改前运行测试，得到预期失败：

```text
motion accumulator width=24 expected=15
```

修改后结果：

```text
TB_MOTION_DIFF_160_FULL_SCALE_PASS count=19200 width=15
TB_MOTION_DIFF_160_PASS
143 passed in 1.22s
```

满网格测试同时确认运动框为 `x=0..159, y=0..119`，计数没有截断；已有小网格阈值、空帧、复位和非法坐标回归保持通过。完整 Python 回归命令为 `python -B -m pytest -q work/tests -p no:cacheprovider`。

## 隔离 TD A/B

两边均以提交 `3314966f675473039e804e8515f9844c4ba287c3` 为其他 RTL 基线，使用同一输入包 `fallback/td_package`、同一 `DefaultFlow.tcl`、同一 TD 版本/器件和 `--place-seed 1`，各完成一次正式顶层综合、Place/Route、STA 和 Bitgen。基线计数器来自该提交的 `HEAD:fallback/rtl/inspection/motion_diff_160.v`（Git blob `eaf60b2c0b002445dcf3d5498fc27daeb0224c3d`，SHA-256 `6c57628a94c4118319ed2dac7f4c7412fce0a319850e87f9b0a6056c7551ccd6`）；候选源码 SHA-256 为 `f53426763f1d45a860b6c0083f020c2ac3da4bef4765e30190074085796682b3`。两份 TD `user_source` 各有 219 个文件，哈希核对确认只有 `motion_diff_160.v` 不同。

| 指标 | 24-bit 基线 | 15-bit 候选 | 候选变化 |
|---|---:|---:|---:|
| RTL basic gates | 64,759 | 64,692 | −67 |
| RTL DFF | 18,367 | 18,367 | 0 |
| RTL LUT | 4,530 | 4,530 | 0 |
| Route slices | 18,266 / 21,216 (86.10%) | 18,040 / 21,216 (85.03%) | −226 slices / −1.07 个百分点 |
| Route wire length | 4,651,536 | 4,600,112 | −51,424 |
| Setup WNS / TNS / failed endpoints | +101 ps / 0 / 0 | +102 ps / 0 / 0 | 通过 |
| Hold WNS / TNS / failed endpoints | +20 ps / 0 / 0 | +20 ps / 0 / 0 | 通过 |
| RAM / DSP / DRAMHARDCON | 43 / 24 / 229 | 43 / 24 / 229 | 不变 |
| Bitstream size | 1,368,049 bytes | 1,367,537 bytes | −512 bytes |
| Bitstream SHA-256 | `18e103c7d6be76fa8ed49b60d3e1c5080be790ab6e02cb40b20c3afb37ecc24c` | `c745f322d6b4ae984519867067f30db0edf398f5c2f542c80088eb4771d8030e` | 不同 |

两个 route QoR gate 均通过。完整构建日志、综合/布线 flow 日志、RTL area、route QoR、final timing 和 provenance manifest 保存在：

- 基线：`release/candidates/industrial-v2-g4-motion-count-width-ab/baseline/`
- 候选：`release/candidates/industrial-v2-g4-motion-count-width-ab/candidate/`

每个目录都保留 `build.log`、`syn_flow_exec.log`、`phy_flow_exec.log`、`camera_to_dsi_display_rtl.area`、`route.qor`、`final_timing.rpt`、Bitstream 和 manifest。

## 告警与边界

两边保留相同的综合/实现告警类别。关键时钟告警仍包括 `PHY-5060`（`scl_clk` 和 `O_cam_24m_syn_3` 混合时钟/数据扇出）、`PHY-5079`（一个时钟网使用 local routing）、`PHY-5016` 和 `PHY-5088`；没有屏蔽或关闭告警。两边完整 `build.log`、`syn_flow_exec.log`、`phy_flow_exec.log`、`camera_to_dsi_display_rtl.area` 和 route/final timing 报告均保存在各自候选目录。

这是同 seed、单次/每臂的受控顶层 A/B。工具的布局布线存在运行敏感性，因此 226 slices 是本次实测差值，不作为可重复性或最终发布收益保证；当前 15 位 Bitstream 仅是 G4 对照候选，没有替换 `release/industrial-v2/` 或冻结 V1，也没有上板。冷启动、真实运动场景、HDMI 显示和长稳仍待硬件验收。
