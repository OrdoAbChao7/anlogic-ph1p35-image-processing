# Industrial Vision V2 G7 RTL 定点标定与形状判定

日期：2026-10-19（Asia/Shanghai）  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`

## 目标

实现 `dimension_calibrator.v`：输入 inclusive BBox、面积、X/Y Q16.16 比例和冻结的尺寸/形状阈值，输出毫米定点尺寸、occupancy、aspect、dimension_valid 和 shape_valid。

## TDD 证据

先只编译 testbench，得到预期 RED：

```text
fallback/sim/inspection/tb_dimension_calibrator.v:22: error: Unknown module type: dimension_calibrator
```

加入 RTL 后运行：

```text
E:/Projects/FPGA/.tools/iverilog/bin/iverilog.exe -g2012 -Wall -s tb_dimension_calibrator -o <temp>/v2-g7-cal-green.vvp fallback/sim/inspection/tb_dimension_calibrator.v fallback/rtl/inspection/dimension_calibrator.v
E:/Projects/FPGA/.tools/iverilog/bin/vvp.exe <temp>/v2-g7-cal-green.vvp
```

结果：

```text
TB_DIMENSION_CALIBRATOR_PASS
```

## 覆盖与结论

- X/Y 独立比例、inclusive BBox、Q16.16 尺寸输出、occupancy=256 的满框和 aspect 计算通过。
- 欠/超尺寸、面积占比不足、未标定、反向 BBox 和复位均按契约拒绝有效结论。
- 该模块只做单目标、轴对齐 BBox 的形状门控，不实现多目标连通域和旋转不变测量。

状态：`RTL_PASS`。TD、正式 OSD/主判定接入、真实标定物和现场误差尚未完成。
