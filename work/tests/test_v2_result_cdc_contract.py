from pathlib import Path


CDC = (
    Path(__file__).resolve().parents[2]
    / "fallback"
    / "rtl"
    / "integration"
    / "industrial_v2_result_cdc.v"
)


def test_result_cdc_has_toggle_and_stable_payload_contract():
    source = CDC.read_text(encoding="utf-8")

    assert "module industrial_v2_result_cdc" in source
    for marker in (
        "I_src_clk",
        "I_dst_clk",
        "I_src_toggle",
        "O_dst_valid",
        "O_dst_frame_id",
        "O_dst_width_mm_q16_16",
        "O_dst_shape_valid",
        "O_dst_overflow",
        "toggle_meta",
        "payload_meta",
    ):
        assert marker in source


def test_result_cdc_does_not_use_per_bit_reset_or_async_data_sampling():
    source = CDC.read_text(encoding="utf-8")

    assert "always @(posedge I_src_clk or negedge I_src_rst_n)" in source
    assert "always @(posedge I_dst_clk or negedge I_dst_rst_n)" in source
    assert "module reset_release_sync" in source
    assert "I_src_toggle != src_toggle_hold" in source
    assert "event_pending" in source
