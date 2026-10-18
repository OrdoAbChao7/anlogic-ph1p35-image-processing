"""Reference model for frame-boundary fixed-point white-balance updates."""

from dataclasses import dataclass


@dataclass(frozen=True)
class AwbResult:
    gains_used: tuple[int, int, int]
    gains_next: tuple[int, int, int]
    corrected: tuple[tuple[tuple[int, int, int], ...], ...]
    gain_updated: bool = False
    scene_protected: bool = False
    invalid: bool = False
    mean_rgb: tuple[int, int, int] = (0, 0, 0)
    mean_luma: int = 0


def _clamp(value: int, lower: int, upper: int) -> int:
    return max(lower, min(upper, value))


def _correct_channel(value: int, gain_q8_8: int) -> int:
    return _clamp((value * gain_q8_8 + 128) >> 8, 0, 255)


def red_mask(rgb: tuple[int, int, int]) -> bool:
    """Keep the frozen strict Q10 Cb/Cr red-part predicate explicit."""

    r, g, b = rgb
    cb = (512 * b - 173 * r - 339 * g + 131072) >> 10
    cr = (512 * r - 429 * g - 83 * b + 131072) >> 10
    return 85 < cb < 125 and 135 < cr < 200


class AwbFrameModel:
    def __init__(
        self,
        *,
        min_gain: int = 128,
        max_gain: int = 512,
        max_step: int = 8,
        smooth_shift: int = 2,
        luma_min: int = 16,
        luma_max: int = 240,
        scene_jump: int = 40,
    ):
        if min_gain < 0 or max_gain < min_gain or max_step < 1:
            raise ValueError("invalid gain limits")
        self.min_gain = min_gain
        self.max_gain = max_gain
        self.max_step = max_step
        self.smooth_shift = smooth_shift
        self.luma_min = luma_min
        self.luma_max = luma_max
        self.scene_jump = scene_jump
        self.reset()

    def reset(self) -> None:
        self._gains = (256, 256, 256)
        self._previous_luma: int | None = None

    def _validate(self, frame):
        try:
            rows = []
            if len(frame) == 0:
                return None
            for row in frame:
                pixels = []
                for pixel in row:
                    if len(pixel) != 3:
                        return None
                    rgb = tuple(int(value) for value in pixel)
                    if any(value < 0 or value > 255 for value in rgb):
                        return None
                    pixels.append(rgb)
                if not pixels:
                    return None
                rows.append(tuple(pixels))
            return tuple(rows)
        except (TypeError, ValueError):
            return None

    def _smooth(self, current: int, desired: int) -> int:
        delta = desired - current
        if delta == 0:
            return current
        magnitude = abs(delta) >> self.smooth_shift
        step = max(1, min(self.max_step, magnitude))
        return _clamp(current + (step if delta > 0 else -step), self.min_gain, self.max_gain)

    def _desired_gain(self, mean_channel: int, target: int) -> int:
        if mean_channel <= 0:
            return 256
        raw = (target * 256 + mean_channel // 2) // mean_channel
        return _clamp(raw, self.min_gain, self.max_gain)

    def process_frame(self, frame, *, mean_luma: int | None = None) -> AwbResult:
        current_gains = self._gains
        normalised = self._validate(frame)
        if normalised is None:
            return AwbResult(
                gains_used=current_gains,
                gains_next=current_gains,
                corrected=(),
                invalid=True,
            )

        pixels = [pixel for row in normalised for pixel in row]
        count = len(pixels)
        mean_rgb = tuple(sum(pixel[channel] for pixel in pixels) // count for channel in range(3))
        if mean_luma is None:
            luma_values = [
                (77 * r + 150 * g + 29 * b) >> 8 for r, g, b in pixels
            ]
            mean_luma = sum(luma_values) // count
        if not 0 <= mean_luma <= 255:
            return AwbResult(
                gains_used=current_gains,
                gains_next=current_gains,
                corrected=(),
                invalid=True,
            )

        corrected = tuple(
            tuple(
                tuple(_correct_channel(value, current_gains[channel]) for channel, value in enumerate(pixel))
                for pixel in row
            )
            for row in normalised
        )
        target = sum(mean_rgb) // 3
        desired = (
            self._desired_gain(mean_rgb[0], target),
            256,
            self._desired_gain(mean_rgb[2], target),
        )
        scene_protected = (
            mean_luma < self.luma_min
            or mean_luma > self.luma_max
            or (
                self._previous_luma is not None
                and abs(mean_luma - self._previous_luma) > self.scene_jump
            )
        )
        next_gains = current_gains if scene_protected else tuple(
            self._smooth(current, want) for current, want in zip(current_gains, desired)
        )
        self._previous_luma = mean_luma
        if not scene_protected:
            self._gains = next_gains
        return AwbResult(
            gains_used=current_gains,
            gains_next=next_gains,
            corrected=corrected,
            gain_updated=not scene_protected,
            scene_protected=scene_protected,
            mean_rgb=mean_rgb,
            mean_luma=mean_luma,
        )
