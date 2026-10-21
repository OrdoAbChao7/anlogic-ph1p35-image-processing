from pathlib import Path


INTEGRATION_DIR = Path(__file__).resolve().parents[2] / "fallback" / "rtl" / "integration"


def test_motion_grid_adapter_declares_explicit_raster_contract():
    source = (INTEGRATION_DIR / "motion_grid_adapter_96.v").read_text(encoding="utf-8")

    assert "module motion_grid_adapter_96" in source
    for marker in (
        "INPUT_WIDTH",
        "INPUT_HEIGHT",
        "GRID_WIDTH",
        "GRID_HEIGHT",
        "I_tuser",
        "I_tlast",
        "O_frame_start",
        "O_frame_end",
        "O_sample_x",
        "O_sample_y",
        "O_y_value",
    ):
        assert marker in source


def test_frame_stats_adapter_declares_atomic_frame_statistics_contract():
    source = (INTEGRATION_DIR / "frame_stats_96.v").read_text(encoding="utf-8")

    assert "module frame_stats_96" in source
    for marker in (
        "I_tuser",
        "I_tlast",
        "O_stats_valid",
        "O_sum_r",
        "O_sum_g",
        "O_sum_b",
        "O_pixel_count",
        "O_mean_luma",
    ):
        assert marker in source
