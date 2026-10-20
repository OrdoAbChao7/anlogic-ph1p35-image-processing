"""Static and simulation checks for the counter-derived I2C phase probe."""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path

import pytest

from scripts.prepare_i2c_counter_phase import transform_uii2c_source


ROOT = Path(__file__).resolve().parents[2]
VENDOR = ROOT / "fallback/td_package/user_source/hdl_source/uics500_cfg/uii2c.v"
TB = ROOT / "fallback/sim/config/tb_i2c_registered_phase.v"


def _iverilog() -> str | None:
    candidates = [
        ROOT / ".tools/iverilog/bin/iverilog.exe",
        ROOT.parent / "FPGA/.tools/iverilog/bin/iverilog.exe",
    ]
    env_root = os.environ.get("FPGA_IVERILOG_ROOT")
    if env_root:
        candidates.append(Path(env_root) / "bin/iverilog.exe")
    return next((str(path) for path in candidates if path.is_file()), shutil.which("iverilog"))


def _vvp() -> str | None:
    candidates = [
        ROOT / ".tools/iverilog/bin/vvp.exe",
        ROOT.parent / "FPGA/.tools/iverilog/bin/vvp.exe",
    ]
    env_root = os.environ.get("FPGA_IVERILOG_ROOT")
    if env_root:
        candidates.append(Path(env_root) / "bin/vvp.exe")
    return next((str(path) for path in candidates if path.is_file()), shutil.which("vvp"))


def _compile_and_run(source: Path, work: Path, iverilog: str, vvp: str) -> str:
    candidate = work / f"{source.stem}.vvp"
    subprocess.run(
        [iverilog, "-g2012", "-s", "tb_i2c_registered_phase", "-o", str(candidate), str(TB), str(source)],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    result = subprocess.run([vvp, str(candidate)], cwd=ROOT, check=True, capture_output=True, text=True)
    return result.stdout


def test_counter_phase_transform_has_no_scl_feedback() -> None:
    source = VENDOR.read_text(encoding="latin1")
    transformed = transform_uii2c_source(source)
    assert "localparam FULL_DIV = 2 * (SCL_DIV + 1);" in transformed
    assert "wire scl_clk = (clkdiv > SCL_DIV);" in transformed
    assert "scl_clk <= !scl_clk;" not in transformed
    assert "counter-derived SCL event phase" in transformed
    assert "assign  scl_offset  = (clkdiv == OFFSET) ||" in transformed


@pytest.mark.skipif(_iverilog() is None, reason="Icarus Verilog is not available")
def test_counter_phase_preserves_direct_i2c_transaction() -> None:
    iverilog = _iverilog()
    vvp = _vvp()
    assert iverilog is not None and vvp is not None
    with tempfile.TemporaryDirectory(prefix="v2_i2c_counter_phase_") as temp:
        work = Path(temp)
        candidate = work / "uii2c_counter_phase.v"
        candidate.write_text(
            transform_uii2c_source(VENDOR.read_text(encoding="latin1")),
            encoding="latin1",
        )
        vendor_out = _compile_and_run(VENDOR, work, iverilog, vvp)
        candidate_out = _compile_and_run(candidate, work, iverilog, vvp)
    assert "TB_I2C_REGISTERED_PHASE_PASS" in vendor_out
    assert "TB_I2C_REGISTERED_PHASE_PASS" in candidate_out
    assert "rd_data=00" in candidate_out
    assert "scl_transitions=59" in candidate_out
