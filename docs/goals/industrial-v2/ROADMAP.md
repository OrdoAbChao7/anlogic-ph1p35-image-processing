# Industrial Vision V2 Roadmap

| Phase | Scope | Depends on | Exit state |
|---|---|---|---|
| V2-G0 | V1 保护、工具/回归/资源基线、回退制度 | none | ACTIVE |
| V2-G1 | 单击模式、十进制 OSD、ROI 合同和基础质量 | G0 | BLOCKED: SOFTWARE_PASS/RTL_PASS; TD/HARDWARE pending |
| V2-G2 | 单目标跟踪和轨迹显示 | G1, V1 result snapshot | BLOCKED: SOFTWARE_PASS/RTL_PASS; top/TD/HARDWARE pending |
| V2-G3 | 输入/处理/显示/结果延迟监视 | G1, frame events | BLOCKED: SOFTWARE_PASS/RTL_PASS; top/TD/HARDWARE pending |
| V2-G4 | 固定 ROI 8-bit 帧差运动检测 | G1, resource trial | BLOCKED: SOFTWARE_PASS/RTL_PASS; top/TD/HARDWARE pending |
| V2-G5 | 内部分拣事件、一次性脉冲和安全互锁 | G2, G4, classifier | BLOCKED: SOFTWARE_PASS/RTL_PASS/virtual actuator; GPIO/TD/HARDWARE pending |
| V2-G6 | 帧统计自适应增益和 AWB 优化 | G1, ISP audit | BLOCKED: SOFTWARE_PASS/RTL_PASS; ISP/top/TD/HARDWARE pending |
| V2-G7 | 固定工位标定尺寸和形状验证 | G1, physical calibration | NOT_STARTED |
| V2-G8 | 同一 Bitstream 融合、长稳、冻结发布 | G1-G7 | NOT_STARTED |

允许在硬件阻塞期间继续独立软件/RTL 工作，但不得越过依赖把阶段标成 `HARDWARE_PASS`。
