#!/usr/bin/env python3
"""Audit the Industrial Vision V2 release gates without claiming hardware success."""

from __future__ import annotations

import argparse
import hashlib
import json
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


def load_status() -> dict:
    path = ROOT / "docs" / "goals" / "industrial-v2" / "STATUS.json"
    return json.loads(path.read_text(encoding="utf-8"))


def build_audit() -> dict:
    status_doc = load_status()
    phases = status_doc.get("phases", {})
    phase_blockers = tuple(
        f"{name} status is {phases.get(name, {}).get('status', 'MISSING')}"
        for name in PHASE_NAMES
        if phases.get(name, {}).get("status") != PASS
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
    v2_release_complete = not missing_paths(v2_release_paths)

    gates = [
        Gate(
            "software_rtl_td_for_7_features",
            PASS if not phase_blockers else BLOCKED,
            phase_evidence,
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
            PASS if all((ROOT / path).exists() for path in td_v2_paths) else BLOCKED,
            existing_paths(td_v2_paths) + candidate_qor_evidence,
            ("complete seven-feature V2 TD evidence is not bound to the final release package",)
            if not all((ROOT / path).exists() for path in td_v2_paths)
            else (),
        ),
        Gate(
            "resource_timing_budget",
            BLOCKED,
            ("docs/goals/industrial-v2/RESOURCE_BUDGET.md",) + candidate_qor_evidence,
            ("candidate QoR is measured, but it is not the complete seven-feature V2 release budget",)
            if candidate_qor_complete
            else ("V2 Slice/RAM/DSP/WNS/TNS are not measured",),
        ),
        Gate(
            "warnings_cdc_constraints_audit",
            BLOCKED,
            ("docs/goals/industrial-v2/STATUS.json",),
            ("V2 clock/PHY/CDC/undriven/exception audit is not complete",),
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
        Gate(
            "reproducible_build_package",
            PASS if v2_release_complete else BLOCKED,
            existing_paths(v2_release_paths),
            tuple(f"missing release artifact: {path}" for path in missing_paths(v2_release_paths)),
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
