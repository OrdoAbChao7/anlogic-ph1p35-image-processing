from pathlib import Path
import sys


MODEL_DIR = Path(__file__).resolve().parents[1] / "models" / "v2"
sys.path.insert(0, str(MODEL_DIR))

from sort_reference import (  # noqa: E402
    SafetyModel,
    SortControllerModel,
    SortPulseModel,
)


def test_pass_target_counts_and_triggers_once_across_frames():
    model = SortControllerModel(trigger_x=100)
    enter = model.step(target_enter=True, track_valid=True, center_x=40)
    classified = model.step(track_valid=True, verdict_valid=True, verdict_pass=True, center_x=60)
    crossing = model.step(track_valid=True, center_x=100)
    repeat = model.step(track_valid=True, center_x=120)

    assert enter.enter_event
    assert classified.pass_event and classified.pass_count == 1
    assert crossing.sort_request
    assert not repeat.sort_request
    assert repeat.pass_count == 1 and repeat.ng_count == 0


def test_ng_is_counted_once_and_can_trigger():
    model = SortControllerModel(trigger_x=10)
    model.step(target_enter=True, track_valid=True, center_x=0)

    event = model.step(
        track_valid=True,
        verdict_valid=True,
        verdict_pass=False,
        center_x=12,
    )

    assert event.ng_event and event.ng_count == 1
    assert event.sort_request


def test_late_verdict_still_triggers_if_target_is_beyond_line():
    model = SortControllerModel(trigger_x=10)
    model.step(target_enter=True, track_valid=True, center_x=0)
    model.step(track_valid=True, center_x=12)

    event = model.step(
        track_valid=True,
        verdict_valid=True,
        verdict_pass=True,
        center_x=12,
    )

    assert event.pass_event and event.sort_request


def test_invalid_verdict_never_executes_and_does_not_count():
    model = SortControllerModel(trigger_x=10)
    model.step(target_enter=True, track_valid=True, center_x=0)
    invalid = model.step(
        track_valid=True,
        verdict_valid=True,
        verdict_invalid=True,
        center_x=12,
    )
    valid = model.step(
        track_valid=True,
        verdict_valid=True,
        verdict_pass=True,
        center_x=12,
    )

    assert invalid.control_fault and not invalid.sort_request
    assert invalid.pass_count == 0 and invalid.ng_count == 0
    assert valid.pass_event and valid.sort_request


def test_tracking_loss_clears_lifecycle_and_requires_new_enter():
    model = SortControllerModel(trigger_x=10)
    model.step(target_enter=True, track_valid=True, center_x=0)
    model.step(track_valid=True, verdict_valid=True, verdict_pass=True, center_x=0)
    lost = model.step(tracking_lost=True, center_x=12)
    stale = model.step(track_valid=True, center_x=12)
    reenter = model.step(target_enter=True, track_valid=True, center_x=12)
    reclassify = model.step(track_valid=True, verdict_valid=True, verdict_pass=True, center_x=12)

    assert lost.control_fault and not lost.sort_request
    assert not stale.sort_request
    assert reenter.enter_event and not reenter.sort_request
    assert reclassify.sort_request


def test_exit_rearms_only_after_a_new_target_enter():
    model = SortControllerModel(trigger_x=10)
    model.step(target_enter=True, track_valid=True, center_x=0)
    first = model.step(track_valid=True, verdict_valid=True, verdict_pass=True, center_x=12)
    model.step(target_exit=True)
    stale = model.step(track_valid=True, center_x=12)
    model.step(target_enter=True, track_valid=True, center_x=0)
    second = model.step(track_valid=True, verdict_valid=True, verdict_pass=True, center_x=12)

    assert first.sort_request and not stale.sort_request and second.sort_request
    assert second.pass_count == 2


def test_safety_requires_arm_and_clear_after_fault():
    safety = SafetyModel()
    assert safety.step().safe_hold
    assert not safety.step(arm=True).safe_hold
    fault = safety.step(arm=True, invalid=True)
    blocked = safety.step(arm=True)
    cleared = safety.step(arm=True, clear_fault=True)

    assert fault.fault_latched and fault.safe_hold
    assert blocked.safe_hold and not blocked.request_allowed
    assert not cleared.safe_hold and cleared.request_allowed


def test_pulse_width_and_busy_rejection_are_deterministic():
    pulse = SortPulseModel(pulse_cycles=3)
    first = pulse.step(request=True, enable=True)
    rejected = pulse.step(request=True, enable=True)
    third = pulse.step(enable=True)
    idle = pulse.step(enable=True)

    assert first.accepted and first.pulse
    assert rejected.pulse and third.pulse
    assert rejected.rejected and rejected.timeout
    assert not idle.pulse and not idle.busy
