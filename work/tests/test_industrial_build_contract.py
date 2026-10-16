from pathlib import Path
import importlib.util


ROOT = Path(__file__).resolve().parents[2]


def load_build_module():
    spec = importlib.util.spec_from_file_location(
        "industrial_td_build", ROOT / "scripts" / "build_industrial_td.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_industrial_build_uses_approved_luma_cartoon_rtl():
    build_script = (ROOT / "scripts" / "build_industrial_td.py").read_text(encoding="utf-8")
    assert 'TRACKED_VIDEO = ROOT / "work" / "rtl" / "video_cartoon_luma.v"' in build_script


def test_industrial_build_writes_the_downloadable_release_directory():
    build_script = (ROOT / "scripts" / "build_industrial_td.py").read_text(encoding="utf-8")
    assert 'DEFAULT_RELEASE_DIR = ROOT / "release" / "industrial-v1"' in build_script


def test_industrial_build_exposes_reproducible_external_inputs():
    build_script = (ROOT / "scripts" / "build_industrial_td.py").read_text(encoding="utf-8")
    assert "--td-exe" in build_script
    assert "--flow-tcl" in build_script
    assert "--baseline-runs" in build_script
    assert "industrial-v1-manifest.json" in build_script


def test_industrial_build_argument_overrides_are_parsed():
    module = load_build_module()
    args = module.parse_args([
        "--td-exe", "td.exe",
        "--flow-tcl", "flow.tcl",
        "--baseline-runs", "baseline",
        "--release-dir", "release",
        "--manifest-only",
    ])
    assert args.td_exe == "td.exe"
    assert args.flow_tcl == "flow.tcl"
    assert args.baseline_runs == "baseline"
    assert args.release_dir == "release"
    assert args.manifest_only is True


if __name__ == "__main__":
    test_industrial_build_uses_approved_luma_cartoon_rtl()
    test_industrial_build_writes_the_downloadable_release_directory()
    test_industrial_build_exposes_reproducible_external_inputs()
    test_industrial_build_argument_overrides_are_parsed()
    print("PASS industrial build contracts")
