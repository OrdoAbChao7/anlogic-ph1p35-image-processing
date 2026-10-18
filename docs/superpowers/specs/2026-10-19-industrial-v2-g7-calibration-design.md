# Industrial Vision V2 G7 尺寸标定与形状验证设计

日期：2026-10-19  
工作区：`E:/Projects/FPGA-v2`  
分支：`goal/industrial-v2-advanced`

## 目标与边界

G7 为当前 BBox/Area 结果增加可追溯的 X/Y 像素到物理单位定点换算，以及有限、可解释的单目标形状合法性检查。没有真实工位距离、参考物和实测样本前，不宣称毫米级测量或现场标定完成。

## 标定合同

- 采用独立 X/Y 比例 `scale_x_q16_16`、`scale_y_q16_16`，单位为 mm/pixel 的 Q16.16；不假定横纵比例相同。
- 软件模型用已知参考长度和像素长度计算比例；RTL 只消费冻结后的比例，不执行复杂标定拟合。
- BBox 端点均为 inclusive，`width_px=xmax-xmin+1`、`height_px=ymax-ymin+1`。
- 输出 `width_mm_q16_16`/`height_mm_q16_16`；任何 OSD 必须后续明确标注 `px` 或 `mm`，不得混用。

## 形状合同

- `bbox_area=width_px*height_px`。
- `occupancy_q8=min(256, area_px*256/bbox_area)`，用面积/BBox 面积占比排除明显稀疏红色干扰；256 表示 100%。
- `aspect_q8=min(65535, width_px*256/height_px)`，用固定上下界限制适用姿态。
- `dimension_valid` 要求 X/Y 物理尺寸均落在独立 nominal±tolerance 内；`shape_valid` 同时要求 occupancy/aspect 通过。
- 这是单目标、轴对齐 BBox 合法性检查；不宣称连通域分离、多目标可靠分割或旋转不变尺寸。

## RTL 边界

`dimension_calibrator.v` 在 `I_result_valid` 事件上输出一次摘要。`I_calibration_valid=0`、空/反向 BBox 或零尺度输出 `invalid`，不产生有效毫米结论。模块不修改已有 PASS/NG 主判定，也不接入未知 OSD/顶层。

## 验证门

覆盖 X/Y 独立比例、inclusive 边界、正常尺寸、欠/超尺寸、面积占比失败、宽高比失败、非法标定和复位。真实参考物、旋转、光照、ROI 边界和统计误差留给硬件实验门。
