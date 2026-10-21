import numpy as np

from work.models.v2.telemetry_osd_reference import (
    format_telemetry_lines,
    render_telemetry_osd,
)
from work.algorithm_lab.plugins.v2_telemetry_osd import V2TelemetryOSDAlgorithm


def _valid_telemetry():
    return {
        "mode": "original",
        "frame_count": 1,
        "detected": True,
        "pass": True,
        "ng": False,
        "invalid": False,
        "width_px": 1280,
        "height_px": 720,
        "proc_valid": True,
        "proc_cycles": 0x89ABCDEF,
        "motion_valid": True,
        "motion": True,
        "motion_count": 19200,
        "pass_count": 65535,
        "ng_count": 65535,
        "sort_pulse": False,
        "safe_enable": False,
        "dimension_valid": True,
        "shape_valid": True,
        "scale_provisional": True,
        "width_mm_q16_16": 60 << 16,
        "height_mm_q16_16": 20 << 16,
    }


def test_telemetry_lines_keep_measurement_units_and_provisional_label():
    lines = format_telemetry_lines(_valid_telemetry())

    assert len(lines) == 12
    assert lines[3] == "N:1 W:1280PX H:0720PX"
    assert lines[5] == "PROC:CYC 89ABCDEF"
    assert lines[6] == "VIDEO:N/A E2E:N/A"
    assert lines[7] == "MOTION:1 COUNT:004B00"
    assert lines[8] == "PASS:FFFF NG:FFFF"
    assert lines[10] == "CAL:PROV W:00060MM"
    assert lines[11] == "H:00020MM SHAPE:VALID"
    assert all(len(line) <= 32 for line in lines)


def test_invalid_proc_and_unavailable_motion_are_not_rendered_as_stale_values():
    telemetry = _valid_telemetry()
    telemetry.update(proc_valid=False, proc_cycles=0xFFFFFFFF, motion_valid=False,
                     motion=True, motion_count=0xFFFFFF)

    lines = format_telemetry_lines(telemetry)

    assert lines[5] == "PROC:CYC N/A"
    assert lines[7] == "MOTION:N/A COUNT:N/A"


def test_maximum_bounded_counts_and_dimensions_are_not_truncated():
    telemetry = _valid_telemetry()
    telemetry.update(width_px=2047, height_px=2047, motion_count=0xFFFFFF,
                     pass_count=0xFFFF, ng_count=0xFFFF)

    lines = format_telemetry_lines(telemetry)

    assert lines[3] == "N:1 W:2047PX H:2047PX"
    assert lines[7] == "MOTION:1 COUNT:FFFFFF"
    assert lines[8] == "PASS:FFFF NG:FFFF"


def test_invalid_dimensions_keep_units_and_do_not_expose_candidate_values():
    telemetry = _valid_telemetry()
    telemetry.update(dimension_valid=False, shape_valid=False,
                     width_mm_q16_16=0xFFFFFFFF, height_mm_q16_16=0xFFFFFFFF)

    lines = format_telemetry_lines(telemetry)

    assert lines[10] == "CAL:PROV DIM:N/A"
    assert lines[11] == "H:N/A SHAPE:N/A"


def test_maximum_candidate_dimension_remains_five_decimal_digits():
    telemetry = _valid_telemetry()
    telemetry.update(width_mm_q16_16=0xFFFFFFFF, height_mm_q16_16=0xFFFFFFFF)

    lines = format_telemetry_lines(telemetry)

    assert lines[10] == "CAL:PROV W:65535MM"
    assert lines[11] == "H:65535MM SHAPE:VALID"


def test_reference_preview_preserves_frame_and_reports_the_rendered_rows():
    image = np.full((360, 640, 3), 32, dtype=np.uint8)
    rendered, metrics = render_telemetry_osd(image, _valid_telemetry())

    assert rendered.shape == image.shape
    assert rendered.dtype == np.uint8
    assert np.any(rendered != image)
    assert metrics["telemetry_lines"] == format_telemetry_lines(_valid_telemetry())
    assert metrics["physical_calibration_claimed"] is False


def test_algorithm_lab_plugin_exposes_reference_and_hardware_preview_contracts():
    plugin = V2TelemetryOSDAlgorithm()
    image = np.full((360, 640, 3), 32, dtype=np.uint8)
    reference, reference_metrics = plugin.process_visual_reference(image, {})
    hardware, hardware_metrics = plugin.process_hardware_equivalent(image, {})

    assert plugin.algorithm_id == "v2_telemetry_osd"
    assert reference.shape == hardware.shape == image.shape
    assert np.array_equal(reference, hardware)
    assert reference_metrics["telemetry_lines"] == hardware_metrics["telemetry_lines"]
    assert {item["id"] for item in plugin.get_parameter_specs()} >= {
        "proc_valid", "motion_count", "pass_count", "sort_pulse", "scale_provisional"
    }
