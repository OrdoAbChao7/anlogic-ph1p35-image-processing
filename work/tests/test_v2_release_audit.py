from pathlib import Path
import sys


MODEL_DIR = Path(__file__).resolve().parents[1] / "models" / "v2"
sys.path.insert(0, str(MODEL_DIR))

from release_audit import (  # noqa: E402
    RELEASED,
    BLOCKED,
    Gate,
    evaluate_release,
)


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
