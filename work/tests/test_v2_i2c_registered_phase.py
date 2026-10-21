import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "prepare_i2c_registered_phase.py"
SPEC = importlib.util.spec_from_file_location("prepare_i2c_registered_phase", SCRIPT)
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
TB = ROOT / "fallback" / "sim" / "config" / "tb_i2c_registered_phase.v"


def find_tool(name: str) -> str:
    roots = [ROOT / ".tools", ROOT.parent / "FPGA" / ".tools"]
    external_root = os.environ.get("FPGA_IVERILOG_ROOT", "")
    if external_root:
        roots.append(Path(external_root))
    for tool_root in roots:
        candidate = tool_root / "iverilog" / "bin" / f"{name}.exe"
        if candidate.exists():
            return str(candidate)
    return shutil.which(name) or ""


def test_i2c_registered_phase_removes_scl_clk_data_fanout():
    source = I2C_SOURCE.read_text(encoding="latin1")
    transformed = MODULE.transform_uii2c_source(source)

    assert "// registered SCL output phase; scl_clk remains an event clock only" in transformed
    assert "always @(posedge I_clk or negedge I_rstn)" in transformed
    assert "else if (clkdiv == SCL_DIV)" in transformed
    assert "scl_r <= scl_clk;" not in transformed
    assert "always @(posedge scl_clk)" in transformed
    assert "always @(negedge scl_clk)" in transformed


def test_i2c_registered_phase_matches_vendor_directed_transaction():
    iverilog = find_tool("iverilog")
    vvp = find_tool("vvp")
    if not iverilog or not vvp:
        raise RuntimeError("Icarus Verilog is required for the I2C registered-phase contract")

    source = I2C_SOURCE.read_text(encoding="latin1")
    transformed = MODULE.transform_uii2c_source(source)
    with tempfile.TemporaryDirectory(prefix="v2-i2c-phase-") as temp_dir:
        candidate_source = Path(temp_dir) / "uii2c_registered_phase.v"
        candidate_source.write_text(transformed, encoding="latin1")
        for name, source_path in (("vendor", I2C_SOURCE), ("candidate", candidate_source)):
            output = Path(temp_dir) / f"{name}.vvp"
            compile_result = subprocess.run(
                [iverilog, "-g2012", "-Wall", "-s", "tb_i2c_registered_phase", "-o", str(output), str(TB), str(source_path)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            assert compile_result.returncode == 0, compile_result.stderr + compile_result.stdout
            run_result = subprocess.run([vvp, str(output)], cwd=ROOT, capture_output=True, text=True, check=False)
            assert run_result.returncode == 0, run_result.stderr + run_result.stdout
            assert "TB_I2C_REGISTERED_PHASE_PASS" in run_result.stdout
            assert "rd_data=00" in run_result.stdout
            assert "scl_transitions=59" in run_result.stdout
