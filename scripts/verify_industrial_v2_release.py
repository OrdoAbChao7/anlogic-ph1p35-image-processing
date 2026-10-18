#!/usr/bin/env python3
"""Audit the Industrial Vision V2 release gates without claiming hardware success."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODEL_DIR = ROOT / "work" / "models" / "v2"
sys.path.insert(0, str(MODEL_DIR))

from release_audit import BLOCKED, Gate, PASS, evaluate_release  # noqa: E402


PHASE_NAMES = tuple(f"V2-G{i}" for i in range(1, 8))
GATE_NAMES = (
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


def sha256(path: Path) -> str | None:
    if not path.is_file():
        return None
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def git_head() -> str | None:
    try:
        return subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return None


def existing_paths(relative_paths: tuple[str, ...]) -> tuple[str, ...]:
    return tuple(path for path in relative_paths if (ROOT / path).exists())


def missing_paths(relative_paths: tuple[str, ...]) -> tuple[str, ...]:
    return tuple(path for path in relative_paths if not (ROOT / path).exists())


def build_resource_timing_gate(route_qor_text: str, evidence: tuple[str, ...]) -> Gate:
    """Evaluate the current candidate's measured resource and timing QoR."""
    labels = {
        "setup_wns": "Setup WNS",
        "setup_tns": "Setup TNS",
        "setup_violations": "Num of violated S-EP",
        "hold_wns": "Hold WNS",
        "hold_tns": "Hold TNS",
        "hold_violations": "Num of violated H-EP",
        "slice_count": "#slices",
        "slice_percent": "slices percentage",
    }
    values: dict[str, float] = {}
    for key, label in labels.items():
        match = re.search(
            rf"\|\s*{re.escape(label)}\s*\|\s*([+-]?\d+(?:\.\d+)?)",
            route_qor_text,
            re.IGNORECASE,
        )
        if match:
            values[key] = float(match.group(1))

    missing = tuple(key for key in labels if key not in values)
    if missing:
        return Gate(
            "resource_timing_budget",
            BLOCKED,
            evidence,
            ("route.qor is missing required QoR metrics: " + ", ".join(missing),),
        )

    blockers: list[str] = []
    if values["slice_percent"] > 85.0:
        blockers.append(
            f"Slice {values['slice_percent']:.2f}% exceeds the <=85% target"
        )
    if values["setup_wns"] < 0:
        blockers.append(f"Setup WNS={values['setup_wns']:.0f} ps is negative")
    if values["setup_tns"] != 0 or values["setup_violations"] != 0:
        blockers.append("Setup TNS or violated endpoints is non-zero")
    if values["hold_wns"] < 0:
        blockers.append(f"Hold WNS={values['hold_wns']:.0f} ps is negative")
    if values["hold_tns"] != 0 or values["hold_violations"] != 0:
        blockers.append("Hold TNS or violated endpoints is non-zero")

    return Gate(
        "resource_timing_budget",
        PASS if not blockers else BLOCKED,
        evidence,
        tuple(blockers),
    )


def fixed_seed_is_byte_identical(evidence_paths: tuple[str, ...]) -> bool | None:
    """Read the explicit fixed-seed result without treating evidence presence as success."""
    if not evidence_paths:
        return None
    text = "\n".join(
        (ROOT / path).read_text(encoding="utf-8", errors="replace")
        for path in evidence_paths
        if (ROOT / path).is_file()
    ).lower()
    if re.search(r"bit_equal\s*=\s*true", text):
        return True
    if re.search(r"bit_equal\s*=\s*false", text):
        return False
    return None


def build_reproducible_build_package_gate(
    *,
    v2_release_complete: bool,
    fixed_seed_evidence: tuple[str, ...],
    fixed_seed_byte_identical: bool | None,
) -> Gate:
    """Keep package completeness separate from byte-identical rebuild evidence."""
    required = (
        "release/industrial-v2/README.md",
        "release/industrial-v2/manifest.json",
        "release/industrial-v2/industrial-v2.bit",
    )
    blockers = tuple(
        f"missing release artifact: {path}" for path in missing_paths(required)
    )
    if not fixed_seed_evidence:
        blockers += ("fixed-seed reproducibility evidence is missing",)
    elif fixed_seed_byte_identical is not True:
        blockers += (
            "fixed placement seed did not produce byte-identical Bitstreams; exact reproducibility remains open",
        )
    return Gate(
        "reproducible_build_package",
        PASS if not blockers and v2_release_complete else BLOCKED,
        existing_paths(required) + fixed_seed_evidence,
        blockers,
    )


