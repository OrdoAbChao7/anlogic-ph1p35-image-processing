# Industrial Vision V2 Roadmap

| Phase | Scope | Depends on | Exit state |
|---|---|---|---|
| V2-G0 | V1 保护、工具/回归/资源基线、回退制度 | none | ACTIVE |
| V2-G1 | 单击模式、十进制 OSD、ROI 合同和基础质量 | G0 | TD_PASS candidate; physical display/board evidence and G0 baseline scope pending |
| V2-G2 | 单目标跟踪和轨迹显示 | G1, V1 result snapshot | TD_PASS candidate; moving-target and board evidence pending |
| V2-G3 | 输入/处理/显示/结果延迟监视 | G1, frame events | TD_PASS candidate; physical HDMI/latency measurement pending |
| V2-G4 | 固定 ROI 8-bit 帧差运动检测 | G1, resource trial | TD_PASS candidate; moving-target and board evidence pending |
| V2-G5 | 内部分拣事件、一次性脉冲和安全互锁 | G2, G4, classifier | TD_PASS candidate; official GPIO/electrical and physical actuator acceptance pending |
| V2-G6 | 帧统计自适应增益和 AWB 优化 | G1, ISP audit | TD_PASS candidate; SC520CS lighting and board evidence pending |
| V2-G7 | 固定工位标定尺寸和形状验证 | G1, physical calibration | TD_PASS candidate; physical calibration and board evidence pending |
| V2-G8 | 同一 Bitstream 融合、长稳、冻结发布 | G1-G7 | BLOCKED: strict audit remains 7/13 PASS; fix8 stops at PHY-9053 with 22,420/21,216 placed slices and Setup WNS -7,216 ps. Fixed-frame invalid, per-domain reset release, tagged full-frame PROC ledger and AWB cadence now pass RTL/SIM; HDMI video/E2E visibility, PHY warnings, hardware, reproducibility, long-stability and actuator gates remain open |

允许在硬件阻塞期间继续独立软件/RTL 工作，但不得越过依赖把阶段标成 `HARDWARE_PASS`。
