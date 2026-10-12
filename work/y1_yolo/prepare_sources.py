"""Fetch pinned FastestDet Git objects without checking out ':' weight filename."""
from __future__ import annotations

import hashlib
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REPO = ROOT / "FastestDet"
URL = "https://github.com/dog-qiuqiu/FastestDet.git"
COMMIT = "50473cd155cb088aa4a99e64ff6a4b3c24fa07e1"
EXPECTED_WEIGHT_SHA256 = "7f688d478ee474c82dbdb9c10e0ede2f8f3cf5d603f0825d2efd925eb561d05e"
FILES = [
    "module/detector.py", "module/custom_layers.py", "module/shufflenetv2.py",
    "configs/coco.yaml", "configs/coco.names", "utils/tool.py",
    "example/onnx-runtime/FastestDet.onnx",
    "example/onnx-runtime/coco.names", "data/3.jpg",
]


def git(*args: str) -> bytes:
    return subprocess.check_output(["git", *args], cwd=REPO)


def main() -> None:
    if not (REPO / ".git").exists():
        REPO.mkdir(parents=True, exist_ok=True)
        subprocess.check_call(["git", "init", str(REPO)])
        git("remote", "add", "origin", URL)
    git("fetch", "--depth=1", "origin", COMMIT)
    assert git("rev-parse", "FETCH_HEAD").decode().strip() == COMMIT
    for name in FILES:
        path = REPO / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(git("show", f"{COMMIT}:{name}"))
    # Git holds the upstream ':' path; never ask Windows to check it out.
    safe = REPO / "weights" / "fastestdet_coco_safe.pth"
    safe.parent.mkdir(exist_ok=True)
    safe.write_bytes(git("show", f"{COMMIT}:weights/weight_AP05:0.253207_280-epoch.pth"))
    digest = hashlib.sha256(safe.read_bytes()).hexdigest()
    assert digest == EXPECTED_WEIGHT_SHA256, digest
    print("FastestDet", COMMIT, "safe weight SHA256", digest)


if __name__ == "__main__":
    main()

