"""Generate the auditable Stage D software-model verification report."""

from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path
from typing import Any

import cv2
import numpy as np

BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))

from plugins.industrial_inspection import IndustrialInspectionAlgorithm
from stage_d_contract import (
    FROZEN_PARAMS,
    FROZEN_VERSION,
    MORPHOLOGY_BORDER,
    Q10_BIAS,
    Q10_SHIFT,
    SAMPLE_SHA256,
    canonical_params_sha256,
    file_sha256,
)


REGISTRY_PATH = BASE_DIR / "registry.json"
PLUGIN_PATH = BASE_DIR / "plugins" / "industrial_inspection.py"
SAMPLES_DIR = BASE_DIR / "samples"
REPORT_PATH = BASE_DIR / "exports" / "stage_d" / "stage_d_report.json"


EXPECTED_VERDICTS = {
    "workpiece_empty_conveyor.png": "NO_OBJECT",
    "workpiece_noisy_speckles.png": "PASS",
    "workpiece_normal_pass.png": "PASS",
    "workpiece_oversized_ng.png": "NG",
    "workpiece_undersized_ng.png": "NG",
}


def _registry_entry() -> dict[str, Any]:
    registry = json.loads(REGISTRY_PATH.read_text(encoding="utf-8"))
    return next(item for item in registry if item["algorithm_id"] == "industrial_inspection")


def _image(name: str) -> np.ndarray:
    image = cv2.imread(str(SAMPLES_DIR / name), cv2.IMREAD_COLOR)
    if image is None:
        raise FileNotFoundError(SAMPLES_DIR / name)
    return cv2.cvtColor(image, cv2.COLOR_BGR2RGB)


def _pixel_summary(first: np.ndarray, second: np.ndarray) -> dict[str, Any]:
    delta = np.abs(first.astype(np.int16) - second.astype(np.int16))
    mse = float(np.mean(np.square(delta.astype(np.float64))))
    mae = float(np.mean(delta))
    psnr = "inf" if mse == 0 else float(20 * math.log10(255.0 / math.sqrt(mse)))
    return {
        "equal": bool(np.array_equal(first, second)),
        "shape": list(first.shape),
        "different_pixels": int(np.count_nonzero(np.any(delta != 0, axis=-1))) if delta.ndim == 3 else int(np.count_nonzero(delta)),
        "max_abs_error": int(np.max(delta)) if delta.size else 0,
        "mae": mae,
        "psnr_db": psnr,
    }


def _metric_equal(first: dict[str, Any], second: dict[str, Any]) -> bool:
    keys = ("verdict", "detected", "x_min", "x_max", "y_min", "y_max",
            "width_px", "height_px", "area_px", "nominal_w", "nominal_h",
            "width_error", "height_error", "roi", "invalid_reason")
    return all(first.get(key) == second.get(key) for key in keys)


def verify() -> dict[str, Any]:
    entry = _registry_entry()
    contract = {
        "registry_status": entry.get("status"),
        "version": entry.get("user_approved_version"),
        "version_ok": entry.get("user_approved_version") == FROZEN_VERSION,
        "params_ok": entry.get("frozen_params") == FROZEN_PARAMS,
        "params_sha256_ok": entry.get("params_sha256") == canonical_params_sha256(FROZEN_PARAMS),
        "plugin_sha256": file_sha256(PLUGIN_PATH),
        "plugin_sha256_ok": entry.get("model_sha256") == file_sha256(PLUGIN_PATH),
        "sample_hashes_ok": entry.get("sample_image_hashes") == SAMPLE_SHA256,
        "q10_shift": Q10_SHIFT,
        "q10_bias": Q10_BIAS,
        "morphology_border": MORPHOLOGY_BORDER,
    }

    plugin = IndustrialInspectionAlgorithm()
    samples = []
    all_samples_pass = True
    for name, expected_verdict in EXPECTED_VERDICTS.items():
        image = _image(name)
        reference = plugin.stage_d_trace(image, FROZEN_PARAMS, model="reference")
        hardware = plugin.stage_d_trace(image, FROZEN_PARAMS, model="hardware")
        raw_summary = _pixel_summary(reference["raw_mask"], hardware["raw_mask"])
        processed_summary = _pixel_summary(reference["processed_mask"], hardware["processed_mask"])
        metrics_equal = _metric_equal(reference["metrics"], hardware["metrics"])
        case_pass = (
            file_sha256(SAMPLES_DIR / name) == SAMPLE_SHA256[name]
            and raw_summary["equal"]
            and processed_summary["equal"]
            and metrics_equal
            and reference["metrics"]["verdict"] == expected_verdict
        )
        all_samples_pass = all_samples_pass and case_pass
        samples.append({
            "name": name,
            "expected_verdict": expected_verdict,
            "input_sha256": SAMPLE_SHA256[name],
            "dimensions": {"width": int(image.shape[1]), "height": int(image.shape[0])},
            "raw_mask": raw_summary,
            "processed_mask": processed_summary,
            "metrics_equal": metrics_equal,
            "reference_metrics": reference["metrics"],
            "hardware_metrics": hardware["metrics"],
            "pass": case_pass,
        })

    boundary = {
        "q10_threshold_vectors": {
            "red_strict_lower_cb_85": "excluded",
            "red_in_range_120_80_40": "included",
            "red_in_range_150_30_30": "included",
            "dark_y_60": "excluded",
            "dark_y_59": "included",
        },
        "roi_policy": "zero geometry at origin means full frame; all other zero/incomplete/out-of-bounds ROI is INVALID",
        "morphology_border": MORPHOLOGY_BORDER,
    }

    report = {
        "schema": "industrial_inspection.stage_d.v1",
        "generated_at": "2026-10-16",
        "stage": "D",
        "scope": "software-only hardware-equivalent verification; no RTL, TD build, or board evidence",
        "contract": contract,
        "samples": samples,
        "boundary": boundary,
        "pass": bool(all(value is True for value in (contract["version_ok"], contract["params_ok"],
                                                       contract["params_sha256_ok"], contract["plugin_sha256_ok"],
                                                       contract["sample_hashes_ok"])) and all_samples_pass),
    }
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return report


if __name__ == "__main__":
    result = verify()
    print(json.dumps({"report": str(REPORT_PATH), "pass": result["pass"]}, ensure_ascii=False))
    raise SystemExit(0 if result["pass"] else 1)
