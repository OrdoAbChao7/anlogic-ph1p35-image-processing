import hashlib
import json
from pathlib import Path
import importlib.util
import pytest


ROOT = Path(__file__).resolve().parents[2]


def load_build_module():
    spec = importlib.util.spec_from_file_location(
        "industrial_td_build", ROOT / "scripts" / "build_industrial_td.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_industrial_build_uses_formal_s4_region_fill_cartoon_rtl():
    build_script = (ROOT / "scripts" / "build_industrial_td.py").read_text(encoding="utf-8")
    assert 'DEFAULT_TRACKED_VIDEO = TRACKED_RTL / "video" / "video_cartoon_region_fill.v"' in build_script
    assert 'TRACKED_DDR_INTERFACE = ROOT / "fallback" / "td_package" / "user_source" / "hdl_source" / "mc_to_user_interface.v"' in build_script
    assert 'TRACKED_VTC = ROOT / "fallback" / "td_source" / "uivtc_guarded.v"' in build_script
    assert 'TRACKED_MIXER = ROOT / "fallback" / "td_source" / "hdmi_mixer_guarded.v"' in build_script
    assert '"vtc/uivtc.v": TRACKED_VTC' in build_script
    assert '"hdmi_mixer.v": TRACKED_MIXER' in build_script


def test_project_owned_video_timing_guards_are_present():
    assert (ROOT / "fallback" / "td_source" / "uivtc_guarded.v").is_file()
    assert (ROOT / "fallback" / "td_source" / "hdmi_mixer_guarded.v").is_file()
    assert (ROOT / "fallback" / "sim" / "display" / "tb_video_timing_contract.v").is_file()


def test_inspection_result_cdc_is_in_simulation_and_td_source_sets():
    assert (ROOT / "fallback" / "rtl" / "inspection" / "inspection_result_cdc.v").is_file()
    assert (ROOT / "fallback" / "sim" / "inspection" / "tb_inspection_result_cdc.v").is_file()
    build_script = (ROOT / "scripts" / "build_industrial_td.py").read_text(encoding="utf-8")
    assert '"inspection_result_cdc.v": TRACKED_RTL / "inspection" / "inspection_result_cdc.v"' in build_script
    verify_script = (ROOT / "scripts" / "verify-industrial-subsystem.ps1").read_text(encoding="utf-8")
    assert "tb_inspection_result_cdc.v" in verify_script


def test_industrial_contract_matrix_is_in_the_one_click_regression():
    verify_script = (ROOT / "scripts" / "verify-industrial-subsystem.ps1").read_text(encoding="utf-8")
    assert (ROOT / "fallback" / "sim" / "inspection" / "tb_industrial_contract.v").is_file()
    assert "tb_industrial_contract.v" in verify_script
    assert "Industrial Detector/Classifier Contract Matrix" in verify_script


def test_current_video_rtl_is_kept_with_synthesizable_fallback_sources():
    assert (ROOT / "fallback" / "rtl" / "video" / "video_cartoon_region_fill.v").is_file()
    assert (ROOT / "fallback" / "rtl" / "video" / "video_cartoon_luma.v").is_file()


def test_industrial_build_writes_the_downloadable_release_directory():
    build_script = (ROOT / "scripts" / "build_industrial_td.py").read_text(encoding="utf-8")
    assert 'DEFAULT_RELEASE_DIR = ROOT / "release" / "industrial-v1"' in build_script


def test_formal_release_exposes_one_compressed_bitstream():
    release = ROOT / "release" / "industrial-v1"
    bit_files = sorted(path.name for path in release.glob("*.bit"))
    assert bit_files == ["camera_to_dsi_display_compress.bit"]


def test_industrial_build_exposes_reproducible_external_inputs():
    build_script = (ROOT / "scripts" / "build_industrial_td.py").read_text(encoding="utf-8")
    assert "--td-exe" in build_script
    assert "--flow-tcl" in build_script
    assert "--baseline-runs" in build_script
    assert "industrial-v1-manifest.json" in build_script


def test_tool_discovery_does_not_embed_the_author_machine_path():
    build_script = (ROOT / "scripts" / "build_industrial_td.py").read_text(encoding="utf-8")
    verify_script = (ROOT / "scripts" / "verify-industrial-subsystem.ps1").read_text(encoding="utf-8")
    assert "E:/Projects/FPGA" not in build_script
    assert "E:\\Projects\\FPGA" not in verify_script
    assert "FPGA_TD_EXE" in build_script
    assert "FPGA_FLOW_TCL" in build_script
    assert "FPGA_BASELINE_RUNS" in build_script
    assert "FPGA_IVERILOG_ROOT" in verify_script


def test_industrial_build_argument_overrides_are_parsed():
    module = load_build_module()
    args = module.parse_args([
        "--td-exe", "td.exe",
        "--flow-tcl", "flow.tcl",
        "--baseline-runs", "baseline",
        "--release-dir", "release",
        "--top-rtl", "candidate_top.v",
        "--manifest-only",
    ])
    assert args.td_exe == "td.exe"
    assert args.flow_tcl == "flow.tcl"
    assert args.baseline_runs == "baseline"
    assert args.release_dir == "release"
    assert args.top_rtl == "candidate_top.v"
    assert args.manifest_only is True


def test_industrial_build_defaults_to_tracked_td_input_package():
    module = load_build_module()
    args = module.parse_args([])
    assert Path(args.input_package).resolve() == (ROOT / "fallback" / "td_package").resolve()


def test_candidate_top_requires_isolated_outputs():
    module = load_build_module()
    args = module.parse_args([
        "--top-rtl", "candidate_top.v",
        "--work-project", str(module.DEFAULT_WORK_PROJECT),
        "--release-dir", str(module.DEFAULT_RELEASE_DIR),
    ])
    with pytest.raises(ValueError, match="Candidate top RTL requires an isolated"):
        module.configure(args)


def test_hx1p35a_manual_led_and_mode_pins_are_bound():
    pin_file = (ROOT / "fallback" / "td_package" / "user_source" / "constraints_source" / "pin.adc")
    pin_text = pin_file.read_text(encoding="utf-8")
    assert "{ I_button[0] }" in pin_text and "LOCATION = D5" in pin_text
    assert "{ I_button[1] }" in pin_text and "LOCATION = A9" in pin_text
    assert "{ O_led1 }" in pin_text and "LOCATION = D10" in pin_text
    assert "{ O_led2 }" in pin_text and "LOCATION = E10" in pin_text
    assert "{ O_led3 }" in pin_text and "LOCATION = C6" in pin_text
    for signal in ("I_button2", "I_button3", "O_led_pass", "O_led_ng", "O_led_det"):
        assert f"{{ {signal} }}" not in pin_text


def test_hx1p35a_board_features_have_the_confirmed_top_level_io():
    top = (ROOT / "fallback" / "td_source" / "design_top_wrapper.v").read_text(encoding="utf-8")
    header = top.split(");", 1)[0]
    for port in ("O_led1", "O_led2", "O_led3"):
        assert port in header
    for port in ("O_led_pass", "O_led_ng", "O_led_det", "I_button2", "I_button3", "I_rst_n", "O_screen_pwm"):
        assert port not in header
    assert "wire I_mode_edge_n = I_button[0];" in top
    assert "wire I_mode_cartoon_n = I_button[1];" in top
    assert ".I_key_edge_n   ( I_mode_edge_n    )" in top
    assert ".I_key_cartoon_n( I_mode_cartoon_n )" in top
    assert '(* keep = "true" *) wire O_led_pass;' in top
    assert '(* keep = "true" *) wire O_led_ng;' in top
    assert '(* keep = "true" *) wire O_led_det;' in top
    assert ".reset    \t ( 1'b0              )" in top
    assert "assign O_led1 = O_led_pass;" in top
    assert "assign O_led2 = O_led_ng;" in top
    assert "assign O_led3 = O_led_det;" in top


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
    rtl = (ROOT / "fallback" / "rtl" / "inspection" / "morph_open_96.v").read_text(encoding="utf-8")
    runner = (ROOT / "work" / "tests" / "run_industrial_rtl_golden.py").read_text(encoding="utf-8")
    assert "module morph_line_ram_4bit" in rtl
    assert "PH1P_LOGIC_ERAM" in rtl
    assert "`ifdef MORPH_SIMULATION" in rtl
    assert '"-DMORPH_SIMULATION"' in runner


def test_roi_parameters_reach_both_morphology_passes_and_boundary_regression():
    morph = (ROOT / "fallback" / "rtl" / "inspection" / "morph_open_96.v").read_text(encoding="utf-8")
    detector = (ROOT / "fallback" / "rtl" / "inspection" / "color_detect_96_v2.v").read_text(encoding="utf-8")
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
    assert "fallback/rtl/inspection/morph_open_96.v" in script
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
    assert "run_cartoon_region_fill_sim.py" in script
    assert "tb_osd_led_joint.v" in script
    assert "industrial_osd_overlay.v" in script


def test_legacy_industrial_verification_covers_mode_and_classifier_contracts():
    script = (ROOT / "scripts" / "verify-industrial-subsystem.ps1").read_text(encoding="utf-8")
    assert "tb_mode_controller.v" in script
    assert "tb_defect_classifier.v" in script
    assert "mode_controller_run" in script
    assert "defect_classifier_run" in script


def test_cartoon_streaming_regression_exposes_full_frame_mode():
    runner = (ROOT / "work" / "tests" / "run_cartoon_region_fill_sim.py").read_text(encoding="utf-8")
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
        "docs/verification-matrix.md",
        "docs/evidence/industrial-v1-stage-g-template.md",
        "docs/fallback-status.md",
        "docs/evidence/industrial-v1-requirement-audit.md",
    ):
        assert bit_sha in (ROOT / rel).read_text(encoding="utf-8"), f"{rel} is stale for the current release bitstream"


