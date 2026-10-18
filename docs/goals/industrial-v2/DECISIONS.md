# Industrial Vision V2 Decisions

## D-001: Keep V1 frozen and develop in a linked Worktree

- Decision: derive `goal/industrial-v2-advanced` from V1 freeze commit; never edit the V1 candidate in place.
- Evidence: V1 freeze report and Worktree audit on 2026-10-19.
- Cost if wrong: V2 changes would be harder to roll back and could invalidate the only known downloadable candidate.

## D-002: V2 extends fixed-red v1; it does not restore YOLO or WM8978

- Decision: use the user-confirmed `PROJECT_GOAL.md` as the V1 scope boundary and keep historical YOLO/WM8978 research out of V2 implementation dependencies.
- Evidence: `PROJECT_GOAL.md` section 2/4/5 and the pasted V2 Goal brief.
- Cost if wrong: scope drift and resource use could displace the verified fixed-red path.

## D-003: Default visual approval is limited to Stage C

- Decision: mark the user-authorized visual review as available for progression, while preserving model, RTL, TD, hardware and calibration gates.
- Evidence: user instruction in the current Goal turn.
- Cost if wrong: a visual result could advance without enough evidence; non-visual gates prevent that from becoming a hardware claim.
