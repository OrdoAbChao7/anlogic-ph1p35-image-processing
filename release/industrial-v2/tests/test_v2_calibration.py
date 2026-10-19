from pathlib import Path
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
