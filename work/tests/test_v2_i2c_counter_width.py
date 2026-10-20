import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "prepare_i2c_counter_width.py"
SPEC = importlib.util.spec_from_file_location("prepare_i2c_counter_width", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


I2C_SOURCE = (
    ROOT
    / "fallback"
    / "td_package"
    / "user_source"
    / "hdl_source"
    / "uics500_cfg"
    / "uii2c.v"
)


def test_i2c_divider_width_is_parameter_specialized_without_protocol_change():
    source = I2C_SOURCE.read_text(encoding="latin1")
    transformed = MODULE.transform_uii2c_source(source)

    assert "localparam integer CLKDIV_WIDTH = (SCL_DIV < 256) ? 8 : 16;" in transformed
    assert "reg [CLKDIV_WIDTH-1:0] clkdiv" in transformed
    assert "clkdiv <= {CLKDIV_WIDTH{1'b0}};" in transformed
    assert "reg [15:0] clkdiv" not in transformed
    assert "always @(posedge scl_clk)" in transformed
    assert "always @(negedge scl_clk)" in transformed
