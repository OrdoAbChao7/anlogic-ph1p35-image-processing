# Industrial Vision V2 G8 feature spine

## 结论

新增 `industrial_v2_feature_spine`，把 G2-G7 的跟踪、轨迹、延迟、运动、分拣安全、AWB 和标定模块接入同一个明确的帧结果合同，并用独立 Icarus 仿真验证跨模块事件链。

这不是正式 V2 Bitstream 证据。当前 spine 是同一时钟域的候选集成层；正式工程仍需把 CSI/ISP、DDR/HDMI 和外部 GPIO 的时钟域边界分别适配后，才能进入 TD 集成。

## 修正的集成问题

原有 tracker 的 `O_track_valid`、`O_enter` 是结果周期脉冲，若两个结果帧之间存在空闲周期，直接接入分拣控制器会丢失 active 状态。spine 使用 tracker 的持久 `O_state==TRACKING` 作为 level，并从当前 `I_result_valid` 结果生成 `spine_target_enter/exit` 和当前中心坐标，避免依赖空闲周期中的脉冲。

## 验证

- 测试：`work/tests/test_v2_feature_spine_contract.py`，2 项通过。
- RTL：`fallback/sim/integration/tb_industrial_v2_feature_spine.v`。
- 命令：

  `E:/Projects/FPGA/.tools/iverilog/bin/iverilog.exe -g2012 -s tb_industrial_v2_feature_spine ...`

  `E:/Projects/FPGA/.tools/iverilog/bin/vvp.exe work/tests/verification_outputs/industrial_v2_feature_spine.vvp`

- 结果：编译无告警，运行输出 `TB_INDUSTRIAL_V2_FEATURE_SPINE_PASS`。
- 覆盖：跟踪/标定、AWB 中性增益更新、分拣安全脉冲、160x120 帧差、视频 overlay 输出和延迟接口连线。

## 未关闭项

- 未实例化到 `fallback/td_source/isp/isp_top.v` 或正式板级顶层。
- motion grid 和 frame statistics 需要从 96-bit ISP 流建立带坐标、行尾和帧边界的适配器。
- tracker/结果域到 HDMI 域需要显式 CDC；不能把 source-clock spine 的 video ports 直接连接到 HDMI pixel clock。
- 未运行 TD、未生成 Bitstream、未做上板或外部执行机构验收。
