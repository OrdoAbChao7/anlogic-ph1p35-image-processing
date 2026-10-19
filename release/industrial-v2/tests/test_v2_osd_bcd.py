from pathlib import Path
import os
import shutil
import subprocess


ROOT = Path(__file__).resolve().parents[2]
OSD = ROOT / "fallback" / "rtl" / "display" / "industrial_osd_overlay.v"
TB = ROOT / "fallback" / "sim" / "display" / "tb_industrial_osd_bcd.v"
LOGO = ROOT / "fallback" / "rtl" / "display" / "anlogic_logo_rom.v"
OUT = ROOT / "work" / "tests" / ".tmp_osd_bcd.vvp"


def find_tool(name: str) -> str:
    roots = [ROOT / ".tools"]
    external_root = os.environ.get("FPGA_IVERILOG_ROOT", "")
    if external_root:
        roots.append(Path(external_root))
    # The isolated V2 worktree intentionally does not duplicate the shared
    # read-only tool cache beside the original repository.
    roots.append(ROOT.parent / "FPGA" / ".tools")
    for tool_root in roots:
        candidate = tool_root / "iverilog" / "bin" / f"{name}.exe"
        if candidate.exists():
            return str(candidate)
    return shutil.which(name) or ""


def test_osd_frame_counter_uses_bcd_and_has_no_runtime_division():
    source = OSD.read_text(encoding="utf-8")
    assert "function [39:0] bcd_increment" in source
    assert "decimal_digit" not in source
    assert "/ 32'd" not in source
    assert "% 10" not in source


def test_osd_bcd_rtl_contract():
    iverilog = find_tool("iverilog")
    vvp = find_tool("vvp")
    if not iverilog or not vvp:
        raise RuntimeError("Icarus Verilog is required for the OSD BCD contract")
    compile_result = subprocess.run(
        [iverilog, "-g2012", "-Wall", "-s", "tb_industrial_osd_bcd", "-o", str(OUT),
         str(TB), str(OSD), str(LOGO)],
        cwd=ROOT, capture_output=True, text=True, check=False,
    )
    assert compile_result.returncode == 0, compile_result.stderr + compile_result.stdout
    run_result = subprocess.run([vvp, str(OUT)], cwd=ROOT, capture_output=True, text=True, check=False)
    try:
        assert run_result.returncode == 0, run_result.stderr + run_result.stdout
        assert "TB_INDUSTRIAL_OSD_BCD_PASS" in run_result.stdout
    finally:
        OUT.unlink(missing_ok=True)
