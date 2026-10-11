"""Generate sourced previews and verify each build parameter against RTL."""
from pathlib import Path
import sys,subprocess,json,hashlib,zipfile
import cv2,numpy as np
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'work/models'),str(ROOT/'work/tests')]
from cartoon_reference import filter_rgb
import run_cartoon_sim as sim
OUT=ROOT/'work/output/staged-cartoon'
OUT.mkdir(parents=True,exist_ok=True)
image=OUT/'image16.jpeg'
ppt=next((ROOT/'安路HX1P35A比赛文档2026').glob('赛题解析二*.pptx'))
with zipfile.ZipFile(ppt) as z: image.write_bytes(z.read('ppt/media/image16.jpeg'))
(OUT/'preview-source.json').write_text(json.dumps({'source':str(ppt.relative_to(ROOT)), 'slide':20,'entry':'ppt/media/image16.jpeg','source_sha256':hashlib.sha256(ppt.read_bytes()).hexdigest(),'image_sha256':hashlib.sha256(image.read_bytes()).hexdigest(),'hardware_capture':False},ensure_ascii=False,indent=2),encoding='utf8')
bgr=cv2.imdecode(np.fromfile(image,np.uint8),1)
# Letterbox to the configured 1280x720 without distorting the source photograph.
h,w=bgr.shape[:2]; scale=min(1280/w,720/h)
res=cv2.resize(bgr,(round(w*scale),round(h*scale)),interpolation=cv2.INTER_AREA)
rgb=np.full((720,1280,3),32,np.uint8)
x=(1280-res.shape[1])//2; y=(720-res.shape[0])//2
rgb[y:y+res.shape[0],x:x+res.shape[1]]=res[:,:,::-1]
cv2.imwrite(str(OUT/'input_720p.png'),rgb[:,:,::-1])
images=[rgb]
for name,threshold in [('s1_color',2047),('s2_contour',240)]:
 toon,edge=filter_rgb(rgb,threshold)
 cv2.imwrite(str(OUT/(name+'.png')),toon[:,:,::-1]); images.append(toon)
 cv2.imwrite(str(OUT/(name+'_edge.png')),edge)
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',22)
board=Image.new('RGB',(1280,3*390+85),'#111827'); draw=ImageDraw.Draw(board)
labels=['输入：赛题PPT第20页原图（等比例缩放，非摄像头实拍）','阶段1：3×3平滑 + 每通道8级量化，不加黑边','阶段2：量化 + Sobel轮廓，阈值240（候选参数）']
for i,(im,label) in enumerate(zip(images,labels)):
 board.paste(Image.fromarray(im).resize((640,360)),(320,i*390+35))
 draw.text((24,i*390+5),label,font=font,fill='white')
draw.text((24,1180),'软件黄金模型预览；不是上板效果或最终区域填充验收。',font=font,fill='#fbbf24')
board.save(OUT/'comparison.png')
# Existing independent golden-model test generator exercises multiple modes,
# random noise, pauses, overlay and reset. Parameterize only the threshold.
tb=(ROOT/'work/tests/tb_video_cartoon.v').read_text()
tb=tb.replace('parameter W=32, H=12;','parameter W=32, H=12, T=160;').replace('.HEIGHT(H))','.HEIGHT(H),.EDGE_THRESHOLD(T))')
(OUT/'tb_stages.v').write_text(tb)
results=[]
for stage,t in [('s1_color',2047),('s2_contour',240)]:
 sim.filter_rgb=lambda data, t=t:filter_rgb(data,t)
 for full in [False,True]:
  width,height=(1280,720) if full else (32,12)
  stem=stage+('_full' if full else '_small')
  vec=OUT/(stem+'.txt'); sim.vectors(vec,width,height,full)
  exe=OUT/(stem+'.vvp')
  cmd=[str(ROOT/'.tools/iverilog/bin/iverilog.exe'),'-g2012','-s','tb_video_cartoon',f'-Ptb_video_cartoon.W={width}',f'-Ptb_video_cartoon.H={height}',f'-Ptb_video_cartoon.T={t}','-o',str(exe),str(OUT/'tb_stages.v'),str(ROOT/'work/rtl/video_cartoon.v')]
  subprocess.run(cmd,check=True)
  result=subprocess.run([str(ROOT/'.tools/iverilog/bin/vvp.exe'),str(exe),'+VECTORS='+vec.as_posix()],capture_output=True,text=True)
  (OUT/(stem+'-result.txt')).write_text(result.stdout+result.stderr)
  print(result.stdout,flush=True)
  if result.returncode: raise SystemExit(result.returncode)
  results.append({'case':stem,'cycles_passed':result.stdout.splitlines()[0],'vector_sha256':hashlib.sha256(vec.read_bytes()).hexdigest()})
  vec.unlink(); exe.unlink()
(OUT/'tb_stages.v').unlink()
(OUT/'simulation.json').write_text(json.dumps(results,indent=2))
