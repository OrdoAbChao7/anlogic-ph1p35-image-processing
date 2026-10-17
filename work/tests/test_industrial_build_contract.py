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


def test_roi_parameters_reach_both_morphology_passes_and_boundary_regression():
    morph = (ROOT / "fallback" / "rtl" / "morph_open_96.v").read_text(encoding="utf-8")
    detector = (ROOT / "fallback" / "rtl" / "color_detect_96_v2.v").read_text(encoding="utf-8")
    runner = (ROOT / "work" / "tests" / "run_industrial_rtl_golden.py").read_text(encoding="utf-8")
    assert morph.count(".ROI_X(ROI_X)") >= 2
    assert morph.count(".ROI_WIDTH(ROI_WIDTH)") >= 2
    assert ".ROI_X(ROI_X)" in detector
    assert '"roi_boundary"' in runner


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


def test_legacy_industrial_verification_covers_mode_and_classifier_contracts():
    script = (ROOT / "scripts" / "verify-industrial-subsystem.ps1").read_text(encoding="utf-8")
    assert "tb_mode_controller.v" in script
    assert "tb_defect_classifier.v" in script
    assert "mode_controller_run" in script
    assert "defect_classifier_run" in script


def test_cartoon_streaming_regression_exposes_full_frame_mode():
    runner = (ROOT / "work" / "tests" / "run_cartoon_luma_sim.py").read_text(encoding="utf-8")
    assert "--full-frame" in runner
    assert "1280, 720" in runner


def test_release_docs_bind_the_current_bitstream_manifest():
    manifest = json.loads((ROOT / "release" / "industrial-v1" / "industrial-v1-manifest.json").read_text(encoding="utf-8"))
    bit_path = ROOT / "release" / "industrial-v1" / "camera_to_dsi_display_compress.bit"
    bit_sha = hashlib.sha256(bit_path.read_bytes()).hexdigest()
    artifact = next(item for item in manifest["artifacts"] if item["path"].endswith("camera_to_dsi_display_compress.bit"))
    assert artifact["sha256"] == bit_sha
    for rel in (
        "README.md",
        "docs/evidence/industrial-v1-stage-g-template.md",
        "docs/fallback-status.md",
        "docs/evidence/industrial-v1-requirement-audit.md",
    ):
        assert bit_sha in (ROOT / rel).read_text(encoding="utf-8"), f"{rel} is stale for the current release bitstream"


def test_manifest_records_external_td_input_provenance():
    manifest = json.loads((ROOT / "release" / "industrial-v1" / "industrial-v1-manifest.json").read_text(encoding="utf-8"))
    hashes = manifest["build_input_hashes"]
    for key in ("td_exe", "flow_tcl"):
        assert hashes[key]["exists"] is True
        assert len(hashes[key]["sha256"]) == 64
    for key in ("syn_1/settings.cfg", "syn_1/camera_to_dsi_display.prj", "phy_1/settings.cfg", "phy_1/camera_to_dsi_display.prj"):
        assert hashes["baseline_files"][key]["exists"] is True
        assert len(hashes["baseline_files"][key]["sha256"]) == 64


def test_current_requirement_and_warning_audits_bind_the_eram_build():
    requirement_audit = (ROOT / "docs" / "evidence" / "industrial-v1-requirement-audit.md").read_text(encoding="utf-8")
    warning_audit = (ROOT / "docs" / "evidence" / "industrial-v1-td-warning-audit.md").read_text(encoding="utf-8")
    for text in (requirement_audit, warning_audit):
        assert "16,852" in text
        assert "79.43%" in text
        assert "Setup WNS `+103 ps`" in text
        assert "Hold WNS `+20 ps`" in text
    assert "77fd2acdc10d1fea6aadb180767a7b93af7c43748228d5c600669b820f9cf8d4" not in requirement_audit
    assert "PHY-7022" not in warning_audit
    for code in ("SYN-5011", "SYN-5013", "SYN-5025", "SYN-5065", "PHY-5016", "PHY-5060", "PHY-5079", "PHY-5088", "PRJ-5611"):
        assert code in warning_audit


if __name__ == "__main__":
    test_industrial_build_uses_approved_luma_cartoon_rtl()
    test_industrial_build_writes_the_downloadable_release_directory()
    test_industrial_build_exposes_reproducible_external_inputs()
    test_industrial_build_argument_overrides_are_parsed()
    test_qor_gate_parses_and_rejects_non_converged_reports()
    test_morphology_declares_explicit_eram_wrapper_and_simulation_path()
    test_roi_parameters_reach_both_morphology_passes_and_boundary_regression()
    test_legacy_industrial_verification_does_not_overwrite_user_vvp_and_compiles_morphology()
    test_legacy_industrial_verification_includes_full_frame_and_threshold_gates()
    test_legacy_industrial_verification_covers_approved_modes_and_osd_led()
    test_legacy_industrial_verification_covers_mode_and_classifier_contracts()
    test_cartoon_streaming_regression_exposes_full_frame_mode()
    test_release_docs_bind_the_current_bitstream_manifest()
    test_manifest_records_external_td_input_provenance()
    test_current_requirement_and_warning_audits_bind_the_eram_build()
    print("PASS industrial build contracts")
