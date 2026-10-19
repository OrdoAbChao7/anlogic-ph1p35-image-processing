"""Board-level contracts for the HX1P35A HDL manual mapping."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
PIN = ROOT / "fallback" / "td_package" / "user_source" / "constraints_source" / "pin.adc"
TOP = ROOT / "fallback" / "td_source" / "design_top_wrapper.v"
PACKAGE_TOP = ROOT / "fallback" / "td_package" / "user_source" / "hdl_source" / "design_top_wrapper.v"


def _assignment(text: str, signal: str, location: str) -> bool:
    pattern = rf"set_pin_assignment\s+\{{\s*{re.escape(signal)}\s*\}}\s+\{{[^}}]*LOCATION\s*=\s*{location}\b"
    return re.search(pattern, text) is not None


def test_hx1p35a_manual_button_and_led_locations_are_bound():
    pin = PIN.read_text(encoding="utf-8")

    assert _assignment(pin, "I_button[0]", "D5")
    assert _assignment(pin, "I_button[1]", "A9")
    assert _assignment(pin, "O_led1", "D10")
    assert _assignment(pin, "O_led2", "E10")
    assert _assignment(pin, "O_led3", "C6")

    assert "LOCATION = N2" not in pin
    assert "LOCATION = J14" not in pin
    assert "{ I_rst_n }" not in pin
    assert "{ O_screen_pwm }" not in pin


def test_top_uses_internal_reset_and_manual_led_outputs():
    top = TOP.read_text(encoding="utf-8")

    assert re.search(r"output\s+wire\s+O_led1\b", top)
    assert re.search(r"output\s+wire\s+O_led2\b", top)
    assert re.search(r"output\s+wire\s+O_led3\b", top)
    assert not re.search(r"input\s+wire\s+I_rst_n\b", top)
    assert not re.search(r"output\s+wire\s+O_screen_pwm\b", top)

    assert re.search(r"\.reset\s*\(\s*1'b0\s*\)", top)
    assert "assign O_led1 = O_led_pass;" in top
    assert "assign O_led2 = O_led_ng;" in top
    assert "assign O_led3 = O_led_det;" in top


def test_td_input_package_exposes_the_same_board_boundary():
    top = PACKAGE_TOP.read_text(encoding="utf-8")

    assert re.search(r"output\s+wire\s+O_led1\b", top)
    assert re.search(r"output\s+wire\s+O_led2\b", top)
    assert re.search(r"output\s+wire\s+O_led3\b", top)
    assert not re.search(r"input\s+wire\s+I_rst_n\b", top)
    assert not re.search(r"output\s+wire\s+O_screen_pwm\b", top)
    assert re.search(r"\.reset\s*\(\s*1'b0\s*\)", top)


def test_mipi_phy_binding_remains_dphy0_two_lane():
    top = TOP.read_text(encoding="utf-8")

    assert 'DPHY_RX_LOCATION      ( "DPHY0" )' in top
    assert re.search(r"\.LANE_NUM\s*\(\s*2\s*\)", top)
    assert re.search(r"\.I_lane_invert\s*\(\s*2'b00\s*\)", top)
