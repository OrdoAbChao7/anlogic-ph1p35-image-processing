"""One-command reproducibility gate; launch with the project's Windows venv."""
import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parent
PIN={"Yolo-FastestV2":("https://github.com/dog-qiuqiu/Yolo-FastestV2.git","ac2a5e3060bff76dd1e45f9b921dd77bfbeb194d"),
     "fpga_accelerator_yolov3tiny":("https://github.com/adamgallas/fpga_accelerator_yolov3tiny.git","6ba312bd220e67a987d3417bacd030db30b15770")}


def run(*argv):
    print("RUN",*[str(x) for x in argv],flush=True)
    subprocess.run([str(x) for x in argv],check=True,cwd=ROOT)


parser=argparse.ArgumentParser()
parser.add_argument("--bootstrap",action="store_true")
args=parser.parse_args()
GIT=shutil.which("git") or r"C:\Program Files\Git\cmd\git.exe"
if not Path(GIT).exists():raise RuntimeError("Git executable missing")
for name,(url,commit) in PIN.items():
    repo=ROOT/"upstream"/name
    if not repo.exists():
        if not args.bootstrap:raise RuntimeError(f"missing {repo}; use --bootstrap")
        run(GIT,"clone",url,repo)
    actual=subprocess.check_output([GIT,"-C",str(repo),"rev-parse","HEAD"],text=True).strip()
    if actual!=commit:
        if not args.bootstrap:raise RuntimeError(f"unexpected commit {name}: {actual}")
        run(GIT,"-C",repo,"checkout","--detach",commit)
run(sys.executable,ROOT/"fetch_eval_images.py")
run(sys.executable,ROOT/"run_official_smoke.py")
run(sys.executable,ROOT/"check_decode.py")
run(sys.executable,ROOT/"run_study.py","profile","--out",ROOT/"results/profile")
run(sys.executable,ROOT/"profile_liveness.py")
for size in (352,160,128,96):
    run(sys.executable,ROOT/"run_study.py","eval","--manifest",ROOT/"data/frozen_eval_manifest.json",
        "--size",size,"--out",ROOT/f"results/frozen_eval_{size}")
run(sys.executable,ROOT/"run_study.py","eval","--manifest",ROOT/"data/frozen_eval_manifest.json",
    "--size",352,"--conf",0.001,"--out",ROOT/"results/frozen_eval_352_conf0001")
run(sys.executable,ROOT/"check_rtl.py")
run(sys.executable,ROOT/"make_budget.py")
print("Reproduction PASS",flush=True)
