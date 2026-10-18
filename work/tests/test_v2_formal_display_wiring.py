from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TOP = ROOT / "fallback" / "td_source" / "design_top_wrapper.v"
SYN_PRJ = ROOT / "fallback" / "td_package" / "td_project" / "camera_to_dsi_display_Runs" / "syn_1" / "camera_to_dsi_display.prj"
PHY_PRJ = ROOT / "fallback" / "td_package" / "td_project" / "camera_to_dsi_display_Runs" / "phy_1" / "camera_to_dsi_display.prj"
BUILD = ROOT / "scripts" / "build_industrial_td.py"


def test_formal_display_top_wires_result_cdc_into_tracking_stage():
    source = TOP.read_text(encoding="utf-8")

    assert "industrial_v2_result_cdc" in source
    assert "industrial_v2_display_tracking" in source
    assert ".I_src_toggle" in source and "( ind_result_toggle" in source
    assert ".I_frame_valid" in source and "( v2_hdmi_result_valid" in source
    assert ".I_rgb" in source and "( S_cartoon_out_data" in source
    assert ".I_rgb" in source and "( S_tracking_out_data" in source


def test_both_td_runs_and_build_script_include_display_integration_sources():
    syn = SYN_PRJ.read_text(encoding="utf-8")
    phy = PHY_PRJ.read_text(encoding="utf-8")
    build = BUILD.read_text(encoding="utf-8")

    for source in (syn, phy):
        assert "industrial_v2_result_cdc.v" in source
        assert "industrial_v2_display_tracking.v" in source
        assert "temporal_tracker.v" in source
        assert "trajectory_history.v" in source
        assert "tracking_overlay.v" in source
    for marker in (
        "industrial_v2_result_cdc.v",
        "industrial_v2_display_tracking.v",
        "temporal_tracker.v",
        "trajectory_history.v",
        "tracking_overlay.v",
    ):
        assert marker in build
