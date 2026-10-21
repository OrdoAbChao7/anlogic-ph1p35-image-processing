# Industrial V2 G8 I2C clock-enable candidate

## 状态

`CANDIDATE_REJECTED_RESOURCE_GATE`。本实验只在隔离 TD 输入包中替换 `uii2c`，未修改当前正式候选包，也未关闭硬件或板级稳定性缺口。

## 目的

验证把 `uii2c` 内部由 fabric 分频得到的 `scl_clk` 事件控制，改为 `I_clk` 域内的 `scl_rise/scl_fall` clock-enable，是否能消除 `u_uicfgcs520/u_i2c/scl_clk` 的混合时钟扇出和 clock-net cascade 告警，同时保持 I2C 事务行为。

## 软件/RTL证据

- 原 vendor 版和 clock-enable 原型均通过同一套 Icarus directed test：单字节写、重复起始后单字节读、ACK 低电平、无 bus error；两者均读回 `8'h00`，外部 `SCL` transition 计数均为 `79`。
- 原始源 SHA-256：`032df05881f9bd7c7cf86cc1381adcb739a18f8a8744ed06b1160ac294a6dc0d`。
- 原型源 SHA-256：`8a2447f3065872c3985a7c74c5de2ecfa32293708f8f3721714f22b7245f6ffb`。

## 隔离 TD 结果

构建使用 TD `6.2.168116`、`--place-seed 1`、官方 `DefaultFlow.tcl`，仅将隔离输入包中的 `uics500_cfg/uii2c.v` 替换为原型。

| 指标 | 结果 |
|---|---:|
| Setup WNS/TNS/violated S-EP | `+100 ps / 0 / 0` |
| Hold WNS/TNS/violated H-EP | `+20 ps / 0 / 0` |
| Slice | `18222/21216 = 85.89%` |
| RAM / DSP / DRAMHARDCON | `43 / 24 / 229` |
| Bitstream | `1367025 bytes` |
| Bitstream SHA-256 | `36ae214e3de2fb1bc7206cb5adecde12a4419cb09c1189dcf2c4f84bb860f233` |

时序和 Bitgen 通过，但 Slice 超过项目动态门限 `<=85%`，因此不替换当前 `80.72%` 的正式 V2 候选。

## Warning 对照

隔离构建最终仅保留：

- `PHY-5060`: `O_cam_24m_syn_3` mixed fanouts of `202 clock pins; 1 data/ctrl pin`。
- `PHY-5079`: `1 clock net(s) utilize the local routing resources`。

原 fixed-seed warning-detail 审计中的 `scl_clk` 混合扇出、`PHY-5016` PLL 到 IO、`PHY-5088` clock-net cascade 在该原型构建中未再出现。上述结果只说明候选拓扑有效，不说明剩余 warning 已关闭。

## 决策

保留候选 Bitstream 和本记录用于后续资源优化；正式包继续使用 `release/candidates/industrial-v2-seed1-current/`。下一步若继续处理 warning，应寻找资源中性、且有官方器件/IP 契约支持的 clock buffer/IO 方案；不得通过放宽资源门限或忽略 `O_cam_24m` 的板级时钟风险来接纳本原型。
