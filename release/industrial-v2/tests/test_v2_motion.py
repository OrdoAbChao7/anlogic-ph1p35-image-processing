from pathlib import Path
import sys


MODEL_DIR = Path(__file__).resolve().parents[1] / "models" / "v2"
sys.path.insert(0, str(MODEL_DIR))

from motion_reference import FixedRoiMotionModel  # noqa: E402


W = 8
H = 6


def solid(value):
    return [[value for _ in range(W)] for _ in range(H)]


def test_first_frame_only_establishes_history():
    model = FixedRoiMotionModel(W, H, threshold=8)

    result = model.process_frame(10, solid(20))

    assert result.summary_valid
    assert result.baseline_ready
    assert not result.motion_valid
    assert not result.motion
    assert result.motion_count == 0


def test_static_frame_has_no_continuous_false_motion():
    model = FixedRoiMotionModel(W, H, threshold=8)
    model.process_frame(10, solid(20))

    result = model.process_frame(11, solid(20))

    assert result.summary_valid and result.motion_valid
    assert not result.motion
    assert result.motion_count == 0
    assert result.xmin is None and result.xmax is None


def test_local_motion_reports_count_and_grid_bbox():
    model = FixedRoiMotionModel(W, H, threshold=8)
    model.process_frame(10, solid(20))
    current = solid(20)
    for y in range(1, 3):
        for x in range(2, 5):
            current[y][x] = 40

    result = model.process_frame(11, current)

    assert result.motion_valid and result.motion
    assert result.motion_count == 6
    assert (result.xmin, result.xmax, result.ymin, result.ymax) == (2, 4, 1, 2)


def test_threshold_is_strictly_greater_than():
    model = FixedRoiMotionModel(W, H, threshold=8)
    model.process_frame(10, solid(20))
    exact = solid(20)
    exact[0][0] = 28
    assert not model.process_frame(11, exact).motion

    above = solid(20)
    above[0][0] = 37  # 37 - 28 is strictly greater than the threshold.
    result = model.process_frame(12, above)
    assert result.motion and result.motion_count == 1


def test_frame_gap_refreshes_history_without_publishing_motion():
    model = FixedRoiMotionModel(W, H, threshold=8)
    model.process_frame(10, solid(20))
    changed = solid(80)

    gap = model.process_frame(12, changed)
    following = model.process_frame(13, changed)

    assert gap.frame_gap and not gap.motion_valid and not gap.motion
    assert following.motion_valid and not following.motion


def test_roi_edges_are_included():
    model = FixedRoiMotionModel(W, H, threshold=8)
    model.process_frame(10, solid(20))
    current = solid(20)
    current[0][0] = 40
    current[H - 1][W - 1] = 40

    result = model.process_frame(11, current)

    assert result.motion_count == 2
    assert (result.xmin, result.xmax, result.ymin, result.ymax) == (0, W - 1, 0, H - 1)


def test_invalid_frame_does_not_destroy_previous_history():
    model = FixedRoiMotionModel(W, H, threshold=8)
    model.process_frame(10, solid(20))

    invalid = model.process_frame(11, [row[:-1] for row in solid(20)])
    unchanged = model.process_frame(11, solid(20))

    assert invalid.invalid and not invalid.summary_valid
    assert unchanged.summary_valid and unchanged.motion_valid and not unchanged.motion


def test_reset_restores_first_frame_semantics():
    model = FixedRoiMotionModel(W, H, threshold=8)
    model.process_frame(10, solid(20))
    model.reset()

    result = model.process_frame(1, solid(200))

    assert result.summary_valid and not result.motion_valid and not result.frame_gap
