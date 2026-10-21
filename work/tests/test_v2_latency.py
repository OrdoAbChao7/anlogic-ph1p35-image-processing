from pathlib import Path
import sys


MODEL_DIR = Path(__file__).resolve().parents[1] / "models" / "v2"
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(MODEL_DIR))

from latency_reference import (  # noqa: E402
    LatencyModel,
    TrackerEvent,
)


def test_matching_tags_publish_proc_and_video_cycles_but_not_physical_e2e():
    monitor = LatencyModel(timeout_cycles=20, counter_width=16)

    input_event = monitor.observe_input(10)
    monitor.advance(5)
    proc_event = monitor.observe_result(10)
    monitor.advance(3)
    video_event = monitor.observe_video(10)

    assert input_event.frame_gap is False
    assert proc_event.proc_valid and proc_event.proc_cycles == 5
    assert video_event.video_valid and video_event.video_cycles == 8
    assert video_event.e2e_valid is False
    assert video_event.e2e_cycles is None


def test_input_frame_gap_is_reported_without_fabricating_a_frame():
    monitor = LatencyModel()

    monitor.observe_input(100)
    gap_event = monitor.observe_input(102)

    assert gap_event.frame_gap
    assert gap_event.proc_valid is False


def test_tag_mismatch_does_not_publish_latency_and_matching_result_can_follow():
    monitor = LatencyModel(timeout_cycles=20)

    monitor.observe_input(7)
    monitor.advance(4)
    mismatch = monitor.observe_result(8)
    matching = monitor.observe_result(7)

    assert mismatch.tag_mismatch
    assert not mismatch.proc_valid
    assert matching.proc_valid and matching.proc_cycles == 4


def test_timeout_emits_once_and_discards_stale_pending_frame():
    monitor = LatencyModel(timeout_cycles=3)

    monitor.observe_input(1)
    timeout = monitor.advance(4)
    late = monitor.observe_result(1)

    assert timeout.timeout
    assert late.tag_mismatch
    assert not late.proc_valid


def test_timestamp_subtraction_is_wrap_safe():
    monitor = LatencyModel(timeout_cycles=20, counter_width=8)

    monitor.advance(254)
    monitor.observe_input(30)
    monitor.advance(5)
    result = monitor.observe_result(30)

    assert result.proc_valid and result.proc_cycles == 5


def test_reset_discards_pending_tags_and_restores_first_frame_semantics():
    monitor = LatencyModel()
    monitor.observe_input(4)
    monitor.advance(2)
    monitor.reset()

    late = monitor.observe_result(4)
    first = monitor.observe_input(20)

    assert late.tag_mismatch and not late.proc_valid
    assert first.frame_gap is False


def test_rtl_latency_ledgers_allow_a_full_720p_frame_before_timeout():
    inspection = ROOT / "fallback" / "rtl" / "inspection"
    for module in ("latency_monitor.v", "frame_tag_monitor.v"):
        source = (inspection / module).read_text(encoding="utf-8")
        assert "TIMEOUT_CYCLES = (2 * 1280 * 720)" in source

    bench = ROOT / "fallback" / "sim" / "inspection" / "tb_latency_monitor_full_frame.v"
    assert bench.is_file()

