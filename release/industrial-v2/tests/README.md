# V2 测试快照

本目录是候选冻结时复制的 73 文件测试源快照，不是可直接从该子目录运行的独立 Python 包；其中测试按仓库根目录的 `work/`、`fallback/` 和 `scripts/` 相对布局解析路径。

请从仓库根目录运行当前回归：

```powershell
python -B -m pytest -q work/tests
```

当前根工作树结果为 `135 passed`；包内快照仍对应候选冻结时的 `134 passed`。测试通过只覆盖软件、RTL 合同和发布审计，不代表摄像头、HDMI、冷启动、长稳或执行器已经在硬件上通过。
