# V2 G8 fixed placement seed reproducibility audit

## 结论

`scripts/build_industrial_td.py --place-seed 1` 已能在隔离 TD 工作区生成 `industrial_v2_fixed_seed.tcl`，并在 `opt_place` 的可编辑区注入：

```tcl
set_param place seed 1
```

两次使用相同源码、TD 可执行文件、DefaultFlow、输入包和 `--place-seed 1` 的完整 synthesis → physical design → STA → Bitgen 构建均通过最终 QoR 门，但最终 Bitstream 不一致。因此 placement seed 只能作为可追踪的构建输入，当前不能作为“Bitstream 完全可复现”的充分条件。

## 构建条件

| 项目 | 值 |
|---|---|
| Worktree | `E:/Projects/FPGA-v2` |
| Branch | `goal/industrial-v2-advanced` |
| TD | `E:/Projects/FPGA/.tools/td/app/bin/td_commands_prompt.exe` |
| Flow | `E:/Projects/FPGA/.tools/td/app/doc/scripts/DefaultFlow.tcl` |
| Input package | `fallback/td_package` |
| Placement seed | `1` |
| 输出 | `camera_to_dsi_display_compress.bit` |

## 两次结果

| Run | Final Bitstream size | SHA-256 | Slice | Setup WNS | Hold WNS | TNS |
|---|---:|---|---:|---:|---:|---|
| `industrial-v2-seed1b` | 1,370,993 bytes | `09d2995c3cd149c442fa091be409a362b202243c29b74d624d40a073f076ef71` | 17,186 / 21,216 (81.00%) | +103 ps | +20 ps | 0 / 0 |
| `industrial-v2-seed1c` | 1,369,841 bytes | `42fd98c2c2643906f130a1ba8edb385ef0c34639466d1cdd9e45e05b6953dceb` | 18,260 / 21,216 (86.07%) | +105 ps | +20 ps | 0 / 0 |

两次均为 `RAM 43`、`DSP 24`、`DRAMHARDCON 229`，最终 QoR gate 为 PASS；但 `bitstream_sha256` 和 Slice 结果均不同，`bit_equal=false`。

## 证据边界

- 这是 TD 工具链的项目级重复构建证据，不是硬件下载、上电、摄像头、HDMI 或长稳证据。
- 该实验未修改 IP、PLL、管脚约束或时序例外。
- 两个临时候选目录只用于提取报告和校验值，不提升 `release/industrial-v2/` 状态，也不替代正式候选 `release/candidates/industrial-v2-formal-feature-spine/`。
- 后续若要关闭可复现构建门禁，需要识别 TD 仍受 seed 影响的其他随机源或固定完整工具/运行环境，并以至少两次字节级一致的干净构建为证据。

## 后续当前源码运行

在同一当前源码和官方 `DefaultFlow.tcl` 上再次使用 `--place-seed 1` 完成了 TD/STA/Bitgen：Slice `17125/21216 (80.72%)`、Setup WNS `+104 ps`、Hold WNS `+20 ps`、TNS `0/0`，Bitstream SHA-256 为 `d6e6a7e12ef7558834904dcc8d2783d5fda827b7fe11c6e407b0119fc3ce1c0d`。该运行满足资源/时序目标，但没有改变已有结论：固定 seed 仍不是字节级可复现证明，必须继续保留 `OPEN`。
