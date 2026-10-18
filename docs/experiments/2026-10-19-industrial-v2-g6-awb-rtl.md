# Industrial Vision V2 G6 RTL 帧统计增益控制器

日期：2026-10-19（Asia/Shanghai）  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`

## 目标

实现独立 `awb_frame_gain_controller.v`，接收帧完成后的 RGB sums、pixel count 和 mean luma，在帧边界更新 Q8.8 R/G/B 增益。模块不接传感器 I2C，也不替换现有厂商 AWB 顶层。

## TDD 证据

先只编译 testbench，得到预期 RED：

```text
fallback/sim/isp/tb_awb_frame_gain_controller.v:14: error: Unknown module type: awb_frame_gain_controller
```

加入 RTL 后运行：

```text
E:/Projects/FPGA/.tools/iverilog/bin/iverilog.exe -g2012 -Wall -s tb_awb_frame_gain_controller -o <temp>/v2-g6-awb-green.vvp fallback/sim/isp/tb_awb_frame_gain_controller.v fallback/rtl/isp/awb_frame_gain_controller.v
E:/Projects/FPGA/.tools/iverilog/bin/vvp.exe <temp>/v2-g6-awb-green.vvp
```

结果：

```text
TB_AWB_FRAME_GAIN_PASS
```

## 行为结论

- Q8.8 初值 256，R/B 目标增益限幅 128–512，G 保持 256。
- 同一 `I_frame_stats_valid` 事件中原子更新下一帧增益，暗场、过亮场、空统计和亮度突变保持旧值并报告 `scene_protected`。
- 每帧最大步长 8，测试覆盖蓝色偏色、连续平滑、暗场、场景跳变和空统计。
- 该 RTL 只证明控制器的固定点/帧边界行为，不证明原有 `awb.v` 已被替换，不证明 TD 资源或真实画面改善。

状态：`RTL_PASS`。TD、正式顶层、真实光照视频和传感器控制仍未完成。
