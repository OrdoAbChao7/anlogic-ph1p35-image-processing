from pathlib import Path
import importlib.util
import sys


MODEL_DIR = Path(__file__).resolve().parents[1] / "models" / "v2"
sys.path.insert(0, str(MODEL_DIR))

from release_audit import (  # noqa: E402
    RELEASED,
    BLOCKED,
    Gate,
    evaluate_release,
)


VERIFY_SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "verify_industrial_v2_release.py"
VERIFY_SPEC = importlib.util.spec_from_file_location("verify_industrial_v2_release", VERIFY_SCRIPT)
VERIFY_MODULE = importlib.util.module_from_spec(VERIFY_SPEC)
assert VERIFY_SPEC.loader is not None
VERIFY_SPEC.loader.exec_module(VERIFY_MODULE)


REQUIRED_GATE_NAMES = (
    "software_rtl_td_for_7_features",
    "same_bitstream_integration",
    "v1_regression",
    "td_full_build",
    "resource_timing_budget",
    "warnings_cdc_constraints_audit",
    "hardware_function_matrix",
    "performance_traceability",
    "cold_reset_long_run",
    "reproducible_build_package",
    "external_actuator_acceptance",
    "visual_approval",
)


def passing_gates():
    return [Gate(name, "PASS", (f"evidence/{name}",), ()) for name in REQUIRED_GATE_NAMES]


def test_all_g8_exit_gates_are_required_for_release():
    result = evaluate_release(passing_gates())

    assert result["release_status"] == RELEASED
    assert result["gate_count"] == 12
    assert tuple(g["name"] for g in result["gates"]) == REQUIRED_GATE_NAMES


def test_one_blocked_hardware_gate_blocks_release_even_with_visual_approval():
    gates = passing_gates()
    gates[6] = Gate(
        "hardware_function_matrix",
        "BLOCKED",
        ("docs/evidence/hardware-matrix.md",),
        ("no bound board/bitstream evidence",),
    )

    result = evaluate_release(gates)

    assert result["release_status"] == BLOCKED
    assert result["blocked_gates"] == ["hardware_function_matrix"]
    assert result["gates"][-1]["name"] == "visual_approval"
    assert result["gates"][-1]["status"] == "PASS"


def test_non_pass_statuses_are_reported_without_being_silently_promoted():
    gates = [Gate("same_bitstream_integration", "NOT_RUN", (), ("no V2 bitstream",))]

    result = evaluate_release(gates)

    assert result["release_status"] == BLOCKED
    assert result["blocked_gates"] == ["same_bitstream_integration"]


def test_reproducible_package_stays_blocked_when_seed_evidence_is_not_byte_identical():
    gate = VERIFY_MODULE.build_reproducible_build_package_gate(
        v2_release_complete=True,
        fixed_seed_evidence=("docs/evidence/industrial-v2-g8-fixed-seed-reproducibility.md",),
        fixed_seed_byte_identical=False,
    )

    assert gate.status == "BLOCKED"
    assert any(
        "fixed placement seed did not produce byte-identical Bitstreams" in blocker
        for blocker in gate.blockers
    )


def test_resource_gate_passes_for_clean_qor_under_slice_target():
    route_qor = """
|     Setup WNS             |          104                |
|     Setup TNS             |            0                |
|     Num of violated S-EP  |            0                |
|     Hold WNS              |           20                |
|     Hold TNS              |            0                |
|     Num of violated H-EP  |            0                |
|     #slices               |        17125                |
|     slices percentage     |       80.72%                |
"""

    gate = VERIFY_MODULE.build_resource_timing_gate(
        route_qor,
        evidence=("release/industrial-v2/route.qor",),
    )

    assert gate.status == "PASS"
    assert gate.blockers == ()


def test_resource_gate_blocks_qor_over_slice_target():
    route_qor = """
|     Setup WNS             |          127                |
|     Setup TNS             |            0                |
|     Num of violated S-EP  |            0                |
|     Hold WNS              |           20                |
|     Hold TNS              |            0                |
|     Num of violated H-EP  |            0                |
|     #slices               |        18484                |
|     slices percentage     |       87.12%                |
"""

    gate = VERIFY_MODULE.build_resource_timing_gate(
        route_qor,
        evidence=("release/industrial-v2/route.qor",),
    )

    assert gate.status == "BLOCKED"
    assert any("Slice 87.12% exceeds the <=85% target" in blocker for blocker in gate.blockers)
