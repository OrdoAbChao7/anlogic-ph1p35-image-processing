# V1 回退说明

V2 候选失败或硬件异常时，回退到 V1 冻结候选，而不是继续使用未绑定的实验位流。

- 冻结基线：`release/candidates/industrial-v1-hx1p35a-pin-correction/camera_to_dsi_display_compress.bit`
- SHA-256：`b483a1ffc30d0b7ae9e8ebef4f31f617d33a53d6784ded8007d5443c51ad80ef`
- 回退状态：V1 基线通过包内哈希复核，但仍需按现场接线和下载记录执行硬件确认。

V2 候选与 V1 回退不能混用报告、Bitstream SHA 或硬件结论。完整 V1 资料仍在仓库 `release/candidates/` 和 `docs/evidence/`。
