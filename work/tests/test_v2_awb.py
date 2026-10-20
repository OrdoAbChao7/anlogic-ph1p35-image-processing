from pathlib import Path
import random
import sys


MODEL_DIR = Path(__file__).resolve().parents[1] / "models" / "v2"
ROOT = Path(__file__).resolve().parents[2]
RTL = ROOT / "fallback" / "rtl" / "isp" / "awb_frame_gain_controller.v"
sys.path.insert(0, str(MODEL_DIR))

from awb_reference import AwbFrameModel, red_mask  # noqa: E402


FIXED_FRAME_PIXELS = 1280 * 720


def fixed_mean_from_sum(total):
    # 921600 = 3600 * 256; ceil(2**32 / 3600) is exact for the
    # physically valid range [0, 255 * 921600].
    return ((total >> 8) * 1_193_047) >> 32


def fixed_mean_luma_from_sum(rgb_total):
    # 3 * 921600 = 10800 * 256; this Q35 reciprocal is exact for
    # the valid RGB sum range [0, 765 * 921600].
    return ((rgb_total >> 8) * 3_181_458) >> 35


def fast_smoothed_gain(current, mean_channel, target, *, max_step=8, smooth_shift=2):
    if mean_channel == 0:
        desired = 256
    else:
        numerator = target * 256 + mean_channel // 2
        if numerator < mean_channel * 128:
            desired = 128
        elif numerator >= mean_channel * 513:
            desired = 512
        else:
            base = mean_channel * current
            quantum = 1 << smooth_shift
            if numerator >= base + mean_channel:
                step = max(
                    [1]
                    + [
                        n
                        for n in range(2, max_step + 1)
                        if numerator >= base + n * quantum * mean_channel
                    ]
                )
                return min(512, current + step)
            if numerator < base:
                step = max(
                    [1]
                    + [
                        n
                        for n in range(2, max_step + 1)
                        if current >= n * quantum
                        and numerator < base - n * quantum * mean_channel + mean_channel
                    ]
                )
                return max(128, current - step)
            return current
    return AwbFrameModel(max_step=max_step, smooth_shift=smooth_shift)._smooth(current, desired)


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


def test_fixed_resolution_reciprocal_means_match_integer_division_boundaries():
    count = FIXED_FRAME_PIXELS
    channel_sums = {0, 255 * count}
    luma_sums = {0, 765 * count}
    for mean in range(256):
        channel_sums.update(
            max(0, min(255 * count, mean * count + delta))
            for delta in (-257, -1, 0, 1, 255, 256)
        )
        luma_sums.update(
            max(0, min(765 * count, mean * 3 * count + delta))
            for delta in (-257, -1, 0, 1, 255, 256)
        )
    rng = random.Random(0xA8B)
    channel_sums.update(rng.randint(0, 255 * count) for _ in range(20_000))
    luma_sums.update(rng.randint(0, 765 * count) for _ in range(20_000))

    assert all(fixed_mean_from_sum(total) == total // count for total in channel_sums)
    assert all(fixed_mean_luma_from_sum(total) == total // (3 * count) for total in luma_sums)


def test_fixed_gain_threshold_step_matches_reference_division_and_smoothing():
    model = AwbFrameModel(max_step=8, smooth_shift=2)
    rng = random.Random(0x6A1)
    cases = [(current, mean, target) for current in (128, 129, 255, 256, 511, 512)
             for mean in (0, 1, 2, 127, 128, 254, 255)
             for target in (0, 1, 64, 127, 128, 200, 254, 255)]
    cases.extend(
        (rng.randint(128, 512), rng.randint(0, 255), rng.randint(0, 255))
        for _ in range(30_000)
    )
    for current, mean, target in cases:
        desired = model._desired_gain(mean, target)
        expected = model._smooth(current, desired)
        assert fast_smoothed_gain(current, mean, target) == expected


def test_fixed_mean_multiplier_is_narrowed_to_the_proven_720p_sum_range():
    source = (
        ROOT / "fallback" / "rtl" / "isp" / "awb_frame_gain_controller.v"
    ).read_text(encoding="utf-8")

    assert "FIXED_MAX_CHANNEL_SUM = 32'd235008000" in source
    assert "reg [19:0] sum_div_256;" in source
    assert "sum_div_256 = channel_sum[27:8];" in source
    assert "reg [40:0] reciprocal_product;" in source


def test_fixed_rgb_target_average_uses_an_exact_narrow_10_bit_contract():
    source = RTL.read_text(encoding="utf-8")

    assert "function [7:0] fixed_average3;" in source
    assert "reciprocal_product = {9'd0, channel_mean_sum} * 19'd683;" in source
    assert "fixed_average3 = reciprocal_product[18:11];" in source
    assert "wire [9:0] fixed_target_mean_sum;" in source
    assert "assign target_mean = {24'd0, fixed_average3(fixed_target_mean_sum)};" in source
    assert all((value * 683) >> 11 == value // 3 for value in range(766))
