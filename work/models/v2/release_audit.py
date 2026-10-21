"""Pure release-gate evaluation for the Industrial Vision V2 freeze audit."""

from dataclasses import dataclass
from typing import Iterable, Tuple


PASS = "PASS"
BLOCKED = "BLOCKED"
NOT_RUN = "NOT_RUN"
MISSING = "MISSING"
RELEASED = "RELEASED"


@dataclass(frozen=True)
class Gate:
    name: str
    status: str
    evidence: Tuple[str, ...] = ()
    blockers: Tuple[str, ...] = ()


def evaluate_release(gates: Iterable[Gate]) -> dict:
    """Return a stable, auditable result; only an explicit PASS can release."""

    normalized = []
    for gate in gates:
        normalized.append(
            {
                "name": gate.name,
                "status": gate.status,
                "evidence": list(gate.evidence),
                "blockers": list(gate.blockers),
            }
        )

    blocked = [gate["name"] for gate in normalized if gate["status"] != PASS]
    return {
        "release_status": RELEASED if not blocked else BLOCKED,
        "gate_count": len(normalized),
        "blocked_gates": blocked,
        "gates": normalized,
    }
