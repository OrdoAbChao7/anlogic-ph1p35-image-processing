"""
Generate exact 2-page and clean 3-page BW versions to evaluate readability.
"""
import os
import subprocess
import pymupdf

# Version: 2-page compact & clean
html_2page = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<title>项目演示视频拍摄与制作要点总结</title>
<style>
  @page {
    size: A4 portrait;
    margin: 10mm 14mm 10mm 14mm;
    @bottom-center {
      content: "第 " counter(page) " 页 / 共 " counter(pages) " 页";
      font-size: 8pt;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif;
      color: #666666;
    }
  }

  * {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
  }

  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", "Noto Sans SC", sans-serif;
    color: #000000;
    background-color: #FFFFFF;
    line-height: 1.45;
    font-size: 8.5pt;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }

  .page {
    width: 100%;
    height: 275mm;
    page-break-after: always;
    position: relative;
    overflow: hidden;
  }

  .page:last-child {
    page-break-after: avoid;
  }

  /* Header */
  .doc-header {
    text-align: center;
    border-bottom: 1.5px solid #000000;
    padding-bottom: 5px;
    margin-bottom: 7px;
  }

  .doc-title {
    font-size: 15pt;
    font-weight: 800;
    color: #000000;
    letter-spacing: 0.5px;
    margin-bottom: 2px;
  }

  .doc-subtitle {
    font-size: 8.5pt;
    color: #444444;
  }

  /* Section Headings */
  .sec-h1 {
    font-size: 10pt;
    font-weight: 700;
    color: #000000;
    border-bottom: 1px solid #000000;
    padding-bottom: 2px;
    margin-top: 6px;
    margin-bottom: 4px;
  }

  .sec-h2 {
    font-size: 9pt;
    font-weight: 700;
    color: #111111;
    margin-top: 4px;
    margin-bottom: 2px;
  }

  /* Content Boxes */
  .box-simple {
    border: 1px solid #444444;
    padding: 5px 8px;
    margin-bottom: 5px;
    background-color: #FFFFFF;
  }

  .box-gray {
    border: 1px solid #B0B0B0;
    background-color: #F7F7F7;
    padding: 5px 8px;
    margin-bottom: 5px;
  }

  /* Lists */
  ul.list-disc {
    list-style-type: disc;
    padding-left: 16px;
    margin-bottom: 3px;
  }

  ul.list-disc li {
    margin-bottom: 1.5px;
    color: #111111;
  }

  ol.list-num {
    padding-left: 16px;
    margin-bottom: 3px;
  }

  ol.list-num li {
    margin-bottom: 1.5px;
    color: #111111;
  }

  /* Grids */
  .row-2 {
    display: flex;
    gap: 8px;
    margin-bottom: 4px;
  }

  .col-half {
    flex: 1;
  }

  /* Tables */
  table.simple-table {
    width: 100%;
    border-collapse: collapse;
    margin-bottom: 5px;
    font-size: 8pt;
  }

  table.simple-table th {
    border: 1px solid #333333;
    background-color: #EAEAEA;
    color: #000000;
    font-weight: 700;
    padding: 3px 5px;
    text-align: left;
  }

  table.simple-table td {
    border: 1px solid #CCCCCC;
    padding: 3px 5px;
    vertical-align: top;
    color: #111111;
  }

  table.simple-table tr:nth-child(even) td {
    background-color: #FAFAFA;
  }

  /* Checkbox Table */
  table.check-table {
    width: 100%;
    border-collapse: collapse;
    margin-bottom: 4px;
    font-size: 7.5pt;
  }

  table.check-table th {
    border: 1px solid #000000;
    background-color: #E2E2E2;
    padding: 3px 5px;
    font-weight: 700;
    text-align: left;
  }

  table.check-table td {
    border: 1px solid #CCCCCC;
    padding: 2.5px 5px;
    color: #111111;
  }

  /* Footer */
  .page-footer {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    border-top: 1px solid #CCCCCC;
    padding-top: 2px;
    display: flex;
    justify-content: space-between;
    font-size: 7.5pt;
    color: #666666;
  }
