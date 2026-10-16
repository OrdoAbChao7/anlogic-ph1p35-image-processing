from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
TOP = ROOT / "fallback" / "td_source" / "design_top_wrapper.v"


def test_hdmi_timing_and_mixer_are_driven_in_the_integrated_top():
    source = TOP.read_text(encoding="utf-8")
    required = [
        "uivtc #(",
        r"\.O_vtc_vs\s*\(\s*S_hdmi_vsync",
        r"\.O_vtc_hs\s*\(\s*S_hdmi_hsync",
        r"\.O_vtc_de_valid\s*\(\s*S_hdmi_de",
        "hdmi_mixer #(",
        r"\.I_video_vsync\s*\(\s*S_hdmi_vsync",
        r"\.O_hdmi_vsync\s*\(\s*S_hdmi_out_vsync",
        r"\.O_hdmi_hsync\s*\(\s*S_hdmi_out_hsync",
        r"\.O_hdmi_de\s*\(\s*S_hdmi_out_de",
        r"\.I_video_rd_data\s*\(\s*S_video_rd_data",
    ]
    missing = [marker for marker in required if not (marker in source if marker.endswith("#(") else re.search(marker, source))]
    assert not missing, "integrated video timing contract missing: " + ", ".join(missing)


if __name__ == "__main__":
    test_hdmi_timing_and_mixer_are_driven_in_the_integrated_top()
    print("PASS integrated video timing contract")
