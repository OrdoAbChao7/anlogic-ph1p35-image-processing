# 到板前准备包

本目录用于安路 PH1P35 题目二的到板前准备。它不替代仓库 `docs/research/` 中的来源、缺口与 Goal 阅读记录，也不表示视频链路已经通过硬件验证。

## 使用顺序

1. 按 [`01-baseline-audit.md`](01-baseline-audit.md) 核对官方资料、原始工程和构建环境。先阅读仓库 `docs/research/INDEX.md`、`sources.yaml`、`known-gaps.md` 与 Goal 1 阅读清单。
   已找到的来源、页码、冲突与取得状态汇总在 [`05-source-ledger.md`](05-source-ledger.md)；官方分享目录的具体文件名见 [`06-package-manifest.md`](06-package-manifest.md)。
2. 用 [`02-interface-contract.md`](02-interface-contract.md) 记录实际工程中的视频、时钟、复位及帧缓存接口。未知项写“待确认”，附证据位置。
3. 按 [`03-algorithm-contract.md`](03-algorithm-contract.md) 统一软件模型、RTL 和演示判定规则。此处提供候选算法定义，只有确认视频格式和插入点后才能冻结。
4. 运行仓库 `work/models/reference_model.py` 检查与板级接口无关的 8 位灰度算法。脚本也能用 `--input` 读取 PGM 测试图并输出结果。
5. 到板后执行 [`04-bringup-and-demo.md`](04-bringup-and-demo.md)，先复现官方视频闭环，再推进算法接入。

在仓库根目录运行：

```powershell
python .\work\models\reference_model.py --self-test
python .\work\models\reference_model.py --input .\work\models\step.pgm --out-dir .\work\output --threshold 128 --edge-threshold 128
```

第二条命令在 `work/output/` 生成 `binary.pgm`、`sobel.pgm`、`edge_binary.pgm` 和 `stats.json`。它是本地临时结果目录，无须纳入交付。

## 当前边界

2026-10-02 更新：用户已购 SC520CS；当前目标及 TD 6.2.1 的 SC520 Lab1 软件构建记录见 [`../docs/setup/tangdynasty.md`](../docs/setup/tangdynasty.md)。以下 2026-09-26 盘点文字保留为历史快照。

2026-09-26 盘点结果：本地已有比赛指南快照，已定位 HX1P35A 资料包的公开分享入口、目录清单及 传感器产品规格；工作区尚无官方工程、RTL、约束、IP 配置或构建报告。网盘只核到了在线文件名，资料包仍标为未取得。具体证据见 `01-baseline-audit.md`。

 - 本包不填写 SC520CS 寄存器、RAW 位宽、Bayer 顺序、Lane 数量、IP 端口、DDR 布局、PLL、HDMI 或管脚参数。
 - `work/models/reference_model.py` 只处理明确约定的 8 位灰度图；它不是摄像头 ISP 模型，也不证明 RTL 或 PH1P35 的行为。
- 本包中的表格是待填写模板。每条结论需标注 `official`、`project`、`measured`、`reference`、`inferred` 或 `unknown`，并附文件、页码或实验记录。

## 到板前可交付判据

- 官方原始工程与资料有清单、版本和来源；可复建所需文件已辨认。
- 视频接口每一段均已标记“已证实”或“待确认”，没有猜填硬件参数。
- 软件模型可对测试图输出确定结果；算法公式、边界和阈值有同一份定义。
- 已备好目标类别样本、空场/多目标样本、照明方案及检测记录表；WM8978 和语音 ROM 仍待确认。

## 到板后第一个阶段门

官方基线工程能重复构建、下载，并在冷启动、热复位后稳定显示实时画面；构建日志、关键告警、分辨率与帧率证据齐全。未通过前不将算法接入板级主链路。
