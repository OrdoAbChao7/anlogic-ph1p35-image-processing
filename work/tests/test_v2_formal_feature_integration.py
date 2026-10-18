from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TOP = ROOT / "fallback" / "td_source" / "design_top_wrapper.v"
ISP = ROOT / "fallback" / "td_source" / "isp" / "isp_top.v"
BUILD = ROOT / "scripts" / "build_industrial_td.py"
AUDIT = ROOT / "scripts" / "verify_industrial_v2_release.py"


def test_formal_top_exposes_awb_stream_and_instantiates_all_v2_feature_boundaries():
    top = TOP.read_text(encoding="utf-8")
    isp = ISP.read_text(encoding="utf-8")

    for marker in (
        "O_ind_awb_tdata",
        "O_ind_awb_tvalid",
        "O_ind_awb_tlast",
        "O_ind_awb_tuser",
    ):
        assert marker in isp, f"formal ISP must expose {marker} for V2 source-domain features"
        assert marker in top, f"formal wrapper must connect {marker}"

    for marker in (
        "motion_grid_adapter_96 #(",
        "u_v2_motion_grid_adapter",
        "frame_stats_96 #(",
        "u_v2_frame_stats",
        "industrial_v2_feature_spine u_industrial_v2_feature_spine",
    ):
        assert marker in top, f"formal top is missing {marker}"


def test_formal_result_cdc_consumes_feature_spine_outputs_not_zero_ties():
    top = TOP.read_text(encoding="utf-8")
    cdc_block = top.split("industrial_v2_result_cdc u_industrial_v2_result_cdc", 1)[1].split(");", 1)[0]

    for port in (
        ".I_src_dimension_valid",
        ".I_src_shape_valid",
        ".I_src_motion",
        ".I_src_motion_count",
        ".I_src_pass_count",
        ".I_src_ng_count",
        ".I_src_sort_pulse",
        ".I_src_safe_enable",
    ):
        assert port in cdc_block
    assert "( 1'b0" not in cdc_block
    assert "( 24'd0" not in cdc_block


def test_td_builder_tracks_all_formal_v2_sources():
    build = BUILD.read_text(encoding="utf-8")
    for filename in (
        "industrial_v2_feature_spine.v",
        "motion_grid_adapter_96.v",
        "frame_stats_96.v",
        "frame_tag_monitor.v",
        "latency_monitor.v",
        "motion_diff_160.v",
        "awb_frame_gain_controller.v",
        "dimension_calibrator.v",
        "sort_event_controller.v",
        "sort_safety_interlock.v",
        "sort_pulse_generator.v",
    ):
        assert filename in build, f"TD builder source manifest is missing {filename}"


def test_release_audit_binds_the_complete_formal_feature_candidate():
    audit = AUDIT.read_text(encoding="utf-8")
    for path in (
        "docs/experiments/2026-10-19-industrial-v2-g8-formal-feature-td.md",
        "release/candidates/industrial-v2-formal-feature-spine/route.qor",
        "release/candidates/industrial-v2-formal-feature-spine/final_timing.rpt",
        "release/candidates/industrial-v2-formal-feature-spine/camera_to_dsi_display_compress.bit",
    ):
        assert path in audit
    assert "TD_PASS" in audit


def test_release_audit_binds_the_v2_clock_warning_evidence():
    audit = AUDIT.read_text(encoding="utf-8")
    for path in (
        "docs/evidence/industrial-v2-g8-clock-warning-audit.md",
        "docs/evidence/industrial-v2-g8-clock-warning-audit-log.txt",
    ):
        assert path in audit
    assert "PHY-5079" in audit
    assert "PHY-5088" in audit


def test_td_builder_supports_a_reproducible_placement_seed():
    build = BUILD.read_text(encoding="utf-8")
    assert "--place-seed" in build
    assert "set_param place seed" in build
    assert "industrial_v2_fixed_seed.tcl" in build
