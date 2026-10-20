from pathlib import Path
import re


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
        "industrial_v2_feature_spine #(\n        .USE_STATIC_CAL_CONFIG",
        "u_industrial_v2_feature_spine",
    ):
        assert marker in top, f"formal top is missing {marker}"


def test_formal_result_cdc_consumes_feature_spine_outputs_not_zero_ties():
    top = TOP.read_text(encoding="utf-8")
    cdc_block = top.split("industrial_v2_result_cdc u_industrial_v2_result_cdc", 1)[1].split(");", 1)[0]

    for port in (
        ".I_src_dimension_valid",
        ".I_src_shape_valid",
        ".I_src_motion_valid",
        ".I_src_motion",
        ".I_src_motion_count",
        ".I_src_pass_count",
        ".I_src_ng_count",
        ".I_src_sort_pulse",
        ".I_src_safe_enable",
        ".I_src_proc_valid",
        ".I_src_proc_cycles",
    ):
        assert port in cdc_block
    assert "( 1'b0" not in cdc_block
    assert "( 24'd0" not in cdc_block


def test_formal_result_tag_is_popped_from_ordered_input_frame_ledger():
    top = TOP.read_text(encoding="utf-8")
    queue_block = top.split("frame_result_tag_queue #(", 1)[1].split(");", 1)[0]
    spine_block = top.split("industrial_v2_feature_spine #(\n        .USE_STATIC_CAL_CONFIG", 1)[1].split(");", 1)[0]
    cdc_block = top.split("industrial_v2_result_cdc u_industrial_v2_result_cdc", 1)[1].split(");", 1)[0]

    assert ".I_push             ( S_ISP_O_tuser && S_ISP_O_tvalid )" in queue_block
    assert ".I_pop              ( ind_result_event" in queue_block
    assert ".I_result_frame_id        ( ind_result_frame_id )" in spine_block
    assert ".I_result_tag_valid       ( ind_result_tag_valid )" in spine_block
    assert ".I_src_frame_id        ( v2_src_result_frame_id_hold )" in cdc_block
    assert "v2_src_result_tag_valid_hold" in cdc_block


def test_formal_result_cdc_releases_reset_in_each_local_clock_domain():
    top = TOP.read_text(encoding="utf-8")
    cdc = (ROOT / "fallback" / "rtl" / "integration" / "industrial_v2_result_cdc.v").read_text(encoding="utf-8")
    cdc_block = top.split("industrial_v2_result_cdc u_industrial_v2_result_cdc", 1)[1].split(");", 1)[0]

    assert ".I_clk          ( S_csi_rx_clk" in top
    assert ".I_clk          ( S_hdmi_pixel_clk" in top
    assert re.search(r"\.I_src_rst_n\s*\(\s*S_v2_src_rst_n\s*\)", cdc_block)
    assert re.search(r"\.I_dst_rst_n\s*\(\s*S_v2_dst_rst_n\s*\)", cdc_block)
    assert "always @(posedge I_clk or negedge I_async_rst_n)" in cdc
    assert "release_pipe <= {release_pipe[0], 1'b1}" in cdc


def test_awb_gain_snapshot_cadence_is_integrated_and_explicit():
    isp = ISP.read_text(encoding="utf-8")
    controller = (ROOT / "fallback" / "rtl" / "isp" / "awb_frame_gain_controller.v").read_text(encoding="utf-8")

    assert "strictly after" in isp
    assert "first later accepted" in controller
    assert (ROOT / "fallback" / "sim" / "isp" / "tb_awb_frame_gain_cadence.v").is_file()


def test_formal_awb_gains_are_applied_to_the_shared_pixel_stream():
    top = TOP.read_text(encoding="utf-8")
    isp = ISP.read_text(encoding="utf-8")

    for gain in ("r", "g", "b"):
        assert re.search(
            rf"\.I_awb_gain_{gain}_q8_8\s*\(\s*v2_gain_{gain}\s*\)", top
        )
    assert "axis_gain_rgb96 u_axis_gain_rgb96" in isp
    gain_block = isp.split("axis_gain_rgb96 u_axis_gain_rgb96", 1)[1].split(");", 1)[0]
    assert re.search(r"\.I_tdata\s*\(\s*awb_O_tdata\s*\)", gain_block)
    assert re.search(r"\.O_tdata\s*\(\s*awb_gain_O_tdata\s*\)", gain_block)
    assert re.search(r"\.I_96b_data\s*\(\s*awb_gain_O_tdata\s*\)", isp)
    assert re.search(r"\.I_tdata\s*\(\s*awb_gain_O_tdata\s*\)", isp)
    for port in ("O_ind_awb_tdata", "O_ind_awb_tlast", "O_ind_awb_tuser", "O_ind_awb_tvalid"):
        assert f"assign {port}" in isp and "awb_gain_O_" in isp
    assert "I_tready    (O_tready)" in isp
    assert "assign awb_O_tready = awb_gain_O_tready" in isp
    assert (ROOT / "fallback" / "sim" / "isp" / "tb_axis_gain_rgb96.v").is_file()


