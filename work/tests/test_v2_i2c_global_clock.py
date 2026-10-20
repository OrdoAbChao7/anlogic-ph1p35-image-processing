import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "prepare_i2c_global_clock.py"
SPEC = importlib.util.spec_from_file_location("prepare_i2c_global_clock", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


I2C_SOURCE = ROOT / "fallback" / "td_package" / "user_source" / "hdl_source" / "uics500_cfg" / "uii2c.v"


def test_i2c_event_clock_uses_official_global_buffer_and_data_stays_raw():
    source = I2C_SOURCE.read_text(encoding="latin1")

    transformed = MODULE.transform_uii2c_source(source)

    assert "wire scl_clk_global;" in transformed
    assert "PH1P_LOGIC_BUFG u_i2c_scl_clk_bufg" in transformed
    assert ".i(scl_clk)" in transformed
    assert ".o(scl_clk_global)" in transformed
    assert transformed.count("always @(posedge scl_clk_global)") == 1
    assert transformed.count("always @(negedge scl_clk_global)") == 1
    assert "scl_r <= scl_clk;" in transformed
    assert "always @(posedge scl_clk)" not in transformed
    assert "always @(negedge scl_clk)" not in transformed
