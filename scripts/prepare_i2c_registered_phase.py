"""Prepare an isolated TD package with a registered I2C SCL output phase.

The vendor master uses ``scl_clk`` both as an event clock and as the data
source for ``scl_r``.  This transform keeps the event-clock state machine but
registers the output phase in the I_clk domain, so the fabric event clock has
no downstream data fanout.  It is an isolated warning-closure probe.
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
    """Return the registered-phase I2C source candidate."""

    if "registered SCL output phase" in source:
        raise ValueError("source already contains the registered-phase candidate")

    old = """always @(*) 
    if(IIC_S == IDLE || IIC_S == STOP1 || IIC_S == STOP2)
        scl_r <= 1'b1;
    else 
        scl_r <= scl_clk;
"""
    new = """// registered SCL output phase; scl_clk remains an event clock only
always @(posedge I_clk or negedge I_rstn)
    if (I_rstn == 1'b0)
        scl_r <= 1'b1;
    else if (IIC_S == IDLE || IIC_S == STOP1 || IIC_S == STOP2)
        scl_r <= 1'b1;
    else if (clkdiv == SCL_DIV)
        scl_r <= !scl_r;
"""
    return replace_once(source, old, new)


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
    print(f"Prepared isolated I2C registered-phase candidate: {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