</style>
</head>
<body>

<!-- ================= PAGE 1 ================= -->
<div class="page">
  <div class="doc-header">
    <div class="doc-title">项目演示视频拍摄与制作要点总结</div>
    <div class="doc-subtitle">竞赛评审培训内容汇总 · 评委心理与避坑指南 · 结构拆解与实操规范</div>
  </div>

  <!-- 一、评委评审逻辑 -->
  <div class="sec-h1">一、 评委评审逻辑（重点理解）</div>
  <div class="box-simple">
    <ol class="list-num" style="margin-bottom:0;">
      <li><strong>评委熟悉赛道，不听原理科普：</strong>评委均为专业人士，不需要逐字讲解算法底层公式与基础定义；评委核心看<strong>“算法有没有实际效果、效果差距有多大”</strong>。</li>
      <li><strong>评审工作量极大，避免视觉疲劳：</strong>连续长时间审阅大量视频，画面抖动、冗长无物片头、杂乱字幕等瑕疵越到后期扣分越明显。</li>
      <li><strong>打分优先级排序：</strong>
        <strong>① 能否直观验证每个功能效果（最重要）</strong> ＞ 
        <strong>② 视频结构逻辑（总分总、层次分明）</strong> ＞ 
        <strong>③ 画面、字幕、镜头等细节</strong>。</li>
      <li><strong>比拼核心能力：</strong>同赛道选题类似的作品，比拼的不是“功能或算法的数量”，而是<strong>效果优劣</strong>以及<strong>解决实际问题的能力</strong>。</li>
    </ol>
  </div>

  <!-- 二、致命缺点与避坑方案 -->
  <div class="sec-h1">二、 致命缺点与避坑方案（最需优先规避的扣分大忌）</div>
  
  <div class="sec-h2">1. 致命缺点一：算法演示看不到前后画面差异（头号问题）</div>
  <div class="box-gray">
    <p><strong>问题表现：</strong>只口头介绍算法原理，实际打开/关闭算法时，画面肉眼看不出明显变化。评委无法验证功能是否真实生效，即便声称实现十几种算法也毫无说服力。</p>
    <p style="margin-top:2px;"><strong>解决办法：</strong></p>
    <ul class="list-disc" style="margin-bottom:0;">
      <li><strong>精心挑选演示素材：</strong>场景必须能放大算法效果，加算法前后对比一眼就能看出差别（边缘、对比度、色彩、噪点等）。选错素材则再好算法也无法证明效果。</li>
      <li><strong>规范演示逻辑：</strong>固定相机机位 → 展示不加算法的原始画面 → 开启算法 → 画面发生直观改善，重点展示差异，不单纯念定义。</li>
    </ul>
  </div>

  <div class="sec-h2">2. 致命缺点二：只罗列功能名称，脱离实际恶劣工况</div>
  <div class="box-gray" style="margin-bottom:4px;">
    <p><strong>问题表现：</strong>仅罗列“我实现了XX算法”。同赛道算法名称基本一致，单纯报功能名称只能拿基础分。必须讲清楚在何种恶劣条件下（强光、暗光、半遮挡、偏色等）算法改善了画面。</p>
  </div>

  <table class="simple-table">
    <thead>
      <tr>
        <th style="width:20%;">功能类型</th>
        <th style="width:40%;">【反面教材】（单纯报菜名 / 扣分）</th>
        <th style="width:40%;">【正面示范】（结合恶劣工况 / 得分）</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><strong>边缘检测与降噪</strong></td>
        <td>“我们实现了Sobel边缘检测和图像降噪算法，效果良好。”</td>
        <td>“在<strong>暗光高噪点环境</strong>下，开启算法后图像噪点显著减少，<strong>物体轮廓与边缘由模糊转为清晰可辨</strong>（分屏对比）。”</td>
      </tr>
      <tr>
        <td><strong>白平衡与色彩校正</strong></td>
        <td>“本系统支持按键切换自动白平衡与颜色量化功能。”</td>
        <td>“在<strong>车间钠灯泛黄强偏色光照</strong>下，开启白平衡算法后，<strong>标准色卡还原真实中性灰，大幅提升识别稳定性</strong>。”</td>
      </tr>
      <tr>
        <td><strong>目标检测与定位</strong></td>
        <td>“采用裁剪版YOLO-tiny完成了INT8量化与硬件部署。”</td>
        <td>“在<strong>工件高速移动且存在局部遮挡</strong>场景下，系统保持实时满帧检测，<strong>稳定输出定位坐标与目标总数统计</strong>。”</td>
      </tr>
    </tbody>
  </table>

  <!-- 三、次要扣分点 -->
  <div class="sec-h1">三、 次要扣分点速查（容易被忽略的细节累积项）</div>
  <div class="box-simple" style="margin-bottom:0;">
    <ul class="list-disc" style="margin-bottom:0;">
      <li><strong>片头过长：</strong>无实质信息的片头严禁超过 5 秒。3 分钟总时长极为有限，不可浪费在空洞动画上。</li>
      <li><strong>镜头抖动：</strong>手持晃动画面易使评委产生视觉疲劳，大幅降低整体印象分，必须使用固定支架或三脚架。</li>
      <li><strong>字幕排版问题：</strong>禁止文字逐个弹出（分散视线）；推荐整段一次性出现，方便边听边扫读。文字需精炼，不堆砌大段原理。</li>
      <li><strong>冗余操作占用时间：</strong>上位机输入指令、参数调节等操作过程需适当倍速或略过，视频重心聚焦最终图像效果对比。</li>
    </ul>
  </div>

  <div class="page-footer">
    <span>项目演示视频拍摄与制作要点总结</span>
    <span>第 1 页 / 共 2 页</span>
  </div>
