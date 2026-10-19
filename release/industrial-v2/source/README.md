# V2 核心源码快照

本目录是候选发布包的源码快照，不是独立于 TD 安装的最终发布包。内容包含：

- `fallback/rtl/`：V2 工业视觉 RTL、集成模块、显示和控制模块；
- `fallback/td_source/`：顶层、ISP、VTC 和 HDMI 适配源；
- `fallback/td_package/`：TD 工程配置、约束和厂商/IP 输入快照。

`source-manifest.json` 记录本目录 249 个文件的大小和 SHA-256。Bitstream 的正式构建仍绑定仓库中的 `scripts/build_industrial_td.py`、TD `v6.2.168116` 和外部器件库；本快照不代表已经完成干净环境重建或硬件验收。
