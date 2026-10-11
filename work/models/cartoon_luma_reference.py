"""Integer luminance posterization preserving RGB channel differences."""
import cv2
import numpy as np

def filter_rgb(rgb,threshold=240):
 if rgb.dtype!=np.uint8 or rgb.ndim!=3 or rgb.shape[2]!=3: raise ValueError('Expected RGB888')
 kernel=np.array([[1,2,1],[2,4,2],[1,2,1]],np.float32)
 smooth=(cv2.filter2D(rgb,cv2.CV_16U,kernel,anchor=(2,2),borderType=cv2.BORDER_REPLICATE)>>4).astype(np.int16)
 y=(smooth[:,:,0]+2*smooth[:,:,1]+smooth[:,:,2])>>2
 level=y>>5
 q=(level<<5)|(level<<2)|(level>>1)
 color=np.clip(smooth+(q-y)[:,:,None],0,255).astype(np.uint8)
 gray=(rgb[:,:,0]>>2)+(rgb[:,:,1]>>1)+(rgb[:,:,2]>>2)
 kx=np.array([[-1,0,1],[-2,0,2],[-1,0,1]],np.float32)
 gx=cv2.filter2D(gray,cv2.CV_16S,kx,anchor=(2,2),borderType=cv2.BORDER_REPLICATE)
 gy=cv2.filter2D(gray,cv2.CV_16S,kx.T,anchor=(2,2),borderType=cv2.BORDER_REPLICATE)
 edge=np.abs(gx)+np.abs(gy)>=threshold
 color[edge]=0
 return color,edge.astype(np.uint8)*255