</div>

<!-- ================= PAGE 2 ================= -->
<div class="page">
  <!-- 四、视频结构：总分总框架（推荐） -->
  <div class="sec-h1" style="margin-top:0;">四、 视频结构：推荐“总-分-总”标准框架</div>
  <table class="simple-table">
    <thead>
      <tr>
        <th style="width:20%;">阶段与建议时长</th>
        <th style="width:40%;">核心任务</th>
        <th style="width:40%;">制作要点与注意事项</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><strong>1. 开头引入</strong><br>(前40s，极限1min)</td>
        <td>简短片头引入（5秒内抓住眼球）；40秒内介绍系统整体架构、功能概况，交代项目主题。</td>
        <td>目的在于让观众快速明白项目是什么、难度与价值所在，无需过早切入微观底层实现细节。</td>
      </tr>
      <tr>
        <td><strong>2. 中间主体</strong><br>(核心演示，约110s)</td>
        <td>核心演示，直观展示效果（对比开/关算法后的画面、灯光、声音、波形变化）。</td>
        <td>
          <ul class="list-disc" style="padding-left:14px; margin-bottom:0;">
            <li>肉眼不易观察的效果（如低延迟、功耗），借助<strong>波形、声音等方式可视化</strong>。</li>
            <li>挑选核心重点功能精讲，简单外设（如纯按键点灯）简要带过，严禁主次不分。</li>
          </ul>
        </td>
      </tr>
      <tr>
        <td><strong>3. 结尾总结</strong><br>(最后30s)</td>
        <td>全功能综合叠加展示，总结技术指标与实际应用价值。</td>
        <td>说明解决了什么实际问题，具有何种工程实用价值；态度求真务实，客观评价不夸大。</td>
      </tr>
    </tbody>
  </table>

  <!-- 五、核心制作原则与画面技巧 -->
  <div class="sec-h1">五、 核心制作原则与画面技巧</div>
  <div class="row-2">
    <div class="col-half">
      <div class="box-simple" style="margin-bottom:0;">
        <div class="sec-h2">1. 核心制作原则</div>
        <ul class="list-disc" style="margin-bottom:0;">
          <li><strong>直观效果优先：</strong>少讲枯燥原理，不长篇大论解释底层逻辑，评委核心关注实际效果。</li>
          <li><strong>倍速处理与上限：</strong>平淡与过渡内容可适度倍速，但<strong>语速倍速严禁超过 1.5 倍</strong>，确保清晰可辨。</li>
          <li><strong>流程前置：</strong>提前写好完整分镜脚本再开机拍摄；预留充裕时间，按视频呈现逻辑反向优化系统演示效果。</li>
          <li><strong>因地制宜：</strong>经验作为参考框架，结合具体硬件与工程特点灵活调整。</li>
        </ul>
      </div>
    </div>
    <div class="col-half">
      <div class="box-simple" style="margin-bottom:0;">
        <div class="sec-h2">2. 画面与对比图技巧</div>
        <ul class="list-disc" style="margin-bottom:0;">
          <li><strong>多画面同屏与画中画：</strong>多采用同屏对比与画中画（PIP），同时保留全局画面与关键ROI细节放大。</li>
          <li><strong>主次绝不能颠倒：</strong>画面重心必须是<strong>处理前/后的图像对比区域</strong>。文字标注仅作辅助，绝不可遮挡画面。</li>
          <li><strong>标注明确清晰：</strong>增加序号标注区分阶段；搭配清晰字幕与箭头高亮对比区域，引导视线。</li>
          <li><strong>转场质朴简洁：</strong>杜绝花哨转场特效，技术演示以硬切或短淡入为主，避免分散注意力。</li>
        </ul>
      </div>
    </div>
  </div>

  <!-- 六、案例评析与环境规范 -->
  <div class="sec-h1">六、 案例复盘与拍摄环境规范</div>
  <div class="row-2">
    <div class="col-half">
      <div class="box-gray" style="margin-bottom:0;">
        <div class="sec-h2">【案例评价】分区背光演示视频复盘</div>
        <p><strong>优点：</strong>①直观对比（同屏放原始 vs 分区背光，突出黑场差异）；②倍速处理（提升信息密度）；③统筹展示（同一画面横向对比）；④带进度条方便定位。</p>
        <p style="margin-top:2px;"><strong>不足与优化建议：</strong>①转场花哨（应质朴简洁）；②进度条辨识度差（黑底蓝字不清晰，需提亮增色）；③倍速上限（语速不超过1.5倍）；④增设序号标注区分阶段。</p>
      </div>
    </div>

    <div class="col-half">
      <div class="box-gray" style="margin-bottom:0;">
        <div class="sec-h2">【优秀范式】值得学习的做法（参考范例2）</div>
        <p>①<strong>分模块讲解：</strong>基础功能（保住及格分）+ 拓展功能（冲刺高分亮点）；②<strong>逐步叠加演进：</strong>从原始较差画面出发逐个开算法，画面逐步改善；③<strong>旁白精炼：</strong>字字紧扣画面，无废话。</p>
        <div class="sec-h2" style="margin-top:3px;">【环境要求】拍摄现场规范</div>
        <p>①<strong>整洁干净：</strong>无饭盒、零食袋、杂物纸张；②<strong>规避敏感信息：</strong>无违规内容，<strong>绝不出现指导老师姓名</strong>；③<strong>光线合适：</strong>均匀无频闪。</p>
      </div>
    </div>
  </div>

  <!-- 七、录制前自查清单 -->
  <div class="sec-h1">七、 演示视频录制前必检清单（10项自查通行证）</div>
  <table class="check-table" style="margin-bottom:0;">
    <thead>
      <tr>
        <th style="width:7%; text-align:center;">勾选</th>
        <th style="width:20%;">检查项</th>
        <th style="width:53%;">合格验收标准</th>
        <th style="width:20%;">风险级别</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td style="text-align:center;">[ &nbsp; ]</td>
        <td>1. 片头时长</td>
        <td>主题与Logo展示控制在 5 秒以内，迅速切入实物演示。</td>
        <td>消耗评委耐心</td>
      </tr>
      <tr>
        <td style="text-align:center;">[ &nbsp; ]</td>
        <td>2. 算法前后差异</td>
        <td>算法开关前后，画面差异肉眼清晰可见；挑选能放大效果的恶劣素材。</td>
        <td><strong>致命项（功能真实性存疑）</strong></td>
      </tr>
      <tr>
        <td style="text-align:center;">[ &nbsp; ]</td>
        <td>3. 实际场景痛点</td>
        <td>讲清在强光/暗光/偏色/遮挡等恶劣工况下解决的实际问题，非纯报菜名。</td>
        <td>仅得基础平庸分</td>
      </tr>
      <tr>
        <td style="text-align:center;">[ &nbsp; ]</td>
        <td>4. 递进叠加演示</td>
        <td>遵循逐步开启算法、画面逐步改善的逻辑，体现模块分层价值。</td>
        <td>结构说服力不足</td>
      </tr>
      <tr>
        <td style="text-align:center;">[ &nbsp; ]</td>
        <td>5. 拍摄镜头防抖</td>
        <td>全流程使用固定支架或三脚架，无手持晃动与反复拉焦。</td>
        <td>视觉疲劳扣分</td>
      </tr>
      <tr>
        <td style="text-align:center;">[ &nbsp; ]</td>
        <td>6. 现场环境规范</td>
        <td>拍摄台面干净无杂物，背景规避违规信息及指导教师姓名。</td>
        <td>扣除风貌严谨分</td>
      </tr>
      <tr>
        <td style="text-align:center;">[ &nbsp; ]</td>
        <td>7. 字幕呈现方式</td>
        <td>字幕整句一次性弹出，排版简洁精炼，文字不遮挡对比画面核心区域。</td>
        <td>影响阅读理解</td>
      </tr>
      <tr>
        <td style="text-align:center;">[ &nbsp; ]</td>
        <td>8. 旁白与倍速上限</td>
        <td>语音清晰无废话，快进片段语速严格控制在 1.5 倍速以内。</td>
        <td>信息听不清漏评</td>
      </tr>
      <tr>
        <td style="text-align:center;">[ &nbsp; ]</td>
        <td>9. 标注与画面主次</td>
        <td>画面重心保留在前后对比图，配序号标注与清晰对比箭头。</td>
        <td>视线焦点分散</td>
      </tr>
      <tr>
        <td style="text-align:center;">[ &nbsp; ]</td>
        <td>10. 总时长控制</td>
        <td>结尾全功能综合呈现并给出客观指标，视频总时长控制在 3 分钟以内。</td>
        <td>超时扣分</td>
      </tr>
    </tbody>
  </table>

  <div class="page-footer">
    <span>项目演示视频拍摄与制作要点总结</span>
    <span>第 2 页 / 共 2 页</span>
  </div>
