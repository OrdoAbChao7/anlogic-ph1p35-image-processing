"""Prepare an isolated TD package with a counter-derived I2C event phase.

The vendor master toggles a fabric register used as both an event clock and a
data source. This candidate derives the event phase directly from the I_clk
divider and registers the external SCL phase in I_clk, removing that feedback
register while preserving the original half-period and offset intent. It does
not convert the internal state-machine event controls to I_clk enables:
posedge/negedge scl_clk consumers remain, so this is not a single-clock fix.
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
    """Return the counter-derived I2C event-phase candidate."""

    if "counter-derived SCL event phase" in source:
        raise ValueError("source already contains the counter-phase candidate")

    source = replace_once(
        source,
        "localparam SCL_DIV = CLK_DIV/2;\n",
        "localparam SCL_DIV = CLK_DIV/2;\nlocalparam FULL_DIV = 2 * (SCL_DIV + 1);\n",
    )
    source = replace_once(
        source,
        "reg scl_clk    = 1'b0;",
        "wire scl_clk = (clkdiv > SCL_DIV);",
    )
    source = replace_once(
        source,
        """always@(posedge I_clk)
    if(clkdiv < SCL_DIV)    
        clkdiv <= clkdiv + 1'b1;
    else begin
        clkdiv <= 16'd0; 
        scl_clk <= !scl_clk;
    end
""",
        """always@(posedge I_clk)
    if(clkdiv < (FULL_DIV - 1))
        clkdiv <= clkdiv + 1'b1;
    else
        clkdiv <= 16'd0;
""",
    )
    source = replace_once(
        source,
        "assign  scl_offset  = (clkdiv == OFFSET);",
        """assign  scl_offset  = (clkdiv == OFFSET) ||
                         (clkdiv == (SCL_DIV + 1 + OFFSET));""",
    )
    source = replace_once(
        source,
        """always @(*) 
    if(IIC_S == IDLE || IIC_S == STOP1 || IIC_S == STOP2)
        scl_r <= 1'b1;
    else 
        scl_r <= scl_clk;
""",
        """// counter-derived SCL event phase; scl_clk has no data fanout
always @(posedge I_clk or negedge I_rstn)
    if (I_rstn == 1'b0)
        scl_r <= 1'b1;
    else if (IIC_S == IDLE || IIC_S == STOP1 || IIC_S == STOP2)
        scl_r <= 1'b1;
    else if ((clkdiv == SCL_DIV) || (clkdiv == (FULL_DIV - 1)))
        scl_r <= !scl_r;
""",
    )
    return source


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
    print(f"Prepared isolated I2C counter-phase candidate: {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
