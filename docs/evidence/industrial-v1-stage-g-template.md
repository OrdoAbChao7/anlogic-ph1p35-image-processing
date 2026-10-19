# fixed-red v1 Stage G 上板验收记录模板

本模板只用于真实板卡验收，不把仿真、TD 构建或屏幕截图替代为硬件通过证据。

## 版本绑定

  - Bitstream source commit：`af0d8e842459f93a00121332a3b24176aa1d5dbc`
- Bitstream：`release/candidates/industrial-v1-hx1p35a-pin-correction/camera_to_dsi_display_compress.bit`
- Bitstream SHA-256：`b483a1ffc30d0b7ae9e8ebef4f31f617d33a53d6784ded8007d5443c51ad80ef`
   - SHA-256：`ba451dddce56234c0e7e5801af28fa11f209d4522978ac92e668ad7554f3c53e`
- 板卡型号/序列号：
- SC520CS 模组版本：
- TD Programmer 版本：
- 测试时间：
- 显示器型号与输入模式：
- 供电与连接方式：

## 下载与启动

1. 将 SC520CS 接入板载 MIPI 接口，HDMI 接显示器，连接 JTAG/下载器。
2. 使用 Tang Dynasty Programmer 下载上述 `.bit` 到 SRAM；本版本不把 SRAM 下载结果当作断电 Flash 自动启动证据。
3. 记录 Programmer 成功日志、板卡上电时间和第一次出图时间。
4. 观察是否有花屏、黑屏、撕裂、锁相丢失或摄像头未启动。

## 功能矩阵

| 场景 | 操作 | 预期画面/LED | 实际结果 | 证据文件 |
|---|---|---|---|---|
| 空场 | 移走零件 | 原图可见；无旧框；状态 `NO_OBJECT`；检测 LED 熄灭 |  |  |
| Original | 释放两枚模式键 | 原始 RGB 画面；OSD `ORIGINAL` |  |  |
| Sobel | 稳定按下边缘键，等待帧边界 | OSD `SOBEL`；轮廓画面；检测分支仍运行 |  |  |
| Cartoon | 稳定按下卡通键，等待帧边界 | OSD `CARTOON`；批准的 s4-region-fill-v1 效果 |  |  |
| 标准红色件 | 放置约 `120×80 px` 红色零件 | 绿色框；`PASS`；数量 `1`；宽高显示；LED1 点亮 |  |  |
| 超宽/超高件 | 放置尺寸超差红色零件 | 红色框；`NG`；LED2 点亮 |  |  |
| 非法输入/不可信测量 | 按验收方案制造无效 ROI 或复位中断 | 明确 `INVALID`，不得显示 PASS |  |  |

LED 预期编码（高电平有效）：`PASS=LED1+LED3`、`NG=LED2+LED3`、`NO_OBJECT=全灭`、`INVALID=LED1+LED2`。
| 连续目标进入/离开 | 连续放入、移走零件 | 结果按帧更新；无旧框、无半帧变化 |  |  |

## 可靠性与性能

- 冷启动恢复：通过 / 失败；观察时间：
- 热复位恢复：通过 / 失败；步骤与时间：
- 重复下载次数：`__/__` 成功
- 长稳时长：`__`；丢帧/花屏/撕裂/锁相丢失次数：
- 实测输出分辨率/帧率：
- 端到端延迟测量方法与结果：
- LED 管脚与极性：本版本按用户提供的 HX1P35A 手册绑定 LED1=`D10`、LED2=`E10`、LED3=`C6`，手册标明 LED 高电平有效；仍需下载本版本后实测确认。

只有本记录填写完成，并附原始日志、照片/视频和位流哈希后，才能把对应项从“待上板”改为 `VERIFIED_ON_BOARD`。

当前发布绑定（工程构建证据，非上板证据）：`release/industrial-v1/camera_to_dsi_display_compress.bit`，SHA-256 `e9815a4a42f085d26cb8744c0d5a485020d3ece3e1a1bb7aff20d92264de68d3`。
