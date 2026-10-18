"""Reference model for calibrated dimensions and explainable shape checks."""

from dataclasses import dataclass


Q16 = 1 << 16


@dataclass(frozen=True)
class CalibrationConfig:
    scale_x_q16_16: int = 0
    scale_y_q16_16: int = 0
    nominal_width_mm_q16_16: int = 0
    nominal_height_mm_q16_16: int = 0
    tolerance_width_mm_q16_16: int = 0
    tolerance_height_mm_q16_16: int = 0
    occupancy_min_q8: int = 0
    aspect_min_q8: int = 0
    aspect_max_q8: int = 0
    valid: bool = True

    @classmethod
    def from_reference(
        cls,
        *,
        reference_width_px: int,
        reference_width_mm: int,
        reference_height_px: int,
        reference_height_mm: int,
        nominal_width_mm: int,
        nominal_height_mm: int,
        tolerance_width_mm: int,
        tolerance_height_mm: int,
        occupancy_min_q8: int,
        aspect_min_q8: int,
        aspect_max_q8: int,
    ):
        if min(reference_width_px, reference_height_px) <= 0:
            raise ValueError("reference dimensions must be positive")
        return cls(
            scale_x_q16_16=(reference_width_mm * Q16 + reference_width_px // 2) // reference_width_px,
            scale_y_q16_16=(reference_height_mm * Q16 + reference_height_px // 2) // reference_height_px,
            nominal_width_mm_q16_16=nominal_width_mm * Q16,
            nominal_height_mm_q16_16=nominal_height_mm * Q16,
            tolerance_width_mm_q16_16=tolerance_width_mm * Q16,
            tolerance_height_mm_q16_16=tolerance_height_mm * Q16,
            occupancy_min_q8=occupancy_min_q8,
            aspect_min_q8=aspect_min_q8,
            aspect_max_q8=aspect_max_q8,
            valid=True,
        )


@dataclass(frozen=True)
class DimensionResult:
    valid: bool = False
    invalid: bool = False
    unit: str = "UNCALIBRATED"
    width_px: int = 0
    height_px: int = 0
    width_mm_q16_16: int = 0
    height_mm_q16_16: int = 0
    occupancy_q8: int = 0
    aspect_q8: int = 0
    dimension_valid: bool = False
    shape_valid: bool = False


class DimensionModel:
    def __init__(self, config: CalibrationConfig):
        self.config = config

    def measure(self, xmin: int, xmax: int, ymin: int, ymax: int, area_px: int) -> DimensionResult:
        if not self.config.valid:
            return DimensionResult(invalid=True)
        if min(xmin, xmax, ymin, ymax, area_px) < 0 or xmax < xmin or ymax < ymin:
            return DimensionResult(invalid=True)

        width_px = xmax - xmin + 1
        height_px = ymax - ymin + 1
        bbox_area = width_px * height_px
        if bbox_area <= 0:
            return DimensionResult(invalid=True)

        width_mm = width_px * self.config.scale_x_q16_16
        height_mm = height_px * self.config.scale_y_q16_16
        occupancy_q8 = min(256, (area_px * 256) // bbox_area)
        aspect_q8 = min(65535, (width_px * 256) // height_px)
        width_ok = (
            self.config.nominal_width_mm_q16_16 - self.config.tolerance_width_mm_q16_16
            <= width_mm
            <= self.config.nominal_width_mm_q16_16 + self.config.tolerance_width_mm_q16_16
        )
        height_ok = (
            self.config.nominal_height_mm_q16_16 - self.config.tolerance_height_mm_q16_16
            <= height_mm
            <= self.config.nominal_height_mm_q16_16 + self.config.tolerance_height_mm_q16_16
        )
        dimension_valid = width_ok and height_ok
        shape_valid = (
            dimension_valid
            and occupancy_q8 >= self.config.occupancy_min_q8
            and self.config.aspect_min_q8 <= aspect_q8 <= self.config.aspect_max_q8
        )
        return DimensionResult(
            valid=True,
            unit="mm_q16_16",
            width_px=width_px,
            height_px=height_px,
            width_mm_q16_16=width_mm,
            height_mm_q16_16=height_mm,
            occupancy_q8=occupancy_q8,
            aspect_q8=aspect_q8,
            dimension_valid=dimension_valid,
            shape_valid=shape_valid,
        )
