"""Prepare an isolated TD input package with a vendor global-buffered I2C clock.

The reference I2C master generates ``scl_clk`` in fabric and uses it as an
event clock.  This probe sends only that event-clock path through the official
PH1P global clock buffer.  The SCL output data path continues to use the raw
registered level, so the transform tests whether the mixed clock/data fanout
is the source of the physical warning without changing the I2C protocol.
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
    """Return the minimal official-global-buffer I2C source candidate."""

    if "scl_clk_global" in source:
        raise ValueError("source already contains the global-clock candidate")

    transformed = replace_once(
        source,
        "reg scl_clk    = 1'b0;",
        "reg scl_clk    = 1'b0;\n"
        "    wire scl_clk_global;\n\n"
        "    PH1P_LOGIC_BUFG u_i2c_scl_clk_bufg (\n"
        "        .i(scl_clk),\n"
        "        .o(scl_clk_global)\n"
        "    );",
    )
    transformed = replace_once(
        transformed,
        "always @(posedge scl_clk)",
        "always @(posedge scl_clk_global)",
    )
    transformed = replace_once(
        transformed,
        "always @(negedge scl_clk)",
        "always @(negedge scl_clk_global)",
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
    print(f"Prepared isolated I2C global-clock candidate: {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
