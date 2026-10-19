from pathlib import Path


SPINE = (
    Path(__file__).resolve().parents[2]
    / "fallback"
    / "rtl"
    / "integration"
    / "industrial_v2_feature_spine.v"
)


REQUIRED_MODULES = (
    "temporal_tracker",
    "trajectory_history",
    "tracking_overlay",
    "frame_tag_monitor",
    "latency_monitor",
    "motion_diff_160",
    "sort_event_controller",
    "sort_safety_interlock",
    "sort_pulse_generator",
    "awb_frame_gain_controller",
    "dimension_calibrator",
)


def test_feature_spine_exists_and_instantiates_all_v2_blocks():
    source = SPINE.read_text(encoding="utf-8")

    assert "module industrial_v2_feature_spine" in source
    for module_name in REQUIRED_MODULES:
        assert f"{module_name} " in source or f"{module_name}#" in source


def test_feature_spine_exposes_frame_and_safety_contracts():
    source = SPINE.read_text(encoding="utf-8")

    for port_name in (
        "I_frame_start",
        "I_frame_id",
        "I_result_valid",
        "I_motion_sample_valid",
        "I_frame_stats_valid",
        "I_calibration_valid",
        "I_arm",
        "I_external_fault",
        "O_track_valid",
        "O_latency_proc_valid",
        "O_motion_valid",
        "O_sort_pulse",
        "O_gain_update_valid",
        "O_shape_valid",
    ):
        assert port_name in source
