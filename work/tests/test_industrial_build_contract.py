from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def test_industrial_build_uses_approved_luma_cartoon_rtl():
    build_script = (ROOT / "scripts" / "build_industrial_td.py").read_text(encoding="utf-8")
    assert 'TRACKED_VIDEO = ROOT / "work" / "rtl" / "video_cartoon_luma.v"' in build_script


def test_industrial_build_writes_the_downloadable_release_directory():
    build_script = (ROOT / "scripts" / "build_industrial_td.py").read_text(encoding="utf-8")
    assert 'RELEASE_DIR = ROOT / "release" / "industrial-v1"' in build_script


if __name__ == "__main__":
    test_industrial_build_uses_approved_luma_cartoon_rtl()
    test_industrial_build_writes_the_downloadable_release_directory()
    print("PASS industrial build contracts")
