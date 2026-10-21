"""Prepare an isolated package combining the two strongest clock probes.

The I2C source uses the counter-derived event phase from
``prepare_i2c_counter_phase.py``.  The tracked top wrapper drives the sensor
MCLK through the PH1P HDIO DDR output cell.  The package is only for an
isolated TD experiment; the formal V2 source is never modified by this tool.
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
UII2C_RELATIVE = Path("user_source/hdl_source/uics500_cfg/uii2c.v")
TOP_RELATIVE = Path("user_source/hdl_source/design_top_wrapper.v")
MCLK_ASSIGN = "assign O_cam_24m \t= S_24m_clk;"
MCLK_ODDR = """// Isolate the PLL clock from the sensor MCLK output through the vendor HDIO DDR cell.
    PH1P_LOGIC_HD_ODDR u_cam_mclk_out (
        .clk(S_24m_clk),
        .rst(~S_pll_lock),
        .d0(1'b1),
        .d1(1'b0),
        .q(O_cam_24m)
    );"""


if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.prepare_i2c_counter_phase import transform_uii2c_source  # noqa: E402


def replace_once(text: str, before: str, after: str) -> str:
    count = text.count(before)
    if count != 1:
        raise ValueError(f"expected one occurrence of {before!r}, found {count}")
    return text.replace(before, after, 1)


def transform_top_source(source: str) -> str:
    """Replace the direct MCLK assignment with the vendor HDIO DDR cell."""

    if "PH1P_LOGIC_HD_ODDR u_cam_mclk_out" in source:
        raise ValueError("source already contains the MCLK ODDR candidate")
    return replace_once(source, MCLK_ASSIGN, MCLK_ODDR)


def prepare_package(input_package: Path, output_package: Path, top_source: Path) -> tuple[Path, Path]:
    input_package = input_package.resolve()
    output_package = output_package.resolve()
    top_source = top_source.resolve()
    if not input_package.is_dir():
        raise FileNotFoundError(input_package)
    if not top_source.is_file():
        raise FileNotFoundError(top_source)
    if output_package.exists():
        raise FileExistsError(f"preserving existing output package: {output_package}")

    shutil.copytree(input_package, output_package)
    i2c_target = output_package / UII2C_RELATIVE
    top_target = output_package / TOP_RELATIVE
    if not i2c_target.is_file():
        raise FileNotFoundError(i2c_target)
    i2c_target.write_text(
        transform_uii2c_source(i2c_target.read_text(encoding="latin1")),
        encoding="latin1",
    )
    top_target.write_text(
        transform_top_source(top_source.read_text(encoding="latin1")),
        encoding="latin1",
    )
    return i2c_target, top_target


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-package", type=Path, required=True)
    parser.add_argument("--output-package", type=Path, required=True)
    parser.add_argument(
        "--top-source",
        type=Path,
        default=ROOT / "fallback/td_source/design_top_wrapper.v",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    i2c_target, top_target = prepare_package(
        args.input_package,
        args.output_package,
        args.top_source,
    )
    print(f"Prepared combined I2C counter/MCLK ODDR package: {args.output_package.resolve()}")
    print(f"I2C source: {i2c_target}")
    print(f"Top source: {top_target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
