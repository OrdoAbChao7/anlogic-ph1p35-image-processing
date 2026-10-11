"""Build isolated diagnostic stages; never overwrite existing project or release.
Uses the existing uncommitted video_cartoon implementation as a hashed input.
"""
from pathlib import Path
import argparse, hashlib, json, re, shutil, subprocess, sys
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'work/td_cartoon'
TD=ROOT/'.tools/td/app/bin/td_commands_prompt.exe'
FLOW=ROOT/'.tools/td/app/doc/scripts/DefaultFlow.tcl'
OUT=ROOT/'work/output/staged-cartoon'
WORK=ROOT/'.tools/td/work'

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def once(s,a,b):
 if s.count(a)!=1: raise ValueError('Expected unique patch: '+a)
 return s.replace(a,b,1)

def prepare(stage,threshold):
 dst=WORK/('staged_cartoon_'+stage)
 if dst.exists(): raise FileExistsError('Preserving '+str(dst))
 dst.mkdir(parents=True)
 for part in ['user_source','td_project/al_ip']:
  shutil.copytree(SOURCE/part,dst/part)
 for name in ['camera_to_dsi_display.al','camera_to_dsi_display.sdc']:
  shutil.copy2(SOURCE/'td_project'/name,dst/'td_project'/name)
 al=dst/'td_project/camera_to_dsi_display.al'
 text=al.read_text('utf8')
 text,n=re.subn(r'(<Project[^>]*? Path=")[^"]+',lambda m:m[1]+(dst/'td_project').as_posix(),text,count=1)
 if n!=1: raise ValueError('Project root missing')
 al.write_text(text,'utf8')
 top=dst/'user_source/hdl_source/design_top_wrapper.v'
 text=top.read_text('utf8')
 text=once(text,".EDGE_THRESHOLD ( 12'd160 )",f".EDGE_THRESHOLD ( 12'd{threshold} )")
 text=once(text,'assign O_cam_24m \t= S_24m_clk;', '''PH1P_LOGIC_HD_ODDR u_cam_mclk_out (
        .clk(S_24m_clk), .rst(~S_pll_lock),
        .d0(1'b1), .d1(1'b0), .q(O_cam_24m)
    );''')
 top.write_text(text,'utf8')
 rel=Path('user_source/hdl_source/uics500_cfg/uii2c.v')
 old=WORK/'lab_ex1_mipi_hdmi_sc520'/rel
 fixed=WORK/'lab_ex1_mipi_hdmi_sc520_clockfix'/rel
 if (dst/rel).read_bytes()!=old.read_bytes(): raise ValueError('I2C baseline differs; no blind copy')
 shutil.copy2(fixed,dst/rel)
 # The source module is copied exactly; threshold is an instance parameter.
 rtl=dst/'user_source/hdl_source/video_cartoon.v'
 if stage=='s3_luma': shutil.copy2(ROOT/'work/rtl/video_cartoon_luma.v',rtl)
 expected=ROOT/('work/rtl/video_cartoon_luma.v' if stage=='s3_luma' else 'work/rtl/video_cartoon.v')
 if rtl.read_bytes()!=expected.read_bytes():
  raise ValueError('Working RTL differs from tested RTL')
 for kind in ['syn_1','phy_1']:
  run=dst/'td_project/camera_to_dsi_display_Runs'/kind
  run.mkdir(parents=True)
  for name in ['settings.cfg','camera_to_dsi_display.prj']:
   shutil.copy2(SOURCE/'td_project/camera_to_dsi_display_Runs'/kind/name,run/name)
 manifest={str(p.relative_to(dst)):sha(p) for p in dst.rglob('*') if p.is_file()}
 (dst/'input-sha256.json').write_text(json.dumps(manifest,indent=2),'utf8')
 return dst

def build(stage,threshold,resume=False):
 dst=WORK/('staged_cartoon_'+stage) if resume else prepare(stage,threshold)
 report=OUT/stage
 report.mkdir(parents=True,exist_ok=resume)
 if resume:
  manifest=json.loads((dst/'input-sha256.json').read_text())
  for name,digest in manifest.items():
   if sha(dst/name)!=digest: raise ValueError('Inputs changed: '+name)
  for name in ['syn_1.log','phy_1.log']:
   source=report/name
   if source.exists(): source.rename(report/(name+'.first-failure'))
 print('PREPARED',stage,dst,flush=True)
 for kind in ['syn_1','phy_1']:
  run=dst/'td_project/camera_to_dsi_display_Runs'/kind
  with (report/(kind+'.log')).open('w',encoding='utf8') as f:
   result=subprocess.run([str(TD),FLOW.as_posix()],cwd=run,stdin=subprocess.DEVNULL,stdout=f,stderr=subprocess.STDOUT)
  text=(report/(kind+'.log')).read_text('utf8',errors='replace')
  if result.returncode or "couldn't read file" in text or 'finish command' not in text or re.search(r'\b(?:ERROR|FATAL)(?::| )',text):
   raise RuntimeError(stage+' '+kind+' failed; inspect log')
  print('FINISHED',stage,kind,flush=True)
 phy=dst/'td_project/camera_to_dsi_display_Runs/phy_1'
 qor=(phy/'route.qor').read_text()
 metrics={key:int(re.search(r'\|\s*'+key+r'\s*\|\s*(-?\d+)',qor).group(1)) for key in ['Setup WNS','Setup TNS','Hold WNS','Hold TNS']}
 passed=metrics['Setup WNS']>=0 and metrics['Hold WNS']>=0 and metrics['Setup TNS']==0 and metrics['Hold TNS']==0
 warnings=[]
 for kind in ['syn_1','phy_1']:
  warnings += [line for line in (report/(kind+'.log')).read_text('utf8',errors='replace').splitlines() if 'WARNING' in line]
 critical=[line for line in warnings if 'CRITICAL-WARNING' in line]
 # Preserve generated candidates even when blocked, but never mark them released.
 bits={}
 for src in phy.glob('*.bit'):
  name=stage+('_compress' if 'compress' in src.name else '')+'.bit'
  shutil.copy2(src,report/name); bits[name]=sha(report/name)
 if not bits: raise RuntimeError('No generated bitstream')
 for name in ['route.qor','final_timing.rpt','camera_to_dsi_display_phy.ts','route_clock_utilization.txt']:
  shutil.copy2(phy/name,report/name)
 shutil.copy2(dst/'input-sha256.json',report/'input-sha256.json')
 data={'stage':stage,'threshold':threshold,'project':str(dst.relative_to(ROOT)), 'timing_ps':metrics,
       'timing_pass':passed,'critical_warnings':critical,'bitstreams':bits,
       'hardware_verified':False,'download_release':'BLOCKED_PENDING_CONSTRAINT_WARNING_AND_BASELINE_REVIEW'}
 (report/'manifest.json').write_text(json.dumps(data,indent=2),'utf8')
 (report/'warnings.txt').write_text('\n'.join(warnings),'utf8')
 print(json.dumps(data,indent=2),flush=True)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('stage',choices=['s1_color','s2_contour','s3_luma'])
 p.add_argument('--resume',action='store_true')
 a=p.parse_args(); build(a.stage,2047 if a.stage=='s1_color' else 240,a.resume)
