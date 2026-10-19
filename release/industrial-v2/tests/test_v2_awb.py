from pathlib import Path
import sys


MODEL_DIR = Path(__file__).resolve().parents[1] / "models" / "v2"
sys.path.insert(0, str(MODEL_DIR))

from awb_reference import AwbFrameModel, red_mask  # noqa: E402


def frame(rgb, width=4, height=4):
    return [[tuple(rgb) for _ in range(width)] for _ in range(height)]


def test_balanced_frame_keeps_unity_gains_and_updates_at_boundary():
    model = AwbFrameModel()

    result = model.process_frame(frame((100, 100, 100)), mean_luma=100)

    assert result.gains_used == (256, 256, 256)
    assert result.gains_next == (256, 256, 256)
    assert result.gain_updated and not result.scene_protected


def test_blue_cast_moves_r_and_b_gains_with_smoothing():
    model = AwbFrameModel(max_step=8)
    model.process_frame(frame((100, 100, 100)), mean_luma=100)

    result = model.process_frame(frame((120, 120, 180)), mean_luma=120)

    assert result.gains_used == (256, 256, 256)
    assert result.gains_next[0] > 256
    assert result.gains_next[2] < 256
    assert result.gains_next[1] == 256


def test_updated_gain_applies_to_next_frame_not_mid_frame():
    model = AwbFrameModel(max_step=8)
    first = model.process_frame(frame((120, 120, 180)), mean_luma=120)
    second = model.process_frame(frame((120, 120, 180)), mean_luma=120)

    assert first.gains_used == (256, 256, 256)
    assert second.gains_used == first.gains_next
    assert second.corrected[0][0] != first.corrected[0][0]


def test_dark_scene_is_protected():
    model = AwbFrameModel()
    result = model.process_frame(frame((2, 2, 2)), mean_luma=2)

    assert result.scene_protected and not result.gain_updated
    assert result.gains_next == result.gains_used


def test_large_luma_jump_holds_once_then_allows_stable_update():
    model = AwbFrameModel(scene_jump=40)
    model.process_frame(frame((100, 100, 100)), mean_luma=100)
    jump = model.process_frame(frame((160, 120, 80)), mean_luma=160)
    stable = model.process_frame(frame((160, 120, 80)), mean_luma=160)

    assert jump.scene_protected and jump.gains_next == jump.gains_used
    assert not stable.scene_protected and stable.gain_updated


def test_gain_limits_and_smoothing_bound_step():
    model = AwbFrameModel(max_step=8)
    model.process_frame(frame((128, 128, 128)), mean_luma=128)
    result = model.process_frame(frame((1, 128, 255)), mean_luma=128)

    assert all(128 <= gain <= 512 for gain in result.gains_next)
    assert abs(result.gains_next[0] - result.gains_used[0]) <= 8
    assert abs(result.gains_next[2] - result.gains_used[2]) <= 8


def test_red_detection_formula_remains_explicit_and_compatible():
    model = AwbFrameModel()
    result = model.process_frame(frame((150, 30, 30)), mean_luma=60)

    assert red_mask(result.corrected[0][0])


def test_invalid_frame_does_not_change_gain_state():
    model = AwbFrameModel()
    model.process_frame(frame((100, 100, 100)), mean_luma=100)
    invalid = model.process_frame([[(300, 0, 0)]], mean_luma=100)
    following = model.process_frame(frame((100, 100, 100)), mean_luma=100)

    assert invalid.invalid and invalid.gains_next == invalid.gains_used
    assert following.gains_used == invalid.gains_used
