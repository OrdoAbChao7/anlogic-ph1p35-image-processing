"""Software reference for the fixed-red detector ROI contract.

Coordinates use a half-open rectangle: [x0, x1) x [y0, y1).  The hardware
detector publishes inclusive bounding-box endpoints, so the result converts
the selected mask back to inclusive coordinates.
"""

from dataclasses import dataclass
from enum import Enum, auto
from typing import Sequence


class DetectionStatus(Enum):
    DETECTED = auto()
    NO_OBJECT = auto()
    INVALID = auto()


@dataclass(frozen=True)
class RoiSpec:
    x0: int
    y0: int
    x1: int
    y1: int

    def is_valid(self, width: int, height: int) -> bool:
        return (
            0 <= self.x0 < self.x1 <= width
            and 0 <= self.y0 < self.y1 <= height
        )


@dataclass(frozen=True)
class DetectionResult:
    status: DetectionStatus
    area: int
    bbox: tuple[int, int, int, int] | None

    @property
    def event_valid(self) -> bool:
        return self.status is DetectionStatus.DETECTED


def _validate_mask(mask: Sequence[Sequence[bool]]) -> tuple[int, int]:
    height = len(mask)
    width = len(mask[0]) if height else 0
    if width == 0 or any(len(row) != width for row in mask):
        raise ValueError("mask must be a non-empty rectangular matrix")
    return width, height


def _roi_mask(mask: Sequence[Sequence[bool]], roi: RoiSpec) -> list[list[bool]]:
    width, height = _validate_mask(mask)
    selected = [[False for _ in range(width)] for _ in range(height)]
    for y in range(roi.y0, roi.y1):
        for x in range(roi.x0, roi.x1):
            selected[y][x] = bool(mask[y][x])
    return selected


def _replicated_sample(
    source: Sequence[Sequence[bool]],
    x: int,
    y: int,
    roi: RoiSpec,
) -> bool:
    sample_x = min(max(x, roi.x0), roi.x1 - 1)
    sample_y = min(max(y, roi.y0), roi.y1 - 1)
    return bool(source[sample_y][sample_x])


def _morph_pass(
    source: Sequence[Sequence[bool]],
    roi: RoiSpec,
    erosion: bool,
) -> list[list[bool]]:
    width, height = _validate_mask(source)
    result = [[False for _ in range(width)] for _ in range(height)]
    for y in range(roi.y0, roi.y1):
        for x in range(roi.x0, roi.x1):
            samples = [
                _replicated_sample(source, x + dx, y + dy, roi)
                for dy in (-1, 0, 1)
                for dx in (-1, 0, 1)
            ]
            result[y][x] = all(samples) if erosion else any(samples)
    return result


def analyze_binary_mask(
    mask: Sequence[Sequence[bool]],
    roi: RoiSpec,
    min_area: int = 1,
) -> DetectionResult:
    width, height = _validate_mask(mask)
    if min_area < 1 or not roi.is_valid(width, height):
        return DetectionResult(DetectionStatus.INVALID, 0, None)

    selected = _roi_mask(mask, roi)
    eroded = _morph_pass(selected, roi, erosion=True)
    opened = _morph_pass(eroded, roi, erosion=False)
    points = [
        (x, y)
        for y in range(roi.y0, roi.y1)
        for x in range(roi.x0, roi.x1)
        if opened[y][x]
    ]
    if len(points) < min_area:
        return DetectionResult(DetectionStatus.NO_OBJECT, len(points), None)

    xs = [point[0] for point in points]
    ys = [point[1] for point in points]
    return DetectionResult(
        DetectionStatus.DETECTED,
        len(points),
        (min(xs), min(ys), max(xs), max(ys)),
    )
