# Industrial Vision V2 result-domain CDC

## 结论

新增 `industrial_v2_result_cdc`，采用 source-domain 稳定负载、toggle 同步、destination-domain 双级负载采样和延后一拍发布的合同，把 BBox、标定、运动、分拣状态和计数传到 HDMI 域。

正常事件之间留有一个目的时钟域处理窗口；事件在待发布期间再次到达时输出 `O_dst_overflow`，不会静默宣称结果完整。

## 验证

- 合同测试：`work/tests/test_v2_result_cdc_contract.py`，`2 passed`。
- 双时钟 RTL：`fallback/sim/integration/tb_industrial_v2_result_cdc.v`。
- 结果：编译无告警，输出 `TB_INDUSTRIAL_V2_RESULT_CDC_PASS`。
- 曾发现并修复正常事件被误报 overflow 的确认时点错误；修复后 separated events 和所有负载字段通过。

## 边界

CDC 模块尚未接入 `design_top_wrapper.v` 的正式 OSD/轨迹链路，也未进入 TD `.prj` 源文件清单。双时钟仿真证明的是协议行为，不是 CDC 工具审计、综合时序或上板事实。