def test_formal_calibration_uses_elaboration_constants_and_keeps_dynamic_default():
    top = TOP.read_text(encoding="utf-8")
    spine = (ROOT / "fallback" / "rtl" / "integration" / "industrial_v2_feature_spine.v").read_text(encoding="utf-8")
    calibrator = (ROOT / "fallback" / "rtl" / "inspection" / "dimension_calibrator.v").read_text(encoding="utf-8")

    assert ".USE_STATIC_CAL_CONFIG              ( 1 )" in top
    assert ".STATIC_SCALE_X_Q16_16               ( V2_SCALE_X_Q16_16 )" in top
    assert ".USE_STATIC_CONFIG              (USE_STATIC_CAL_CONFIG)" in spine
    assert "parameter integer USE_STATIC_CONFIG = 0" in calibrator
    assert "wire occupancy_min_met" in calibrator
    assert "wire aspect_min_met" in calibrator and "wire aspect_max_met" in calibrator


def test_every_selected_result_cdc_field_reaches_the_final_osd_consumer():
    top = TOP.read_text(encoding="utf-8")
    cdc_block = top.split("industrial_v2_result_cdc u_industrial_v2_result_cdc", 1)[1].split(");", 1)[0]
    osd_block = top.split("u_industrial_osd (", 1)[1].split(");", 1)[0]
    field_map = {
        "O_dst_proc_valid": ("v2_hdmi_proc_valid", "I_proc_valid"),
        "O_dst_proc_cycles": ("v2_hdmi_proc_cycles", "I_proc_cycles"),
        "O_dst_motion_valid": ("v2_hdmi_motion_valid", "I_motion_valid"),
        "O_dst_motion": ("v2_hdmi_motion", "I_motion"),
        "O_dst_motion_count": ("v2_hdmi_motion_count", "I_motion_count"),
        "O_dst_pass_count": ("v2_hdmi_pass_count", "I_pass_count"),
        "O_dst_ng_count": ("v2_hdmi_ng_count", "I_ng_count"),
        "O_dst_sort_pulse": ("v2_hdmi_sort_pulse", "I_sort_pulse"),
        "O_dst_safe_enable": ("v2_hdmi_safe_enable", "I_safe_enable"),
        "O_dst_dimension_valid": ("v2_hdmi_dimension_valid", "I_dimension_valid"),
        "O_dst_shape_valid": ("v2_hdmi_shape_valid", "I_shape_valid"),
        "O_dst_width_mm_q16_16": ("v2_hdmi_width_mm_q16_16", "I_width_mm_q16_16"),
        "O_dst_height_mm_q16_16": ("v2_hdmi_height_mm_q16_16", "I_height_mm_q16_16"),
    }
    for cdc_port, (wire_name, osd_port) in field_map.items():
        cdc_match = re.search(rf"\.{cdc_port}\s*\(\s*([A-Za-z_]\w*)\s*\)", cdc_block)
        assert cdc_match and cdc_match.group(1) == wire_name, (
            f"CDC output {cdc_port} does not terminate at {wire_name}"
        )
        osd_match = re.search(rf"\.{osd_port}\s*\(\s*([A-Za-z_]\w*)\s*\)", osd_block)
        assert osd_match and osd_match.group(1) == wire_name, (
            f"{wire_name} does not reach the final OSD input {osd_port}"
        )
    assert ".I_src_proc_valid" in cdc_block and "v2_src_latency_proc_valid" in cdc_block
    assert ".I_src_proc_cycles" in cdc_block and "v2_src_latency_proc_cycles" in cdc_block
    assert ".I_scale_provisional" in osd_block and "1'b1" in osd_block


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


def test_release_audit_binds_fixed_seed_reproducibility_evidence():
    audit = AUDIT.read_text(encoding="utf-8")
    assert "docs/evidence/industrial-v2-g8-fixed-seed-reproducibility.md" in audit
    assert "exact reproducibility remains open" in audit


def test_td_builder_supports_a_reproducible_placement_seed():
    build = BUILD.read_text(encoding="utf-8")
    assert "--place-seed" in build
    assert "set_param place seed" in build
    assert "industrial_v2_fixed_seed.tcl" in build
