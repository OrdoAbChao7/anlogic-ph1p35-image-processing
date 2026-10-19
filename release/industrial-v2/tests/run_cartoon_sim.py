"""Generate OpenCV expectations, then compare real RTL on every clock."""
import argparse
from collections import deque
from pathlib import Path
import subprocess
import sys
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'work/models'))
from cartoon_reference import filter_rgb


def vectors(path, width, height, full=False):
    rng = np.random.default_rng(520)
    pipe = deque([0]*6, maxlen=6)
    active_mode = 0
    cycles = 0
    with path.open('w', encoding='ascii') as f:
        def emit(rgb=0, de=0, vs=0, hs=0, request=0, keep=0, overlay=0,
                 wanted=0, mode=0, reset=1):
            nonlocal cycles
            # Simultaneous requests are included: cartoon has priority.
            e, t = request & 1, (request >> 1) & 1
            flags = (reset<<6)|(vs<<5)|(hs<<4)|(de<<3)|(e<<2)|(t<<1)|keep
            stimulus = (flags<<48)|(rgb<<24)|overlay
            if not reset:
                pipe.clear(); pipe.extend([0]*6)
            else:
                pipe.appendleft((vs<<28)|(hs<<27)|(de<<26)|(mode<<24)|(wanted if de else 0))
            f.write(f'{stimulus:014x} {pipe[-1]:08x}\n')
            cycles += 1

        def pack(p):
            return (int(p[0])<<16)|(int(p[1])<<8)|int(p[2])

        for _ in range(4): emit(reset=0)
        modes = [2] if full else [0, 1, 2, 0, 2, 1, 2, 0, 2]
        for frame, mode in enumerate(modes):
            request = {0:0, 1:1, 2:3}[mode]
            for _ in range(8): emit(vs=1, request=request, mode=active_mode)
            for _ in range(8): emit(request=request, mode=active_mode)
            yy, xx = np.indices((height, width))
            if frame % 3 == 0:
                rgb = np.stack([(xx*17+frame*32)%256,(yy*39)%256,((xx+yy)*11)%256],axis=2).astype(np.uint8)
            elif frame % 3 == 1:
                rgb = np.full((height,width,3),(100,150,200),dtype=np.uint8)
                rgb[:, width//2:] = (255,255,255)
            else:
                rgb = rng.integers(0,256,(height,width,3),dtype=np.uint8)
            toon, edge = filter_rgb(rgb)
            active_mode = mode
            for y in range(height):
                for x in range(width):
                    # Requests bounce/change within the frame; selection must hold.
                    req_now = request if y < height//2 else ((x+y+frame)&3)
                    keep = int(y == 2 and 3 <= x < min(width,12))
                    overlay = 0x19e7a2
                    raw = pack(rgb[y,x])
                    wanted = raw if mode==0 else (int(edge[y,x])*0x010101 if mode==1 else pack(toon[y,x]))
                    if keep: wanted = overlay
                    emit(raw,1,request=req_now,keep=keep,overlay=overlay,wanted=wanted,mode=mode)
                    # Pauses exercise valid gating without restarting row coordinates.
                    if not full and (x+3*y)%17==3:
                        for _ in range(2): emit(request=req_now,mode=mode)
                for j in range(12 if not full else 370):
                    emit(hs=int(3<=j<7),request=req_now,mode=mode)
            if not full and frame==4:
                for _ in range(3): emit(reset=0)
                active_mode=0
        for _ in range(12): emit(mode=active_mode)
    return cycles


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--full',action='store_true')
    a=p.parse_args()
    out=ROOT/'work/output/cartoon-tests'; out.mkdir(parents=True,exist_ok=True)
    width,height=(1280,720) if a.full else (32,12)
    stem='full' if a.full else 'small'
    vec=out/f'{stem}.txt'; vectors(vec,width,height,a.full)
    iv=ROOT/'.tools/iverilog/bin/iverilog.exe'; vvp=iv.with_name('vvp.exe')
    compile_cmd=[str(iv),'-g2012','-Wall','-s','tb_video_cartoon',
                 f'-Ptb_video_cartoon.W={width}',f'-Ptb_video_cartoon.H={height}',
                 '-o',str(out/f'{stem}.vvp'),str(ROOT/'work/tests/tb_video_cartoon.v'),
                 str(ROOT/'work/rtl/video_cartoon.v')]
    subprocess.run(compile_cmd,check=True)
    r=subprocess.run([str(vvp),str(out/f'{stem}.vvp'),f'+VECTORS={vec.as_posix()}'],
                     capture_output=True,text=True)
    (out/f'{stem}-result.txt').write_text(r.stdout+r.stderr,encoding='utf-8')
    print(r.stdout+r.stderr,end='')
    if r.returncode: raise SystemExit(r.returncode)


if __name__=='__main__': main()
