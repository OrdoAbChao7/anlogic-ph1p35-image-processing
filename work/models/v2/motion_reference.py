"""Reference model for fixed-ROI, cross-frame luminance motion detection."""

from dataclasses import dataclass


@dataclass(frozen=True)
class MotionResult:
    frame_id: int
    summary_valid: bool = False
    baseline_ready: bool = False
    frame_gap: bool = False
    invalid: bool = False
    motion_valid: bool = False
    motion: bool = False
    motion_count: int = 0
    xmin: int | None = None
    xmax: int | None = None
    ymin: int | None = None
    ymax: int | None = None


class FixedRoiMotionModel:
    """Compare one fixed-size 8-bit luminance grid against the prior frame."""

    def __init__(self, width: int = 160, height: int = 120, threshold: int = 8):
        if width < 1 or height < 1:
            raise ValueError("ROI dimensions must be positive")
        if not 0 <= threshold <= 255:
            raise ValueError("threshold must fit in 8 bits")
        self.width = width
        self.height = height
        self.threshold = threshold
        self.reset()

    def reset(self) -> None:
        self._history: tuple[tuple[int, ...], ...] | None = None
        self._last_frame_id: int | None = None

    def _normalise_frame(self, frame) -> tuple[tuple[int, ...], ...] | None:
        try:
            if len(frame) != self.height:
                return None
            rows = []
            for row in frame:
                if len(row) != self.width:
                    return None
                values = tuple(int(value) for value in row)
                if any(value < 0 or value > 255 for value in values):
                    return None
                rows.append(values)
            return tuple(rows)
        except (TypeError, ValueError):
            return None

    def process_frame(self, frame_id: int, frame) -> MotionResult:
        frame_id &= 0xFFFF
        current = self._normalise_frame(frame)
        if current is None:
            return MotionResult(
                frame_id=frame_id,
                baseline_ready=self._history is not None,
                invalid=True,
            )

        frame_gap = (
            self._last_frame_id is not None
            and frame_id != ((self._last_frame_id + 1) & 0xFFFF)
        )
        if self._history is None or frame_gap:
            self._history = current
            self._last_frame_id = frame_id
            return MotionResult(
                frame_id=frame_id,
                summary_valid=True,
                baseline_ready=True,
                frame_gap=frame_gap,
            )

        count = 0
        xmin = xmax = ymin = ymax = None
        for y in range(self.height):
            for x in range(self.width):
                if abs(current[y][x] - self._history[y][x]) > self.threshold:
                    count += 1
                    xmin = x if xmin is None else min(xmin, x)
                    xmax = x if xmax is None else max(xmax, x)
                    ymin = y if ymin is None else min(ymin, y)
                    ymax = y if ymax is None else max(ymax, y)

        self._history = current
        self._last_frame_id = frame_id
        return MotionResult(
            frame_id=frame_id,
            summary_valid=True,
            baseline_ready=True,
            motion_valid=True,
            motion=count != 0,
            motion_count=count,
            xmin=xmin,
            xmax=xmax,
            ymin=ymin,
            ymax=ymax,
        )
