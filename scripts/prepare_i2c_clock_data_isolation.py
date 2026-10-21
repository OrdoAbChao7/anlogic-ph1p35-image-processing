"""Prepare an isolated TD input package with I2C clock/data fanout separated.

The vendor I2C master uses ``scl_clk`` both as a fabric-generated event clock
and as a data input to the SCL output mux.  This probe keeps the event-clock
architecture unchanged and gives the output mux a separately registered copy
of the same level.  It is intentionally an isolated candidate transform; it
does not modify the tracked TD package or the formal release.
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
    """Return the minimal clock/data-isolated I2C source candidate."""

    if "scl_data_clk" in source:
        raise ValueError("source already contains the isolation candidate")

    transformed = replace_once(
        source,
        "reg scl_clk    = 1'b0;",
        "reg scl_clk    = 1'b0;\n"
        "    (* keep = \"true\" *) reg scl_data_clk = 1'b0;",
    )
    transformed = replace_once(
        transformed,
        "        scl_clk <= !scl_clk;",
        "        scl_clk <= !scl_clk;\n"
        "        scl_data_clk <= !scl_data_clk;",
    )
    transformed = replace_once(
        transformed,
        "        scl_r <= scl_clk;",
        "        scl_r <= scl_data_clk;",
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
    target.write_text(transform_uii2c_source(target.read_text(encoding="latin1")), encoding="latin1")
    return target


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-package", type=Path, required=True)
    parser.add_argument("--output-package", type=Path, required=True)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    target = prepare_package(args.input_package, args.output_package)
    print(f"Prepared isolated I2C clock/data candidate: {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

