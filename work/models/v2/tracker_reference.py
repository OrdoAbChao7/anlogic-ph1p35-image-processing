"""Frame-domain software reference for the single-target tracker."""

from dataclasses import dataclass
from enum import Enum, auto


class DetectionState(Enum):
    NO_OBJECT = auto()
    TRACKING = auto()
    LOST = auto()
    INVALID = auto()


class MotionDirection(Enum):
    NONE = auto()
    STATIC = auto()
    LEFT = auto()
    RIGHT = auto()
    UP = auto()
    DOWN = auto()
    UP_LEFT = auto()
    UP_RIGHT = auto()
    DOWN_LEFT = auto()
    DOWN_RIGHT = auto()


@dataclass(frozen=True)
class TrackerConfig:
    max_step_x: int = 64
    max_step_y: int = 64
    max_lost_frames: int = 3

    def __post_init__(self):
        if self.max_step_x < 0 or self.max_step_y < 0:
            raise ValueError("association gates must be non-negative")
        if self.max_lost_frames < 1:
            raise ValueError("max_lost_frames must be positive")


@dataclass(frozen=True)
class FrameObservation:
    frame_id: int
    detected: bool
    invalid: bool
    cx: int
    cy: int


@dataclass(frozen=True)
class TrackerState:
    state: DetectionState
    track_valid: bool
    enter: bool
    exit: bool
    frame_gap: bool
    static: bool
    cx: int
    cy: int
    dx: int
    dy: int
    direction: MotionDirection
    lost_frames: int


def _direction(dx: int, dy: int) -> MotionDirection:
    if dx == 0 and dy == 0:
        return MotionDirection.STATIC
    if dx < 0 and dy == 0:
        return MotionDirection.LEFT
    if dx > 0 and dy == 0:
        return MotionDirection.RIGHT
    if dx == 0 and dy < 0:
        return MotionDirection.UP
    if dx == 0 and dy > 0:
        return MotionDirection.DOWN
    if dx < 0 and dy < 0:
        return MotionDirection.UP_LEFT
    if dx > 0 and dy < 0:
        return MotionDirection.UP_RIGHT
    if dx < 0 and dy > 0:
        return MotionDirection.DOWN_LEFT
    return MotionDirection.DOWN_RIGHT


class TemporalTracker:
    def __init__(self, config: TrackerConfig | None = None):
        self.config = config or TrackerConfig()
        self.reset()

    def reset(self) -> None:
        self._active = False
        self._lost_frames = 0
        self._last_frame_id: int | None = None
        self._cx = 0
        self._cy = 0

    def _state(
        self,
        state: DetectionState,
        *,
        track_valid: bool = False,
        enter: bool = False,
        exit: bool = False,
        frame_gap: bool = False,
        dx: int = 0,
        dy: int = 0,
        direction: MotionDirection = MotionDirection.NONE,
    ) -> TrackerState:
        return TrackerState(
            state=state,
            track_valid=track_valid,
            enter=enter,
            exit=exit,
            frame_gap=frame_gap,
            static=track_valid and dx == 0 and dy == 0,
            cx=self._cx,
            cy=self._cy,
            dx=dx,
            dy=dy,
            direction=direction,
            lost_frames=self._lost_frames,
        )

    def update(self, observation: FrameObservation) -> TrackerState:
        current_frame_id = observation.frame_id & 0xFFFF
        frame_gap = (
            self._last_frame_id is not None
            and current_frame_id != ((self._last_frame_id + 1) & 0xFFFF)
        )
        self._last_frame_id = current_frame_id

        if observation.invalid:
            self._active = False
            self._lost_frames = 0
            return self._state(DetectionState.INVALID, frame_gap=frame_gap)

        if not observation.detected:
            if not self._active:
                return self._state(DetectionState.NO_OBJECT, frame_gap=frame_gap)
            if self._lost_frames < self.config.max_lost_frames:
                self._lost_frames += 1
                return self._state(DetectionState.LOST, frame_gap=frame_gap)
            self._active = False
            return self._state(
                DetectionState.NO_OBJECT,
                exit=True,
                frame_gap=frame_gap,
            )

        if not self._active:
            self._active = True
            self._lost_frames = 0
            self._cx = observation.cx
            self._cy = observation.cy
            return self._state(
                DetectionState.TRACKING,
                track_valid=True,
                enter=True,
                frame_gap=frame_gap,
                direction=MotionDirection.STATIC,
            )

        dx = observation.cx - self._cx
        dy = observation.cy - self._cy
        within_gate = (
            abs(dx) <= self.config.max_step_x
            and abs(dy) <= self.config.max_step_y
        )

        if within_gate:
            self._cx = observation.cx
            self._cy = observation.cy
            self._lost_frames = 0
            return self._state(
                DetectionState.TRACKING,
                track_valid=True,
                frame_gap=frame_gap,
                dx=dx,
                dy=dy,
                direction=_direction(dx, dy),
            )

        if self._lost_frames > 0:
            self._active = True
            self._lost_frames = 0
            self._cx = observation.cx
            self._cy = observation.cy
            return self._state(
                DetectionState.TRACKING,
                track_valid=True,
                enter=True,
                frame_gap=frame_gap,
                direction=MotionDirection.STATIC,
            )

        self._lost_frames = 1
        return self._state(DetectionState.LOST, frame_gap=frame_gap)