def load_status() -> dict:
    path = ROOT / "docs" / "goals" / "industrial-v2" / "STATUS.json"
    return json.loads(path.read_text(encoding="utf-8"))


def build_audit() -> dict:
    status_doc = load_status()
    phases = status_doc.get("phases", {})
    formal_candidate_paths = (
        "docs/experiments/2026-10-19-industrial-v2-g8-formal-feature-td.md",
        "docs/evidence/industrial-v2-g8-formal-feature-td-log.txt",
        "release/candidates/industrial-v2-formal-feature-spine/README.md",
        "release/candidates/industrial-v2-formal-feature-spine/route.qor",
        "release/candidates/industrial-v2-formal-feature-spine/final_timing.rpt",
        "release/candidates/industrial-v2-formal-feature-spine/camera_to_dsi_display_compress.bit",
        "release/candidates/industrial-v2-formal-feature-spine/industrial-v1-manifest.json",
    )
    formal_candidate_evidence = existing_paths(formal_candidate_paths)
    formal_candidate_complete = not missing_paths(formal_candidate_paths)
    warning_audit_paths = (
        "docs/evidence/industrial-v2-g8-clock-warning-audit.md",
        "docs/evidence/industrial-v2-g8-clock-warning-audit-log.txt",
        "docs/evidence/industrial-v2-g8-clock-warning-detail-log.txt",
        "docs/experiments/2026-10-19-industrial-v2-g8-clock-detail.md",
    )
    warning_audit_evidence = existing_paths(warning_audit_paths)
    warning_audit_complete = not missing_paths(warning_audit_paths)
    fixed_seed_paths = (
        "docs/evidence/industrial-v2-g8-fixed-seed-reproducibility.md",
    )
    fixed_seed_evidence = existing_paths(fixed_seed_paths)
    fixed_seed_byte_identical = fixed_seed_is_byte_identical(fixed_seed_evidence)
    phase_blockers = tuple(
        f"{name} status is {phases.get(name, {}).get('status', 'MISSING')}"
        for name in PHASE_NAMES
        if phases.get(name, {}).get("status") not in (PASS, "TD_PASS")
    )
    phase_evidence = tuple(
        evidence
        for name in PHASE_NAMES
        for evidence in phases.get(name, {}).get("evidence", [])
        if isinstance(evidence, str)
    )

    baseline = status_doc.get("baseline", {})
    baseline_relative = baseline.get("bitstream", "")
    baseline_path = ROOT / baseline_relative
    baseline_actual = sha256(baseline_path)
    baseline_ok = baseline_actual == baseline.get("sha256")

    v2_release_paths = (
        "release/industrial-v2/README.md",
        "release/industrial-v2/manifest.json",
        "release/industrial-v2/industrial-v2.bit",
    )
    td_v2_paths = (
        "docs/build/industrial-v2-summary.md",
        "docs/evidence/industrial-v2-td-build.md",
        "release/industrial-v2/td-reports",
    )
    candidate_qor_paths = (
        "docs/experiments/2026-10-19-industrial-v2-g8-osd-bcd-td.md",
        "release/candidates/industrial-v2-osd-bcd/route.qor",
        "release/candidates/industrial-v2-osd-bcd/final_timing.rpt",
    )
    candidate_qor_evidence = existing_paths(candidate_qor_paths)
    candidate_qor_complete = not missing_paths(candidate_qor_paths)
    current_release_qor_paths = (
        "release/industrial-v2/route.qor",
        "release/industrial-v2/final_timing.rpt",
    )
    current_release_qor_evidence = existing_paths(current_release_qor_paths)
    current_release_qor_complete = not missing_paths(current_release_qor_paths)
    v2_release_complete = not missing_paths(v2_release_paths)
    if current_release_qor_complete:
        current_route_qor = (ROOT / current_release_qor_paths[0]).read_text(
            encoding="utf-8", errors="replace"
        )
        resource_gate = build_resource_timing_gate(
            current_route_qor,
            ("docs/goals/industrial-v2/RESOURCE_BUDGET.md",)
            + current_release_qor_evidence,
        )
    else:
        resource_gate = Gate(
            "resource_timing_budget",
            BLOCKED,
            ("docs/goals/industrial-v2/RESOURCE_BUDGET.md",)
            + candidate_qor_evidence
            + formal_candidate_evidence,
            (
                "formal TD_PASS candidate measures Slice 86.07% with Setup WNS +100ps and Hold WNS +20ps, "
                "but it exceeds the initial <=85% target and still lacks warning closure, hardware and long-run evidence",
            )
            if formal_candidate_complete
            else (
                "candidate QoR is measured, but it is not the complete seven-feature V2 release budget",
            )
            if candidate_qor_complete
            else ("V2 Slice/RAM/DSP/WNS/TNS are not measured",),
        )

    gates = [
        Gate(
            "software_rtl_td_for_7_features",
            PASS if not phase_blockers and formal_candidate_complete else BLOCKED,
            phase_evidence + formal_candidate_evidence,
            phase_blockers,
        ),
        Gate(
            "same_bitstream_integration",
            PASS if v2_release_complete else BLOCKED,
            existing_paths(v2_release_paths),
            ("no V2 release directory/Bitstream is present",)
            if not v2_release_complete
            else (),
        ),
        Gate(
            "v1_regression",
            BLOCKED,
            ("docs/experiments/2026-10-19-industrial-v2-g0-baseline.md",),
            ("full work/tests baseline retains 8 frozen-vs-later contract failures",),
        ),
        Gate(
            "td_full_build",
            PASS if formal_candidate_complete or all((ROOT / path).exists() for path in td_v2_paths) else BLOCKED,
            existing_paths(td_v2_paths) + candidate_qor_evidence + formal_candidate_evidence,
            ("complete seven-feature V2 TD evidence is not present",)
            if not (formal_candidate_complete or all((ROOT / path).exists() for path in td_v2_paths))
            else (),
        ),
        resource_gate,
        Gate(
            "warnings_cdc_constraints_audit",
            BLOCKED,
            ("docs/goals/industrial-v2/STATUS.json",) + warning_audit_evidence,
            (
                "PHY-5016/PHY-5060/PHY-5079/PHY-5088 remain open; detailed source/sink analysis is recorded, but official pin/IP and hardware closure are pending",
            )
            if warning_audit_complete
            else ("V2 clock/PHY/CDC/undriven/exception audit is not complete",),
        ),
        Gate(
            "hardware_function_matrix",
            BLOCKED,
            (),
            ("no bound V2 board, camera, display, or Bitstream evidence",),
        ),
        Gate(
            "performance_traceability",
            BLOCKED,
            (),
            ("no physical frame-rate, end-to-end latency, or detection experiment",),
        ),
        Gate(
            "cold_reset_long_run",
            BLOCKED,
            (),
            ("cold start, hot reset, repeated download, and long-stability run are not executed",),
        ),
        build_reproducible_build_package_gate(
            v2_release_complete=v2_release_complete,
            fixed_seed_evidence=fixed_seed_evidence,
            fixed_seed_byte_identical=fixed_seed_byte_identical,
        ),
        Gate(
            "external_actuator_acceptance",
            BLOCKED,
            ("docs/experiments/2026-10-19-industrial-v2-g5-summary.md",),
            ("GPIO, electrical, actuator, and mechanical closed-loop evidence is unknown",),
        ),
        Gate(
            "visual_approval",
            PASS
            if status_doc.get("visual_approval", {}).get("status") == "AUTHORIZED"
            else BLOCKED,
            ("docs/goals/industrial-v2/STATUS.json:visual_approval",),
            ()
            if status_doc.get("visual_approval", {}).get("status") == "AUTHORIZED"
            else ("visual approval authorization is absent",),
        ),
    ]

    result = evaluate_release(gates)
    result.update(
        {
            "audit": "industrial-v2-g8-release",
            "audit_version": 1,
            "commit": git_head(),
            "worktree": str(ROOT).replace("\\", "/"),
            "baseline": {
                "path": baseline_relative,
                "expected_sha256": baseline.get("sha256"),
                "actual_sha256": baseline_actual,
                "status": PASS if baseline_ok else BLOCKED,
                "evidence_type": baseline.get("evidence_type", "unknown"),
            },
            "note": "RELEASED is permitted only when every gate is explicit PASS; visual approval authorization does not substitute for hardware or build evidence.",
        }
    )
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write-report", type=Path)
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    report = build_audit()
    payload = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    print(payload, end="")
    if args.write_report:
        path = args.write_report if args.write_report.is_absolute() else ROOT / args.write_report
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(payload, encoding="utf-8")
    return 0 if (not args.strict or report["release_status"] == "RELEASED") else 1


if __name__ == "__main__":
    raise SystemExit(main())
