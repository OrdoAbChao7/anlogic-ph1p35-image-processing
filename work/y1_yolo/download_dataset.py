"""Download exact annotation sources required by prepare_dataset.py."""
from __future__ import annotations

import hashlib
import urllib.request
import zipfile
from pathlib import Path

DATA = Path(__file__).resolve().parent / "datasets"
SOURCES = [
    ("coco128.zip",
     "https://github.com/ultralytics/assets/releases/download/v0.0.0/coco128.zip",
     "61e5e3028863d8ffc3b81d6a514603954889f0edd5e4b44c4ce60b2da99aeb8e"),
    ("instances_val2017.json",
     "https://huggingface.co/datasets/merve/coco/resolve/main/annotations/instances_val2017.json",
     "e8c7f7908f1d7278341fae127d0da654f102f11bd7b21d8aeefa635b8c810b6f"),
]


def main() -> None:
    DATA.mkdir(exist_ok=True)
    for filename, url, expected in SOURCES:
        path = DATA / filename
        if not path.exists():
            urllib.request.urlretrieve(url, path)
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        if actual != expected:
            raise RuntimeError(f"{filename}: SHA256 {actual} != {expected}")
        print(filename, actual)
    with zipfile.ZipFile(DATA / "coco128.zip") as archive:
        archive.extractall(DATA)


if __name__ == "__main__":
    main()
