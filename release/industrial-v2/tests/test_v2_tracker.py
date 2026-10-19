from pathlib import Path
import sys


MODEL_DIR = Path(__file__).resolve().parents[1] / "models" / "v2"
sys.path.insert(0, str(MODEL_DIR))

from tracker_reference import (  # noqa: E402
    DetectionState,
    FrameObservation,
    TemporalTracker,
    TrackerConfig,
)


def obs(frame_id, *, detected=False, invalid=False, cx=0, cy=0):
    return FrameObservation(
        frame_id=frame_id,
        detected=detected,
        invalid=invalid,
        cx=cx,
        cy=cy,
    )


def test_initial_detection_and_small_motion_publish_atomic_tracking_state():
    tracker = TemporalTracker()

    entered = tracker.update(obs(10, detected=True, cx=100, cy=80))
    static = tracker.update(obs(11, detected=True, cx=100, cy=80))
    moved = tracker.update(obs(12, detected=True, cx=110, cy=92))

    assert entered.state is DetectionState.TRACKING
    assert entered.enter and entered.track_valid
    assert entered.cx == 100 and entered.cy == 80
    assert entered.static
    assert not static.enter and static.static and static.track_valid
    assert moved.dx == 10 and moved.dy == 12
    assert not moved.static and moved.track_valid


def test_short_dropout_enters_lost_and_recovers_without_new_enter_event():
    tracker = TemporalTracker(TrackerConfig(max_lost_frames=3))

    tracker.update(obs(1, detected=True, cx=200, cy=120))
    lost_one = tracker.update(obs(2))
    lost_two = tracker.update(obs(3))
    recovered = tracker.update(obs(4, detected=True, cx=202, cy=121))

    assert lost_one.state is DetectionState.LOST
    assert lost_one.lost_frames == 1 and not lost_one.track_valid
    assert lost_two.state is DetectionState.LOST
    assert lost_two.lost_frames == 2
    assert recovered.state is DetectionState.TRACKING
    assert recovered.track_valid and not recovered.enter
    assert recovered.dx == 2 and recovered.dy == 1


def test_lost_window_emits_one_exit_and_reentry_emits_one_enter():
    tracker = TemporalTracker(TrackerConfig(max_lost_frames=2))

    tracker.update(obs(1, detected=True, cx=20, cy=20))
    tracker.update(obs(2))
    tracker.update(obs(3))
    exited = tracker.update(obs(4))
    reentered = tracker.update(obs(5, detected=True, cx=300, cy=200))

    assert exited.state is DetectionState.NO_OBJECT
    assert exited.exit and not exited.track_valid
    assert reentered.state is DetectionState.TRACKING
    assert reentered.enter and reentered.track_valid
    assert reentered.cx == 300 and reentered.cy == 200


def test_large_jump_is_rejected_then_same_location_is_a_new_target():
    tracker = TemporalTracker(TrackerConfig(max_step_x=10, max_step_y=10))

    tracker.update(obs(1, detected=True, cx=10, cy=10))
    rejected = tracker.update(obs(2, detected=True, cx=50, cy=10))
    reacquired = tracker.update(obs(3, detected=True, cx=50, cy=10))

    assert rejected.state is DetectionState.LOST
    assert not rejected.track_valid and not rejected.enter
    assert reacquired.state is DetectionState.TRACKING
    assert reacquired.enter and reacquired.track_valid


def test_invalid_result_clears_association_and_frame_gap_is_reported():
    tracker = TemporalTracker()

    tracker.update(obs(100, detected=True, cx=40, cy=30))
    invalid = tracker.update(obs(102, invalid=True, detected=True, cx=41, cy=31))
    next_target = tracker.update(obs(105, detected=True, cx=42, cy=32))

    assert invalid.state is DetectionState.INVALID
    assert invalid.frame_gap and not invalid.track_valid
    assert invalid.cx == 40 and invalid.cy == 30
    assert next_target.state is DetectionState.TRACKING
    assert next_target.enter and next_target.frame_gap


def test_reset_discards_previous_target_and_lost_counter():
    tracker = TemporalTracker()
    tracker.update(obs(1, detected=True, cx=8, cy=9))
    tracker.update(obs(2))

    tracker.reset()
    after_reset = tracker.update(obs(20, detected=True, cx=80, cy=90))

    assert after_reset.enter and after_reset.track_valid
    assert after_reset.state is DetectionState.TRACKING
    assert after_reset.lost_frames == 0
    assert not after_reset.frame_gap
