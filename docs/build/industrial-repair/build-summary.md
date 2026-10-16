# 工业颜色检测修复候选构建

日期：2026-10-14；证据类型 project；hardware_verified=false，visual_approved=false。

最终导出：fallback/release/industrial-color-bbox-20261014/industrial_color_bbox.bit；完整包同名.zip。目标 PH1P35MDG324 -3，顶层 design_top_wrapper，TD6.2.168116。

| 项目 | 最终导出版本 |
|---|---:|
| Setup WNS / TNS | +70ps / 0ps |
| Hold WNS / TNS | +20ps / 0ps |
| Slice | 16123 / 21216（75.99%） |
| RAM / DSP | 39 / 25 |
| Bitstream字节数 | 1789539 |
| Bitstream SHA-256 | C41714E9E960A4C393EAB0444B479F790114750B5E4B76CB9F2512806E7AA470 |

完整物理报告、综合日志、输入凭据及输出哈希保存在本目录。九组逻辑回归通过，包含完整ISP三帧518400字；其上游模型与AWB依赖模型范围见fallback/README.md，不能当厂商IP或板卡验证。

## 构建复现

第一轮最终Setup WNS -1118ps，拒绝导出；见attempt-1。并行命中计数/极值选择和AWB支路寄存修复后，开发目录构建+7/+20ps，TNS0；独立无缓存交付布局重建+70/+20ps，TNS0。两轮通过版本使用相同RTL/约束；布局布线结果不同（Slice16097→16123，连线长度3707968→3767008），位流校验值也不同。工具种子/并行实现差异的更深原因未定位，不宣称bit字节确定性。最终只使用独立重建的报告与位流。

## 导出验证

最终包253项文件的SHA-256及长度全部匹配manifest.json；7-Zip完整性测试PASS。源码/RTL副本/测试修改，Bitstream或route.qor修改，输入新增/删除，均拒绝导出；失败或仅综合不签发完整构建凭据。原始build/test快照保留不改写。

PowerShell5把JSON数组再序列化为包装对象，曾导致导出误拒；最终导出器改为逐项语义比较，核对数量、路径集合、哈希及重复路径。仅精确排除不参与TD/仿真的export.ps1自身，最终包manifest记录其实际哈希，导出逻辑已独立负向验证。未为此重复未变的RTL构建。

## 告警与板级边界

物理告警原文见physical-warnings.txt。PHY-5060涉及scl_clk与摄像头MCLK的时钟/数据混合扇出；PHY-5016涉及PLL到IO位置/时钟能力；PHY-5079与PHY-5088涉及局部路由、非时钟端及级联时钟网络。保留原平台配置，未屏蔽告警、未放宽SDC；这些仍是待真实板卡观察的阻塞项，不能判定无害。综合中厂商HDMI/DDR端口位宽、未驱动端及RAM_STYLE告警仍在完整日志；不能以无ERROR替代关闭。

当前设备枚举未识别可确认下载器。实测分辨率、帧率、检测效果、冷启动、复位和长稳均未执行；G1/G2及工业完整F1–F5验收未通过。文件可作为下载候选，但尚不是已上板验证版本。
