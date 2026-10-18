# Industrial V2 G8：单线程固定 seed 可复现性探针

## 目的

验证 TangDynasty 在固定 `place seed=1` 且将 `flow/gate/place/route` 线程参数限制为 `1` 后，是否能对同一份 V2 源码生成字节级一致的 Bitstream。该实验只验证构建复现性，不改变正式 `release/industrial-v2/` 候选包，也不替代硬件验收。

## 环境与输入

- 日期：2026-10-19
- 工作树：`E:/Projects/FPGA-v2`
- Git commit：`1cbee61df71612517198729261e525d5fcb76b5e`
- 器件：`PH1P35MDG324`
- TD executable：`E:/Projects/FPGA/.tools/td/app/bin/td_commands_prompt.exe`
- 输入工程包：`fallback/td_package`
- 视频 RTL：`fallback/rtl/video/video_cartoon_region_fill.v`
- Flow：由官方 `DefaultFlow.tcl` 的 editable zones 派生；在综合、布局、布线和 Bitgen 对应步骤注入 `set_param flow thread 1`，并在 gate/place/route 步骤分别注入对应的 `set_param`。
- 位置 seed：`1`

两次构建使用相同的源码、Flow、输入包、seed 和单线程参数，但使用独立的 TD work project：

```text
release/candidates/industrial-v2-thread1-after-commit/
work/td_industrial_v2_thread1_after_commit/

release/candidates/industrial-v2-thread1-after-commit-2/
work/td_industrial_v2_thread1_after_commit_2/
```

日志中确认了 `set_param flow thread 1`、`set_param place thread 1`、`set_param route thread 1`，并出现 `Global iterations in 1 thread`。

## 结果

| 构建 | Bitstream SHA-256 | 大小 | Slice | Setup WNS | Hold WNS | TNS | Bitstream 字节一致 |
|---|---|---:|---:|---:|---:|---:|---|
| thread1-after-commit | `139499ea5e9bfd6bc99f7502d92ea81f53786b3d366631daf81a3c9f5da52dea` | 1,369,777 | 18,363/21,216 = 86.55% | +112 ps | +20 ps | 0 | — |
| thread1-after-commit-2 | `da63492d7b8c28e29487c2087e847dc88589cc44f956547d02645fc0f75287b5` | 1,364,145 | 18,285/21,216 = 86.18% | +108 ps | +20 ps | 0 | 否 |

两次构建均完成 TD synthesis、implementation、timing 和 Bitgen；两次 `route.qor` 的时序端点均为零违例。但两个文件的大小和 SHA-256 不同，逐字节比较结果为 `false`。两次 Slice 占用也都超过项目的 `≤85%` 初始资源门限，因此不能作为正式发布候选。

## 结论与影响

- `project`：在本派生 Flow 中，单线程参数已实际生效，不能再把“TD 默认多线程”作为当前唯一的复现性解释。
- `project`：即使固定 seed 和单线程，两个独立 work project 仍未得到字节级一致的 Bitstream；G8 的 reproducible build gate 继续保持 `OPEN`。
- `project`：该探针没有改善资源门限，最好结果仍是 86.18%，未晋级正式包。
- `unknown`：尚未定位 TD 内部仍影响 Bitstream 的非确定性来源，也未证明官方发布流程可以通过额外数据库/环境冻结达到字节级复现。
- `measured`：无板卡、摄像头、HDMI、冷启动、长稳或执行器证据；本实验不能推出任何硬件结论。

正式候选包 `release/industrial-v2/` 保持不变，仍为 `CANDIDATE_ONLY`。下一步仍需关闭复现性、PHY warning/CDC、硬件功能矩阵、性能追溯、冷启动长稳、可重建发布包和外部执行器验收。