def test_release_readme_binds_current_qor_snapshot():
    readme = (ROOT / "release" / "industrial-v1" / "README.md").read_text(encoding="utf-8")
    assert "Setup WNS：`104 ps`" in readme
    assert "Hold WNS：`20 ps`" in readme
    assert "Slices：`17,679 / 83.33%`" in readme
    assert "RAM：`43`" in readme
    assert "DSP：`24`" in readme


def test_manifest_records_external_td_input_provenance():
    manifest = json.loads((ROOT / "release" / "industrial-v1" / "industrial-v1-manifest.json").read_text(encoding="utf-8"))
    hashes = manifest["build_input_hashes"]
    for key in ("td_exe", "flow_tcl"):
        assert hashes[key]["exists"] is True
        assert len(hashes[key]["sha256"]) == 64
    for key in ("syn_1/settings.cfg", "syn_1/camera_to_dsi_display.prj", "phy_1/settings.cfg", "phy_1/camera_to_dsi_display.prj"):
        assert hashes["baseline_files"][key]["exists"] is True
        assert len(hashes["baseline_files"][key]["sha256"]) == 64


def test_manifest_uses_portable_external_input_tokens():
    manifest = json.loads((ROOT / "release" / "industrial-v1" / "industrial-v1-manifest.json").read_text(encoding="utf-8"))
    assert manifest["build_inputs"]["td_exe"] in ("<FPGA_TD_EXE>", ".tools/td/app/bin/td_commands_prompt.exe")
    assert manifest["build_inputs"]["flow_tcl"] in ("<FPGA_FLOW_TCL>", ".tools/td/app/doc/scripts/DefaultFlow.tcl")
    assert not any("E:\\Projects\\" in json.dumps(manifest, ensure_ascii=False) for _ in [0])


