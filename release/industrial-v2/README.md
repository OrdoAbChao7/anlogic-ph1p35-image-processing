# Industrial Vision V2 candidate package

状态：`CANDIDATE_ONLY`。本目录包含一个七功能 V2 Bitstream、TD 报告、构建 Flow 和 provenance manifest；它不是最终硬件发布包。

发布物逐项完整性审计见 [`RELEASE_PACKAGE_AUDIT.md`](RELEASE_PACKAGE_AUDIT.md)。

## 构建绑定

- 目标：`HX1P35A / PH1P35MDG324`
- Tang Dynasty：`v6.2.168116`
- Flow：官方 `DefaultFlow.tcl`
- Placement seed：`1`
- Bitstream：`industrial-v2.bit`
- SHA-256：`d6e6a7e12ef7558834904dcc8d2783d5fda827b7fe11c6e407b0119fc3ce1c0d`
- Slice：`17125/21216 (80.72%)`
- RAM / DSP / DRAMHARDCON：`43 / 24 / 229`
- Setup WNS / Hold WNS：`+104 ps / +20 ps`
- Setup/Hold TNS：`0 / 0`
- Setup/Hold 违例端点：`0 / 0`

## 七项功能验证层级

| 功能 | 软件 | RTL | TD | 硬件 |
|---|---|---|---|---|
| OSD、按键、基础质量 | `SOFTWARE_PASS` | `RTL_PASS` | `TD_PASS` | `HARDWARE_NOT_RUN` |
| 动态跟踪 | `SOFTWARE_PASS` | `RTL_PASS` | `TD_PASS` | `HARDWARE_NOT_RUN` |
| 延迟测量 | `SOFTWARE_PASS` | `RTL_PASS` | `TD_PASS` | `HARDWARE_NOT_RUN` |
| ROI 帧差 | `SOFTWARE_PASS` | `RTL_PASS` | `TD_PASS` | `HARDWARE_NOT_RUN` |
| 分拣控制 | `SOFTWARE_PASS` | `RTL_PASS` | `TD_PASS` | `HARDWARE_NOT_RUN` |
| 自适应白平衡 | `SOFTWARE_PASS` | `RTL_PASS` | `TD_PASS` | `HARDWARE_NOT_RUN` |
| 标定与形状验证 | `SOFTWARE_PASS` | `RTL_PASS` | `TD_PASS` | `HARDWARE_NOT_RUN` |

`python -B -m pytest -q work/tests` 当前为 `132 passed`；Stage D 软件等价模型为 `PASS`。这些结果不等价于板级摄像头、HDMI、LED、冷启动、长稳或机械执行器验收。

## 当前未关闭门禁

- 固定 seed 的重复构建尚未产生字节一致 Bitstream。
- `PHY-5016/PHY-5060/PHY-5079/PHY-5088` 告警和 CDC/IO 约束审计仍开放。
- PH1P35、SC520CS、HDMI 的硬件功能矩阵、性能测量、冷/热复位和长稳测试尚未执行。
- 外部执行器和机械闭环尚未验收。

Stage C 视觉审批按用户指令记录为 `AUTHORIZED`（默认通过）；这不替代上述硬件和构建门禁。详细来源、报告、回退候选和审计结果见 `manifest.json`、`route.qor`、`final_timing.rpt`、`td-reports/` 以及 `docs/goals/industrial-v2/`。
