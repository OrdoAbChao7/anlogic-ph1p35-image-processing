from pathlib import Path
import random
import sys


MODEL_DIR = Path(__file__).resolve().parents[1] / "models" / "v2"
sys.path.insert(0, str(MODEL_DIR))

from calibration_reference import CalibrationConfig, DimensionModel  # noqa: E402


RTL = Path(__file__).resolve().parents[2] / "fallback" / "rtl" / "inspection" / "dimension_calibrator.v"


def calibrated_model():
    config = CalibrationConfig.from_reference(
        reference_width_px=120,
        reference_width_mm=60,
        reference_height_px=80,
        reference_height_mm=20,
        nominal_width_mm=60,
        nominal_height_mm=20,
        tolerance_width_mm=2,
        tolerance_height_mm=2,
        occupancy_min_q8=200,
        aspect_min_q8=320,
        aspect_max_q8=448,
    )
    return DimensionModel(config)


def test_reference_fit_keeps_independent_x_y_scales():
    model = calibrated_model()

    assert model.config.scale_x_q16_16 == 32768
    assert model.config.scale_y_q16_16 == 16384


def test_inclusive_bbox_converts_dimensions_and_passes_shape():
    result = calibrated_model().measure(10, 129, 20, 99, 9600)

    assert result.valid and result.unit == "mm_q16_16"
    assert (result.width_px, result.height_px) == (120, 80)
    assert result.width_mm_q16_16 == 60 * 65536
    assert result.height_mm_q16_16 == 20 * 65536
    assert result.occupancy_q8 == 256
    assert result.aspect_q8 == 384
    assert result.dimension_valid and result.shape_valid


def test_area_occupancy_rejects_sparse_red_interference():
    result = calibrated_model().measure(10, 129, 20, 99, 7000)

    assert result.dimension_valid
    assert result.occupancy_q8 < 200
    assert not result.shape_valid


def test_aspect_ratio_rejects_out_of_range_shape():
    result = calibrated_model().measure(0, 159, 0, 79, 12800)

    assert result.dimension_valid is False
    assert result.aspect_q8 == 512
    assert not result.shape_valid


def test_dimension_tolerance_rejects_under_and_over_size():
    under = calibrated_model().measure(0, 99, 0, 79, 8000)
    over = calibrated_model().measure(0, 139, 0, 79, 11200)

    assert not under.dimension_valid and not under.shape_valid
    assert not over.dimension_valid and not over.shape_valid


def test_invalid_or_uncalibrated_input_never_claims_mm():
    config = CalibrationConfig(valid=False)
    result = DimensionModel(config).measure(0, 119, 0, 79, 9600)
    reverse = calibrated_model().measure(20, 10, 0, 79, 1)

    assert result.invalid and result.unit == "UNCALIBRATED"
    assert reverse.invalid and not reverse.valid


def test_occupancy_is_saturated_and_single_pixel_edges_are_defined():
    full = calibrated_model().measure(0, 0, 0, 0, 4)
    saturated = calibrated_model().measure(10, 129, 20, 99, 20000)

    assert full.width_px == 1 and full.height_px == 1
    assert saturated.occupancy_q8 == 256


def test_rtl_dimension_arithmetic_uses_bounded_fixed_width_operands():
    source = RTL.read_text(encoding="utf-8")

    assert "localparam integer PIXEL_WIDTH" in source
    assert "localparam integer BBOX_AREA_WIDTH" in source
    assert "wire [63:0] bbox_area" not in source
    assert "wire [63:0] width_product" not in source
    assert "wire [63:0] height_product" not in source
    assert "[63:32]" not in source


def test_cross_product_shape_predicates_match_saturated_integer_division():
    rng = random.Random(0xD1A6)
    directed = [
        (9600, 9600, 200, 120, 80, 320, 448),
        (7499, 9600, 200, 120, 80, 320, 448),
        (7500, 9600, 200, 120, 80, 320, 448),
        (2**20 - 1, 1, 256, 2048, 1, 0, 65535),
    ]
    for _ in range(20_000):
        width = rng.randint(1, 2048)
        height = rng.randint(1, 2048)
        area = rng.randint(0, 2**20 - 1)
        occupancy_min = rng.randint(0, 511)
        aspect_min = rng.randint(0, 65535)
        aspect_max = rng.randint(aspect_min, 65535)
        directed.append((area, width * height, occupancy_min, width, height, aspect_min, aspect_max))

    for area, bbox_area, occupancy_min, width, height, aspect_min, aspect_max in directed:
        occupancy_q8 = min(256, area * 256 // bbox_area)
        occupancy_by_product = (
            occupancy_min <= 256 and area * 256 >= bbox_area * occupancy_min
        )
        assert (occupancy_q8 >= occupancy_min) == occupancy_by_product

        aspect_q8 = min(65535, width * 256 // height)
        aspect_by_product = (
            width * 256 >= height * aspect_min
            and (aspect_max == 65535 or width * 256 < height * (aspect_max + 1))
        )
        assert (aspect_min <= aspect_q8 <= aspect_max) == aspect_by_product
