"""Contract checks for the combined I2C counter/MCLK ODDR probe."""

from __future__ import annotations

import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/prepare_i2c_counter_mclk_oddr.py"
SPEC = importlib.util.spec_from_file_location("prepare_i2c_counter_mclk_oddr", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


def test_combined_probe_preserves_both_structural_changes() -> None:
    top = (ROOT / "fallback/td_source/design_top_wrapper.v").read_text(encoding="latin1")
    i2c = (ROOT / "fallback/td_package/user_source/hdl_source/uics500_cfg/uii2c.v").read_text(encoding="latin1")

    transformed_top = MODULE.transform_top_source(top)
    transformed_i2c = MODULE.transform_uii2c_source(i2c)

    assert "assign O_cam_24m \t= S_24m_clk;" not in transformed_top
    assert "PH1P_LOGIC_HD_ODDR u_cam_mclk_out" in transformed_top
    assert "wire scl_clk = (clkdiv > SCL_DIV);" in transformed_i2c
    assert "scl_clk <= !scl_clk;" not in transformed_i2c


def test_combined_probe_does_not_change_the_seven_feature_top_contract() -> None:
    top = (ROOT / "fallback/td_source/design_top_wrapper.v").read_text(encoding="latin1")
    transformed_top = MODULE.transform_top_source(top)
    for marker in (
        "industrial_v2_feature_spine",
        "industrial_v2_result_cdc",
        "industrial_osd_overlay",
        "O_ind_result_toggle",
        "S_osd_out_data",
    ):
        assert marker in transformed_top
