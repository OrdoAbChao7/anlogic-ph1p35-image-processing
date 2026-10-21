from pathlib import Path
import sys


MODEL_DIR = Path(__file__).resolve().parents[1] / "models" / "v2"
sys.path.insert(0, str(MODEL_DIR))

from roi_contract import (  # noqa: E402
    DetectionStatus,
    RoiSpec,
    analyze_binary_mask,
)


def mask_with_rectangles(width, height, rectangles):
    mask = [[False for _ in range(width)] for _ in range(height)]
    for x0, y0, rect_w, rect_h in rectangles:
        for y in range(y0, y0 + rect_h):
            for x in range(x0, x0 + rect_w):
                if 0 <= x < width and 0 <= y < height:
                    mask[y][x] = True
    return mask


def test_full_frame_roi_preserves_nominal_object():
    mask = mask_with_rectangles(16, 12, [(3, 2, 8, 6)])

    result = analyze_binary_mask(mask, RoiSpec(0, 0, 16, 12), min_area=4)

    assert result.status is DetectionStatus.DETECTED
    assert result.bbox == (3, 2, 10, 7)
    assert result.area == 48


def test_subwindow_edges_use_border_replicate_and_stay_in_roi():
    roi = RoiSpec(4, 3, 12, 9)
    mask = mask_with_rectangles(16, 12, [(4, 3, 8, 6)])

    result = analyze_binary_mask(mask, roi, min_area=4)

    assert result.status is DetectionStatus.DETECTED
    assert result.bbox == (4, 3, 11, 8)
    assert result.area == 48


def test_half_target_is_clipped_at_left_roi_boundary():
    roi = RoiSpec(4, 3, 12, 9)
    mask = mask_with_rectangles(16, 12, [(1, 3, 8, 6)])

    result = analyze_binary_mask(mask, roi, min_area=4)

    assert result.status is DetectionStatus.DETECTED
    assert result.bbox == (4, 3, 8, 8)
    assert result.area == 30


def test_roi_external_red_interference_is_ignored():
    roi = RoiSpec(4, 3, 12, 9)
    mask = mask_with_rectangles(
        16,
        12,
        [
            (6, 5, 4, 4),
            (0, 0, 4, 12),
            (12, 0, 4, 12),
        ],
    )

    result = analyze_binary_mask(mask, roi, min_area=4)

    assert result.status is DetectionStatus.DETECTED
    assert result.bbox == (6, 5, 9, 8)
    assert result.area == 16


def test_empty_roi_publishes_no_object():
    mask = mask_with_rectangles(16, 12, [])

    result = analyze_binary_mask(mask, RoiSpec(4, 3, 12, 9), min_area=4)

    assert result.status is DetectionStatus.NO_OBJECT
    assert result.bbox is None
    assert result.area == 0


def test_invalid_roi_publishes_invalid_without_detection_event():
    mask = mask_with_rectangles(16, 12, [(3, 2, 8, 6)])

    result = analyze_binary_mask(mask, RoiSpec(8, 3, 4, 9), min_area=4)

    assert result.status is DetectionStatus.INVALID
    assert result.bbox is None
    assert result.area == 0
    assert not result.event_valid
