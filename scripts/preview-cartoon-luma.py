"""Compare current RGB posterization and luminance variant using supplied PPT input."""
from pathlib import Path
import sys,json
import cv2,numpy as np
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'work/models'))
from cartoon_reference import filter_rgb as old
from cartoon_luma_reference import filter_rgb as new
OUT=ROOT/'work/output/staged-cartoon'
rgb=cv2.imread(str(OUT/'input_720p.png'))[:,:,::-1].copy()
a,_=old(rgb,160);b,_=old(rgb,240);c,_=new(rgb,240)
cv2.imwrite(str(OUT/'s3_luma.png'),c[:,:,::-1])
board=Image.new('RGB',(1280,840),'#111827');d=ImageDraw.Draw(board)
f=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',20)
for i,(im,label) in enumerate([(rgb,'输入：赛题示例，非摄像头实拍'),(a,'当前算法参考：RGB独立量化 / 阈值160'),(b,'阶段2：RGB独立量化 / 阈值240'),(c,'阶段3：亮度量化，保留色差 / 阈值240')]):
 x=(i%2)*640;y=(i//2)*395
 board.paste(Image.fromarray(im).resize((640,360)),(x,y+30));d.text((x+12,y+2),label,font=f,fill='white')
d.text((12,800),'黄金模型对照；阶段3改善量化引入的色差，不等于完成区域填充。',font=f,fill='#fbbf24')
board.save(OUT/'luma-comparison.png')
# Quantify introduced channel-difference error against the common smoothed image,
# excluding edge-black pixels and pixels clipped at 0 or 255.
k=np.array([[1,2,1],[2,4,2],[1,2,1]],np.float32)
s=(cv2.filter2D(rgb,cv2.CV_16U,k,anchor=(2,2),borderType=cv2.BORDER_REPLICATE)>>4).astype(np.int16)
stats={}
common=np.all((b>0)&(b<255)&(c>0)&(c<255),axis=2)&np.any(rgb!=32,axis=2)
for name,im in [('rgb_quant',b),('luma_quant',c)]:
 q=im.astype(np.int16);m=common
 err=np.abs((q[:,:,0]-q[:,:,1])-(s[:,:,0]-s[:,:,1]))+np.abs((q[:,:,2]-q[:,:,1])-(s[:,:,2]-s[:,:,1]))
 stats[name]={'mean_channel_difference_error':float(err[m].mean()),'evaluated_pixels':int(m.sum())}
(OUT/'chroma-metric.json').write_text(json.dumps(stats,indent=2));print(stats)
