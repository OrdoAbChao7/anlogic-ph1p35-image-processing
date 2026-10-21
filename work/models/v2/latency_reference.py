"""Reference model for tagged internal latency measurements."""

from dataclasses import dataclass


@dataclass(frozen=True)
class LatencyEvent:
    frame_gap: bool = False
    tag_mismatch: bool = False
    timeout: bool = False
    proc_valid: bool = False
    proc_cycles: int | None = None
    video_valid: bool = False
    video_cycles: int | None = None
    e2e_valid: bool = False
    e2e_cycles: int | None = None


# Kept as a compatibility name for testbenches that call all frame-domain
# observations tracker events.
TrackerEvent = LatencyEvent


@dataclass
class _PendingFrame:
    frame_id: int
    timestamp: int
    result_seen: bool = False
    video_seen: bool = False


class LatencyModel:
    def __init__(self, timeout_cycles: int = 1024, counter_width: int = 32):
        if timeout_cycles < 1 or counter_width < 2:
            raise ValueError("timeout and counter width must be positive")
        self.timeout_cycles = timeout_cycles
        self.counter_width = counter_width
        self._mask = (1 << counter_width) - 1
        self.reset()

    def reset(self) -> None:
        self._cycle = 0
        self._last_input_id: int | None = None
        self._pending: _PendingFrame | None = None

    def _delta(self, timestamp: int) -> int:
        return (timestamp - self._pending.timestamp) & self._mask

    def _finish_if_complete(self) -> None:
        if self._pending and self._pending.result_seen and self._pending.video_seen:
            self._pending = None

    def advance(self, cycles: int) -> LatencyEvent:
        if cycles < 0:
            raise ValueError("cycles must be non-negative")
        timeout_event = LatencyEvent()
        for _ in range(cycles):
            self._cycle = (self._cycle + 1) & self._mask
            if self._pending and self._delta(self._cycle) > self.timeout_cycles:
                self._pending = None
                timeout_event = LatencyEvent(timeout=True)
        return timeout_event

    def observe_input(self, frame_id: int) -> LatencyEvent:
        frame_id &= 0xFFFF
        frame_gap = (
            self._last_input_id is not None
            and frame_id != ((self._last_input_id + 1) & 0xFFFF)
        )
        self._last_input_id = frame_id
        self._pending = _PendingFrame(frame_id, self._cycle)
        return LatencyEvent(frame_gap=frame_gap)

    def observe_result(self, frame_id: int) -> LatencyEvent:
        frame_id &= 0xFFFF
        if self._pending is None or self._pending.frame_id != frame_id:
            return LatencyEvent(tag_mismatch=True)
        self._pending.result_seen = True
        event = LatencyEvent(
            proc_valid=True,
            proc_cycles=self._delta(self._cycle),
        )
        self._finish_if_complete()
        return event

    def observe_video(self, frame_id: int) -> LatencyEvent:
        frame_id &= 0xFFFF
        if self._pending is None or self._pending.frame_id != frame_id:
            return LatencyEvent(tag_mismatch=True)
        self._pending.video_seen = True
        event = LatencyEvent(
            video_valid=True,
            video_cycles=self._delta(self._cycle),
        )
        self._finish_if_complete()
        return event
