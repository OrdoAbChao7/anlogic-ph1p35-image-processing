from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
OSD = ROOT / "fallback" / "rtl" / "industrial_osd_overlay.v"


def test_osd_font_lookup_is_row_wise_for_resource_control():
    source = OSD.read_text(encoding="utf-8")

    assert "function [4:0] glyph_row;" in source
    assert "current_row" in source
    assert "current_glyph" not in source


if __name__ == "__main__":
    test_osd_font_lookup_is_row_wise_for_resource_control()
    print("PASS OSD row-wise font contract")