</div>

</body>
</html>
"""

# Save 2-page BW HTML
html_path = r"e:\Projects\FPGA\docs\video_guide\项目演示视频拍摄与制作要点总结_黑白极简版.html"
with open(html_path, "w", encoding="utf-8") as f:
    f.write(html_2page)
print("Saved 2-page BW HTML.")

# Generate PDF with headless Chrome
pdf_path = r"e:\Projects\FPGA\docs\video_guide\项目演示视频拍摄与制作要点总结_黑白极简版.pdf"
chrome_cmd = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    "--headless=new",
    "--disable-gpu",
    "--no-pdf-header-footer",
    f"--print-to-pdf={pdf_path}",
    html_path
]

res = subprocess.run(chrome_cmd, capture_output=True, text=True)
print(f"Chrome exit code: {res.returncode}")

doc = pymupdf.open(pdf_path)
print(f"BW 2-Page PDF Total pages: {len(doc)}")
os.makedirs(r"e:\Projects\FPGA\docs\video_guide\preview_bw_clean", exist_ok=True)
for i, page in enumerate(doc):
    pix = page.get_pixmap(dpi=150)
    pix.save(f"e:/Projects/FPGA/docs/video_guide/preview_bw_clean/page_{i+1}.png")
print("Saved preview clean images.")
