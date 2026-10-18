# Industrial V2 Stage D hash repair

## 结论

Stage D 的唯一失败项是插件文件的字节哈希不一致，不是算法或参数不一致。registry 保存的 `model_sha256` 与 Git blob SHA-256 相同；工作树插件因 CRLF 行尾产生了不同字节哈希。将 `work/algorithm_lab/plugins/industrial_inspection.py` 规范为 LF 后，未改变 Git 内容或算法逻辑，Stage D 验证通过。

## 证据

- Registry expected SHA-256：`ef929f28a9a6790247df8c44b79fff74ddbd91aa152ea51bb3bf0a703f253713`
- 修复前工作树 SHA-256：`08f929d45e1ffdab60cc12fd74b2c21b95bf1f74d4b3658f56739202e3f095bb`
- 修复后工作树 SHA-256：`ef929f28a9a6790247df8c44b79fff74ddbd91aa152ea51bb3bf0a703f253713`
- Git blob SHA-256：`ef929f28a9a6790247df8c44b79fff74ddbd91aa152ea51bb3bf0a703f253713`
- 命令：`python -B work/algorithm_lab/verify_stage_d.py`
- 结果：`pass: true`
- 五个 Stage D 样本的 raw/processed mask 均逐像素一致，`different_pixels=0`、`MAE=0`、`PSNR=inf`，判定、BBox、宽高、面积和 ROI 指标一致。

该修复只消除跨平台 checkout 的字节表示差异，不构成硬件、TD 或视觉效果验收；报告仍明确为 software-only hardware-equivalent verification。
