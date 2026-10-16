import hashlib
import json
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


def test_qor_gate_parses_and_rejects_non_converged_reports():
    module = load_build_module()
    passing = """
|     Setup WNS             |          116                |
|     Setup TNS             |            0                |
|     Num of violated S-EP |            0                |
|     Hold WNS              |           20                |
|     Hold TNS              |            0                |
|     Num of violated H-EP |            0                |
|     #slices               |        20159                |
|     slices percentage     |       95.02%                |
|     #RAMs                 |           39                |
|     #DSPs                 |           24                |
"""
    metrics = module.parse_qor_metrics(passing)
    assert metrics["setup_wns_ps"] == 116
    assert metrics["hold_wns_ps"] == 20
    assert metrics["slices"] == 20159
    module.assert_qor_pass(metrics)

    failing = passing.replace("116", "-12").replace("0                |            0", "0                |            1", 1)
    failed = False
    try:
        module.assert_qor_pass(module.parse_qor_metrics(failing))
    except RuntimeError as exc:
        failed = True
        assert "QoR gate" in str(exc)
    assert failed, "negative WNS or violated endpoints must block release"


def test_morphology_declares_explicit_eram_wrapper_and_simulation_path():
    rtl = (ROOT / "fallback" / "rtl" / "morph_open_96.v").read_text(encoding="utf-8")
    runner = (ROOT / "work" / "tests" / "run_industrial_rtl_golden.py").read_text(encoding="utf-8")
    assert "module morph_line_ram_4bit" in rtl
    assert "PH1P_LOGIC_ERAM" in rtl
    assert "`ifdef MORPH_SIMULATION" in rtl
    assert '"-DMORPH_SIMULATION"' in runner


def test_legacy_industrial_verification_does_not_overwrite_user_vvp_and_compiles_morphology():
    script = (ROOT / "scripts" / "verify-industrial-subsystem.ps1").read_text(encoding="utf-8")
    assert "fallback/tb_color.vvp" not in script
    assert "verification_outputs" in script
    assert "-DMORPH_SIMULATION" in script
    assert "fallback/rtl/morph_open_96.v" in script
    assert "Start-Process" in script


def test_legacy_industrial_verification_includes_full_frame_and_threshold_gates():
    script = (ROOT / "scripts" / "verify-industrial-subsystem.ps1").read_text(encoding="utf-8")
    assert "tb_color_detect_96_v2.v" in script
    assert "tb_color_detect_96_v2_boundaries.v" in script
    assert "full_frame_compile" in script
    assert "threshold_boundaries_compile" in script


def test_legacy_industrial_verification_covers_approved_modes_and_osd_led():
    script = (ROOT / "scripts" / "verify-industrial-subsystem.ps1").read_text(encoding="utf-8")
    assert "test_stage_d.py" in script
    assert "test_industrial_contract.py" in script
    assert "run_cartoon_luma_sim.py" in script
    assert "tb_osd_led_joint.v" in script
    assert "industrial_osd_overlay.v" in script


def test_release_docs_bind_the_current_bitstream_manifest():
    manifest = json.loads((ROOT / "release" / "industrial-v1" / "industrial-v1-manifest.json").read_text(encoding="utf-8"))
    bit_path = ROOT / "release" / "industrial-v1" / "camera_to_dsi_display_compress.bit"
    bit_sha = hashlib.sha256(bit_path.read_bytes()).hexdigest()
    artifact = next(item for item in manifest["artifacts"] if item["path"].endswith("camera_to_dsi_display_compress.bit"))
    assert artifact["sha256"] == bit_sha
    for rel in ("README.md", "docs/evidence/industrial-v1-stage-g-template.md", "docs/fallback-status.md"):
        assert bit_sha in (ROOT / rel).read_text(encoding="utf-8"), f"{rel} is stale for the current release bitstream"


if __name__ == "__main__":
    test_industrial_build_uses_approved_luma_cartoon_rtl()
    test_industrial_build_writes_the_downloadable_release_directory()
    test_industrial_build_exposes_reproducible_external_inputs()
    test_industrial_build_argument_overrides_are_parsed()
    test_qor_gate_parses_and_rejects_non_converged_reports()
    test_morphology_declares_explicit_eram_wrapper_and_simulation_path()
    test_legacy_industrial_verification_does_not_overwrite_user_vvp_and_compiles_morphology()
    test_legacy_industrial_verification_includes_full_frame_and_threshold_gates()
    test_legacy_industrial_verification_covers_approved_modes_and_osd_led()
    test_release_docs_bind_the_current_bitstream_manifest()
    print("PASS industrial build contracts")
