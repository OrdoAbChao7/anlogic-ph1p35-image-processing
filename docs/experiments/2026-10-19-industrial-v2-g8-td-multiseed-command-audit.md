# Industrial V2 G8：TD MultiSeed 命令审计

## 目的

补充固定 placement seed 可复现性审计，验证 TangDynasty `6.2.168116` 实际可执行文件中暴露的 `set_seed_param`、`report_seed_param` 和 `select_seed` 是否提供 gate、route 或 bitgen 的独立随机种子控制。

## 只读命令证据

在隔离工作目录使用临时 Tcl 查询脚本调用：

```tcl
report_seed_param
```

TD 返回当前 MultiSeed 配置：

```text
Minimum Seed 0
Number of Seeds 10
Save Number 1
Run Jobs 3
End Step bitgen
Seed Step 10
PRJ-1001 : set_seed_param -num 10 -init 0 -step 10 -jobs 3 -save 1 -endStep route -genBit on -random off -filter off -rwns 0 -pwns 0 -congestion 100 -farm off -ip -queue
```

本地官方 `MultiSeed.tcl` 的 `prepare` 过程实际只注入：

```tcl
set_param place seed $seed
```

并在每个 `seed_$seed` 目录执行同一套 `place`、`route` 和 `bitgen`。TD 二进制的命令参数字符串也只显示 MultiSeed 的 seed range、run jobs、filter、random、farm 和 queue 选项，没有独立的 gate/route/bitgen seed 参数。

## 判定

`set_seed_param` 是 MultiSeed 运行配置，不是当前 DefaultFlow 中可证明的完整实现随机源冻结接口；默认 MultiSeed 配置已经是 `random off`。`select_seed` 在没有已运行 seed 时只返回无效 seed 错误，不能用于固定普通 DefaultFlow 的实现结果。

因此，本审计没有找到可以合理加入 `build_industrial_td.py` 的新随机控制参数，也不能关闭字节级 Bitstream reproducibility gate。已有两次独立固定 seed、单线程构建仍产生不同 Bitstream 的实测证据继续有效。正式候选和构建流程未修改。

## 证据边界

- 这是本机 TD 可执行文件、官方 Flow 和只读命令输出的 `project` 证据。
- 未把二进制字符串误写成官方支持的 gate/route/bitgen seed API。
- 没有执行新的综合、布局布线、Bitgen 或硬件下载。
