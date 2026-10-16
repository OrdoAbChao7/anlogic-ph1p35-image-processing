# 实验记录：工业视觉 Algorithm Lab 契约补全与回归

**日期**：2026-10-16
**工作区**：`E:\Projects\FPGA-fallback`
**分支**：`fallback/industrial-inspection`，HEAD `651f9bc`；工作区原有脏改动保留
**阶段**：Software-First Stage B/C，当前仍为 `VISUAL_REVIEW_PENDING`

## 1. 本次变更

- 在 `plugins/industrial_inspection.py` 为 Visual Reference 和 Hardware-equivalent 两条路径加入相同 ROI 契约：`roi_x/roi_y/roi_width/roi_height`。四项均为 0 时表示整帧；越界、负数、非整数或不完整零尺寸返回 `INVALID`，不静默裁剪。
- 目标在 ROI 内检测后，将包围盒坐标偏移回整幅图坐标，并在预览图上显示 ROI 边界。两条模型路径共享相同 ROI 语义。
- 在 `app.py` 增加参数预设保存、列表和加载 API，预设存放在 `work/algorithm_lab/configs/<algorithm_id>/`；不修改 `registry.json` 的批准状态。
- 在 `static/index.html` 增加参数预设控件。现有批准按钮保留，但本次没有调用 `/api/approve`，也没有设置 `VISUAL_APPROVED`。
- 将工业视觉登记册的许可证描述改为 `Mixed/see source audit (reference-only)`，并把当前参考 RTL/Testbench 路径改为 Fallback v2 对应文件，避免把 6 个来源误标为统一 MIT。

## 2. 可复现命令与结果

在 Fallback 工作区执行：

```powershell
python -m unittest work/algorithm_lab/test_industrial_contract.py -v
python work/algorithm_lab/test_industrial_inspection.py
python -m py_compile work/algorithm_lab/app.py work/algorithm_lab/plugins/industrial_inspection.py work/algorithm_lab/test_industrial_contract.py
```

结果：

- 新增契约测试 `4/4 PASS`：ROI 坐标回映射、非法 ROI、整帧兼容、参数预设保存/加载。
- 工业视觉样本回归 `5/5 PASS`，Visual Reference 与 Hardware-equivalent 判定及尺寸一致。
- Python 语法检查通过；页面内嵌 JavaScript 使用 Node `vm.Script` 检查通过。
- API 端到端处理返回 HTTP `200`；在 `500,250,300,200` ROI 下，参考模型和硬件等价模型均返回 `PASS`，坐标为 `x=580..700, y=320..400`。

完整 Algorithm Lab 回归共 14 项，其中工业视觉、基础算法和新增契约测试通过；4 项 YOLO 测试因缺失既有外部资产而报错：`work/y1_yolo/FastestDet/example/onnx-runtime/coco.names` 与本地 `work/algorithm_lab/yolov8n.pt`。这不是本次工业视觉变更引入的失败。

## 3. 仍未关闭的证据与风险

- 没有用户的视觉审查确认，因此不能进入新的正式 RTL/整机视频集成，也不能把现有离线 TD 位流写成板级通过。
- `fallback/rtl/color_detect_96_v2.v` 的 `O_area[18:0]` 不能覆盖 1280×720 全帧面积；其 `CR_MAX=240` 与当前软件模型 `cr<200` 的边界契约仍不一致。
- Fallback TD 最终报告为 Setup WNS `+221 ps`、Hold WNS `+20 ps`，但仍存在 `PHY-5079`/`PHY-5088` 时钟告警；构建脚本含外部工程绝对路径，干净环境重建尚未证明。
- ROI 仍是像素坐标，不是毫米。必须先完成固定物距/镜头条件下的标定，才能讨论物理尺寸误差。
- Playwright 浏览器检查因本机未安装 Chrome 未完成；后端 API 和静态脚本语法已检查，尚不等同于用户在浏览器中的视觉批准。

## 4. 下一阶段入口与退出条件

用户在 Algorithm Lab 中检查原图、Visual Reference、Hardware-equivalent、ROI 和参数预设效果，并明确回复 `VISUAL_APPROVED` 后，才可进入 Stage D 的硬件等价模型冻结与 RTL/视频集成。批准前只允许修正软件预览、测试和文档，不修改正式视频链路。
