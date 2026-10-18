"""Reference models for internal sort events, safety and virtual actuation."""

from dataclasses import dataclass


@dataclass(frozen=True)
class SortEvent:
    enter_event: bool = False
    pass_event: bool = False
    ng_event: bool = False
    sort_request: bool = False
    control_fault: bool = False
    active: bool = False
    classified: bool = False
    triggered: bool = False
    pass_count: int = 0
    ng_count: int = 0


class SortControllerModel:
    def __init__(self, trigger_x: int = 100):
        if trigger_x < 0:
            raise ValueError("trigger_x must be non-negative")
        self.trigger_x = trigger_x
        self.reset()

    def reset(self) -> None:
        self._active = False
        self._classified = False
        self._verdict_pass = False
        self._triggered = False
        self._previous_x: int | None = None
        self._pass_count = 0
        self._ng_count = 0

    def _event(self, **kwargs) -> SortEvent:
        return SortEvent(
            active=self._active,
            classified=self._classified,
            triggered=self._triggered,
            pass_count=self._pass_count,
            ng_count=self._ng_count,
            **kwargs,
        )

    def step(
        self,
        *,
        track_valid: bool = False,
        target_enter: bool = False,
        target_exit: bool = False,
        tracking_lost: bool = False,
        verdict_valid: bool = False,
        verdict_pass: bool = False,
        verdict_invalid: bool = False,
        center_x: int = 0,
    ) -> SortEvent:
        enter_event = False
        pass_event = False
        ng_event = False
        sort_request = False
        control_fault = False

        if target_enter:
            self._active = True
            self._classified = False
            self._verdict_pass = False
            self._triggered = False
            self._previous_x = None
            enter_event = True

        if tracking_lost:
            self._active = False
            self._classified = False
            self._verdict_pass = False
            self._triggered = False
            self._previous_x = None
            return self._event(enter_event=enter_event, control_fault=True)

        if target_exit:
            self._active = False
            self._classified = False
            self._verdict_pass = False
            self._triggered = False
            self._previous_x = None
            return self._event(enter_event=enter_event)

        if verdict_invalid:
            control_fault = True

        newly_classified = False
        if self._active and verdict_valid and not verdict_invalid and not self._classified:
            self._classified = True
            self._verdict_pass = bool(verdict_pass)
            newly_classified = True
            if self._verdict_pass:
                self._pass_count += 1
                pass_event = True
            else:
                self._ng_count += 1
                ng_event = True

        if self._active and track_valid and self._classified and not self._triggered:
            crossed = center_x >= self.trigger_x and (
                self._previous_x is None or self._previous_x < self.trigger_x
            )
            already_beyond_on_classification = newly_classified and center_x >= self.trigger_x
            if crossed or already_beyond_on_classification:
                self._triggered = True
                sort_request = True

        if self._active and track_valid:
            self._previous_x = center_x

        return self._event(
            enter_event=enter_event,
            pass_event=pass_event,
            ng_event=ng_event,
            sort_request=sort_request,
            control_fault=control_fault,
        )


@dataclass(frozen=True)
class SafetyEvent:
    safe_hold: bool
    request_allowed: bool
    fault_latched: bool


class SafetyModel:
    def __init__(self):
        self.reset()

    def reset(self) -> None:
        self._fault_latched = False

    def step(
        self,
        *,
        arm: bool = False,
        invalid: bool = False,
        tracking_lost: bool = False,
        external_fault: bool = False,
        clear_fault: bool = False,
    ) -> SafetyEvent:
        if clear_fault and not (invalid or tracking_lost or external_fault):
            self._fault_latched = False
        if invalid or tracking_lost or external_fault:
            self._fault_latched = True
        allowed = bool(arm and not self._fault_latched and not invalid and not tracking_lost and not external_fault)
        return SafetyEvent(
            safe_hold=not allowed,
            request_allowed=allowed,
            fault_latched=self._fault_latched,
        )


@dataclass(frozen=True)
class PulseEvent:
    pulse: bool
    busy: bool
    accepted: bool
    rejected: bool
    timeout: bool


class SortPulseModel:
    def __init__(self, pulse_cycles: int = 3):
        if pulse_cycles < 1:
            raise ValueError("pulse_cycles must be positive")
        self.pulse_cycles = pulse_cycles
        self.reset()

    def reset(self) -> None:
        self._busy = False
        self._remaining = 0

    def step(self, *, request: bool = False, enable: bool = False) -> PulseEvent:
        pulse = False
        accepted = False
        rejected = False
        timeout = False

        if self._busy:
            if not enable:
                self._busy = False
                self._remaining = 0
                timeout = True
            else:
                pulse = True
                if request:
                    rejected = True
                    timeout = True
                if self._remaining <= 1:
                    self._busy = False
                    self._remaining = 0
                else:
                    self._remaining -= 1
        elif request:
            if enable:
                accepted = True
                pulse = True
                self._remaining = self.pulse_cycles - 1
                self._busy = self._remaining > 0
            else:
                rejected = True
                timeout = True

        return PulseEvent(
            pulse=pulse,
            busy=self._busy,
            accepted=accepted,
            rejected=rejected,
            timeout=timeout,
        )