def test_current_requirement_and_warning_audits_bind_the_current_build():
    requirement_audit = (ROOT / "docs" / "evidence" / "industrial-v1-requirement-audit.md").read_text(encoding="utf-8")
    warning_audit = (ROOT / "docs" / "evidence" / "industrial-v1-td-warning-audit.md").read_text(encoding="utf-8")
    assert "17,679" in requirement_audit
    assert "83.33%" in requirement_audit
    assert "Setup WNS `+104 ps`" in requirement_audit
    assert "Hold WNS `+20 ps`" in requirement_audit
    assert "17,679" in warning_audit
    assert "83.33%" in warning_audit
    assert "Setup WNS `+104 ps`" in warning_audit
    assert "Hold WNS `+20 ps`" in warning_audit
    assert "ba451dddce56234c0e7e5801af28fa11f209d4522978ac92e668ad7554f3c53e" in requirement_audit
    assert "ba451dddce56234c0e7e5801af28fa11f209d4522978ac92e668ad7554f3c53e" in warning_audit
    assert "PHY-7022" not in warning_audit
    for code in ("SYN-5011", "SYN-5025", "SYN-5041", "PHY-5079", "PHY-5088"):
        assert code in warning_audit


def test_g2_video_interface_contract_is_traceable_through_the_top_level():
    top = (ROOT / "fallback" / "td_source" / "design_top_wrapper.v").read_text(encoding="utf-8")
    isp = (ROOT / "fallback" / "td_source" / "isp" / "isp_top.v").read_text(encoding="utf-8")
    hdmi = (ROOT / "fallback" / "td_package" / "user_source" / "hdl_source" / "hdmi_tx.v").read_text(encoding="utf-8")

    # MIPI/CSI-2/RAW10 to the fixed 1280x720 ISP input contract.
    for marker in (
        "csi_unpacket_2lane u_csi_unpacket",
        "raw10_unpacket_2lane u_raw10_unpacket",
        ".IMG_WIDTH(1280)",
        ".IMG_HEIGHT(720)",
        ".INPUT_DATA_WIDTH(40)",
        ".I_data_start(S_raw10_frame_start)",
        ".I_data_end  (S_raw10_frame_end  )",
    ):
        assert marker in top, marker

    # The ISP must preserve the AXI sidebands and expose the detector result
    # in the same source clock domain as the AWB RGB stream.
    for marker in (
        "input [39:0]",
        "output [127:0]",
        "u_demosaic",
        "u_awb",
        ".I_96b_valid",
        ".I_96b_frame_start",
        ".O_frame_sync",
    ):
        assert marker in isp, marker

    # The fixed-red branch feeds DDR through video_in; the reader is timed by
    # the explicit 720p VTC and the OSD output reaches HDMI TX in RGB mode.
    for marker in (
        ".I_camera_frame_start ( S_ISP_O_tuser",
        ".I_camera_valid       ( S_ISP_O_tvalid",
        "u_video_out",
        "u_hdmi_vtc",
        ".H_FrameSize  ( 1650 )",
        ".V_FrameSize  ( 750  )",
        "u_hdmi_mixer",
        ".I_video_rgb_enable ( 1'b1",
        ".I_video_in_de      ( S_osd_out_de",
        ".I_video_in_vs      ( S_osd_out_vsync",
        ".I_video_in_data    ( S_osd_out_data",
    ):
        assert marker in top, marker

    # In RGB mode the vendor HDMI wrapper derives stream valid/last/user from
    # DE/VS and intentionally ignores the stream sidebands supplied by the
    # caller. Keep this contract explicit so a future refactor cannot silently
    # switch the TX back to AXI-stream mode.
    assert "I_video_rgb_enable" in hdmi
    assert "I_video_in_de" in hdmi
    assert "I_video_in_vs" in hdmi
    assert "I_video_rgb_enable == 1'b1" in hdmi


if __name__ == "__main__":
    test_industrial_build_uses_formal_s4_region_fill_cartoon_rtl()
    test_industrial_build_writes_the_downloadable_release_directory()
    test_formal_release_exposes_one_compressed_bitstream()
    test_industrial_build_exposes_reproducible_external_inputs()
    test_tool_discovery_does_not_embed_the_author_machine_path()
    test_industrial_build_argument_overrides_are_parsed()
    test_hx1p35a_manual_led_and_mode_pins_are_bound()
    test_hx1p35a_board_features_have_the_confirmed_top_level_io()
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
    test_current_requirement_and_warning_audits_bind_the_current_build()
    test_g2_video_interface_contract_is_traceable_through_the_top_level()
    print("PASS industrial build contracts")
