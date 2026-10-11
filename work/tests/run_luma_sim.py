"""Validate chroma-preserving posterization with independent constant vectors and RTL."""
from pathlib import Path
import sys,subprocess,argparse
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'work/models'),str(ROOT/'work/tests')]
import run_cartoon_sim as sim
from cartoon_luma_reference import filter_rgb
p=argparse.ArgumentParser();p.add_argument('--full',action='store_true');a=p.parse_args()
# Constant RGB: Y=(100+300+200)/4=150; quantized Y=146; delta=-4.
color,edge=filter_rgb(np.full((3,5,3),(100,150,200),np.uint8))
assert np.all(color==np.array([96,146,196])) and not edge.any()
for v in [0,255]:
 color,_=filter_rgb(np.full((3,5,3),v,np.uint8));assert np.all(color==v)
OUT=ROOT/'work/output/staged-cartoon';OUT.mkdir(parents=True,exist_ok=True)
stem='s3_luma_full' if a.full else 's3_luma_small'
width,height=(1280,720) if a.full else (32,12)
sim.filter_rgb=filter_rgb
vec=OUT/(stem+'.txt');sim.vectors(vec,width,height,a.full)
tb=(ROOT/'work/tests/tb_video_cartoon.v').read_text().replace('.HEIGHT(H))','.HEIGHT(H),.EDGE_THRESHOLD(240))')
test=OUT/(stem+'_tb.v');test.write_text(tb)
exe=OUT/(stem+'.vvp')
subprocess.run([str(ROOT/'.tools/iverilog/bin/iverilog.exe'),'-g2012','-s','tb_video_cartoon',f'-Ptb_video_cartoon.W={width}',f'-Ptb_video_cartoon.H={height}','-o',str(exe),str(test),str(ROOT/'work/rtl/video_cartoon_luma.v')],check=True)
r=subprocess.run([str(ROOT/'.tools/iverilog/bin/vvp.exe'),str(exe),'+VECTORS='+vec.as_posix()],capture_output=True,text=True)
print(r.stdout+r.stderr)
(OUT/(stem+'-result.txt')).write_text(r.stdout+r.stderr)
if r.returncode: raise SystemExit(r.returncode)
vec.unlink();exe.unlink();test.unlink()
