from pathlib import Path


DISPLAY = (
    Path(__file__).resolve().parents[2]
    / "fallback"
    / "rtl"
    / "integration"
    / "industrial_v2_display_tracking.v"
)


def test_display_tracking_owns_hdmi_domain_coordinates_and_history():
    source = DISPLAY.read_text(encoding="utf-8")

    assert "module industrial_v2_display_tracking" in source
    for marker in (
        "temporal_tracker",
        "trajectory_history",
        "tracking_overlay",
        "I_frame_valid",
        "I_frame_id",
        "I_vsync",
        "O_track_valid",
        "O_rgb",
        "video_x",
        "video_y",
    ):
        assert marker in source


def test_display_tracking_does_not_use_source_clock_for_hdmi_pixels():
    source = DISPLAY.read_text(encoding="utf-8")

    assert "I_clk" in source
    assert "always @(posedge I_clk or negedge I_rst_n)" in source
    assert "I_src_clk" not in source
