"""Prepare an isolated TD input package with a width-sized I2C divider.

The SC520 instance only needs an 8-bit divider (SCL_DIV=118), while the
legacy SC500 default remains large enough to require 16 bits.  This probe
keeps the vendor event-clock protocol unchanged and specializes the counter
width from the elaborated parameter value.
"""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path


UII2C_RELATIVE = Path("user_source/hdl_source/uics500_cfg/uii2c.v")


def replace_once(text: str, before: str, after: str) -> str:
    count = text.count(before)
    if count != 1:
        raise ValueError(f"expected one occurrence of {before!r}, found {count}")
    return text.replace(before, after, 1)


def transform_uii2c_source(source: str) -> str:
    """Return the divider-width-specialized I2C source candidate."""

    if "CLKDIV_WIDTH" in source:
        raise ValueError("source already contains the counter-width candidate")

    transformed = replace_once(
        source,
        "localparam SCL_DIV = CLK_DIV/2;",
        "localparam SCL_DIV = CLK_DIV/2;\n"
        "localparam integer CLKDIV_WIDTH = (SCL_DIV < 256) ? 8 : 16;",
    )
    transformed = replace_once(
        transformed,
        "reg [15:0] clkdiv = 16'd0;",
        "reg [CLKDIV_WIDTH-1:0] clkdiv = {CLKDIV_WIDTH{1'b0}};",
    )
    transformed = replace_once(
        transformed,
        "clkdiv <= 16'd0;",
        "clkdiv <= {CLKDIV_WIDTH{1'b0}};",
    )
    return transformed


def prepare_package(input_package: Path, output_package: Path) -> Path:
    input_package = input_package.resolve()
    output_package = output_package.resolve()
    if not input_package.is_dir():
        raise FileNotFoundError(input_package)
    if output_package.exists():
        raise FileExistsError(f"preserving existing output package: {output_package}")

    shutil.copytree(input_package, output_package)
    target = output_package / UII2C_RELATIVE
    if not target.is_file():
        raise FileNotFoundError(target)
    target.write_text(
        transform_uii2c_source(target.read_text(encoding="latin1")),
        encoding="latin1",
    )
    return target


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-package", type=Path, required=True)
    parser.add_argument("--output-package", type=Path, required=True)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    target = prepare_package(args.input_package, args.output_package)
    print(f"Prepared isolated I2C counter-width candidate: {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
