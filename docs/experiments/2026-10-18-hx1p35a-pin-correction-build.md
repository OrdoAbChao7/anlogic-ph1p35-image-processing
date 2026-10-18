# HX1P35A 管脚修正与 TD 构建记录

## 目标

验证用户提供的 HX1P35A 手册管脚修正能够进入真实 TangDynasty 工程，并生成包含新按键、LED、复位和 MIPI 配置的位流。

## 输入与命令

- Worktree：`E:/Projects/FPGA-fallback`
- Commit：`af0d8e842459f93a00121332a3b24176aa1d5dbc`
- TD executable：`E:/Projects/FPGA/.tools/td/app/bin/td_commands_prompt.exe`
- Flow script：`E:/Projects/FPGA/.tools/td/app/doc/scripts/DefaultFlow.tcl`
- Input package：`fallback/td_package`
- Isolated project：`work/td_board_mapping_v3`
- Release directory：`work/release_board_mapping_v3`

```powershell
python scripts/build_industrial_td.py `
  --td-exe E:/Projects/FPGA/.tools/td/app/bin/td_commands_prompt.exe `
  --flow-tcl E:/Projects/FPGA/.tools/td/app/doc/scripts/DefaultFlow.tcl `
  --work-project work/td_board_mapping_v3 `
  --release-dir work/release_board_mapping_v3
```

## 修正过程

第一次真实 TD 运行确认工具路径有效，但发现输入按键约束带有不适用于 HDIO 输入的 `DRIVESTRENGTH=8`，触发 `USR-8409` 和 `USR-8168`。已删除按键输入的驱动强度属性，保留 D5/A9、LVCMOS33 和 PULLUP；LED 输出继续使用 D10/E10/C6、LVCMOS33、DRIVESTRENGTH=8 和 PULLDOWN。

修正后的板级契约测试结果为 `31 passed`。

## TD 结果

- `syn_1`：PASS
- `phy_1`、Hold Fix、Bitgen：PASS
- Setup WNS：`+103 ps`
- Hold WNS：`+20 ps`
- Setup/Hold TNS：`0 / 0`
- 违例端点：`0`
- Slice：`17,642 / 21,216`（`83.15%`）
- RAM：`43`
- DSP：`24`
- DRAMHARDCON：`229`
- TD 版本：`v6.2.168116`

## 交付产物

- Bitstream：`work/release_board_mapping_v3/camera_to_dsi_display_compress.bit`
- 可交付副本：`release/candidates/industrial-v1-hx1p35a-pin-correction/camera_to_dsi_display_compress.bit`
- 大小：`1,366,769 bytes`
- SHA-256：`b483a1ffc30d0b7ae9e8ebef4f31f617d33a53d6784ded8007d5443c51ad80ef`
- QoR：`work/release_board_mapping_v3/route.qor`
- 时序：`work/release_board_mapping_v3/final_timing.rpt`
- Manifest：`work/release_board_mapping_v3/industrial-v1-manifest.json`
- 原始 TD 日志：`work/td_board_mapping_v3/td_project/camera_to_dsi_display_Runs/syn_1/flow_exec.log` 与 `work/td_board_mapping_v3/td_project/camera_to_dsi_display_Runs/phy_1/flow_exec.log`

## 未关闭项

本记录只证明源码、约束和 TD 构建结果，不证明板级功能。尚未下载本位流到 HX1P35A；LED、按键、MIPI 摄像头、HDMI、冷启动、热复位和长稳仍需实测。PHY-5060、PHY-5079、PHY-5016、PHY-5088 结构性时钟告警仍保持开放。
